# Rock.Blocks — Cambios y personalizaciones VidaReal

> **Última actualización:** 2026-10-15 (revisión de traspaso: índice completo de carpetas custom, corrección del frontend de `VRSimpleRegistration` y aviso de trabajo sin commitear en `Qr/QrMetrics.cs`)

## Contexto general

`Rock.Blocks` contiene los **bloques de servidor Obsidian** (ASP.NET / C#) del CMS Rock RMS.
Cada clase en este proyecto es un `RockBlockType` que expone:

- **`GetObsidianBlockInitialization()`** — inicializa el estado del bloque y lo envía al frontend Vue/Obsidian.
- **`[BlockAction]` methods** — endpoints invocados desde el frontend mediante `invokeBlockAction`.
- **Atributos de bloque** — configuración declarativa (páginas enlazadas, textos, flags).

Los bloques Obsidian reemplazan a los WebForms tradicionales (`.ascx`). Rock 18.x continúa el proceso de "chop" (migración WebForms → Obsidian).

---

## Rama de trabajo

- Repositorio: fork de `SparkDevNetwork/Rock`
- Rama: `hotfix-18.1`
- Organización: VidaReal (iglesia)

---

## Resumen de cambios en Rock.Blocks

| Archivo | Tipo de cambio | Descripción |
|---|---|---|
| `Security/Login.cs` | Modificacion upstream | Se agrega `Category = p.PhotoUrl` al mapeo de personas en seleccion passwordless |
| `Security/VRSimpleRegistration.cs` | Nuevo — personalización VidaReal | Bloque de registro simplificado post-validacion passwordless (ver detalle abajo) |
| `Dar/CybersourceDonationEntry.cs`, `Dar/DonationDashboard.cs` | Nuevo — personalización VidaReal | Módulo DAR (donaciones con Cybersource, anti-fraude, multimoneda, NIT/SAT). Detalle en `Dar/CHANGES.md` |
| `Wallet/PaseDigital.cs` | Nuevo — personalización VidaReal | Tarjeta web del pase digital de la iglesia (diseño del pase de wallet: navy, "Asisto a" = campus de la persona, QR = Alternate Id). Imágenes leídas de la WalletTemplate. Botón "Guardar en mi teléfono" oculto por defecto (BooleanField para reactivarlo; emite el pase real al clic). GUID BlockType `f0a1b2c3-d4e5-4f60-8a01-950000000002`, registrado en migración 015 y renombrado en la 016 del plugin Wallet (antes `VidaAventuraPass`). Frontend: `src/Wallet/paseDigital.obs` |


### Índice completo de carpetas custom (verificado con `git log` el 2026-10-15)

| Carpeta / archivo | Tipo | Documentación | Estado al 2026-10-15 |
|---|---|---|---|
| `Dar/` (2 bloques + `EmailTemplates/confirmacion-donacion.html`) | Nuevo | `Dar/CHANGES.md`, `Dar/CybersourceDonationEntry.md` | Último cambio 2026-09-03 (plantilla de correo). Commiteado |
| `Event/RegistrationEntry.cs` | Modificación upstream | `Event/CHANGES.md` (§7: NIT/FEL) | Último cambio 2026-06-22. Commiteado |
| `Eventos/` (EventAdmin, EventCalendar, EventCheckout, EventReport, MyTickets, QuestionCatalog, TicketScanner) | Nuevo | `Rock/Model/Eventos/ARCHITECTURE.md`, `docs/eventos-custom/` | Commiteado en `81d2622dbc` (2026-10-06). En producción, incluido el ajuste a las capturas del diseñador (confirmado 2026-10-15) |
| `FamilyHub/FamilyHub.cs` | Nuevo | `FamilyHub/CHANGES.md` | Sin cambios de backend desde 2026-06-06 |
| `LayoutCustom/` (Header, Footer) | Nuevo | `LayoutCustom/CHANGES.md` | Sin cambios desde 2026-06-06 |
| `QREVENT/` (SundayServiceRegistration, ReservationScanner, SundayServiceCapacityAdmin, QRScanner, CelebremosQrCheckIn, `RealTime/SundayServiceTopic.cs`) | Nuevo | `QREVENT/CHANGES.md` | En producción (confirmado 2026-10-15); detalle en ese documento |
| `Qr/` (QrCodeDetail, QrCodeList, QrDashboard, QrMetrics) | Nuevo — QR Generator | `Rock/Model/Qr/ARCHITECTURE.md`, `docs/qr-custom/` | Commiteado en `81d2622dbc`; en producción (confirmado 2026-10-15). **En prod, commiteado en `36fa46789a` (2026-10-15):** `Qr/QrMetrics.cs` (tabla de códigos + filtro por QR en «Uso»), ver `docs/qr-custom/` |
| `Security/Login.cs` | Modificación upstream | `Security/CHANGES.md` | Último cambio 2026-07-06 |
| `Security/VRSimpleRegistration.cs` | Nuevo | `Security/CHANGES.md` | Último cambio 2026-07-06 |
| `Wallet/PaseDigital.cs`, `Wallet/WalletTemplateAdmin.cs` | Nuevo | `docs/wallet-module/`, `Plugin.VidaRealWallet/README.md` | Último cambio 2026-08-12 |
| `Crm/PersonDuplicateReview.cs` | Nuevo (DupDetect) | `Plugin.VidaRealDupDetect/` | Último cambio 2026-07-14 |

Notas:
- `Rock.Blocks.csproj` (proyecto SDK, incluye las carpetas por glob) solo cambió para agregar la referencia `EPPlus` (`..\libs\EPPlus\EPPlus.dll`, exportación Excel); conservarla al hacer merge con upstream.
- `Rock.Blocks/.claude/settings.local.json` está versionado por accidente (configuración local de Claude Code); no afecta el build.
- `Rock.Blocks.dll` empaqueta TODOS estos módulos: compilar y subir el DLL arrastra cualquier cambio local de otro módulo (p. ej. el filtro de Uso de QR, en prod pero pendiente de commit). Compilar siempre desde el árbol que se quiere desplegar.

---

## Bloques personalizados VidaReal

### VRSimpleRegistration

Bloque completamente nuevo, creado por VidaReal. No existe en el Rock original.

- **Namespace:** `Rock.Blocks.Security`
- **Categoria en Rock:** `VidaReal > Security`
- **GUID bloque:** `61C805E0-F228-4DCA-9934-3F12FEC67C7D`
- **GUID EntityType:** `E0AE2775-BFB2-4F28-A7C3-9FC968C42A86`
- **Archivo frontend:** `Rock.JavaScript.Obsidian.Blocks/src/Security/vrSimpleRegistration.obs` (existe desde 2026-06-06; antes este documento decía "a crear")
- **Proposito:** Ver `Security/CHANGES.md`

---

## Notas para futuras sesiones

- Los bloques con prefijo `VR` son creaciones propias de VidaReal, no modificaciones de Rock.
- El bloque `Login.cs` es el original de Rock con un cambio minimo documentado en `Security/CHANGES.md`.
- El resto de archivos en `Security/` (AccountEntry, ConfirmAccount, ForgotUserName, LoginHistory, etc.) son Rock puro sin modificar.
