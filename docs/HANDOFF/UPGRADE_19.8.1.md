# Upgrade de Rock 18.1 → 19.8.1 (prueba local y runbook del cambio real)

> **Estado:** en prueba **local** (máquina `DESKTOP-PB412F9`, BD `Rock19Test`). Nada de esto se ha
> aplicado en producción. Este documento se actualiza al cerrar cada fase.
>
> | Fase | Estado |
> |---|---|
> | 1. BD nueva aislada | ✅ 2026-11-19 |
> | 2. Merge de código + build | ✅ commiteado (local, sin push); core + 8 plugins compilan; precompilación de `RockWeb` pendiente (Smart App Control) |
> | 3. Arranque y migraciones | ✅ migraciones aplicadas y sitio arriba (§5b). Respaldo `.bak` de Rock19Test migrada **antes de jobs** (§11.1). Jobs post-actualización: analizados, **sin correr** (§11) |
> | 3b. Análisis previo a las pruebas | ✅ 2026-11-19: diagnósticos locales (§5c), inventario (`INVENTARIO_DESARROLLOS_VR.md`), jobs (§11), check-in (§12), comparación servidor vs repo preparada (§13) |
> | 4. Pruebas de humo | ⏳ checklist lista: `PLAN_PRUEBAS_19.8.1.md` |

---

## 1. Versiones y refs

| | Valor |
|---|---|
| Origen | Rock **18.1** con el fork de Vida Real (rama `hotfix-18.1` / `Test_Update_18.1_a_18.8`) |
| Base común del merge | tag `18.1.0` = `f8e5bcf161` |
| Destino | tag upstream **`19.8.1`** = `85705ceb0b` (SparkDevNetwork/Rock; mismo commit que `19.8.1-alpha`) |
| Rama de prueba | `Test_Update_18.1_a_18.8` |
| Commit antes del merge | `b61a80a019` (incluye el merge de `origin/Rock_RMS_Rama_Fredy`) |
| Commit del merge con 19.8.1 | El merge que agrega este archivo: `git log --merges -1 --format=%H -- docs/HANDOFF/UPGRADE_19.8.1.md` (2026-11-19) |
| BD de prueba | `Rock19Test`, importada de `Rock18_Prod_20261119.bacpac` |

**Ojo con la versión:** en git, el tag `19.8.1` apunta al mismo commit que `19.8.1-alpha`. Antes del
cambio real, confirmar en las notas de versión de Rock que la 19.8.1 sea una versión **estable**.
La ruta que recomienda `CLAUDE.md` es otra (Rock limpio, saltos 18.7.0 → 19.1.8 → 19.7.0). Esta
prueba sirve para medir conflictos y riesgos del salto directo sobre el fork.

---

## 2. Fase 1 — BD de prueba (2026-11-19)

1. Import: `sqlpackage /Action:Import /SourceFile:Rock18_Prod_20261119.bacpac` a `Rock19Test`
   (localhost, Integrated Security, TrustServerCertificate). **7 min 09 s**. Compatibilidad 160.
   Última migración core antes de subir: `202511121736124_CodeGenerated_20251112`. `Rock18` quedó intacta.
2. Inventario previo: 95 jobs activos → `dev-isolation\jobs_activos_Rock19Test_2026-11-19.csv`
   (fuera del repo; respecto al 2026-11-06 se sumó el job Id 1).
3. Aislamiento: `dev-isolation\aislar_dev_Rock19Test.sql` = `aislar_dev_Rock18.sql` con la guarda
   cambiada a `DB_NAME() = 'Rock19Test'` (la guarda de máquina se conserva). Corrida 1: URLs 3,
   SMTP 1, kiosco 1, transportes 13, gateways 7 + 1, Odoo 8, Wallet 2, Azure 2, jobs 95. Corrida 2: todo 0.
4. Verificado por SQL: SendGrid/Twilio/WhatsApp/OneSignal `Active=False` y credenciales vacías; SMTP
   `localhost:25` y medio Email → SMTP; Epay `Live=False` sin credenciales `Live*`; Pay Flow Pro
   inactivo; Odoo, `AppleWalletPassP12*`, `AzureApiKey`, `AiApiKey` vacíos; 0 jobs activos.
5. `RockWeb\web.ConnectionStrings.config` → `Initial Catalog=Rock19Test` (archivo ignorado por git).

Diferencia con `Dev Tools\Sql\Aislar_BD_Dev.sql` (repo): ese script desactiva **todas** las
pasarelas y agrega `.test` a los correos, pero no vacía credenciales ni cubre Odoo/Wallet/Azure. Se
usó el de `dev-isolation` por ser el de referencia del 2026-11-06.

---

## 3. Fase 2 — Merge

Orden: commit del doc pendiente → merge de `origin/Rock_RMS_Rama_Fredy` (solape en
`SETUP_DESARROLLO.md`: se conservaron ambas bitácoras, §9.1 y §9.2) → `git fetch upstream tag 19.8.1`
→ `git merge 19.8.1`.

Reglas aplicadas: seguridad de upstream gana; funcionalidad propia (Eventos, Wallet, QR, Dar,
FamilyHub, Security, RegistrationEntry, controles de dirección y fecha, preRegistration, WhatsApp,
QREVENT y todo lo listado en los `CHANGES.md`) se conserva; `.csproj`/`package.json` = upstream +
nuestras entradas; modify/delete = se acepta el borrado de upstream y se documenta.

### 3.1 Los 33 conflictos

| # | Archivo | Se conservó | Por qué |
|---|---|---|---|
| 1 | `.githooks/commit-msg` (nosotros lo borramos, upstream lo modificó) | **Borrado** (nuestro) | El hook de upstream exige mensajes en inglés con formato Spark; los commits del fork van en español |
| 2 | `.gitignore` | Unión | Nuestras entradas (`PrecompiledWeb/`, kits de deploy, `.claude/settings.local.json`) + la de upstream (`obsidian-backend-watch/logs/`) |
| 3 | `CLAUDE.md` (add/add) | Nuestro | Regla del upgrade |
| 4 | `Rock.Blocks/Event/RegistrationEntry.cs` | Ambos | Nuestra región NIT/FEL (`ValidateNitInfo`, anti-SSRF, rate limit) + el `ResolveRegistrantPerson` nuevo de upstream (inscritos duplicados) |
| 5 | `Rock.Blocks/Rock.Blocks.csproj` | Ambos | Nuestra referencia `EPPlus` + `Slingshot.Core` de upstream |
| 6 | `Rock/Rock.csproj` | Upstream + nuestra | Versiones de upstream (Serilog 10, ImageSharp 2.1.12, Jwt 8.15, Pipelines/Memory.Data 10…) + nuestra `System.Net.Http.WinHttpHandler 8.0.0` (Wallet) |
| 7 | `Rock.JavaScript.Obsidian.Blocks/package.json` | Upstream + nuestra | `vue-eslint-parser`/`vue-tsc` de upstream + nuestras `dependencies` `@zxing/browser` y `@zxing/library` (escáner QREVENT) |
| 8 | `Rock/Model/Security/RemoteAuthenticationSessionService.cs` (passwordless) | Combinado | `RandomNumberGenerator` + `GetRandomIndex` de upstream (seguridad) con **nuestro alfabeto `0123456789`**. Ver hallazgo §8 |
| 9 | `Rock/Web/UI/Controls/AddressControl.cs` | Nuestro + corrección de upstream | Nuestra cascada Departamento → Municipio (`renderState/renderCity/renderLocality`, `_ddlCity`); se aplicó dentro la corrección de `autocomplete` de upstream (ciudad `address-level2`, condado `address-level3`) |
| 10 | `Rock.JavaScript.Obsidian/Framework/Controls/addressControl.obs` | Nuestro + estilo upstream | `getConfiguration(currentVal, internalValue.state)` (cascada) con el `!==` de upstream. El resto de upstream (`useHttp`, autocomplete) entró sin conflicto |
| 11 | `Rock.JavaScript.Obsidian/Framework/Controls/datePicker.obs` | Combinado | Nuestro `{ ...field, ...basePickerProps }` (formato/idioma) + la prop `disabled` nueva de upstream |
| 12 | `RockWeb/Blocks/CheckIn/Manager/LiveMetrics.ascx` | Combinado | Clases de espaciado nuevas de upstream (`ml-spacing-md`) + nuestros textos `Abrir`/`Cerrar` |
| 13 | `RockWeb/Blocks/CheckIn/Manager/Roster.ascx` (upstream lo borró) | **Borrado** | Check-in Manager pasó a Obsidian en la 19. Personalización perdida: §6 |
| 14 | `RockWeb/Blocks/Crm/PersonMerge.ascx.cs` | Nuestro | Nuestro `AddPersonToMerge` (agregar por ID) ya hace lo mismo que el código nuevo de upstream (incluye fallecidos/sin nombre y `UpdateAccountProtectionProfileForPerson`). El arreglo XSS de upstream entró sin conflicto |
| 15 | `RockWeb/Themes/RockNextGen/Styles/theme.css` (upstream lo borró) | **Borrado** | En la 19 los temas se compilan desde `Rock.Frontend.Styles/src/themes` (salida ignorada por git). Personalización perdida: §6 |
| 16 | `src/Communication/CommunicationEntry/communicationMediumEmail.partial.obs` | Upstream | Solo era un salto de línea final; nuestro encabezado bilingüe sigue intacto |
| 17 | `src/Crm/FamilyPreRegistration/preRegistrationChild.partial.obs` | Nuestro | Etiquetas traducidas con `t()` (2 hunks, uno de sangría) |
| 18 | `src/Crm/familyPreRegistration.obs` | Ambos | Nuestras etiquetas `normalizeConfiguredLabel` + `isCaptchaComplete` de upstream (su plantilla ya usa el captcha nuevo) |
| 19 | `src/Event/RegistrationEntry/discountCodeForm.partial.obs` | Nuestro | Mensajes traducidos y estilos móviles |
| 20 | `src/Event/RegistrationEntry/intro.partial.obs` | Nuestro | Texto traducido |
| 21 | `src/Event/RegistrationEntry/payment.partial.obs` | Ambos | Nuestro bloque NIT/FEL y estilos + `onMounted(waitForCaptcha)` de upstream. Entraron sin conflicto el captcha previo a los botones y el manejo de `409` (cupo lleno; mensaje traducido) |
| 22 | `src/Event/RegistrationEntry/registrant.partial.obs` | Ambos | Nuestra validación traducida (`hideErrors` + lista propia) + función de upstream «evitar inscritos duplicados» (dropdown con `"NEW"`, regla `preventDuplicateRegistrantRule`, `ResolveRegistrantPerson`). Mensajes nuevos traducidos |
| 23 | `src/Event/RegistrationEntry/registrantPersonField.partial.obs` | Upstream + nuestras etiquetas | Se tomó la versión 19.8.1 (validaciones de elegibilidad por género/edad/grado) y se reaplicaron nuestras 16 etiquetas `t("label…")`. Los mensajes de elegibilidad quedaron en inglés (pendiente §9) |
| 24 | `src/Event/RegistrationEntry/success.partial.obs` | Nuestro (archivo completo) | Habíamos quitado `SaveFinancialAccountForm`; todo lo de upstream en este archivo era sobre ese formulario (token de seguridad) |
| 25 | `src/Event/RegistrationEntry/summary.partial.obs` | Nuestro | Estilos de los chips de inscritos |
| 26 | `src/Event/RegistrationEntry/types.partial.ts` | Ambos | Campos `wantsInvoice/nit/nitName/nitAddress` + `isCapacityFull` |
| 27 | `src/Event/registrationEntry.obs` | Ambos | Nuestra plantilla (indicador de paso móvil, transiciones, textos) + paso nuevo `capacityFullFailure` de upstream e imports `Enumerable`/`NumberFilter` |
| 28 | `src/Security/AccountEntry/duplicatePersonSelectionStep.partial.obs` | Nuestro | Diseño Vida Real con captcha en slot; queda la prop `hideActions` de upstream sin uso |
| 29 | `src/Security/AccountEntry/existingAccountStep.partial.obs` | Nuestro | Ídem |
| 30 | `src/Security/AccountEntry/phoneNumberDetails.partial.obs` | Nuestro | Ídem |
| 31 | `src/Security/AccountEntry/registrationStep.partial.obs` | Nuestro | Ídem |
| 32 | `src/Security/AccountEntry/registrationStepAccountInfo.partial.obs` | Nuestro (archivo completo) | Textos en español; el cambio de upstream era solo de maquetación |
| 33 | `src/Security/accountEntry.obs` | Nuestro + script de upstream | Plantilla y estilos nuestros (captcha dentro de cada paso). Se conservaron del script de upstream `triggerCaptchaRevalidationIfNeeded` tras un error y `onMounted(waitForCaptcha)`: los tokens de captcha son de un solo uso |

Rutas `src/...` = `Rock.JavaScript.Obsidian.Blocks/src/...`.

**Sin conflicto, pero hay que saberlo:** upstream movió los temas `RockNextGen`, `RockManagerNextGen` y
`NextGenCheckin` a `Rock.Frontend.Styles/src/themes/` y git llevó nuestras ediciones de
`RockNextGen/Layouts/Site.Master` y `Blank.aspx` (script de CSS no bloqueante, viewport, anti-zoom iOS)
a la ubicación nueva. Se verificó que están. Los `Blank.aspx` de `LandingPage`, `Rock`, `RockManager` y
`Stark` no cambiaron.

**Finales de línea:** con `core.autocrlf=true`, `git add` durante el merge no respetó el estilo del
blob. Los archivos resueltos se agregaron con `git hash-object --no-filters` + `update-index`, con los
mismos finales de línea que el blob de HEAD (CRLF en `.gitignore`, LF en el resto).

### 3.2 Archivos del core que quedan distintos de upstream por el upgrade

Además de los de `docs/HANDOFF/core-files-modified.txt` (que ya existían):

**Choque `Rock.Model.Event`.** La 19 declara el namespace `Rock.Model.Event.*` y choca con nuestra
entidad `Rock.Model.Event` (`CS0101`). Decisión: **no** renombrar nuestra entidad (cambiaría
`/api/Events`, el `EntityType` 1367 y el Lava guardado). Se movió el namespace de upstream a
`Rock.Model.EventRegistrationOptions.*`:

| Archivo | Cambio |
|---|---|
| `Rock/Model/Event/RegistrationInstance/Options/GetSpotsAvailableOptions.cs` | `namespace` + nota `[VidaReal]` |
| `Rock/Model/Event/RegistrationTemplate/Options/RegistrantEligibilityEvaluationMode.cs` | `namespace` + nota |
| `Rock/Model/Event/RegistrationTemplate/Options/RegistrantEligibilityEvaluationOptions.cs` | `namespace` + nota |
| `Rock.Blocks/Event/RegistrationEntry.cs` | 2 `using` |
| `Rock/Model/Event/RegistrationInstance/RegistrationInstanceService.cs` | 1 `using` |
| `Rock/Model/Event/RegistrationSession/RegistrationSessionService.cs` | 1 `using` |
| `Rock/Model/Event/RegistrationTemplate/RegistrantEligibilityEvaluator.cs` | 1 `using` |

No hay usos en Rock.ViewModels, Rock.Rest, Obsidian ni en los plugins (búsqueda en todo el repo).
Registrado en `CHANGES.md` («Modificados del core por choque de nombres») y en `core-files-modified.txt`. **En el próximo upgrade:**
`git grep -n "Rock\.Model\.Event\."` después del merge y cambiar el prefijo en declaraciones y `using`
(upstream puede agregar archivos nuevos a ese namespace).

---

## 4. Cambios de dependencias

| Dependencia | Cambio | Motivo |
|---|---|---|
| `Newtonsoft.Json` en `Rock.WhatsApp.csproj` | 13.0.1 → **13.0.4** | `Rock.Common` de la 19 exige ≥ 13.0.4; con 13.0.1 el restore falla (`NU1605`, degradación). Todos los proyectos de `Rock.sln` quedan en 13.0.4; `RockWeb/packages.config` 13.0.4. `bindingRedirect` de `web.config`: `0.0.0.0-13.0.0.0 → 13.0.0.0` (toda la serie 13.x tiene versión de ensamblado 13.0.0.0: cubre 13.0.4, no hay que cambiarlo) |
| `Rock.WhatsApp.csproj`: versionado | Se quitó `GenerateAssemblyInfo=False` y el enlace a `..\Rock.Version\AssemblySharedInfo.cs`; se agregó `GenerateAssemblyTitleAttribute=false` | Upstream eliminó `AssemblySharedInfo.cs` en la 19 («Updated solution to new standard SDK versioning», `c167a7243f`) y pasó todos sus proyectos a tomar la versión de `Directory.Build.props`. Sin el cambio: `CS2001`. El título sigue saliendo de `Rock.WhatsApp/Properties/AssemblyInfo.cs`. **No cambia lógica**; `Rock.WhatsApp.dll` ahora reporta 19.8.1 |
| `Plugin.CybersourceInlineRestGateway`, `Plugin.EpayVisanetGateway`, `Plugin.OdooEventSale` → `Dependencies/*.dll` (versionadas) | Refrescadas desde `RockWeb\Bin` del build 19.8.1: `Rock.dll`, `Rock.Common`, `Rock.Enums`, `Rock.Rest`/`Rock.Lava.Shared` 18.1.0 → 19.8.1; `Newtonsoft.Json` 13.0.1 → 13.0.4; `Microsoft.Extensions.Logging.Abstractions` 8.0 → 10.0; `System.Runtime.CompilerServices.Unsafe` 6.0 → 6.1; `System.Web.Http(.WebHost)` 5.2.3 → 5.2.9. `EntityFramework` igual | `build-all.ps1` **no** las refresca. Los otros 5 plugins referencian `RockWeb\Bin` directo |
| `RockWeb\Bin` (DLLs de terceros, no versionadas) | **122 DLLs** cambiaron de versión (AngleSharp 0.16 → 1.4, Microsoft.Extensions.* 8 → 10, IdentityModel/Jwt 8.15, Serilog 10, Twilio 7.13, SendGrid, etc.) | Hay que correr `nuget restore RockWeb\packages.config -PackagesDirectory packages` (se usó `%USERPROFILE%\.nuget\packages\nuget.commandline\5.11.5\tools\NuGet.exe`) y copiar a `Bin` cada destino de los `.refresh` (rutas relativas a `RockWeb\`). Sin esto, la precompilación falla con `AngleSharp 1.4.0.0 … no coincide` |
| npm (`package-lock.json`) | Se commitean los lock **del merge** en `Rock.JavaScript.Obsidian`, `.Blocks` y `.Reporting` (sus `package.json` cambiaron por el merge; el de `.Blocks` conserva `@zxing`) y los nuevos de upstream (`Rock.Frontend.Styles`, `Dev Tools/obsidian-style-checker`, `Dev Tools/tabler-icon-updater`). Lo que reescribe npm 11.20 al instalar (quita entradas opcionales/peer, agrega `fsevents`) **no** se commitea | El build pasó con esas resoluciones. Diferencias solo de versión de npm |

---

## 5. Build (2026-11-19)

`build-all.ps1 -FullObsidian` necesitó 5 corridas. Errores y arreglo de cada una:

| Corrida | Error | Arreglo |
|---|---|---|
| 1 | `NU1605` restore de `Rock.WhatsApp`: Newtonsoft 13.0.1 < 13.0.4 de `Rock.Common` | §4 |
| 2 | `CS0101` `Rock.Model` ya contiene `Event` (+2 `CS0246` en cascada); `TS2322` en `src/Dar/DonationDashboard.obs:563` (`Uint8Array` no asignable a `BlobPart`, por el TypeScript 5.9 de upstream) | §3.2; cast solo de tipo `new Blob([bytes as BlobPart], …)` |
| 3 | `CS2001` falta `Rock.Version\AssemblySharedInfo.cs` (Rock.WhatsApp); `npm run build-fast` salió con -1 después de `DONE` (sin errores de TS: fallo intermitente ya documentado en `SETUP_DESARROLLO.md` §9.1) | §4 |
| 4 | Precompilación de `RockWeb`: `AngleSharp 1.4.0.0 … la definición del manifiesto no coincide` | `nuget restore` del sitio + copiar los `.refresh` (§4) |
| 5 | Precompilación de `RockWeb`: `ASPRUNTIME: Referencia a objeto no establecida` | **Bloqueo del sistema operativo, no del código**: ver abajo |

**Resultado:**

- Todos los proyectos de `Rock.sln` compilan en Release (`Rock`, `Rock.Blocks`, `Rock.ViewModels`, `Rock.Rest`,
  `Rock.Migrations`, `Rock.WhatsApp`… versión 19.8.1 en `RockWeb\Bin`).
- Obsidian: los 829 bundles `.obs.js` se regeneraron hoy (registrationEntry 390 KB, accountEntry 98 KB,
  DonationDashboard 37 KB; Eventos, Wallet, Qr, QREVENT, FamilyHub con fecha de hoy). Quedan 3 bundles
  viejos de controles que **upstream eliminó** (`searchField`, `Internal/communicationRecipientActivity`,
  `Internal/pageDebugTimingRow`): restos inofensivos.
- **Los 8 plugins compilan** (`build-all.ps1 -SkipCore`, 15 s): solo los 5 avisos `CS0618 AddPageRoute`
  conocidos (Events 003, Wallet 002).
- **Precompilación de `RockWeb` (aspnet_compiler): bloqueada por Smart App Control.** Corrido a mano con
  `-errorstack`: `FileLoadException … App_Browsers.*.dll … Una directiva de Control de aplicaciones bloqueó
  este archivo`. El Visor de eventos (`CodeIntegrity/Operational`, Id 3033/3077) muestra el bloqueo de los
  DLLs que ASP.NET compila en `Temporary ASP.NET Files`. `VerifiedAndReputablePolicyState = 1`
  (Smart App Control **activado**). No hay bloqueos de este tipo antes del 2026-11-19: el 2026-11-06 el
  sitio arrancó en esta misma máquina. **Afecta solo a esta máquina de desarrollo**: el servidor de
  producción es Windows Server (sin Smart App Control). Pendiente de decisión (§9).
- Bundle versionado `RockWeb/Plugins/com_vidareal/Translator/translatorDashboard.obs.js`: al compilar
  contra la 19 cambia de **contenido** (no solo finales de línea). Se dejó el del repo; revisar en la
  prueba del Traductor.

---

## 5b. Fase 3 — Arranque y migraciones (2026-11-19, local)

Preparación: Smart App Control desactivado por el responsable (`VerifiedAndReputablePolicyState = 0`),
`%LOCALAPPDATA%\Temp\Temporary ASP.NET Files\` borrada (4 376 archivos, ~940 MB), connection string a
`Rock19Test`, `RunJobsInIISContext=False`. IIS Express desde consola en `localhost:6229`.

Estado antes: 707 migraciones core (última `202511121736124_CodeGenerated_20251112`), 341 `PluginMigration`,
103 jobs (0 activos), `CommunicationRecipient` máx. Id 103426.

**Tiempos medidos** (máquina de dev: 20 núcleos, SQL Server 2025 Developer, BD de 7.2 GB):

| Tramo | Duración |
|---|---|
| IIS Express arriba → primera petición | 10 s |
| Compilación en frío del sitio (sin migraciones) | ~59 s (11:30:00 → 11:30:59) |
| **67 migraciones core** (`MigrationLog.csv`) | **46,4 s** de ejecución (11:30:59 → 11:31:45). Las más lentas: `UpdateExistingToCoreAzureBlobStorageProvider` 3,96 s, `AddMobileOutreachToolbox` 3,87 s, `AddConnectionsFeatures` 3,36 s |
| **45 `PluginMigration` del ensamblado `Rock`** (hotfixes de la 19) | ~5 s (11:31:48 → 11:31:52) |
| Primera petición completa | **HTTP 500 a los 120,9 s**: falló el arranque después de las migraciones (ver abajo) |
| Tras el arreglo: arranque en frío, migraciones ya aplicadas | **HTTP 302 → login a los 72,5 s**; el login responde 200 en 10,6 s |

Para producción, calcular: compilación en frío (~1–2 min) + ~1 min de migraciones (más si el servidor es
más lento que esta máquina) + arranque. Reservar al menos 15 min con margen.

**Falla de arranque y arreglo — `Rock.SignNow.dll` y `SignNowSDK.dll`.** Después de las migraciones, el arranque
falló con `TypeLoadException: No se puede cargar el tipo 'Rock.Security.DigitalSignatureComponent'`. Upstream
**eliminó SignNow** en la 19 (`a3276b724b`: proyectos `Rock.SignNow` y `SignNowSDK`, webhook
`RockWeb/Webhooks/SignNow.ashx`), pero los DLLs del build de 18.1 seguían en `RockWeb\Bin`. No son del Rock
Shop. Se **movieron** (no se borraron) a una carpeta de respaldo fuera de `Bin` y el sitio arrancó. En la BD no
hay plantillas de firma con SignNow (EntityType 405, 0 `SignatureDocumentTemplate`).
**Día real:** quitar `Rock.SignNow.dll`, `SignNowSDK.dll` (y `.pdb`) de `RockWeb\Bin` y `RockWeb\Webhooks\SignNow.ashx`
de prod **antes** de arrancar. Son los únicos DLLs de proyectos que upstream eliminó entre 18.1.0 y 19.8.1.

**Estado después:** 774 migraciones core (última `202605122315282_UpdateExistingToCoreAzureBlobStorageProvider`),
386 `PluginMigration` (+45 de `Rock`; ninguna nueva de los plugins de Vida Real ni del Rock Shop),
116 jobs, `CommunicationRecipient` sin cambios (máx. Id 103426): **no se envió nada**.

**Excepciones después del arranque bueno** (`ExceptionLog`): solo las ya conocidas del 2026-11-06:
`AIAgentSessionAnchor` (trampa 2), `/Blocks/Event/eventos.ascx.cs` y `/Blocks/QREVENT/TestCybersource.ascx` no
existen, Apollos (`ApollosUser.ascx`, `ApollosAudit.ascx`), OpenID Connect sin https (esperado en dev). Ninguna
de los plugins del Rock Shop (MailChimp/bema, AcmeCertificate y DataToolkit/blueboxmoon, MinePass, MinistryPass).

**WhatsApp después de las migraciones:** EntityType 1362 `Rock.WhatsApp.Communication.Transport.WhatsAppTransport`
con sus **13 atributos** presentes (los mismos que antes), `Active=False`, `AccessToken`/`AppSecret`/
`PhoneNumberId`/`VerifyToken` vacíos (aislamiento intacto). No se reactivó ni se envió nada. Falta ver el
componente en Admin > Communications > Transports (Fase 4).

**Jobs que crearon o reactivaron las migraciones (14 activos).** Con `RunJobsInIISContext=False` no corren solos.
Post-actualización (correr con «Run Now», en este orden sugerido):

| Id | Job | Clase |
|---|---|---|
| 231 | Rock Update Helper v17.10 - Fix Transaction Image Mime Types | `PostV1710FixTransactionImageMimeTypes` |
| 232 | Rock Update Helper v17.11 - Clean Social Media Account Values | `PostV1711CleanSocialMediaAccountValues` |
| 233 | Rock Update Helper v17.11 - Fix Person Image Mime Types | `PostV1711FixPersonImageMimeTypes` |
| 220 | Rock Update Helper v18.1 - Add FinancialBatch Index | `PostV181AddFinancialBatchIndex` |
| 221 | Rock Update Helper v18.1 - Add Indexes For Communication Prep | `PostV181AddIndexesForCommunicationPrep` |
| 228 | Rock Update Helper v18.3 - Fix Broken Achievement Types | `PostUpdateJobs.PostV183UpdateAchievementTypes` |
| 225 | Rock Update Helper v19.0 - Add Index For Communication Unsubscribe Report | `PostV19AddCommunicationUnsubscribeReportIndex` |
| 230 | Rock Update Helper v19.0 - Backfill Connection Request Connected DateTime | `PostV19BackfillConnectionRequestConnectedDateTime` |
| 222 | Replace WebForms Blocks with Obsidian - Chop Block Types 19.0 (19.0.1) | `PostUpdateDataMigrationsReplaceWebFormsBlocksWithObsidianBlocks` |
| 223 | Replace WebForms Blocks with Obsidian - (final) Registration Entry 19.0 | ídem |
| 226 | Replace WebForms Blocks with Obsidian - (final) Service Metric Entry 19.0 | ídem |
| 227 | Replace WebForms Blocks with Obsidian - (final) File Manager | ídem |

Los jobs «Replace WebForms Blocks with Obsidian» **cambian páginas**: reemplazan los bloques WebForms por los
Obsidian, incluida la inscripción nativa (Registration Entry). Probar la inscripción **después** de correrlos.
Jobs normales que también quedaron activos (no son de post-actualización): 224 *Update Outreach Toolbox
Touchpoints* y 229 *Update Analytics Source PostalCode v19*. En dev no corren (`RunJobsInIISContext=False`).

«Run Now» necesita una sesión de administrador en el sitio: **lo hace el responsable** (nunca se piden contraseñas).
Análisis de qué hace cada uno y recomendación: §11.

---

## 5c. Diagnósticos de la prueba local (2026-11-19)

Tres cosas que se ven rotas en local y **no** son fallas del upgrade:

1. **Logo roto en el login y en la barra.** `/Content/logo_vidareal-03.png` y
   `/Content/ExternalSite/Icons/icon-ipad-retina-vr.png` dan 404. `RockWeb/Content/` está en `.gitignore` y
   **solo existe en el servidor de prod**. Prod depende mucho de esa carpeta: 85 bloques HTML en ~60
   páginas, 3 `Page.HeaderContent`, 2 plantillas de comunicación, 5 acciones de workflow, varios atributos
   globales de imágenes y el proveedor de assets «Local Content» (`~/Content/`) la referencian
   (`INVENTARIO_DESARROLLOS_VR.md` §4.2). **Consecuencia para el runbook:** el upgrade se aplica como kit
   **encima** de `RockWeb`, nunca reemplazando la carpeta (§7.2, «Qué se conserva»).
2. **Modales en blanco.** El sitio interno manda `Content-Security-Policy: frame-ancestors <Allowed Frame Domains>`
   (`RockWeb/App_Code/Global.asax.cs:98-113`) y en prod ese campo solo tiene dominios de prod; el iframe del
   modal en `localhost:6229` queda bloqueado. **Solo en Rock19Test** se antepuso `'self' localhost:6229` al
   sitio «Rock RMS» (Id 1) y se agregó como sección 7 de `dev-isolation\aislar_dev_Rock19Test.sql`. Se reinició
   IIS Express y el header ya sale con `'self' localhost:6229`. En prod no se toca.
3. **El video de Vimeo no se reproduce.** Restricción de dominio de Vimeo (solo permite los dominios de prod).
   Esperado; se verifica en prod (`PLAN_PRUEBAS_19.8.1.md` 10.5).

---

## 6. Personalizaciones perdidas que hay que reaplicar en la 19

| Qué | Dónde estaba (18.1) | Cómo reaplicar en la 19 |
|---|---|---|
| Color primario `--base-primary: #073642` (upstream `#FF791D`) | `RockWeb/Themes/RockNextGen/Styles/theme.css`, bloque «CSS Overrides Bottom» | Editor de temas de la 19 (Admin > CMS > Themes > RockNextGen), o variables en `Rock.Frontend.Styles/src/themes/RockNextGen/Styles/` |
| Logo de Vida Real en la esquina del navbar: `.navbar-brand-corner.no-logo:after { background-image: url('/Content/ExternalSite/Icons/icon-ipad-retina-vr.png'); background-size: 42px 42px; 80×80 }` (todo `!important`) | ídem | ídem (CSS overrides del tema) |
| Roster del Check-in Manager en español: títulos `Confirmar`, botones `Registrar Entrada` / `Registrar Salida` (3 modales) | `RockWeb/Blocks/CheckIn/Manager/Roster.ascx` (borrado en la 19) | El Roster ahora es Obsidian: traducir en el bloque nuevo o con el Traductor; revisar en las pruebas de check-in |
| Página «Room Settings» del Check-in Manager | La migración `UpdateCheckinManagerToNextGen` la borra (y «Room Manager» pasa a ser el Roster) | La traducción de `RoomSettings.ascx` queda sin uso; nada que reaplicar |

El diff completo de lo perdido quedó en la carpeta temporal de la sesión; se puede regenerar con
`git diff 18.1.0 b61a80a019 -- RockWeb/Themes/RockNextGen RockWeb/Blocks/CheckIn/Manager/Roster.ascx`.

---

## 7. Runbook para producción (borrador; leer junto con `DEPLOY_PRODUCCION.md`)

**Principio:** en prod el sitio es la carpeta `RockWeb` del servidor. El upgrade se aplica como **kit copiado
encima** de esa carpeta (igual que cualquier deploy, `DEPLOY_PRODUCCION.md` §3). **Nunca** se reemplaza ni se
vacía `RockWeb`: tiene carpetas y archivos que solo existen en el servidor (§5c).

### 7.1 Días antes

1. Confirmar que la 19.8.1 es **estable** (notas de versión de Rock; en git el tag es el mismo commit que `-alpha`).
2. Correr en el servidor `Dev Tools\Upgrade\Get-RockWebInventario.ps1` (solo lectura) y comparar contra el repo
   (§13). Todo lo que salga como «cambiado en prod / solo en prod» se resuelve **antes**: o se trae al repo, o se
   agrega a «Qué se conserva».
3. Plugins del Rock Shop: revisar en **Admin > Rock Shop > Installed Plugins** de prod si hay versión para la 19
   (`INVENTARIO_DESARROLLOS_VR.md` §3). En local cargan las versiones actuales.
4. Pedir a TI el **valor** de `RunJobsInIISContext` en el `web.config` de prod (solo el valor; no copiar el archivo).
5. Preparar el `web.config` de la 19 con las llaves de prod (`PasswordKey`, `DataEncryptionKey`, `machineKey`…)
   fusionadas; lo hace TI en el servidor. Ponerle `RunJobsInIISContext=False` para la ventana (§7.3, paso 6).
6. Armar el kit (fuera del repo) **desde un commit**, con `build-all.ps1 -FullObsidian`:
   - `Bin\` completo del build (122 DLLs de terceros cambian de versión, §4) + DLLs de los 8 plugins.
   - `Obsidian\` completo, `Plugins\{com_vidareal,EpayVisanetGateway,CybersourceInlineRestGateway}\`.
   - Los archivos versionados de `RockWeb` que cambiaron entre `hotfix-18.1` y la rama del upgrade
     (`git diff --name-only --diff-filter=AMR hotfix-18.1 <rama> -- RockWeb`).
   - **Salida compilada que git no tiene:** `Themes\RockNextGen\`, `Themes\RockManagerNextGen\`,
     `Themes\NextGenCheckin\`, `Styles\styles-v2\` (102 archivos; ver
     `docs/HANDOFF/upgrade-19.8.1/regenerados_por_el_build.txt`). Sin ellos el sitio interno y el Check-in
     Manager quedan sin estilos.
   - **No** usar `Plugin.CybersourceInlineRestGateway\Deploy\` (kit viejo con `Rock.dll` 18.1.0).
   - Anotar `Get-FileHash` de cada archivo del kit.

### 7.2 Qué se conserva en el servidor (el kit no lo trae ni lo pisa)

| Ruta en `RockWeb\` | Por qué |
|---|---|
| `Content\` (todo) | Logos, íconos, imágenes de correos y páginas; raíz del proveedor de assets «Local Content». Solo existe en prod |
| `App_Data\` (todo): `Files`, `Communication Attachments`, `Communication Images`, `MobileAppBundles` (archivos de FileSystem), `Logs`, `Geolocation`, `PackageStaging`, `Avatar`, `Uploads`, `Cache`, `ChromeEngine`, `InstalledStorePackages.json` si existe | Archivos de usuarios y estado de Rock |
| `Cache\` | Caché de Rock |
| `web.config` | Se **fusiona** (§7.1 paso 5), no se pisa con el del repo |
| `web.ConnectionStrings.config` | Nunca se toca |
| `Plugins\` de terceros: `com_bemaservices`, `com_blueboxmoon`, `com_centralaz`, `com_mineCartStudio`, `tech_triumph`, `Qrgenerador`, `TwilioOverrideWhatsApp` | Rock Shop / binarios sin fuente |
| DLLs del Rock Shop en `Bin\`: `com.bemaservices.MailChimp.dll`, `com.bemaservices.WorkflowExtensions.dll`, `MailChimp.Net*.dll`, `com.blueboxmoon.*.dll`, `com.minecartstudio.*.dll`, `tech.triumph.*.dll` | No salen de ningún build |
| Todo lo que la comparación (§13) marque como «solo en prod» y se decida conservar | — |

### 7.3 El día

1. Respaldo: `.bak` de la BD `Rock18` (COPY_ONLY, CHECKSUM, verificado) y **copia completa** de `RockWeb`
   (incluye `Content`, `App_Data`, `Bin`, `Plugins`, `web.config`). Con el sitio detenido para que sea consistente.
2. `app_offline.htm` y detener el sitio (trampa 1).
3. **Mover** (no borrar) a la carpeta de respaldo lo que la 19 eliminó: lista
   `docs/HANDOFF/upgrade-19.8.1/quitar_del_servidor.txt`. Obligatorio: `Bin\Rock.SignNow.dll`, `Bin\SignNowSDK.dll`
   (+ `.pdb`) y `Webhooks\SignNow.ashx`; si se quedan, el arranque falla (§5b). El resto: `.ascx/.cs` de bloques
   que upstream reemplazó por Obsidian, `Styles\styles-v2\*` viejos, 3 bundles `.obs.js` de controles eliminados.
   ```powershell
   $rw = '<ruta>\RockWeb'; $dst = 'D:\deploy-backup\<fecha>\retirados'
   Get-Content quitar_del_servidor.txt | Where-Object { $_ -and -not $_.StartsWith('#') } | ForEach-Object {
       $rel = $_ -replace '/', '\'; $src = Join-Path $rw $rel
       if (Test-Path -LiteralPath $src) {
           $d = Join-Path $dst $rel; New-Item -ItemType Directory -Force (Split-Path $d) | Out-Null
           Move-Item -LiteralPath $src -Destination $d } }
   ```
4. Copiar el kit **encima** de `RockWeb` (todo en la misma pasada: DLLs, bundles, `App_Code`, temas compilados).
5. Poner el `web.config` fusionado con `RunJobsInIISContext=False`.
6. Quitar `app_offline.htm`, arrancar y esperar migraciones. Medido en local: ~1 min de compilación en frío +
   46 s de 67 migraciones core + 5 s de 45 hotfixes; segundo arranque 72 s. Vigilar
   `App_Data\Logs\MigrationLog.csv`, `RockExceptions.csv` y `ExceptionLog`. Anotar el `ExceptionLog.Id` máximo
   como línea base para las pruebas.
7. Jobs post-actualización con «Run Now», en el orden de §11.3, más el job propuesto para los 2 bloques huérfanos
   (§11.4, `Dev Tools\Upgrade\19.8.1_job_reemplazo_bloques_huerfanos.sql`).
8. Pruebas: `PLAN_PRUEBAS_19.8.1.md`, columna P.
9. Si todo está bien: devolver `RunJobsInIISContext` a su valor original (reinicia el sitio).

**Rollback:** detener el sitio, restaurar el `.bak` y la copia completa de `RockWeb`. Las migraciones de la 19 no
tienen vuelta atrás: el rollback es **siempre** BD + archivos juntos.

---

## 8. Hallazgo de seguridad (ya existe en la 18.1 de producción)

**Passwordless sin límite de intentos de verificación.** El código va cifrado en el `state` que guarda el
cliente y `PasswordlessAuthentication.IsRequestValid` solo lo compara. No hay contador de intentos
fallidos; el único límite (`PasswordlessSignInDailyIpThrottle`) es por IP al **enviar** el código. Con
nuestro alfabeto numérico de 6 dígitos son 10⁶ combinaciones (upstream: 23⁶ ≈ 1.5×10⁸). Rock 19.8.1
no lo corrige. **No se arregla en este upgrade**: arreglo aparte (contador de intentos por
`RemoteAuthenticationSession` o volver al alfabeto de upstream).

---

## 9. Pendientes

- ~~Fase 3 bloqueada por Smart App Control~~ — **resuelto el 2026-11-19**: el responsable lo desactivó y la
  Fase 3 corrió. Registro original: **Fase 3 bloqueada por Smart App Control de Windows 11** en la máquina de desarrollo: CodeIntegrity
  eventos 3033/3077 sobre los `App_Web_*.dll` / `App_Browsers.*.dll` que ASP.NET compila en
  `%LOCALAPPDATA%\Temp\Temporary ASP.NET Files\`. Impide la precompilación de `RockWeb` y el arranque con
  IIS Express. **No afecta a producción** (Windows Server no tiene Smart App Control). El responsable lo va a
  desactivar en esta máquina; antes de reanudar la Fase 3, borrar `%LOCALAPPDATA%\Temp\Temporary ASP.NET Files\`.
- El merge se commiteó (2026-11-19, decisión del responsable) con los proyectos de `Rock.sln` y los 8
  plugins compilando; la precompilación de `RockWeb` queda por validar en la Fase 3.
- Textos en inglés que entraron con upstream: mensajes de elegibilidad en `registrantPersonField`
  (`must be … due to eligibility requirements`) y `capacityFullFailure.partial.obs`.
- Props `hideActions` de upstream sin uso en los pasos de AccountEntry (inofensivas).
- **Bloques huérfanos sin job (§11.4):** páginas 327 «System Phone Numbers» y 740 «Experience Administration».
  Job propuesto listo, **no aplicado** (decisión del responsable).
- **Tema `VidAventuracheckin` no recompila en la 19 (§12):** falta `_css-overrides.less`. Arreglo propuesto
  (crear el archivo vacío en el repo), **no aplicado**.
- **Check-in Manager:** Roster en inglés (personalización perdida, §6); pasa al tema `RockManagerNextGen`.
- **Comparación servidor vs repo (§13):** correr el script en prod y revisar el resultado antes de fijar fecha.
- **Rock Shop:** confirmar versiones para la 19 en *Installed Plugins* de prod (`INVENTARIO_DESARROLLOS_VR.md` §3).
- **`RunJobsInIISContext` de prod:** pedir el valor a TI (§11.5).
- Acciones de workflow con DLL fuera de `Bin` (workflows 77 y 83): no cargan desde la 18.1; decidir si se
  retiran (`INVENTARIO_DESARROLLOS_VR.md` §4.3).

---

## 10. Pruebas

Checklist por módulo para local y prod: **`PLAN_PRUEBAS_19.8.1.md`** (URL, qué hacer, qué debe pasar, y la consulta
de `ExceptionLog` para revisar después del recorrido; línea base local `ExceptionLog.Id` = 1630320).
Resultados: _(pendiente, Fase 4)_.

---

## 11. Jobs post-actualización — análisis (2026-11-19, sin correr ninguno)

### 11.1 Respaldo previo

`Rock19Test` ya migrada a 19.8.1 y **antes de cualquier job**:
`C:\Program Files\Microsoft SQL Server\MSSQL17.MSSQLSERVER\MSSQL\Backup\Rock19Test_migrada_sin_jobs_2026-11-19.bak`
(COPY_ONLY, COMPRESSION, CHECKSUM; 905 594 páginas en 20,5 s; `RESTORE VERIFYONLY`: válido). Fuera del repo.
Sirve para repetir el análisis o volver atrás si un job hace algo inesperado.

### 11.2 Los 4 jobs «Replace WebForms Blocks with Obsidian»

Clase `Rock.Jobs.PostUpdateDataMigrationsReplaceWebFormsBlocksWithObsidianBlocks`. Por cada par
(WebForms → Obsidian) copia cada bloque al tipo nuevo en la misma zona y orden, copia valores de atributos,
permisos y preferencias, y **borra los bloques viejos**. Con estrategia **Chop**, además **borra el BlockType viejo
y su `.ascx`/`.ascx.cs` del disco** del servidor. Si termina bien, se borra a sí mismo; si falla, queda como
no-sistema con el error.

| Job | Estrategia | Reemplaza | Instancias en prod | Página | ¿El `.ascx` existe en la 19? |
|---|---|---|---|---|---|
| 222 | Swap | File Manager `~/Blocks/Cms/FileManager.ascx` → File Asset Manager (Obsidian) | 1 | 433 «File Manager» | ❌ (borrado en la 19: la página está rota hasta correr el job) |
| 223 | Chop | Registration Entry `~/Blocks/Event/RegistrationEntry.ascx` → `Rock.Blocks.Event.RegistrationEntry` | **0** (la inscripción ya es Obsidian) | — | ❌ |
| 226 | Chop | Service Metrics Entry `~/Blocks/Reporting/ServiceMetricsEntry.ascx` → Obsidian | 1 | 451 «Weekly Metrics» | ❌ (página rota hasta correr el job) |
| 227 | Chop | Asset Manager `5EC30776…` (no existe en nuestra BD) y File Manager → File Asset Manager | 1 (el mismo de 222) | 433 | ❌ |

**¿Se pueden conservar los bloques viejos?** Solo con estrategia Swap y el atributo «Should Keep Old Blocks (FOR
TESTING PURPOSES ONLY)»; Chop lo ignora. **No tiene sentido usarlo aquí:** los 4 `.ascx` ya no existen en la 19, así
que un bloque viejo conservado solo muestra error.

**Cruce con nuestros bloques personalizados** (check-in, TransactionDetail/List, PersonMerge, GivingOverview,
RegistrationDetail, RegistrationInstanceRegistrationList): **ninguna coincidencia**. Ningún job pendiente los
reemplaza y sus `.ascx` siguen en 19.8.1. **No se pierde ninguna personalización.** Nuestra RegistrationEntry es
el bloque Obsidian (`0252E237…`, destino del job 223): el job no lo modifica, solo limpia el BlockType WebForms sin
uso. Riesgo a futuro: si una versión 20.x «chopea» TransactionList/Detail, PersonMerge o el check-in, ahí sí se
pierden nuestras personalizaciones; revisar la lista de jobs de cada upgrade futuro.

### 11.3 Recomendación

| Job | Qué hace | Recomendación |
|---|---|---|
| 231, 233 | Corrigen `MimeType` de imágenes de transacción y de persona (BinaryFile) | Correr tal cual |
| 232 | Limpia valores de redes sociales | Correr tal cual |
| 220, 221, 225 | Crean índices (FinancialBatch, Communication, Unsubscribe) | Correr tal cual; pueden tardar en tablas grandes: dentro de la ventana |
| 228 | Arregla Achievement Types | Correr tal cual |
| 230 | Rellena `ConnectedDateTime` de solicitudes de conexión | Correr tal cual |
| 222 → 227 | File Manager → File Asset Manager | Correr tal cual (sin conservar bloques viejos); probar página 433 |
| 223 | Limpia el RegistrationEntry WebForms | Correr tal cual; volver a probar la inscripción (`PLAN_PRUEBAS` 7.4) |
| 226 | Service Metrics Entry → Obsidian | Correr tal cual; probar página 451 |
| Propuesto (§11.4) | System Phone Numbers + Interactive Experiences | Crear y correr (pendiente de aprobación) |
| 224, 229 | Jobs normales nuevos (Outreach Toolbox, Analytics PostalCode); horarios `:10` cada hora y 01:20 | No son de actualización: decidir si quedan activos como los demás jobs de prod |

Ninguno se recomienda «no correr»: los que tocan bloques arreglan páginas que la 19 dejó rotas.

### 11.4 Bloques huérfanos que ningún job arregla

`Test-TiposRock.ps1` (`INVENTARIO_DESARROLLOS_VR.md` §5) encontró dos bloques en páginas cuyo `.ascx` borró la 19
(commits `9a14ff011b` y `c44e103663`, «chopped webforms»):

| Página | BlockType viejo (nuestra BD) | Nuevo (Obsidian, ya registrado) |
|---|---|---|
| 327 «System Phone Numbers» | `CCF3C814-5D4E-4BBE-BB69-7FFBF7D1A45D` (`SystemPhoneNumberList.ascx`) | `72C74D98-D80F-4EEE-BD14-6308EA565D7A` |
| 740 «Experience Administration» | `1BC8542B-D2C8-4496-BB5C-EFF4C0E6AE9D` (`InteractiveExperienceList.ascx`) | `BD89FE49-4DD2-4313-AFF8-ABAA97B3235D` |

Causa: upstream hizo que el bloque Obsidian reuse el GUID del `.ascx`, pero en nuestra BD esos `.ascx` se
registraron con otros GUIDs; la 19 creó BlockTypes nuevos y las páginas quedaron apuntando a un `.ascx`
inexistente. Las llaves de atributos coinciden (`SystemPhoneNumberDetailPage`; `DetailPage`,
`OccurrenceChooserPage`). **Propuesta, no aplicada:** `Dev Tools\Upgrade\19.8.1_job_reemplazo_bloques_huerfanos.sql`
crea un job más del mismo tipo de upstream (Chop) con esos dos pares; se corre con «Run Now». Vale igual para prod
(mismos GUIDs). Alternativa manual: borrar el bloque de cada página y agregar el Obsidian, reconfigurando la
página de detalle.

### 11.5 Si en prod `RunJobsInIISContext` es True

Los jobs post-actualización los crean las migraciones al arrancar, con cron diario a las **21:00** (220–223,
226, 227, 231–233), **20:00** (228) y **02:00** (225, 230). Con el scheduler activo correrían solos esa noche,
junto con los ~95 jobs normales de prod. Para controlarlos:
- **Recomendado:** desplegar el `web.config` de la 19 con `RunJobsInIISContext=False` (§7.3 paso 5), correr los
  jobs con «Run Now», probar, y al final devolver el valor original (reinicia el sitio).
- Alternativa: inmediatamente después de las migraciones, desactivar solo esos jobs por SQL
  (`UPDATE ServiceJob SET IsActive = 0 WHERE Class LIKE 'Rock.Jobs.PostV%' OR Class LIKE 'Rock.Jobs.PostUpdate%'`) y
  correrlos a mano. Que «Run Now» funcione con el job inactivo es una suposición **no verificada**: probarla en
  local antes de elegir esta vía.

---

## 12. Check-in: ¿la 19 obliga a migrar a Obsidian? (análisis, 2026-11-19)

**Veredicto: no.** El check-in WebForms (`RockWeb/Blocks/CheckIn/*.ascx`, `CheckInState`, `KioskDevice`, acciones
`Rock.Workflow.Action.CheckIn.*`) sigue en 19.8.1 sin marcas `[Obsolete]` nuevas.

Evidencia (git `f8e5bcf161` → `85705ceb0b`):
- En `RockWeb/Blocks/CheckIn` lo único borrado es `Manager/Roster.ascx` (`3ab0ca2523`): el Roster pasó a Obsidian
  reusando su GUID. El resto solo trae arreglos (`EncodeHtml`, `PinAttemptLimiter` en `Welcome.ascx.cs`,
  `GetUnsecurePersonIdentifier` en `MobileLauncher`). El merge conservó esos arreglos junto a los nuestros.
- `Rock/CheckIn/{CheckInState,KioskDevice,CheckInBlock}.cs` sin cambios; en las acciones solo `FindFamilies.cs`
  (`WithRecompile`) y `SaveAttendance.cs` (cosmético).
- Migración `202602092251477_UpdateCheckinManagerToNextGen`: solo toca el **Check-in Manager** (borra «Room
  Settings», renombra Roster a «Room Manager», tema `RockManagerNextGen`). El sitio del kiosco no se toca.
- Los temas LESS legacy siguen compilando en runtime (dotless, `Rock/Web/UI/RockTheme.cs`).
- Señales de retiro futuro: comentarios «Temporary until legacy check-in is removed» (ya estaban en 18.1) y,
  nuevo en la 19, guardas `#if NET472_OR_GREATER` alrededor de la interoperabilidad con el check-in legacy.
  *Inferido:* upstream lo retirará cuando deje .NET Framework (20.x o después); no hay fecha anunciada.

BD (`Rock19Test`): 47 bloques WebForms de check-in/asistencia, **todos con su `.ascx` en disco**. El sitio «Rock
Check-in» tiene tema `CheckinPark`; `VidAventuracheckin` no está asignado a ningún sitio: lo fuerza
`RockWeb/Blocks/CheckIn/Admin.ascx.cs:215` (`activeTheme = "vidaventuracheckin"`).

**Riesgos para el día:**
1. **El tema VidAventuracheckin no recompila (verificado).** `checkin-theme.less:140` importa `_css-overrides.less`,
   que nunca existió en la carpeta (el defecto viene de `hotfix-18.1`). Al cambiar `RockWeb/Styles` en la 19,
   Rock intenta recompilar y falla (`ExceptionLog` 1630300). Se sigue sirviendo el `checkin-theme.css` compilado
   antes, así que el kiosco se ve igual pero no recibe cambios. **Arreglo propuesto (no aplicado):** crear
   `RockWeb/Themes/VidAventuracheckin/Styles/_css-overrides.less` vacío (y, si se quieren los íconos `ti`, el
   `@import` de tabler que upstream agregó a sus temas de check-in). Antes, revisar si prod tiene ese archivo (§13).
2. Check-in Manager pasa a `RockManagerNextGen`: el kit debe traer ese tema compilado (§7.1).
3. Roster en inglés (§6).
4. Los `.ascx` compilan al primer request: un error de compilación solo aparece al abrir la página.

Recomendación: no migrar el kiosco a Obsidian ahora; probar el flujo completo (`PLAN_PRUEBAS_19.8.1.md` §8) y
planear la migración a next-gen antes de la 20.x.

---

## 13. Comparación servidor vs repo (preparada, no ejecutada)

Objetivo: detectar archivos cambiados o agregados en prod que no están en el repo, antes de copiar el kit.

1. **En el servidor** (solo lectura; no lee `web.config` ni connection strings; Content/App_Data/Cache solo se
   cuentan):
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\Get-RockWebInventario.ps1 -RockWeb "<ruta>\RockWeb" -CarpetaSalida "<carpeta fuera de RockWeb>"
   ```
   Genera `RockWeb_inventario_<equipo>_<fecha>.csv` (Ruta, Bytes, Modificado, SHA256), `…_excluidas_….csv` y un
   `.txt` de resumen. Probado en la máquina de dev: 5 768 archivos, 197 s, 0 errores. Se puede correr con el
   sitio arriba.
2. **En la máquina de desarrollo**, inventario de la referencia (lo que debería estar en prod):
   ```powershell
   git worktree add ..\Rock-ref-prod hotfix-18.1
   & ".\Dev Tools\Upgrade\Get-RockWebInventario.ps1" -RockWeb ..\Rock-ref-prod\RockWeb -SinValidarBin -CarpetaSalida <x>
   & ".\Dev Tools\Upgrade\Compare-RockWebInventario.ps1" -Servidor <csv de prod> -Referencia <csv de la referencia>
   git worktree remove ..\Rock-ref-prod
   ```
3. Leer el resultado: `DISTINTO` y `SOLO_SERVIDOR` con `Generado=No` son los que importan (cambios hechos
   directamente en prod, o plugins/archivos que hay que conservar). `Generado=Si` (Bin, Obsidian, temas
   compilados) es esperado. `SOLO_REFERENCIA` = algo del repo que nunca se desplegó.
4. Cada hallazgo: traerlo al repo, o agregarlo a §7.2 «Qué se conserva».

Además, `Dev Tools\Upgrade\Test-TiposRock.ps1` puede correrse contra el `RockWeb` de prod después del upgrade
(`INVENTARIO_DESARROLLOS_VR.md` §5).
