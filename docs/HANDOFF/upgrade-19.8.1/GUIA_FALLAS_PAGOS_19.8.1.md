# Guía de fallas de pagos — upgrade 19.8.1

Para el día del upgrade y la primera semana. Cubre Dar (Cybersource), Eventos/boletería (ePay), inscripciones de
Rock (ePay) y los correos/recibos que disparan. Escrita el 2026-11-23 tras probar 18.1 y 19 lado a lado en local
(`PLAN_PRUEBAS_19.8.1.md` §16) y auditar el núcleo. **Todas las consultas son de solo lectura.**

## 1. Qué está probado y qué no

| Flujo | Código propio 18.1 → 19 | Probado en local (19 vs 18.1) | No se puede probar en local | Cómo se cierra |
|---|---|---|---|---|
| **Dar** `/dar` (bloque 1947, página 962) | Sin cambios (1 línea de tipo en el dashboard) | Página, modo, formulario, confirmación, fila Pending y su limpieza: **iguales** | El cobro contra Cybersource (secretos cifrados con la llave de prod) | Donación de **Q1** en prod (UPGRADE §7.3 paso 8) |
| **Eventos** `/eventos/evento/{slug}` (ePay) | Sin cambios | Boletos → asistentes → resumen (IVA, NIT) → control ePay → rechazo: **iguales**; orden queda `Failed`, se libera el cupo, se ofrece reintentar | El cobro aprobado en ePay y la factura FEL en Odoo | Primera compra real tras el upgrade, vigilada con §4 |
| **Inscripciones** de Rock (ePay en «Servicio de Navidad») | Personalizaciones del fork intactas (`RegistrationEntry.cs:5350` y `:5472`, `RegistrationService.cs:114`, región NIT/FEL) | Inscripción completa con la Test Gateway en la 19: transacción con la **misma forma** que las de prod de junio (lote, tipo, fuente, detalle, persona, entidad 258) | El cobro real con ePay | Primera inscripción pagada tras el upgrade, vigilada con §4 |
| **Núcleo** (cifrado, `GatewayComponent`, lotes, transacciones) | — | Auditoría de código: sin cambios en `GatewayComponent`, `FinancialBatchService`, SaveHooks; cifrado compatible (ver §3) | — | Preflight bloque 12 |

## 2. La falla más probable y la más grave: la llave de cifrado

Los secretos de Dar (`*SharedSecretBase64`, `RecaptchaApiKey`) y de ePay (`*MerchantPasswd`) son «Encrypted Text».
Se descifran con `DataEncryptionKey` del `web.config`. **Si al fusionar el `web.config` de la 19 la llave no queda
idéntica a la de la 18.1, todos los cobros fallan a la vez.** Es exactamente lo que pasa en local (otra llave).

- Síntoma en Dar: «Faltan configuraciones del bloque: … Shared Secret (Base64)».
- Síntoma en Eventos: «El pago no pudo procesarse…» en todos los intentos.
- Síntoma en inscripciones: mensaje de ePay de credenciales/configuración.
- Prevención: TI compara `DataEncryptionKey` y `PasswordKey` (y las `OldDataEncryptionKey*` si existen) entre el
  `web.config` viejo y el nuevo **sin mostrarlas** (p. ej. comparar el hash de cada valor). No se pasan a Claude.
- Detección: la donación de Q1 de Dar prueba la llave (es la misma para todos los secretos).
- Arreglo: corregir la llave en el `web.config` (reinicia el sitio). **No** re-escribir los secretos en la UI como
  arreglo: quedarían cifrados con la llave equivocada y en formato V2 (ver §3).

## 3. Cifrado de la 19 (resultado de la auditoría)

- La 19 lee la llave igual que la 18.1 y descifra los valores viejos por el mismo camino (`Encryption.cs`,
  `DecryptString` → camino V1 si no hay pie «V2»). Ninguna migración ni job re-cifra valores.
- La 19 **escribe** en formato nuevo V2 (AES + HMAC, pie de 2 bytes `0x56 0x32`). Consecuencias:
  - Un valor viejo cuyos 2 últimos bytes sean `0x56 0x32` se trataría como V2 y quedaría vacío (1 en 65 536).
    Revisado: **0 de 83** en la copia del 19-nov. El preflight (bloque 12) lo revisa en prod.
  - **Rollback:** todo secreto que se guarde de nuevo en la 19 (configuración de la pasarela, del bloque Dar,
    atributos cifrados) **no lo lee la 18.1**. El rollback del runbook restaura el `.bak`, así que no aplica; pero si
    se volviera a la 18.1 sin restaurar la BD, hay que re-capturar esos secretos.
  - Regla para la primera semana: **no** editar ni re-guardar la configuración de pasarelas ni del bloque Dar salvo
    que haga falta.

## 4. Síntoma → dónde mirar → qué hacer

### Dar (Cybersource)

Forma de una donación aprobada en prod (copia del 18-nov, 18.1): `Status = 'Approved'`, `StatusMessage = 'AUTHORIZED'`,
`ForeignKey` = `CYBS|IDEM=…|MODE=live|CUR=GTQ|RC=AUTHORIZED|REF=…`, lote «Cybersource Online Giving (GTQ) …»,
`FinancialGatewayId` vacío (normal: el bloque no tiene pasarela asignada) y sin entidad en el detalle. La de Q1 de la
19 debe verse igual (consulta 6.1). Si dice `MODE=test`, el bloque quedó en modo prueba: revisar «Use Live Mode».

| Síntoma | Causa probable | Dónde mirar | Qué hacer |
|---|---|---|---|
| «Faltan configuraciones del bloque: …» | Llave de cifrado (§2) o secreto vacío | Configuración del bloque 1947 | §2 |
| «Verificación de seguridad fallida…» | reCAPTCHA: token no llegó o el dominio no está en la llave | Consola del navegador; sello reCAPTCHA | En prod el dominio sí está autorizado; revisar que la llave del sitio no se haya cambiado |
| Rechazo de Cybersource (mensaje con código) | Tarjeta, AVS, antifraude | Consulta 6.1 (`StatusMessage`, `ForeignKey` con `RC=`/`MODE=`) y Business Center de Cybersource | Normal si es la tarjeta; si todos fallan, revisar §2 y el modo (debe ser Live) |
| 2 excepciones al fallar un cobro: `FinancialPaymentDetail.SaveHook.PostSave` («…Null debe tener un valor») y `DeletePendingTransaction` línea 1002 | **Defecto previo** (igual en 18.1): limpieza de la fila Pending sin lote | ExceptionLog | Ignorar; no deja filas sobrantes (consulta 6.2) |
| Cobro aprobado pero no llega el correo | Workflow 147 (correo) o SMTP | Workflow 147 y su log; Communication/ExceptionLog | Ver «Correos y recibos» |

### Eventos / boletería (ePay)

| Síntoma | Causa probable | Dónde mirar | Qué hacer |
|---|---|---|---|
| «El pago no pudo procesarse…» | Rechazo de ePay, o §2 | **El mensaje real de ePay no se guarda** (`PaymentService.cs:114-119` lo descarta, defecto previo). Ver logs de Rock (abajo) y el portal de ePay | Si son todos: §2. Si es uno: tarjeta |
| «Tu pago se está procesando…» y la orden queda en `Status = 5` (Charging) | Cobro hecho pero falló el registro final | Consulta 6.3 | **Conciliación manual**: buscar el cobro en ePay por `PaymentReference` antes de reintentar |
| Orden `Paid` sin factura | Odoo/FEL | `OdooStatus` en la consulta 6.3; addon `custom_event_sale_api` | Reintentar desde Odoo; no repetir el cobro |
| Error de comunicación con ePay | Red/SOAP | Rock Logs: `[EpayVisanetGateway]` / `[EpaySoapClient]` (avisos y errores); el plugin intenta reversa automática | Ver el log; confirmar en el portal de ePay si quedó cobro |

Para ver más detalle de ePay: *Admin → System Settings → Rock Logs*, nivel Warning (o Debug temporal) para la
categoría del plugin `EpayVisanetGateway`. Desactivarlo al terminar.

### Inscripciones de Rock (ePay)

| Síntoma | Causa probable | Qué hacer |
|---|---|---|
| El mensaje de ePay aparece en pantalla | Rechazo (el bloque sí lo muestra) | Normal si es la tarjeta |
| «Monto a pagar hoy must not be less than Q0.00» con un monto válido | **Defecto previo** (igual en 18.1): si la plantilla permite pago parcial, la regla compara contra «Q0.00» y no lo reconoce como número (`numberUtils.toNumberOrNull` solo quita `$`) | Configurar la plantilla/instancia con pago completo (sin «Minimum Initial Payment»). Hoy no afecta: la única con cobro exige pago completo |
| Nuevo en la 19: aviso de duplicado o «ya no hay cupo» antes de pagar | Funciones nuevas de upstream (antes del cobro) | Esperado |

### Correos y recibos (workflows)

- Dar lanza el workflow **147** «Correo de confirmación de donación» (`SendEmail`) y el **150** «Dar Recibo»
  (`WebRequest` a Odoo + `SendEmail`). Su Lava está en los campos de la acción (se sigue evaluando en la 19).
- Cambio de la 19: las acciones ya no evalúan Lava que venga **dentro del valor de un atributo** y descartan
  destinatarios con Lava. Síntoma: en el log del workflow, «…contains Lava and was not used» o «Email was not sent
  to a recipient address that contains Lava». Revisado: los atributos de 147 y 150 no tienen Lava en sus valores.
- Si no llegan correos de ningún tipo: transporte SMTP (no es de pagos).

### Validación de textos nueva de la 19

La 19 revisa al guardar nombres de lote, notas, nombre en la tarjeta, etc. (`DbContext.cs`, `AttributeValue.SaveHook`).
Con `EnableServerModelValidation = false` (default) solo deja entradas en el log («may not contain…»). **No activar
esa opción la primera semana**: con ella, esos guardados fallarían.

## 5. Antes de la ventana (checklist corto)

1. Preflight (`19.8.1_preflight_bd_prod.sql`): todo «OK», incluido el bloque 12.
2. TI confirma que `DataEncryptionKey`/`PasswordKey` del `web.config` nuevo son idénticas a las de la 18.1 (§2).
3. Anotar `MAX(Id)` de `FinancialTransaction`, `ExceptionLog` y `_com_vidareal_Events_Order` (consulta 6.0).
4. Tras arrancar: donación de Q1 (UPGRADE §7.3 paso 8) y consulta 6.1.

## 6. Consultas (solo lectura; correr en la BD de prod con la línea base de 6.0)

```sql
-- 6.0 Líneas base (anotar antes de quitar app_offline.htm)
SELECT (SELECT MAX(Id) FROM FinancialTransaction) AS MaxTx, (SELECT MAX(Id) FROM ExceptionLog) AS MaxExc,
       (SELECT MAX(Id) FROM _com_vidareal_Events_Order) AS MaxOrden, GETDATE() AS Ahora;

-- 6.1 Transacciones nuevas (Dar, Eventos, inscripciones). Reemplazar @baseTx.
DECLARE @baseTx int = 0;
SELECT t.Id, t.TransactionDateTime, t.Status, LEFT(t.StatusMessage, 80) AS Mensaje, g.Name AS Pasarela,
       t.BatchId, b.Name AS Lote, d.Amount, d.FeeCoverageAmount, et.Name AS Entidad, d.EntityId,
       LEFT(t.ForeignKey, 80) AS ForeignKey
FROM FinancialTransaction t
LEFT JOIN FinancialGateway g ON g.Id = t.FinancialGatewayId
LEFT JOIN FinancialBatch b ON b.Id = t.BatchId
LEFT JOIN FinancialTransactionDetail d ON d.TransactionId = t.Id
LEFT JOIN EntityType et ON et.Id = d.EntityTypeId
WHERE t.Id > @baseTx ORDER BY t.Id;

-- 6.2 Dar: filas Pending sobrantes (debe ser 0 salvo un cobro en curso)
SELECT Id, TransactionDateTime, Status FROM FinancialTransaction
WHERE Status = 'Pending' AND ForeignKey LIKE '%IDEM=%' AND TransactionDateTime > DATEADD(hour, -24, GETDATE());

-- 6.3 Órdenes de Eventos nuevas (0 Pending, 1 Paid, 2 Failed, 3 Refunded, 4 Cancelled, 5 Charging = conciliar)
DECLARE @baseOrden int = 0;
SELECT Id, EventId, Status, Total, FinancialTransactionId, PaymentReference, WantsInvoice, OdooStatus,
       FelSerie, FelNumero, CreatedDateTime
FROM _com_vidareal_Events_Order WHERE Id > @baseOrden ORDER BY Id;

-- 6.4 Errores nuevos agrupados (separar el ruido conocido de PLAN_PRUEBAS §14)
DECLARE @baseExc int = 0;
SELECT COUNT(*) AS N, MIN(CreatedDateTime) AS Desde, MAX(CreatedDateTime) AS Hasta,
       LEFT(REPLACE(Description, CHAR(10), ' '), 150) AS Descripcion
FROM ExceptionLog WHERE Id > @baseExc AND ParentId IS NULL
GROUP BY LEFT(REPLACE(Description, CHAR(10), ' '), 150) ORDER BY MIN(Id);
```

## 7. Defectos previos encontrados (no son del upgrade; corregir después)

1. Dar: limpieza de la fila Pending al fallar un cobro registra 2 excepciones (§4, Dar).
2. Eventos: `PaymentService.Charge` descarta el mensaje de error de ePay (`TODO` en `PaymentService.cs:118`).
3. ePay: los rechazos (código de respuesta) no se registran en ningún log; solo vuelven como texto.
4. Inscripciones: pago parcial en quetzales nunca valida (§4, Inscripciones).
5. Workflow 150 «Dar Recibo»: el token de la API de Odoo está en texto plano en la configuración de la acción
   `WebRequest`. Recomendación: rotarlo en Odoo y guardarlo en un atributo cifrado.
6. Dev: el workflow 150 apunta a la API de Odoo de **producción**; en una BD de dev, una donación aprobada emitiría
   un recibo real. Antes de probar Dar con secretos de sandbox en dev, desactivar ese workflow en la BD de dev.
