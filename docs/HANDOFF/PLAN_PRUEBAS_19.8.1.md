# Plan de pruebas — upgrade a Rock 19.8.1

> Checklist por módulo para recorrer **dos veces**: en local (`http://localhost:6229`, BD `Rock19Test`) y el día
> real en prod (`https://personas.vidareal.tv`, y `https://q.vidareal.tv` para QR). Donde dice `{base}` va
> uno u otro. Marcar `L` (local) y `P` (prod). Contexto en `UPGRADE_19.8.1.md`; dónde vive cada cosa, en
> `INVENTARIO_DESARROLLOS_VR.md`.
>
> **Reglas:**
> - En local nada sale: transportes, gateways y jobs están aislados. **No activar** WhatsApp, SMS ni gateways.
> - En prod, los cobros reales se hacen solo donde se indica, con monto mínimo.
> - Check-in, VidAventura y Somos.Jóvenes se prueban con **personas de prueba**. Se verifica que el sistema
>   funcione; no se revisan datos de menores reales.
> - Si algo falla, anotar la URL y la hora. Al terminar se revisa `ExceptionLog` (§14).

**Antes de empezar (local):** el sitio debe haberse reiniciado después del cambio de `Allowed Frame Domains`
(UPGRADE §5c; el «Borrar caché» de Rock está dentro de un modal, que es justo lo que fallaba). **No correr jobs.** Las páginas que dependen de los jobs 222/223/226/227 están
marcadas ⏸ y se prueban después de correrlos.

---

## 1. Entrada y sesión

| # | URL | Qué hacer | Debe pasar | L | P |
|---|---|---|---|---|---|
| 1.1 | `{base}/page/3` | Iniciar sesión con usuario y contraseña | Entra; se ven el CSS y el HTML de marca (bloques 2216/2217). En local el logo de `/Content/` da 404 (esperado) | | |
| 1.2 | `{base}/acceso` | Passwordless por teléfono y por email (en local el código llega a Papercut; por SMS no sale) | Selector Email/Teléfono, código de 6 dígitos numérico, verificación con foto/edad si hay varias coincidencias | | |
| 1.3 | `{base}/Login` | Login del sitio externo | Funciona | | |
| 1.4 | `{base}/NewAccount` y página 964 «Crear Cuenta» | Abrir el formulario (no crear en prod) | Textos en español, captcha visible | | |
| 1.5 | `{base}/access-learn`, páginas 1068 / 1073 / 1074 | Abrir | Cargan con su HTML de LMS | | |
| 1.6 | Cualquier página interna | Abrir un modal (p. ej. Configuración de bloque) | El modal **no** sale en blanco (en local requiere el arreglo §5c) | | |

## 2. Personas y familias

| # | URL | Qué hacer | Debe pasar | L | P |
|---|---|---|---|---|---|
| 2.1 | `{base}/Person/{Id}` (persona de prueba) | Abrir perfil, editar y guardar sin cambios | Sin errores | | |
| 2.2 | Editar dirección | País Guatemala | Cascada Departamento → Municipio (WebForms y Obsidian) | | |
| 2.3 | `{base}/person/{Id}/contributions` | Ver pestaña de donaciones | GivingOverview con KPIs por moneda | | |
| 2.4 | `{base}/people/merge` | Combinar dos personas de prueba (solo local) | Agregar por Person ID funciona | | |
| 2.5 | `{base}/crm/duplicados` | Abrir | Lista de pares | | |
| 2.6 | Página 859 «Family Hub» / `{base}/vrencuesta` | Abrir con usuario de prueba | Muestra la familia | | |
| 2.7 | `{base}/FamilyPreRegistration`, `/labienvenida`, `/vidaventura`, `/somosjovenes`, `/Navidad`, `/RegistroCCIZ10` | Abrir (enviar solo en local) | Textos en español, captcha, fecha DD/MM | | |

## 3. Eventos (boletería)

| # | URL | Qué hacer | Debe pasar | L | P |
|---|---|---|---|---|---|
| 3.1 | `{base}/eventos/calendario` | Abrir | Lista eventos visibles | | |
| 3.2 | `{base}/eventos/evento/{Slug}` | Compra completa: boletos → asistentes → NIT → pago ePay **Test** (local) / monto mínimo (prod) | Orden pagada, correo con boleto (local: Papercut), factura FEL en Odoo (solo prod) | | |
| 3.3 | `{base}/eventos/mis-entradas` | Ver el boleto | QR, PDF y botón Wallet | | |
| 3.4 | `{base}/eventos/scanner` | Escanear el boleto de 3.2 | Check-in OK; el segundo escaneo avisa duplicado | | |
| 3.5 | `{base}/eventos/reporteria` | Abrir y reenviar correo | Datos de 3.2 visibles | | |
| 3.6 | Página 983 «Administrar Eventos», `{base}/eventos/preguntas` | Abrir y editar un evento de prueba | Guarda | | |

## 4. QR

| # | URL | Qué hacer | Debe pasar | L | P |
|---|---|---|---|---|---|
| 4.1 | `{base}/qr` | Lista | Carga | | |
| 4.2 | `{base}/qr/codigo/{QrCodeId}` | Crear/editar un QR de prueba, descargar SVG y PNG | Imagen correcta; short link con el dominio `q.vidareal.tv` (trampa 7) | | |
| 4.3 | `{base}/qr/uso`, `/qr/reporteria` | Filtro por código | Métricas | | |
| 4.4 | `https://q.vidareal.tv/<token>` (solo prod) | Abrir un QR existente | Redirige | | |

## 5. Wallet

| # | URL | Qué hacer | Debe pasar | L | P |
|---|---|---|---|---|---|
| 5.1 | `{base}/wallet/plantillas` | Abrir y previsualizar | Carga | | |
| 5.2 | Mis Entradas → «Agregar a Apple/Google Wallet» | Descargar el pase (en local no hay certificado: se espera error controlado) | Prod: el pase se instala | | |
| 5.3 | Página 857 «VidAventura Check-in» (Pase Digital) | Abrir con persona de prueba | Tarjeta con QR | | |

## 6. Dar

| # | URL | Qué hacer | Debe pasar | L | P |
|---|---|---|---|---|---|
| 6.1 | `{base}/dar` | Llenar el formulario (local: sin cobrar; prod: donación mínima solo si se acuerda) | Header/Footer propios, montos multi-moneda, reCAPTCHA | | |
| 6.2 | Página 963 «DashBoard Donaciones» | Abrir y exportar | Carga | | |
| 6.3 | `{base}/finance/transactions` y detalle de una transacción | Abrir | Totales por moneda | | |

## 7. Inscripción nativa de Rock (RegistrationEntry, Obsidian)

| # | URL | Qué hacer | Debe pasar | L | P |
|---|---|---|---|---|---|
| 7.1 | `{base}/Registration/{Slug}` de una inscripción de prueba | Inscribir con pago (local: gateway Test) | Pasos en español, NIT/factura, sección de duplicados nueva de la 19 | | |
| 7.2 | Misma inscripción llena | Intentar inscribir | Mensaje «No se pudo completar la inscripción porque ya no hay cupo.» | | |
| 7.3 | `{base}/web/event-registrations/{Id}` | Lista y detalle de la inscripción | Saldo sin FeeCoverage | | |
| 7.4 | ⏸ después del job 223 | Repetir 7.1 | Igual | | |

## 8. Check-in (kiosco WebForms y Check-in Manager)

| # | URL | Qué hacer | Debe pasar | L | P |
|---|---|---|---|---|---|
| 8.1 | Sitio «Rock Check-in» (Admin del kiosco) | Configurar kiosco y áreas | Tema **VidAventuracheckin** (globos, sonidos) | | |
| 8.2 | Welcome → búsqueda → familia → persona → horario → éxito | Check-in de persona de prueba | Horario autoseleccionado si faltan < 15 min; etiqueta (impresora local deshabilitada en dev) | | |
| 8.3 | Repetir 8.2 con la misma persona | | Bloquea el doble check-in | | |
| 8.4 | Check-out | | Funciona | | |
| 8.5 | Página 852 «Checkin Pendientes» | Abrir | Lista y check-out manual | | |
| 8.6 | Página 856 «Asistencia» | Check-in desde perfil | Sugiere campus | | |
| 8.7 | Check-in Manager (sitio 5) | Abrir Room Manager (Roster), persona, LiveMetrics | Tema RockManagerNextGen; Roster nuevo (Obsidian, **en inglés**: personalización perdida) | | |
| 8.8 | Check-in Manager > persona | Botón de aviso por WhatsApp | El botón aparece; **no enviar** en local | | |
| 8.9 | Sitio 10 «Next-gen Check-in» | Abrir | Carga (no se usa en producción hoy) | | |

## 9. QREVENT (reservas dominicales y escáneres)

| # | URL | Qué hacer | Debe pasar | L | P |
|---|---|---|---|---|---|
| 9.1 | Página 860 «Registro Domingos App» | Reservar un horario | QR de la reserva | | |
| 9.2 | Página 863 «Domingos Scanner» | Escanear la reserva (cámara) | Marca ingreso; en el teléfono aparece «Bienvenido» (RealTime) | | |
| 9.3 | Página 862 «Configuracion Domingos» | Ver cupos y Métricas | Carga | | |
| 9.4 | Página 861 «qrs» (QR Scanner Evento) y 864 «Celebremos QR Check-in» | Abrir y permitir cámara | Carga sin errores, lista eventos | | |
| 9.5 | Página 847 «Lector QR» (externo) y 848 «Reporteria Eventos» | Abrir | Cargan (WebForms legacy) | | |

## 10. Páginas externas de esta semana y sitio público

| # | URL | Qué hacer | Debe pasar | L | P |
|---|---|---|---|---|---|
| 10.1 | Páginas 1071 «Pagina de Cursos», 997 «Learn Demo», 1070, `/learn` | Abrir | Igual que en 18.1 (en local las imágenes de `/Content/` dan 404) | | |
| 10.2 | 1072/1064 «Encuesta Iglesia Vida Real» | Abrir | Redirección correcta | | |
| 10.3 | 1019–1059 (reportes de la ruta de asimilación), 1023/1030 VidAventura | Abrir | Lava sin errores | | |
| 10.4 | `/reportequieroservir` | Abrir | Header/Footer propios | | |
| 10.5 | Video de Vimeo en una página externa | Reproducir | **Local: no reproduce (restricción de dominio de Vimeo, esperado).** Prod: reproduce | | |

## 11. Traductor

| # | URL | Qué hacer | Debe pasar | L | P |
|---|---|---|---|---|---|
| 11.1 | Página 1008 «VidaReal Translator» | Abrir dashboard | Configuración y estadísticas | | |
| 11.2 | Página externa con el selector de idioma | Cambiar a inglés y volver | Traduce; textos de Vue en `notranslate` no se congelan (trampa 4) | | |

## 12. WhatsApp y comunicaciones (sin enviar)

| # | URL | Qué hacer | Debe pasar | L | P |
|---|---|---|---|---|---|
| 12.1 | Admin > Communications > Transports | Abrir «WhatsApp Business Cloud» | Aparece con sus atributos; **no activar** en local | | |
| 12.2 | Workflow 210 (VidAventura cumpleañeros) > editar acción | Abrir la acción «WhatsApp Send» | Formulario carga | | |
| 12.3 | Nueva comunicación (correo) | Llegar al paso de revisión sin enviar | Validaciones en español | | |
| 12.4 | Prod | Una comunicación real de prueba a un número interno, si se acuerda | Llega | | |

## 13. Administración, plugins de terceros y páginas tocadas por la 19

| # | URL | Qué hacer | Debe pasar | L | P |
|---|---|---|---|---|---|
| 13.1 | Páginas MailChimp, Acme Certificates, Data Toolkit (export/import), Lava Tester, Ministry Pass | Abrir cada una | Cargan sin error | | |
| 13.2 | Admin > Rock Shop > Installed Plugins | Revisar | Anotar si hay actualizaciones para la 19 | | |
| 13.3 | Página 327 «System Phone Numbers» | Abrir | **Hoy falla** (bloque huérfano, UPGRADE §11.4) hasta correr el job propuesto | | |
| 13.4 | Página 740 «Experience Administration» | Abrir | **Hoy falla** (ídem) | | |
| 13.5 | ⏸ Página 433 «File Manager» | Abrir después de los jobs 222/227 | File Asset Manager (Obsidian) | | |
| 13.6 | ⏸ Página 451 «Weekly Metrics» | Abrir después del job 226 | Service Metrics Entry Obsidian | | |
| 13.7 | Admin > Finance > Gateways | Abrir ePay y Cybersource | Configuración carga (no activar en local) | | |
| 13.8 | Workflows con acciones de plugins: 86, 166, 208, 209, 210 | Abrir el tipo de workflow | Las acciones muestran su configuración | | |

---

## 14. Revisión del `ExceptionLog` al terminar

Línea base en Rock19Test antes del recorrido: **`ExceptionLog.Id` máximo = 1630320** (2026-11-19 13:0x).

```sql
-- Excepciones nuevas desde el inicio del recorrido, agrupadas
SELECT LEFT(ExceptionType, 60) Tipo, LEFT(REPLACE(Description, CHAR(13), ' '), 150) Descripcion,
       COUNT(*) Veces, MIN(Id) PrimerId, MAX(PageUrl) Pagina
FROM ExceptionLog
WHERE Id > 1630320 AND ParentId IS NULL
GROUP BY LEFT(ExceptionType, 60), LEFT(REPLACE(Description, CHAR(13), ' '), 150)
ORDER BY MIN(Id);
```

Ruido conocido que no cuenta como regresión: `AIAgentSessionAnchor` (trampa 2); `.ascx` que no existen de
`eventos.ascx.cs`, `TestCybersource`, Apollos, `rocks_pillars`, `CheckInOutViews`, `SundayServiceScanner`,
`FamilyHub.ascx`, `FamilyPreRegistration2`, `SnippetTypeList`, `PersistedDataViewList`, `RegistrationEntry.ascx`;
OpenID Connect sin https (local); «Store Key too long» (local); `_css-overrides.less` (UPGRADE §12, hasta arreglarlo).
En prod la línea base se toma justo antes de quitar `app_offline.htm`.
