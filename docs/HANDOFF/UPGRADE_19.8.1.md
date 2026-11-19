# Upgrade de Rock 18.1 → 19.8.1 (prueba local y runbook del cambio real)

> **Estado:** en prueba **local** (máquina `DESKTOP-PB412F9`, BD `Rock19Test`). Nada de esto se ha
> aplicado en producción. Este documento se actualiza al cerrar cada fase.
>
> | Fase | Estado |
> |---|---|
> | 1. BD nueva aislada | ✅ 2026-11-19 |
> | 2. Merge de código + build | ✅ commiteado (local, sin push); core + 8 plugins compilan; precompilación de `RockWeb` pendiente (Smart App Control) |
> | 3. Arranque y migraciones | ⛔ bloqueada por Smart App Control (§9) |
> | 4. Pruebas de humo | ⏳ |

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

## 6. Personalizaciones perdidas que hay que reaplicar en la 19

| Qué | Dónde estaba (18.1) | Cómo reaplicar en la 19 |
|---|---|---|
| Color primario `--base-primary: #073642` (upstream `#FF791D`) | `RockWeb/Themes/RockNextGen/Styles/theme.css`, bloque «CSS Overrides Bottom» | Editor de temas de la 19 (Admin > CMS > Themes > RockNextGen), o variables en `Rock.Frontend.Styles/src/themes/RockNextGen/Styles/` |
| Logo de Vida Real en la esquina del navbar: `.navbar-brand-corner.no-logo:after { background-image: url('/Content/ExternalSite/Icons/icon-ipad-retina-vr.png'); background-size: 42px 42px; 80×80 }` (todo `!important`) | ídem | ídem (CSS overrides del tema) |
| Roster del Check-in Manager en español: títulos `Confirmar`, botones `Registrar Entrada` / `Registrar Salida` (3 modales) | `RockWeb/Blocks/CheckIn/Manager/Roster.ascx` (borrado en la 19) | El Roster ahora es Obsidian: traducir en el bloque nuevo o con el Traductor; revisar en las pruebas de check-in |

El diff completo de lo perdido quedó en la carpeta temporal de la sesión; se puede regenerar con
`git diff 18.1.0 b61a80a019 -- RockWeb/Themes/RockNextGen RockWeb/Blocks/CheckIn/Manager/Roster.ascx`.

---

## 7. Runbook para producción (borrador; se completa con los tiempos medidos)

1. **Antes:** confirmar que la 19.8.1 es estable. Ventana anunciada. Respaldo completo de la BD `Rock18`
   (`.bak` en SQL 2022 de prod) y copia de `RockWeb` completo (incluye `Bin`, `App_Code`, `Plugins`,
   `web.config`, `web.ConnectionStrings.config`).
2. Plugins del Rock Shop (MailChimp/bema, AcmeCertificate y DataToolkit/blueboxmoon, MinePass,
   MinistryPass): conseguir las versiones compatibles con 19.x **antes** del día. _(resultado local: §10)_
3. `app_offline.htm` en `RockWeb` y detener el sitio (trampa 1: nada en caliente).
4. Copiar **juntos** los artefactos del mismo build: **todo `RockWeb\Bin`** (no solo las DLLs del fork:
   122 DLLs de terceros cambian de versión, §4) + las DLLs de los 8 plugins + `RockWeb\Obsidian\`
   completo + los temas compilados (`RockWeb\Themes\` de `Rock.Frontend.Styles`) + `web.config` de la 19
   con las llaves de prod (`PasswordKey`, `DataEncryptionKey`…) fusionadas. Conservar en `Bin` las DLLs
   de terceros del Rock Shop solo si sus versiones nuevas lo indican.
5. Quitar `app_offline.htm`, arrancar y esperar las migraciones. _(tiempo medido en local: pendiente)_
6. Jobs post-actualización de la 19: _(lista pendiente, Fase 3)_
7. Verificación: pruebas de humo de §10.
8. **Rollback:** detener el sitio, restaurar el `.bak` de la BD y la copia de `RockWeb`. Las migraciones
   de la 19 no tienen vuelta atrás en caliente: el rollback es **siempre** BD + archivos juntos.

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

- **Fase 3 bloqueada por Smart App Control de Windows 11** en la máquina de desarrollo: CodeIntegrity
  eventos 3033/3077 sobre los `App_Web_*.dll` / `App_Browsers.*.dll` que ASP.NET compila en
  `%LOCALAPPDATA%\Temp\Temporary ASP.NET Files\`. Impide la precompilación de `RockWeb` y el arranque con
  IIS Express. **No afecta a producción** (Windows Server no tiene Smart App Control). El responsable lo va a
  desactivar en esta máquina; antes de reanudar la Fase 3, borrar `%LOCALAPPDATA%\Temp\Temporary ASP.NET Files\`.
- El merge se commiteó (2026-11-19, decisión del responsable) con los proyectos de `Rock.sln` y los 8
  plugins compilando; la precompilación de `RockWeb` queda por validar en la Fase 3.
- Textos en inglés que entraron con upstream: mensajes de elegibilidad en `registrantPersonField`
  (`must be … due to eligibility requirements`) y `capacityFullFailure.partial.obs`.
- Props `hideActions` de upstream sin uso en los pasos de AccountEntry (inofensivas).

---

## 10. Pruebas

_(pendiente, Fase 4: login, persona/familia, Eventos compra + ticket, QR, Wallet, Dar, check-in
Obsidian, inscripción nativa de Rock (RegistrationEntry), páginas externas, Traductor, WhatsApp
(compila, carga el transporte y sus atributos siguen en la BD; sin reactivarlo ni enviar), escáner
QREVENT)_
