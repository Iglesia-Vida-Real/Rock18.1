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

> En local, el check-in de VidAventura se prueba **lado a lado** contra la 18.1: ver §15.

## 9. QREVENT (reservas dominicales y escáneres)

| # | URL | Qué hacer | Debe pasar | L | P |
|---|---|---|---|---|---|
| 9.1 | Página 860 «Registro Domingos App» | Reservar un horario | QR de la reserva | | |
| 9.2 | Página 863 «Domingos Scanner» | Escanear la reserva (cámara) | Marca ingreso; en el teléfono aparece «Bienvenido» (RealTime) | | |
| 9.3 | Página 862 «Configuracion Domingos» | Ver cupos y Métricas | Carga | | |
| 9.4 | Página 861 «qrs» (QR Scanner Evento) y 864 «Celebremos QR Check-in» | Abrir y permitir cámara | Carga sin errores, lista eventos | | |
| 9.5 | Página 847 «Lector QR» (externo) y 848 «Reporteria Eventos» | Abrir | Cargan (WebForms legacy) | | |
| 9.6 | 862 → pestaña «Servicios especiales» → «+ Nuevo servicio especial» | Crear un especial de prueba para hoy (MANUAL §4.3): nombre sin hora, lugares, puerta, visible | Aparece en «Programados» como «Nombre HH:mm h»; sale en la 860 y se puede reservar | ✅ 23-nov | |
| 9.7 | 862 → «Editar» del especial (o de un servicio de la semana) | Cambiar «La puerta abre a las» (p. ej. 2 h antes) y guardar; luego «Puerta normal» | La lista muestra «Puerta HH:mm a HH:mm»; la 863 acepta el QR dentro de esa ventana aunque falte más de 15 min para el inicio | ✅ 23-nov | |
| 9.8 | 862 → «Editar» → desmarcar «Mostrar en la app de reservas» (y en «Semana normal», la casilla «Visible en la app» de un horario) | Ocultar y volver a mostrar | Deja de salir en la 860 y no se puede reservar; quien ya reservó **sigue entrando** por la 863 y ve su QR; «Programados» muestra «Oculto en la app» | ✅ 23-nov | |
| 9.9 | 863 con un QR de un servicio cuya puerta aún no abre | Escanear antes de la apertura | Aviso ámbar «Esta reserva es del servicio de las HH:mm. La puerta abre a las HH:mm.»; no marca ingreso ni cuenta como intento inválido | ✅ 23-nov | |

> 9.6–9.9: funciones nuevas de reservas de noviembre de 2026 (`docs/qrevent/MANUAL_RESERVAS_DOMINGOS.md`). Requieren
> `Dev Tools/Sql/QREVENT_SundayService_SlotSettings.sql` en la BD (sin él, la 862 muestra un aviso azul y todo
> funciona con 15 min / 1 h 20 min / visible). En local: probado en 6229 el 2026-11-23 (antes, matriz completa en
> la 18.1 de reservas; `ESTADO_TRABAJO_RESERVAS.md`). En prod: crear el especial **oculto** y desactivarlo al
> terminar (smoke test de `DESPLIEGUE_RESERVAS_SERVICIOS_ESPECIALES.md` §4).

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
| 13.3 | Página 327 «System Phone Numbers» | Abrir | Lista de números del sistema (bloque Obsidian 2231 en Rock19Test, tras el job de UPGRADE §11.4). En prod: después de crear y correr ese job | | |
| 13.4 | Página 740 «Experience Administration» | Abrir | Lista de experiencias interactivas (bloque Obsidian 2232 en Rock19Test). En prod: ídem 13.3 | | |
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

---

## 15. Prueba comparativa de check-in VidAventura: 18.1 vs 19 (solo local)

Objetivo: que el check-in de VidAventura se vea y funcione **igual** que hoy en prod. Se recorre el mismo
flujo en dos sitios a la vez, con la misma BD de origen (bacpac de prod del 18-nov) y la misma preparación.

| | 18.1 (referencia = prod hoy) | 19.8.1 (upgrade) |
|---|---|---|
| URL | `http://localhost:6230` | `http://localhost:6229` |
| Código | worktree `Documents\GitHub\Rock18Base-wt` (commit de `hotfix-18.1`, desacoplado) | rama `Test_Update_18.1_a_19.8.1` |
| BD | `Rock18Base` (bacpac, aislada, sin migrar) | `Rock19Test` (bacpac, aislada, migrada) |
| «Impresora» | `127.0.0.1:9100` | `127.0.0.1:9101` |

**Preparación ya aplicada en las dos BDs** (`dev-isolation\preparar_prueba_checkin_vidaventura.sql`, idempotente):
- Familia **ficticia** «Familia PruebaUpgrade» (campus *Punto Ilumina Z.10*): Ana (adulta, móvil **99001919**),
  Delta (~2 años → *Descubridores*), Eco (~5 años → *Exploradores*), Foxtrot (~9 años → *Defensores*).
- Horario 35 «Check In - Prueba» activado: lunes a viernes, check-in abierto **09:00–21:00**. Probar en ese
  horario (fuera de él el kiosco dice que no hay check-in disponible: es lo esperado).
- Kiosco nuevo **«Kiosko Prueba Upgrade»** (Id 26), copia del «Kiosko Mostrador» con las 3 salas de Ilumina e
  impresión **desde el servidor**. El kiosco 12 real no se tocó.
- Impresora 14 apuntada a un listener local que guarda el ZPL en `dev-isolation\etiquetas_capturadas\`
  (`9100_*.zpl` = 18.1, `9101_*.zpl` = 19). **No se imprime nada.** El listener lo arranca Claude.

Para cada paso: hacerlo **primero en 6230 y luego en 6229**, y comparar. Anotar diferencias en la columna.

> **Un navegador (o perfil) por sitio.** Los dos sitios usan la cookie `.ROCK` en el host `localhost` y el navegador
> no separa cookies por puerto: iniciar sesión en uno cierra o pisa la del otro, y el estado del kiosco también se
> mezcla. 6230 solo acepta el host `localhost` (con `127.0.0.1` responde 400). Usar, por ejemplo, Chrome para
> 6230 y Edge (o una ventana InPrivate) para 6229; o, mientras esté abierto a la red local, entrar a 6229 por la IP de
> la PC de desarrollo (host distinto, cookies separadas; UPGRADE §15).
>
> **Recorrido del 2026-11-20.** Sitios levantados a las 08:07 (primera respuesta: 6229 en 57 s, 6230 en 73 s).
> Aislamiento verificado en las dos BDs: `AzureApiKey` y `AiApiKey` vacías; SendGrid, Twilio, WhatsApp y OneSignal
> `Active=False` con credenciales vacías; SMTP a `localhost`. Rock19Test tiene los 14 jobs activos que crearon las
> migraciones (UPGRADE §5b), inertes por `RunJobsInIISContext=False` en los dos `web.config`.
> Líneas base de `ExceptionLog`:
>
> | BD | Antes del arranque | Después del arranque (todo ruido conocido) |
> |---|---|---|
> | Rock18Base | 1630286 | **1630305** |
> | Rock19Test | 1630379 | 1630404 → **1630439** tras los reinicios de ~08:35 para abrirlo a la red local (UPGRADE §15) |
>
> En el arranque de la 19 aparecen además `Cms/FileManager.ascx` y `Reporting/ServiceMetricsEntry.ascx`: páginas
> 433 y 451, que arreglan los jobs 222 y 226 (UPGRADE §11.2); no son regresión del recorrido.

| # | Pantalla / URL | Qué hacer | Qué comparar entre 6230 y 6229 | Diferencias |
|---|---|---|---|---|
| C1 | `/checkin` (Admin del kiosco) | Kiosco «Kiosko Prueba Upgrade», tipo «Ilumina(VidAventura)», área «VidAventura» → Iniciar | Tema VidAventura (fondo, globos, colores, fuentes), textos en español, lista de kioscos (filtrada por permiso), botón «Iniciar» | ✅ 23-nov (Claude): igual. Tema VidAventura, kiosco 26 e Ilumina seleccionables. El usuario ya lo había probado también en iPad con la app Rock Check-in e impresora real (20-nov, 2 check-ins en Rock19Test) |
| C2 | Welcome | Ver pantalla de inicio | Fondo, logo, botón de inicio, sonido de toque, botón de cerrar sesión del kiosco | ✅ igual (fondo, logo, «Iniciar»); sonido no verificable desde el navegador de Claude |
| C3 | Search | Buscar `99001919` (y luego `PruebaUpgrade`) | Teclado numérico, mensajes, tiempo de respuesta | ✅ igual: `99001919` encuentra «Familia PruebaUpgrade» |
| C4 | Family Select | Elegir «Familia PruebaUpgrade» (si aparece la lista) | Botones de familia (`FamilyLavaTemplate`) | ✅ igual |
| C5 | Person Select (familia) | Ver a Delta, Eco y Foxtrot con su sala y horario sugeridos | Sala asignada por edad (Descubridores / Exploradores / Defensores), fotos, el texto «Count: N» junto a la sala (**en la 19 puede perder el margen izquierdo**, ver UPGRADE §12), Ana no elegible | ✅ igual en las dos: muestra Ana, Foxtrot y Eco; **Delta no aparece en ninguna** (no es del upgrade; revisar la edad/sala de Descubridores si se quiere usar Delta) |
| C6 | Time Select / Group / Location | Si pregunta: «Check In - Prueba» | Autoselección del horario (personalización nuestra), textos | ✅ igual: Eco va directo a Exploradores; a Foxtrot (~9 años) las dos le preguntan grupo (Exploradores / Defensores) |
| C7 | Success | Confirmar | Mensaje de éxito (`SuccessLavaTemplate`), código de seguridad de 3 caracteres, globos/sonido | ✅ igual: «Confirmación de check-in» con los dos niños y su sala |
| C8 | Etiquetas | (las captura el listener) | Avisar a Claude: compara `9100_*.zpl` vs `9101_*.zpl` (contenido, campos, códigos; se ignoran código de seguridad y hora) | ✅ **idénticas byte a byte** (salvo el código de seguridad) en las 2 etiquetas de Foxtrot (niño + ticket de padre). Las dos versiones mandan 4 etiquetas. La impresora falsa pisaba archivos que llegaban en el mismo milisegundo: corregido (contador en el nombre) |
| C9 | Repetir C3–C7 con Delta | Intentar check-in de nuevo | **Bloqueo de doble check-in** (personalización nuestra): mismo mensaje en las dos | ✅ 19: «Advertencia — Las siguientes personas ya están registradas actualmente: Eco PruebaUpgrade» (se probó con Eco) |
| C10 | Check-in Manager `/checkinmanager` | Elegir campus/área de Ilumina; ver las 3 salas | Roster: los 3 niños en su sala. Roster Obsidian en la 19: los 3 modales en español como en 18.1 (UPGRADE §14.6); el resto de textos del Roster en inglés en ambas. Comparar también el tema (`RockManager` vs `RockManagerNextGen`) en PC y móvil (UPGRADE §14.9b) | ✅ 19: Roster con Foxtrot «Present», código y sala. Comparación visual del tema pendiente (§14.9b) |
| C11 | Check-in Manager > persona | Abrir a Delta | Perfil (PersonLeft), botón WhatsApp visible (**no enviar**), historial | ✅ 19: perfil, familia e «Historial de asistencia». WhatsApp: el botón sale solo junto a un teléfono con mensajería habilitada (igual en 18.1); con el móvil de Ana habilitado temporalmente, abre «Nuevo Mensaje de WhatsApp» / «Enviar». **No se envió** (0 comunicaciones); el teléfono se devolvió a como estaba |
| C12 | Check-in Manager > Live Metrics | Abrir | Conteos por sala | ✅ 19: tras elegir la configuración en «Configuración», muestra los conteos (0 presentes tras las salidas) |
| C13 | Checkout desde el kiosco | `/checkin` → buscar `99001919` → acción «Check Out» → Eco | Pantallas de check-out (Action Select, Check Out Person Select, Check Out Success) | ✅ 19: Action Select → «Registrar Salida» → «Eco PruebaUpgrade fue retirado de Exploradores…» |
| C14 | Checkout desde el Manager | Roster → check-out de Foxtrot | Funciona; modal con título «Confirmar» y botón «Registrar Salida» en las dos; el nombre del niño se ve completo | ✅ 19: «Check Out» (en el filtro «Presente») sale **sin modal** cuando hay un solo horario; el modal «Confirmar / Registrar Salida» aparece solo con varios horarios. La 18.1 hace lo mismo (`Roster.ascx.cs`: modal solo si `scheduleIds.Count > 1`) |
| C15 | Página 852 «Checkin Pendientes» (interno) | Abrir | Lista de presentes (CheckInOutView, bloque nuestro) igual en ambas | ✅ igual en las dos: «No se pudo determinar el Check-in Configuration actual» (no es del upgrade) |
| C16 | Alta de familia desde el kiosco (validación nueva de textos de la 19, UPGRADE §14.5) | Modo supervisor (PIN) → buscar `PruebaTildes` (sin resultados) → «Agregar familia». Adulta: nombre **Begoña**, apellido **Peña O'Connor**, móvil `99002020`. Niños: **Iñaki** (nacido hace ~5 años) y **Zoë María-José** (~9 años), mismo apellido | Se guarda en las dos; los nombres se ven igual (tildes, ñ, ü, apóstrofo y guion) en la familia, en la selección de personas y en el Roster | |
| C17 | Editar esa familia desde el kiosco | Cambiar el apellido a **D'Ávila Ñúñez** y guardar | Se guarda en las dos | |
| C18 | Check-in de Iñaki y Zoë | Flujo C3–C7 con `99002020` | Etiqueta capturada con los nombres bien escritos (comparar `9100_*` vs `9101_*`: acentos en UTF-8) | |
| C19 | (Negativo, opcional) Alta con nombre **Prueba&lt;b&gt;** o **{{ Prueba }}** | Intentar guardar | **Esperado distinto:** la 18.1 lo acepta; la 19 lo rechaza (validación nueva, por diseño). Anotar el mensaje que muestra la 19 | |
| C20 | PIN de supervisor (UPGRADE §14.8) | Teclear un PIN equivocado 2–3 veces y luego el correcto | Entra con el correcto en las dos. **No** llegar a 10 fallos (bloquearía el PIN 10 min en esa versión) | |

Al terminar: avisar a Claude para comparar las etiquetas y revisar el `ExceptionLog` de **las dos** BDs
(líneas base: la tabla del recorrido del 2026-11-20, arriba. Las del 2026-11-19 eran Rock18Base 1630266 y
Rock19Test 1630350).

**Después de la prueba (lo hace Claude):** detener los dos IIS Express y el listener; restaurar
`checkin-theme.css` con `git checkout`; dejar o borrar el worktree y `Rock18Base` según decida el responsable.

---

## 16. Recorrido del 2026-11-23 (Claude, local, 6229 vs 6230)

Sesión iniciada por el responsable; Claude recorrió el plan salvo §6 Dar (lo prueba el responsable). Línea base
`ExceptionLog` de Rock19Test: **1630470**.

**Check-in (§15):** C1–C15 hechos; resultado en la tabla de §15. Sin diferencias de comportamiento entre 18.1 y 19.
Etiquetas idénticas byte a byte (salvo el código de seguridad). Pendientes C16–C20: necesitan el PIN de supervisor
(lo teclea el responsable; Claude no introduce PINs ni contraseñas).

**Jobs post-actualización (UPGRADE §11.3), ensayados en Rock19Test** con «Run Now» (respaldo previo:
`Rock19Test_antes_jobs_2026-11-23.bak`, verificado):

| Orden | Jobs | Resultado |
|---|---|---|
| 1 | 231, 233, 232 (MIME de imágenes, redes sociales) | OK en segundos; se autoeliminaron |
| 2 | 220, 221, 225 (índices), 228 (achievements), 230 (conexiones) | OK en < 10 s; índices `IX_Status_Name_BatchStartDateTime_BatchEndDateTime`, `IX_CommunicationId`, `IX_UnsubscribeDateTime_SendDateTime` creados |
| 3 | 222 → 227 (File Manager), 223 (Registration Entry), 226 (Service Metrics) | OK; página 433 = bloque 2233 «File Asset Manager», 451 = bloque 2234 «Service Metrics Entry» (Obsidian); BlockTypes viejos borrados; ningún archivo del repo tocado (los `.ascx` ya no existían) |

Quedan 224 y 229 (jobs normales nuevos, no de actualización). **Cero excepciones** durante los jobs.

**Barrido de páginas** (cada página cargada con su JavaScript, buscando errores visibles, de Lava y de bloque):

| Grupo | Páginas | Resultado en la 19 |
|---|---|---|
| §1 Entrada | `/page/3`, `/acceso`, `/Login`, `/NewAccount`, 964, `/access-learn`, 1068, 1073, 1074 | Cargan. 964 redirige a `/Login` (igual en 18.1) |
| §2 Personas | `/Person/{Id}`, `/people/merge`, `/crm/duplicados`, 859, `/vrencuesta` | Cargan |
| §2 (no prueba) | `/person/{Id}/contributions`, `/FamilyPreRegistration` | Error de **permiso** en 18.1 y 19 por igual (no es del upgrade) |
| §2 (no prueba en local) | `/labienvenida`, `/vidaventura`, `/somosjovenes`, `/Navidad`, `/RegistroCCIZ10` | Exigen https (302 a `https://localhost`); probar en prod |
| §3 Eventos | `/eventos/calendario`, `/mis-entradas`, `/scanner`, `/reporteria`, 983, `/eventos/preguntas` | Cargan |
| §4–5 QR y Wallet | `/qr`, `/qr/uso`, `/qr/reporteria`, `/wallet/plantillas`, 857 | Cargan; Wallet avisa «Apple Wallet no está configurado» (esperado en local: no hay certificado) |
| §8–9 | 856, 860–864, 847, 848 | Cargan |
| §10–11 | 1071, 997, 1070, `/learn`, 1072, 1064, 1019, 1023, 1030, 1059, `/reportequieroservir`, 1008 | Cargan, sin errores de Lava |
| §12–13 | Gateways (lista, ePay 7, Test 2), transportes, workflows 86/166/208/209/210, `/admin/plugins`, 750, 758, 790, `MinistryPassTemplates`, 842, 327, 740, 433, 451 | Cargan |

`ExceptionLog` después de todo (check-in, jobs y ~70 páginas): solo las 6 entradas de 433/451 **de antes** de
correr los jobs. Nada más.

**Hallazgos:**
- `Rock.Blocks.dll` de 6229 es del 23-nov (reservas) y `Rock.dll`, `Rock.ViewModels.dll`, `Rock.Rest.dll` del 19-nov.
  Hoy funciona (los cambios de reservas solo tocan `Rock.Blocks`), pero el kit del día **debe** salir de un build
  completo desde un solo commit (`build-all.ps1 -FullObsidian`) y probarse en 6229 antes de llevarlo a prod.
  **Resuelto el mismo día** (ver «Kit» abajo).
- ePay en Rock19Test: `Live=False` (modo prueba) y credenciales live vacías. Los cobros de §3.2, §6 y §7.1 los
  hace el responsable con tarjetas de prueba del proveedor.
- Nuevo `Dev Tools/Upgrade/19.8.1_preflight_bd_prod.sql`: revisión de solo lectura de la BD de prod (versión y nivel
  de compatibilidad de SQL, espacio, respaldos, migraciones y plugins contra la copia probada, script de reservas).
  Probado contra Rock18Base: todo OK.

**Kit (mismo día, 14:20–14:45):**
- Respaldo previo de `RockWeb\Bin` y `RockWeb\Obsidian` fuera del repo (`respaldos_kit\antes_build_2026-11-23\`).
- `build-all.ps1 -FullObsidian` + `npm run build` de `Rock.JavaScript.Obsidian.Reporting`: 0 errores de MSBuild, los 8
  plugins OK, npm con código 0 (solo avisos de sourcemap de rollup). Las DLL del fork y de los plugins quedan del
  mismo build (19.8.1, 14:22–14:25). Bundles: todos regenerados salvo `obsidian-core.js`/`obsidian-vendor.js`
  (idénticos a la salida de webpack, que no reescribe si no cambian), los 4 restos de controles que upstream eliminó
  (sin referencias) y `Reporting` (recompilado, byte a byte igual).
- `translatorDashboard.obs.js` (versionado en `Plugins`) cambia al compilar con la 19: solo helpers de Babel. Se
  commiteó (`0c2b04675e`).
- Prueba rápida en 6229 con línea base `ExceptionLog` **1630511** (lo anterior: arranques durante el build, todo ruido
  conocido de §14): check-in de Eco y Foxtrot (Foxtrot pide grupo, igual que antes), 4 etiquetas idénticas byte a byte
  a las de la mañana salvo el código de seguridad, salida desde el kiosco, Roster del Check-in Manager, reservas
  860–864, 433, 451, 327, 740, QR, Eventos, Wallet, plugins, Data Toolkit. **0 excepciones nuevas.**
- Kit: `kit_19.8.1_2026-11-23\` fuera del repo, armado con `Dev Tools/Upgrade/New-KitUpgrade.ps1` (3556 archivos,
  550 MB, commit `c190618011`). Armado dos veces (a mano y con el script): manifiestos idénticos.

**Pendiente (responsable):** §6 Dar; cobros ePay de prueba (§3.2, §7.1); C16–C20 (PIN); comparación visual del tema
del kiosco y del Check-in Manager (§14.9).
