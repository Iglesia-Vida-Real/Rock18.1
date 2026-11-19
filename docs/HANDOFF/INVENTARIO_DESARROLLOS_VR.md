# Inventario de desarrollos propios de Vida Real (código + BD)

> Hecho el 2026-11-19 para el upgrade 18.1 → 19.8.1 (`docs/HANDOFF/UPGRADE_19.8.1.md`). Sirve también
> como mapa general: **dónde vive cada cosa nuestra y cómo se prueba**. La checklist de pruebas está en
> `PLAN_PRUEBAS_19.8.1.md`.
>
> - **Código:** rama `Test_Update_18.1_a_18.8` contra el tag upstream `19.8.1` (`85705ceb0b`).
>   `git diff --diff-filter=A` = 494 archivos agregados; `--diff-filter=M` = 144 archivos upstream modificados.
> - **BD:** `Rock19Test` = copia de prod del 2026-11-18 (bacpac) ya migrada a 19.8.1. Las consultas fueron
>   solo `SELECT`. No se listan datos de personas.
> - Complementa `docs/HANDOFF/CAMBIOS_VS_UPSTREAM.md` (riesgo por archivo) y los `CHANGES.md` de cada carpeta.

---

## 1. Resumen

| Área | Qué hay | ¿Carga en la 19? |
|---|---|---|
| Bloques Obsidian propios | 26 BlockTypes (Eventos 7, Wallet 2, QR 4, QREVENT 5, Dar 2, FamilyHub 1, LayoutCustom 2, Security 1, Crm 1, Translator 1) | ✅ los 26 resuelven (§5) |
| Bloques WebForms propios | `Asistencia`, `QREVENT`, `SundayService`, `CheckIn/CheckInOutView` | ✅ `.ascx` presentes |
| Bloques upstream modificados | Check-in (41 archivos), PersonMerge, GivingOverview, RegistrationDetail, RegistrationInstanceRegistrationList, TransactionDetail/List; Obsidian: RegistrationEntry, Login, AccountEntry, FamilyPreRegistration | ✅ todos siguen existiendo en 19.8.1 |
| Plugins propios (8 DLL) | Events 25, Wallet 16, Qr 7, DupDetect 5, Translator 4 migraciones; Odoo, ePay, Cybersource sin migraciones | ✅ compilan y sus tipos resuelven |
| Plugins de terceros (Rock Shop) | MailChimp + WorkflowExtensions (BEMA), AcmeCertificate + DataToolkit (Blue Box Moon), LavaTester (Central AZ), MinePass, MinistryPass | ✅ `.ascx` y tipos resuelven; sin excepciones al arrancar (§3) |
| Binarios sin fuente | `Plugins/Qrgenerador`, `Plugins/TwilioOverrideWhatsApp` | ⚠️ sus DLL **no están en `Bin`**: sus acciones de workflow no cargan ni en 18.1 ni en 19 (§4.4) |

---

## 2. Código

### 2.1 `CHANGES.md` (33 versionados)

`git ls-files '*CHANGES.md'`. Los que describen funcionalidad:

| Archivo | Cubre |
|---|---|
| `CHANGES.md` (raíz) | Historial general, archivos nuevos/modificados, choque de namespace del upgrade 19 |
| `Rock/CHANGES.md`, `Rock/Security/Authentication/CHANGES.md` | Core: passwordless, SMS, multi-moneda, direcciones; OTP numérico, portón `/acceso` |
| `Rock.Blocks/{Dar,Event,FamilyHub,LayoutCustom,QREVENT,Security}/CHANGES.md` | Bloques de servidor por módulo |
| `Rock.JavaScript.Obsidian.Blocks/CHANGES.md` y `src/{Communication,Dar,Engagement,Finance,QREVENT,QREVENT/vendor,Security,Security/AccountEntry,Security/Login}/CHANGES.md` | Frontend Obsidian por módulo |
| `Rock.JavaScript.Obsidian/Framework/Controls/CHANGES.md` | datePicker, datePartsPicker, rockValidation, addressControl |
| `Rock.WhatsApp/CHANGES.md` | Transporte WhatsApp, acción «WhatsApp Send», webhook, OTP |
| `Plugin.{CybersourceInlineRestGateway,EpayVisanetGateway,VidaRealTranslator}/CHANGES.md` | Gateways y traductor |
| `RockWeb/Blocks/{CheckIn,Crm,Event,Finance}/CHANGES.md` | WebForms upstream modificados |
| `RockWeb/Scripts/CHANGES.md`, `RockWeb/Themes/CHANGES.md`, `RockWeb/Themes/VidAventuracheckin/CHANGES.md` | datePicker.js, Blank.aspx responsivo, tema del kiosco |
| `Dev Tools/Sql/CHANGES.md` | Scripts SQL de SundayService, aislamiento de BD dev |

### 2.2 Bloques Obsidian propios (`Rock.Blocks/` + `Rock.JavaScript.Obsidian.Blocks/src/`)

Bundle: `RockWeb/Obsidian/Blocks/<Carpeta>/<clase camelCase>.obs.js` (DLL y bundle del mismo build van juntos).
**Ojo:** 8 clases no declaran `BlockTypeGuid` (marcadas «—»): su GUID cambia en cada BD; cruzarlas por
`EntityType.Name`.

| Clase | BlockTypeGuid | Página(s) en prod (Id, sitio) | Cómo se prueba |
|---|---|---|---|
| `Rock.Blocks.Eventos.EventAdmin` | `b2e4d8f1-…-200000000001` | 983 «Administrar Eventos» (interno) | Crear/editar evento, boletos, promos |
| `Rock.Blocks.Eventos.EventCheckout` | `…0002` | 985 (externo) `/eventos/evento/{Slug}`, `/eventos/checkout/{EventId}` | Compra completa con ePay de prueba |
| `Rock.Blocks.Eventos.MyTickets` | `…0003` | 986 `/eventos/mis-entradas`, 991 | Ver boleto, QR, PDF, Wallet |
| `Rock.Blocks.Eventos.TicketScanner` | `…0004` | 984 `/eventos/scanner` | Escanear un boleto |
| `Rock.Blocks.Eventos.EventReport` | `…0005` | 987 `/eventos/reporteria` | Abrir reporte, reenviar correo (dev: Papercut) |
| `Rock.Blocks.Eventos.QuestionCatalog` | `…0006` | 989 `/eventos/preguntas` | Listar/editar preguntas |
| `Rock.Blocks.Eventos.EventCalendar` | `…0007` | 990 `/eventos/calendario` | Ver calendario público |
| `Rock.Blocks.Wallet.WalletTemplateAdmin` | `f0a1b2c3-…-950000000001` | 993 `/wallet/plantillas` | Abrir y previsualizar plantilla |
| `Rock.Blocks.Wallet.PaseDigital` | `…0002` | 857 «VidAventura Check-in» | Ver la tarjeta del pase |
| `Rock.Blocks.Qr.QrCodeList` / `QrCodeDetail` / `QrMetrics` / `QrDashboard` | `c7d2e5a0-…-b40000000103/102/104/105` | 1038 `/qr`, 1039 `/qr/codigo/{QrCodeId}`, 1040 `/qr/uso`, 1041 `/qr/reporteria` (+ copias 1047–1050 sin ruta) | Crear QR, descargar SVG/PNG, ver uso |
| `Rock.Blocks.QREVENT.QRScanner` | — | 861 «qrs» | Lista de eventos + cámara |
| `Rock.Blocks.QREVENT.CelebremosQrCheckIn` | — | 864 «Celebremos QR Check-in» | Escaneo de prueba |
| `Rock.Blocks.QREVENT.ReservationScanner` | — | 863 «Domingos Scanner» | Escanear QR de reserva |
| `Rock.Blocks.QREVENT.SundayServiceRegistration` | — | 860 «Registro Domingos App» | Reservar lugar (en dev) |
| `Rock.Blocks.QREVENT.SundayServiceCapacityAdmin` | `54953569-…` | 862 «Configuracion Domingos» | Ver cupos y pestaña Métricas |
| `Rock.Blocks.Dar.CybersourceDonationEntry` | — | 962 `/dar` | Formulario de donación (sin cobrar en dev) |
| `Rock.Blocks.Dar.DonationDashboard` | `F4B5C6D7-…` | 963 «DashBoard Donaciones» | Ver tablero, exportar |
| `Rock.Blocks.FamilyHub.FamilyHub` | — | 859 «Family Hub», 994 `/vrencuesta` | Ver familia (usuario de prueba) |
| `Rock.Blocks.LayoutCustom.Header` / `Footer` | — | 9–10 páginas externas: 841 `/acceso`, 916 `/learn`, 962 `/dar`, 975 `/reportequieroservir`, 985, 1017 `/access-learn`… | Que se vean en esas páginas |
| `Rock.Blocks.Security.VRSimpleRegistration` | `61C805E0-…` | 964 «Crear Cuenta» | Flujo `/acceso` con persona nueva |
| `Rock.Blocks.Crm.PersonDuplicateReview` | `d0a1b2c3-…-9d0000000010` | `/crm/duplicados` | Abrir la revisión de duplicados |
| `com.vidareal.Translator.Blocks.TranslatorDashboard` | `A7B8C9D0-…` | 1008 «VidaReal Translator» | Ver configuración y estadísticas |

`src/Eventos/miPaseDigital.obs` es una maqueta con datos mock: compila, pero ningún bloque la sirve.

### 2.3 Bloques upstream modificados

| Bloque | Dónde | Personalización | Páginas en prod |
|---|---|---|---|
| RegistrationEntry (Obsidian) | `Rock.Blocks/Event/RegistrationEntry.cs` + 19 archivos en `src/Event/` | NIT/FEL, rediseño, i18n | 413 `/Registration/...` |
| Login, AccountEntry, ConfirmAccount, ForgotUserName, CodeBox (Obsidian) | `Rock.Blocks/Security/Login.cs` + 23 archivos `src/Security/` | Passwordless Email/Teléfono, OTP numérico, rediseño | Login 3, 207 `/Login`, 841 `/acceso`, 837, 1017, 1068, 1073, 1074; AccountEntry 4, 208 `/NewAccount`, 390 |
| FamilyPreRegistration (Obsidian) | `src/Crm/familyPreRegistration.obs` + 3 partials | i18n | 12 páginas externas: 522, 761 `/registro` `/vidaventura`, 767 `/labienvenida`, 800 `/Vidaventuraregistro`, 802 `/somosjovenes`, 821 `/Navidad`, 823 `/RegistroCCIZ10`, … |
| Controles de framework | `Rock.JavaScript.Obsidian/Framework/Controls/{addressControl,datePicker,datePartsPicker,datePickerBase,rockValidation}.obs` | Español, cascada Departamento→Municipio | Todo formulario Obsidian |
| AddressControl (WebForms) + `ControlsController` | `Rock/Web/UI/Controls/AddressControl.cs`, `Rock.Rest/v2/ControlsController.cs` | Cascada GT | Editar dirección de una persona |
| Check-in WebForms (41) | `RockWeb/Blocks/CheckIn/**` | Traducción, anti doble check-in, autoselección de horario, logout de kiosco, WhatsApp en PersonLeft | Sitio «Rock Check-in» + Check-in Manager (ver UPGRADE §12) |
| PersonMerge | `RockWeb/Blocks/Crm/PersonMerge.ascx(.cs)` | Agregar persona por Id | 263 `/PersonMerge/{Set}`, 614 Business Merge |
| GivingOverview | `RockWeb/Blocks/Crm/PersonDetail/GivingOverview.ascx(.cs)` | KPIs por moneda | 177 `/person/{PersonId}/contributions` |
| RegistrationDetail, RegistrationInstanceRegistrationList | `RockWeb/Blocks/Event/*.ascx.cs` | Saldo sin FeeCoverage | 405, 404 `/web/event-registrations/...` |
| TransactionDetail, TransactionList | `RockWeb/Blocks/Finance/*` | Totales por moneda | 83 `/finance/transactions`, 163, 165, 166, 177, 283, 319, 416, 441, 468, 703 |
| Sms / SmsActionConversations, GetImage.ashx | `Rock/Communication/...`, `RockWeb/App_Code/GetImage.ashx.cs` | Pipeline WhatsApp, webp | Conversación por WhatsApp |
| Passwordless / RemoteAuthenticationSession | `Rock/Security/Authentication/PasswordlessAuthentication.cs`, `Rock/Model/Security/RemoteAuthenticationSessionService.cs` | OTP numérico (UPGRADE §8) | `/acceso` |
| Temas | `RockWeb/Themes/{Rock,RockManager,LandingPage,Stark}/Layouts/Blank.aspx`; `Rock.Frontend.Styles/src/themes/RockNextGen/Layouts/{Blank.aspx,Site.Master}` | Blank responsivo | Página Blank en móvil |

### 2.4 Modelo, REST, jobs y Lava propios (dentro de `Rock.dll` / `Rock.Rest.dll`)

| Qué | Dónde | Cómo se prueba |
|---|---|---|
| Eventos: 7 entidades (`_com_vidareal_Events_*`) + 19 servicios | `Rock/Model/Eventos/` (arquitectura hexagonal, `ARCHITECTURE.md`) | `docs/eventos-custom/SMOKE_TESTS.md` |
| Wallet: 3 entidades + 5 servicios (Apple/Google, APNs) | `Rock/Model/Wallet/` | Agregar pase desde Mis Entradas |
| QR: entidad `QrCode` + 3 servicios | `Rock/Model/Qr/` | `/qr`; tests MSTest en `Rock.Tests/Model/Qr/` |
| `AddressCascade` | `Rock/Model/Core/Location/AddressCascade.cs` | Dirección GT |
| Job `Rock.Jobs.EventsMaintenance` («Eventos: Mantenimiento») | `Rock/Jobs/EventsMaintenance.cs` | Admin > Jobs |
| Filtro Lava `WalletPassUrl` | `Rock/Lava/Filters/LavaFilters.VidaRealWallet.cs` | Plantilla con el filtro |
| REST PassKit `api/vidareal/wallet/v1/...` | `Rock.Rest/VidaReal/WalletPassKitController.cs` | Descargar pase |
| `Rock.WhatsApp.dll`: transporte `WhatsAppTransport` + acción `SendWhatsAppTemplate` | `Rock.WhatsApp/` | Admin > Communications > Transports (sin activar en dev) |
| Webhook WhatsApp | `RockWeb/Webhooks/WhatsAppSms.ashx` + `RockWeb/App_Code/WhatsAppSms.ashx.cs` (**App_Code: nunca en caliente**) | Verificación GET de Meta |

### 2.5 Plugins propios (`Plugin.*`, fuera de `Rock.sln`)

| Plugin | DLL | Última migración | Qué aporta |
|---|---|---|---|
| VidaRealEvents | `com.vidareal.Events.dll` | 25 | Páginas/rutas `eventos/*`, SP de holds, job de mantenimiento |
| VidaRealWallet | `com.vidareal.Wallet.dll` | 16 | Página `wallet/plantillas`, plantillas VidAventura |
| VidaRealQr | `com.vidareal.Qr.dll` | 7 | Páginas `qr/*` |
| VidaRealDupDetect | `com.vidareal.DupDetect.dll` | 5 | Jobs 194 y 195 (inactivos), página `crm/duplicados` |
| VidaRealTranslator | `com.vidareal.Translator.dll` | 4 | Bloque dashboard, REST `api/com_vidareal/Translator/*`, `translator.js` inyectado en todos los sitios |
| OdooEventSale | `OdooEventSale.dll` | — | Acción `Plugin.OdooEventSale.PostEventSaleToOdoo` (workflow 166 «ODOO») |
| EpayVisanetGateway | `EpayVisanetGateway.dll` | — | Gateway + `RockWeb/Plugins/EpayVisanetGateway/Obsidian/*.obs.js` |
| CybersourceInlineRestGateway | `CybersourceInlineRestGateway.dll` | — | Gateway + `RockWeb/Plugins/CybersourceInlineRestGateway/Obsidian/*.obs.js` |

`Plugin.*/Dependencies/` ya está en 19.8.1 (refrescado en la Fase 2). **`Plugin.CybersourceInlineRestGateway/Deploy/`
es un kit viejo con `Rock.dll` 18.1.0: no usarlo para el deploy de la 19** (pisaría el core).

### 2.6 WebForms, App_Code, assets y temas propios

| Qué | Dónde | Página / prueba |
|---|---|---|
| Asistencia (check-in desde perfil) | `RockWeb/Blocks/Asistencia/CheckInFromProfile.ascx`, `CheckIn.ashx` | 856 «Asistencia» |
| CheckInOutView | `RockWeb/Blocks/CheckIn/CheckInOutView.ascx` | 852 «Checkin Pendientes» |
| QREVENT legacy | `RockWeb/Blocks/QREVENT/{EventParticipants,QRScanner}.ascx` (QRScanner tiene Ids de atributo fijos 8400/8401) | 848 «Reporteria Eventos», 847 «Lector QR» (externo) |
| SundayServiceCapacityAdmin legacy | `RockWeb/Blocks/SundayService/` | 0 instancias |
| Traductor (front) | `RockWeb/Plugins/com_vidareal/Translator/` (`translator.js` es la única copia de su fuente) | Cualquier página externa |
| Fuentes Brújula VR y Montserrat | `RockWeb/Assets/Fonts/` | Bloques QREVENT/Eventos |
| `datePicker.js` en español | `RockWeb/Scripts/Rock/Controls/datePicker.js` | Cualquier fecha WebForms |
| Tema `VidAventuracheckin` | `RockWeb/Themes/VidAventuracheckin/` (forzado por `Admin.ascx.cs`; ningún sitio lo tiene asignado) | Kiosco (UPGRADE §12) |

---

## 3. Plugins de terceros (`RockWeb/Plugins` + `RockWeb/Bin`)

Los `.ascx` están versionados; las DLL **no salen de ningún build** (vienen de prod o del zip de handoff).
No existe `App_Data/InstalledStorePackages.json` en dev: las versiones son el FileVersion de la DLL.

| Plugin | DLL (versión) | Usado en prod | ¿Carga en la 19 (local)? | ¿Versión para la 19? |
|---|---|---|---|---|
| BEMA MailChimp | `com.bemaservices.MailChimp.dll` 1.0.3.14 | 6 bloques admin; job 92 | ✅ 6 `.ascx` y entidad resuelven | No confirmado. Mínima publicada: 1.16.0 |
| BEMA Workflow Extensions | `com.bemaservices.WorkflowExtensions.dll` 1.0.7.14 | Acción `LavaToCSV` en workflow 86 «VidAventura-CSV Niños Activos» (activo, 16 desde agosto) | ✅ 14 acciones resuelven | No confirmado. Mínima publicada: 1.16.10 |
| Blue Box Moon AcmeCertificate | `com.blueboxmoon.AcmeCertificate.dll` 3.1.0.0 | 4 bloques; job 93 | ✅ | No confirmado |
| Blue Box Moon DataToolkit | `com.blueboxmoon.DataToolkit.dll` 2.4.1.0 | 2 bloques; filtros/selects de DataView registrados (uso en DataViews no revisado); job 108 | ✅ 7 tipos resuelven | No confirmado |
| Central AZ LavaTester | (sin DLL; `.ascx` con CodeFile) | 1 bloque | ✅ | n/a |
| Mine Cart Studio MinePass | `com.minecartstudio.MinePass.Client.dll` 1.0.0.0 | 0 instancias | ✅ | No confirmado (reemplazado por MinistryPass) |
| Triumph Tech MinistryPass | `tech.triumph.MinistryPass.Client.dll` 1.0.0.0 | 4 bloques | ✅ | No confirmado. Mínima publicada: 17.1 |

«Carga» = el `.ascx` existe y sus tipos se resuelven por reflexión contra el `Bin` de la 19, y no hubo
excepciones suyas en dos arranques. **No** se abrieron sus páginas todavía (eso va en el plan de pruebas).
**Versión para la 19:** la información pública no lo confirma
([Workflow Extensions](https://www.rockrms.com/rockshop/plugin/109),
[MailChimp](https://chiptraining.rockrms.com/ask-chip-training/rock-shop/132),
[Ministry Pass](https://www.rockrms.com/rockshop/plugin/93)). Verificarlo en **Admin > Rock Shop > Installed
Plugins** de prod, que muestra si hay actualización para la versión instalada.

Restos de plugins que ya no existen (no son de la 19, ya fallaban en 18.1): Apollos (`Plugins/apollosproject`,
2 bloques), `rocks_pillars/ServiceReservation` (1 bloque). Generan una excepción por arranque.

---

## 4. Base de datos

### 4.1 Sitios y dominios

| Id | Sitio | Tema | Dominios |
|---|---|---|---|
| 1 | Rock RMS (interno) | RockNextGen | `localhost` (Order 0, ver trampa 7), la IP pública del servidor, `personas.vidareal.tv` |
| 2 | Rock Check-in | CheckinPark (el kiosco fuerza `VidAventuracheckin`) | — |
| 3 | External Website | Stark | — |
| 5 | Rock Check-in Manager | RockManagerNextGen (la 19 lo cambió) | — |
| 7 | Landing Page | LandingPage | — |
| 8 / 9 | «pagina de prueba» / «prueba hans» | Stark / LandingPage | — |
| 10 | Next-gen Check-in | NextGenCheckin | — |
| 11 | Vida Real | (sin tema) | — |
| 12 | QR | Rock (`EnableExclusiveRoutes`) | `q.vidareal.tv` |

`Allowed Frame Domains` del sitio 1 (prod): `personas.vidareal.tv vidareal.tv …webflow… vidareal.tv/prueba-rock`
(en Rock19Test además `'self' localhost:6229`, UPGRADE §5c).

### 4.2 Páginas modificadas en los últimos 10 días (2026-11-08 → 2026-11-18, copia de prod)

| Página | Qué cambió | Nota para el upgrade |
|---|---|---|
| 3 «Log In» (interno) | Bloque Login (1739) reconfigurado + 2 HTML nuevos «CSS – Diseño Vida Real» y «HTML + JavaScript – Marca Vida Real» (18-nov) | Usa `/Content/` → necesita la carpeta `Content` de prod (logo roto en local, UPGRADE §5c) |
| 1073 «Prueba - Log In - Prueba Passworless», 1074 «Prueba - Passwordless - Para LMS - Copy» | Nuevas (18-nov), Login + HTML | Login modificado por nosotros: probar |
| 1068 «Passwordless - Para LMS», 997 «Learn Demo», 1070 «Prueba LMS - Copy», 1071 «Pagina de Cursos» | HTML/Lava (17-nov) | 1070 tiene 28 referencias a `/Content/` |
| 1072 «Encuesta Iglesia Vida Real», 1064 «… 2026» | Nueva / HTML de redirección (18-nov) | — |
| 1034 «Proceso Abordo», 1052 «Abordo», 1019/1021/1026/1027/1032/1033/1036/1037/1045/1046/1051/1057/1059 (reportes de la ruta de asimilación) | HTML actualizado (18-nov) | Bloques HTML: riesgo bajo |
| 1023 «VidAventura - Asistencias», 1030 «VidAventura - Check Ins» | HTML (12-nov) | — |

Sin cambios en ese período: sitios, layouts, rutas, shortcodes Lava.
**Dependencia de `/Content/`:** 85 bloques HTML en ~60 páginas, 3 `Page.HeaderContent`, 2 plantillas de
comunicación (7 «Sidebar», 18 «Mail template - Vidaventura»), 5 acciones de workflow y el proveedor de assets
«Local Content» (`~/Content/`). `RockWeb/Content` **solo existe en el servidor** (ignorado por git).

### 4.3 Workflows con acciones que no son del core

| Acción (ensamblado) | Workflows (Id: nombre) | Uso reciente | ¿Resuelve en la 19? |
|---|---|---|---|
| `Rock.WhatsApp.Workflow.Action.SendWhatsAppTemplate` (`Rock.WhatsApp`) | 153, 155, 205 (pruebas), 208 «Email y WhatsApp 4 días después - No está en GPS», 209 «… 2 días después No Bautizado», 210 «VidAventura-WhatsApp cumpleañeros semanales» | 210: 2 817 desde agosto | ✅ |
| `Plugin.OdooEventSale.PostEventSaleToOdoo` | 166 «ODOO» | último 2026-06-22 | ✅ |
| `com.bemaservices.WorkflowExtensions…LavaToCSV` | 86 «VidAventura-CSV Niños Activos» | 16 desde agosto | ✅ |
| `com.vidareal.Workflow.Actions.GenerarQrCodeRegistrantAction` | 83 «Event_Set Registrant» | último 2025-08-21 | ❌ DLL solo en `RockWeb/Plugins/Qrgenerador/bin/`, fuera de `Bin` (ya pasaba en 18.1) |
| `com.yourorg…SendWhatsAppMessage` (`TwilioOverride`) | 77 «Prueba WhatsApp» | último 2026-05-18 | ❌ DLL solo en `RockWeb/Plugins/TwilioOverrideWhatsApp/bin/` (ya pasaba en 18.1) |

### 4.4 Jobs propios y de terceros

| Id | Job | Clase | Activo en prod |
|---|---|---|---|
| — | Eventos: Mantenimiento | `Rock.Jobs.EventsMaintenance` (core del fork) | ver prod |
| 194 / 195 | VidaReal: Detectar Duplicados / Reporte Semanal | `com.vidareal.DupDetect.Jobs.*` | creados inactivos |
| 92 | Mail Chimp Sync | `com.bemaservices.MailChimp.Jobs.MailChimpSync` | — |
| 93 | Renew Certificates | `com.blueboxmoon.AcmeCertificate.Jobs.RenewAcmeCertificates` | — |
| 108 | Cleanup Data Toolkit SQL Filters | `com.blueboxmoon.DataToolkit.Jobs.CleanupDataToolkitSqlFilter` | — |

(En Rock19Test todos están inactivos por el aislamiento; el estado original de prod está en
`dev-isolation\jobs_activos_Rock19Test_2026-11-19.csv`.)

### 4.5 Atributos globales propios (no de sistema)

Por grupo (claves, sin valores):
- **Integraciones (secretos, nunca en el repo):** `OdooEventSaleApiKey`, `OdooEventSaleBaseUrl`, `OdooNitApiUrl(1)`,
  `OdooNitApiBearerToken(1)`, `AppleWalletPassP12`, `AppleWalletPassP12Password`, `ZoomLMS*` (4),
  Cognitive Services Translator Key/Region, `techTriumph_License_Settings`, `StoreOrganizationKey`.
- **Imágenes/recursos de correo y páginas** (~70): `EmailHeader`, `EmailFooter(Logo)`, `header_mail*`, `Icono*`,
  `Logo*`, `Head*`/`head-*`, `banner*`, `ft*`, `Foto*`, `*morado`, `*azuljv`, `walletpassimg`, `PasedigitalBienvenida`…
  Muchos apuntan a archivos de `/Content/`.
- **Otros:** `numeronotificaciones`, `eventos`, `oracion`, `predicas`, `reservaz10`, `servidores1`, `VA-MSC26`, `VMAMA-26`.

### 4.6 Almacenamiento de archivos

| Proveedor | Tipos de archivo (BinaryFileType) | Archivos | Ruta |
|---|---|---|---|
| Base de datos | Person Image (2 255), Transaction Image (598), Unsecured (365), Event Ticket QR (49), Check-in Label, Location Image, Content Channel Item Image, Learning Management, Merge Template, … | 3 341 (487 MB) | en la BD |
| FileSystem | Communication Attachment (148), Communication Image (84), Mobile App Bundle (2), Media File (1) | 235 (111 MB) | `~/App_Data/Communication Attachments`, `~/App_Data/Communication Images`, `~/App_Data/MobileAppBundles`, `~/App_Data/Files` |
| Azure Blob (core `Rock.Storage.Provider.AzureBlobStorage`) | LMS VIDEO | 0 | contenedor `lms-videos`, carpeta `/lmsvideos` |
| Assets (Asset Manager) | «Local Content» → `~/Content/`; «Azure Blob Storage» | — | — |

**Migración `UpdateExistingToCoreAzureBlobStorageProvider` (19.0):** solo actúa si existe el proveedor *legacy*
`rocks.pillars.AzureStorageProvider.AzureBlobStorage` activo; copia su configuración al proveedor del core y
reapunta los BinaryFileType. **En nuestra BD ese proveedor no existe** (0 EntityTypes `rocks.pillars.*`) y LMS
VIDEO ya usa el del core: fue un **no-op**. Verificado: los BinaryFileType de `Rock18` (copia previa) y de
`Rock19Test` (migrada) apuntan a los mismos proveedores. **No afecta archivos de prod.** Lo que sí hay que
cuidar es la carpeta física: `App_Data` (las 4 rutas de FileSystem) y `Content` deben conservarse en el deploy.

---

## 5. Verificación automática de BlockTypes y componentes (2026-11-19)

`Dev Tools/Upgrade/Test-TiposRock.ps1` sobre los 883 BlockTypes de Rock19Test y los 64 EntityTypes de
ensamblados que no son el core:

| Resultado | BlockTypes | Detalle |
|---|---|---|
| OK | 865 | `.ascx` existe o el tipo carga desde `Bin` |
| FALTA_ASCX, **con bloques en páginas, nuevo por la 19** | 4 | `Cms/FileManager.ascx` (página 433) y `Reporting/ServiceMetricsEntry.ascx` (451) → los arreglan los jobs 227 y 226. `Communication/SystemPhoneNumberList.ascx` (327) y `Event/InteractiveExperiences/InteractiveExperienceList.ascx` (740) → **ningún job los arregla** (UPGRADE §11.4) |
| FALTA_ASCX, sin bloques, nuevo por la 19 | 3 | `Event/RegistrationEntry.ascx` (job 223 lo limpia), `Communication/SnippetTypeList.ascx`, `Reporting/PersistedDataViewList.ascx` (restos inofensivos) |
| FALTA_ASCX, ya faltaba en 18.1 | 10 | `QREVENT/TestCybersource.ascx` (2 bloques), `Event/eventos.ascx.cs` (1), Apollos (2), `rocks_pillars` (1), `CheckIn/CheckInOutViews.ascx`, `SundayServiceScanner/ReservationScanner.ascx` (2 rutas), `FamilyHub/FamilyHub.ascx`, `Crm/FamilyPreRegistration2.ascx` (0 bloques) |
| TIPO_NO_RESUELVE | 1 | `Rock.Blocks.CustomGiving.CustomGivingEntry` (0 bloques; resto de un desarrollo retirado) |

EntityTypes: 62 de 64 resuelven; los 2 que no son las acciones de §4.3 (DLL fuera de `Bin`).

Para repetirlo en prod después del upgrade: exportar con la consulta del encabezado del script y correrlo
contra el `RockWeb` del servidor (solo lectura).

---

## 6. Hallazgos que no son del upgrade (anotar, no bloquean)

1. 8 bloques Obsidian propios sin `BlockTypeGuid` (§2.2).
2. `Rock.Blocks/Dar/CybersourceDonationEntry.md` dice que el `BlockTypeGuid` está en la línea 314: no existe.
3. Binarios sin fuente: `Plugins/Qrgenerador`, `Plugins/TwilioOverrideWhatsApp`; y sus acciones no cargan (§4.3).
4. `QRScanner.ascx.cs` con Ids de atributo fijos (8400/8401).
5. `RockWeb/Plugins/com_vidareal/Translator/translatorDashboard.obs.js` versionado difiere del compilado hoy.
6. Carpeta `Asistencia/` en la raíz del repo duplica `RockWeb/Blocks/Asistencia/`.
7. `core-files-modified.txt` no lista `CLAUDE.md` ni los dos `Rock.Frontend.Styles/.../RockNextGen/Layouts`
   (todavía los nombra con la ruta 18.x).
8. «Store Key too long» al arrancar (la clave del Rock Shop de prod copiada a dev): esperado en dev.
9. **Objeto de BD propio que no está en el repo:** trigger `dbo.tr_PhoneNumber_FixGT02` (AFTER INSERT, UPDATE en
   `PhoneNumber`): si `CountryCode = '502'` y `Number` empieza con `02`, le quita los 2 primeros dígitos y recalcula
   `NumberFormatted`/`FullNumber`. Sobrevive al upgrade (las migraciones de la 19 no lo tocan), pero no hay fuente
   versionada: conviene guardarlo en `Dev Tools/Sql/`.
