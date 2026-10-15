# Cambios del fork VidaReal respecto a Rock RMS upstream (SparkDevNetwork)

Fecha del análisis: **2026-10-15** · Rama analizada: `hotfix-18.1` (HEAD `81d2622dbc`) + working tree.
Lista plana para checklist de portado: [`core-files-modified.txt`](core-files-modified.txt) (148 rutas).

Este documento compara el fork contra **la versión de Rock de la que nació**, no contra otras ramas
del fork. Su objetivo es que el próximo desarrollador sepa qué partes del core de Rock se tocaron,
qué es código propio y cómo actualizar a una versión nueva de Rock sin perder nada.

---

## Índice

1. [Base upstream: de qué versión de Rock parte el fork](#1-base-upstream)
2. [Resumen en números](#2-resumen-en-números)
3. [A. Modificaciones al core de Rock](#a-modificaciones-al-core-de-rock) (lo crítico al actualizar)
4. [B. Código nuevo dentro de proyectos core](#b-código-nuevo-dentro-de-proyectos-core)
5. [C. Proyectos y plugins propios](#c-proyectos-y-plugins-propios)
6. [D. Scripts SQL, temas, App_Code, assets, Dev Tools y documentación](#d-scripts-sql-temas-app_code-assets-dev-tools-y-documentación)
7. [E. Migraciones de base de datos propias](#e-migraciones-de-base-de-datos-propias)
8. [Ruido excluido del análisis](#ruido-excluido-del-análisis)
9. [Cómo actualizar a una nueva versión de Rock](#cómo-actualizar-a-una-nueva-versión-de-rock)
10. [Archivos core de alto riesgo (top)](#archivos-core-de-alto-riesgo)
11. [Hallazgos y advertencias](#hallazgos-y-advertencias)

---

## 1. Base upstream

| Dato | Valor |
|---|---|
| Commit base | `f8e5bcf16123119e79fc3cc7228499ce9065dd66` (2025-12-08, *"Removed a v18.0 Rock Startup Job responsible for improving a Communication Recipient index…"*) |
| Tag upstream | **`18.1.0`** (también `18.1.0-beta` apuntan al mismo commit) |
| Rama upstream equivalente | `upstream/hotfix-18.1`: su punta es exactamente ese commit |
| Primer commit propio | `ca2ca0ec94` "Bloques nuevos" (2026-02-10), hijo directo del commit base |
| Commits propios | 43 commits lineales (sin merges), todos de `rodobriones`, de `ca2ca0ec94` a `81d2622dbc` |

**Cómo se determinó:**

```bash
git fetch upstream --tags                      # funcionó; upstream = github.com/SparkDevNetwork/Rock
git merge-base HEAD upstream/hotfix-18.1      # -> f8e5bcf161...
git merge-base HEAD upstream/develop          # -> f8e5bcf161... (mismo)
git merge-base HEAD 18.1.0                    # -> f8e5bcf161... (mismo)
git rev-list -n1 18.1.0                       # -> f8e5bcf161... => la base ES el tag 18.1.0
git describe --tags --abbrev=0 HEAD           # -> 18.1.0
git rev-list --count --merges f8e5bcf161..HEAD   # -> 0 (historia lineal)
```

Se verificó además que `f8e5bcf161` es ancestro de los tags `18.7.0` y `19.7.0`. Aun así, el
procedimiento recomendado para actualizar **no es un merge** sobre este repo: se baja la BD de prod,
se clona Rock limpio, se sube de versión mayor en versión mayor y lo propio se porta al final (ver
[procedimiento](#cómo-actualizar-a-una-nueva-versión-de-rock)).

> **Ojo con la documentación vieja.** Varios `CHANGES.md` del repo dicen *"Base de comparación:
> commit `ca2ca0ec94`"*. Ese es el **primer commit propio**, no la base: comparar contra él omite lo
> que entró en ese mismo commit. La base correcta es `18.1.0` / `f8e5bcf161`.

Para reproducir cualquier diff de este documento:

```bash
git diff --stat 18.1.0..HEAD            # comprometido
git diff --stat HEAD                    # working tree sin commitear
git diff 18.1.0 HEAD -- <archivo>       # cambio exacto de un archivo core
```

---

## 2. Resumen en números

Total: **634 archivos** distintos entre `18.1.0` y `HEAD` (486 agregados, 139 modificados, 9
borrados), más 5 archivos del módulo QR que al momento del análisis estaban sin commitear (ya en producción; commiteados después en `36fa46789a`).

| Categoría | Archivos | Comentario |
|---|---|---|
| **A. Core modificado** (existe upstream y se editó/borró) | **148** | 139 modificados + 9 borrados. Incluye `RockWeb/Plugins/.gitignore`. Ver [`core-files-modified.txt`](core-files-modified.txt) |
| **B. Código nuevo en proyectos core** | 144 | 131 en `Rock/`, `Rock.Blocks/`, `Rock.ViewModels/`, `Rock.Rest/`, `Rock.JavaScript.Obsidian*/`, `Rock.Tests/` + 13 en `RockWeb/Blocks`, `App_Code`, `Webhooks`. +5 archivos QR modificados **sin commitear** |
| **C. Proyectos/plugins propios** | 106 (+62 en `RockWeb/Plugins`) | 7 carpetas `Plugin.*` + `Rock.WhatsApp`. `RockWeb/Plugins` versiona DLLs/archivos de plugins (propios y de terceros) |
| **D. Scripts, temas, assets, Dev Tools** | 51 | Seed SQL, tema VidAventuracheckin, fuentes, Dev Tools, `Asistencia/` |
| **E. Migraciones propias** | 58 | Todas en proyectos `Plugin.*` (Plugin Migrations de Rock). **Cero** migraciones en `Rock.Migrations` |
| Documentación (`*.md`, `docs/`, `.claude/`, PDFs) | 66 | No afecta el build |

Archivos sin seguimiento al momento del análisis: `Dev Tools/Build/build-all.ps1` y
`Dev Tools/Build/check-prereqs.ps1` (los está escribiendo otro agente del handoff; no son parte de
esta comparación).

---

## A. Modificaciones al core de Rock

Son archivos que **existen en SparkDevNetwork/Rock** y que el fork editó. Cada uno es un conflicto
potencial en cada actualización. Columnas:

- **Δ** = líneas agregadas/quitadas contra `18.1.0`.
- **Up 18.7 / Up 19.7** = cuántos commits upstream tocaron ese archivo entre `18.1.0` y el tag
  indicado. Es el mejor predictor de conflicto: 0 = el merge casi seguro entra limpio.
- **Riesgo**: combinación de churn upstream, tamaño del cambio propio y criticidad funcional.

Convención: el código propio dentro de archivos core suele estar marcado con `VR:`, `[VidaReal]` o
`Fork VidaReal` en comentarios. Buscar esos marcadores después de un merge ayuda a confirmar que nada
se perdió (no todos los cambios de UI/i18n están marcados).

### A.1 Librería core `Rock/` (C#)

| Archivo | Δ | Up 18.7 / 19.7 | Qué se cambió y por qué | Riesgo |
|---|---|---|---|---|
| `Rock/Security/Authentication/PasswordlessAuthentication.cs` | +44/−18 | 2 / 2 | (1) Mensajes de error traducidos al español. (2) Búsqueda de persona por teléfono **con o sin código de país** (el front ahora manda `+<código><dígitos>`; los teléfonos legados están sin código) y sufijo de ≥7 dígitos. (3) Devuelve `PhotoUrl` y `Age` de cada coincidencia. Doc: `Rock/Security/Authentication/CHANGES.md` | **Alto** (login de todos) |
| `Rock/Model/Security/RemoteAuthenticationSessionService.cs` | +1/−4 | 2 / 2 | El código OTP pasa de alfanumérico (`BCDFGHJKLMNPRSTXZ245678`) a **solo dígitos** `0123456789` (UX tipo banca, teclado numérico). Ver [hallazgos](#hallazgos-y-advertencias) sobre entropía | Medio-alto |
| `Rock/Security/Authentication/OneTimePasscode/MatchingPersonResult.cs` | +10/−0 | 0 / 0 | Propiedades nuevas `PhotoUrl` y `Age` (selección de persona en passwordless) | Bajo |
| `Rock/Communication/Medium/Sms.cs` | +20/−1 | 0 / 1 | Overload nuevo de `ProcessResponse(..., Person resolvedFromPerson, ...)`: permite que el webhook de WhatsApp pase el remitente ya resuelto por `wamid` (varias personas comparten celular). Con `null` se comporta igual que Rock | Bajo |
| `Rock/Communication/SmsActions/SmsActionConversations.cs` | +5/−1 | 0 / 0 | Pasa `message.FromPerson` al overload anterior. Doc: `Rock.WhatsApp/CHANGES.md` §"Atribución del remitente" | Bajo |
| `Rock/Model/Event/Registration/RegistrationService.cs` | +3/−2 | 1 / 3 | El total pagado de una inscripción resta `FeeCoverageAmount` (recargo por cuotas de ePay no debe reducir el saldo). Doc: `EPAY_FLOW_SUMMARY.md` | Medio |
| `Rock/Model/Finance/FinancialTransaction/FinancialTransactionService.cs` | +4/−1 | 1 / 3 | Historial mensual de donaciones agrupa también por `ForeignCurrencyCodeValueId` (multi-moneda GTQ/USD/MXN) | Medio |
| `Rock/Model/Finance/FinancialTransaction/MonthlyAccountGivingHistory.cs` | +6/−0 | 0 / 0 | Propiedad `ForeignCurrencyCodeValueId` (soporte del cambio anterior) | Bajo |
| `Rock/SystemGuid/DefinedType.cs` | +7/−0 | 0 / 1 | Constante `LOCATION_ADDRESS_MUNICIPALITY` (`85788452-69E0-45C5-B7A4-8134AFDC5975`) para la cascada Departamento→Municipio | Bajo |
| `Rock/Web/UI/Controls/AddressControl.cs` | +238/−14 | 1 / 1 | Cascada Departamento→Municipio en WebForms: `_ddlCity`, `BindCities`, AutoPostBack del estado **solo** si el país tiene cascada, orden del DOM invertido, anchos `col-sm-4/5`. La regla vive en `Rock/Model/Core/Location/AddressCascade.cs` (nuevo). Doc: `CHANGES.md` raíz, fila "Direcciones Guatemala" | **Alto** (control usado en muchos bloques) |
| `Rock/Rock.csproj` | +2/−0 | 1 / 12 | `PackageReference System.Net.Http.WinHttpHandler 8.0.0` (HTTP/2 para APNs de Wallet) y `Reference System.IO.Compression` (pkpass). Las clases nuevas de `Rock/` entran por globbing, no están listadas | Medio (churn alto del csproj) |

### A.2 `Rock.Blocks/`, `Rock.Rest/`, `Rock.ViewModels/` (C#)

| Archivo | Δ | Up 18.7 / 19.7 | Qué se cambió y por qué | Riesgo |
|---|---|---|---|---|
| `Rock.Blocks/Event/RegistrationEntry.cs` | +202/−2 | **32 / 59** | Región "Vida Real – NIT / FEL Validation": BlockAction `ValidateNitInfo` + `LookupNitFromExternalApi` (valida NIT contra SAT vía Global Attributes `OdooNitApiUrl`/`OdooNitApiBearerToken`, whitelist https anti-SSRF, rate-limit). En `ProcessPostSave` el `LaunchWorkflow` pasa `{ Nit, WantsInvoice }` al workflow de facturación Odoo. Doc: `AI_HANDOFF_ROCK18_EVENT_CRM.md`, `Plugin.OdooEventSale/CONTEXT.md` | **Crítico** |
| `Rock.Blocks/Security/Login.cs` | +4/−1 | 2 / 4 | En la selección de persona passwordless: `Text = "Nombre|Edad"` (el front lo separa) y `Category = PhotoUrl`. Contrato implícito con `passwordlessLoginVerifyStep.partial.obs` | Medio |
| `Rock.Blocks/Rock.Blocks.csproj` | +3/−0 | 0 / 6 | Referencia `EPPlus` (`..\libs\EPPlus\EPPlus.dll`, ya existe en upstream) para exportes de reportes propios | Medio |
| `Rock.Rest/v2/ControlsController.cs` | +10/−0 | **35 / 82** | `AddressControlGetConfiguration` devuelve municipios del departamento (cascada) | **Alto** (archivo enorme y muy activo upstream) |
| `Rock.ViewModels/Blocks/Event/RegistrationEntry/RegistrationEntryArgsBag.cs` | +12/−0 | 0 / 0 | Props `Nit`, `WantsInvoice` | Bajo |
| `Rock.ViewModels/Rest/Controls/AddressControlConfigurationBag.cs` | +17/−0 | 0 / 0 | Props `Cities`, `HasCityList`, `SupportsCityList` | Bajo |
| `Rock.ViewModels/Rest/Controls/AddressControlGetConfigurationOptionsBag.cs` | +6/−0 | 0 / 0 | Prop `StateCode` | Bajo |

### A.3 Framework Obsidian `Rock.JavaScript.Obsidian/` (controles compartidos)

> **El cambio de mayor alcance del fork:** estos controles los usa prácticamente todo bloque
> Obsidian. Además, el framework Obsidian **se despliega completo** (ver `CHANGES.md` raíz, "Aviso:
> el framework Obsidian se despliega completo"). Doc: `Rock.JavaScript.Obsidian/Framework/Controls/CHANGES.md`.

| Archivo | Δ | Up 18.7 / 19.7 | Qué se cambió y por qué | Riesgo |
|---|---|---|---|---|
| `Framework/Controls/datePartsPicker.obs` | +105/−20 | 1 / 1 | Orden DD/MM en español, nombres de meses bilingües, detección de idioma (localStorage / `<html lang>` / navegador) | **Crítico** |
| `Framework/Controls/datePickerBase.obs` | +30/−4 | 0 / 0 | Props `format` y `language` para bootstrap-datepicker; conversión de formato bootstrap↔Luxon | Alto |
| `Framework/Controls/datePicker.obs` | +15/−1 | 0 / 1 | Expone `format`/`language` | Medio |
| `Framework/Controls/rockValidation.obs` | +15/−1 | 0 / 0 | "Por favor corrige lo siguiente:" si la UI está en español | Medio |
| `Framework/Controls/addressControl.obs` | +131/−10 | 1 / 4 | Dropdown de Municipio con `watch` del departamento, valor legado conservado como opción extra, orden del DOM invertido | **Alto** |
| `Framework/ViewModels/Blocks/Event/RegistrationEntry/registrationEntryArgsBag.d.ts` | +6/−0 | 0 / 0 | Espejo TS de `Nit`/`WantsInvoice` | Bajo (regenerable) |
| `Framework/ViewModels/Rest/Controls/addressControlConfigurationBag.d.ts` | +9/−0 | 0 / 0 | Espejo TS de los bags de dirección | Bajo (regenerable) |
| `Framework/ViewModels/Rest/Controls/addressControlGetConfigurationOptionsBag.d.ts` | +3/−0 | 0 / 0 | Ídem | Bajo (regenerable) |

### A.4 Bloques Obsidian existentes `Rock.JavaScript.Obsidian.Blocks/`

**Configuración del proyecto**

| Archivo | Δ | Up 18.7 / 19.7 | Qué/por qué | Riesgo |
|---|---|---|---|---|
| `package.json` | +5/−1 | 0 / 3 | Dependencias `@zxing/browser` y `@zxing/library` (lectura de QR con cámara en QREVENT) | Medio |
| `package-lock.json` | +75/−0 | 0 / 3 | Consecuencia del anterior. En un merge: tomar el de upstream y re-ejecutar `npm install` | Medio (regenerable) |
| `tsconfig.json` | +4/−0 | 0 / 0 | Registra `src/Dar`, `src/FamilyHub`, `src/Qr`, `src/QREVENT` (los demás módulos nuevos se compilan sin entrada propia) | Bajo |

**Event / RegistrationEntry** — i18n completo al español + sección NIT/FEL en el pago (2026-06-15)
+ rediseño UI/UX 2026 del wizard (2026-06-18, casi todo en `<style scoped>` de `registrationEntry.obs`
con tokens `--re-*` que cascadean con `:deep()`). Doc: `CHANGES.md` raíz §"Rock.JavaScript.Obsidian.Blocks/src/Event (modificado)".

| Archivo (bajo `src/Event/`) | Δ | Up 18.7 / 19.7 | Riesgo |
|---|---|---|---|
| `registrationEntry.obs` | +636/−47 | 1 / 1 | **Alto** (shell del wizard, capa de estilos central, estado NIT) |
| `RegistrationEntry/payment.partial.obs` | +464/−19 | 2 / 3 | **Alto** (toggle de factura, NIT, validación SAT, guard de pago) |
| `RegistrationEntry/utils.partial.ts` | +237/−1 | 1 / 1 | Alto (diccionario i18n + formato multi-moneda) |
| `RegistrationEntry/costSummary.partial.obs` | +117/−38 | 1 / 1 | Medio |
| `RegistrationEntry/success.partial.obs` | +117/−47 | 1 / 3 | Medio |
| `RegistrationEntry/summary.partial.obs` | +94/−13 | 2 / 6 | Medio-alto (tarjetas con avatar) |
| `RegistrationEntry/registrant.partial.obs` | +55/−11 | 0 / 5 | Medio-alto |
| `RegistrationEntry/discountCodeForm.partial.obs` | +53/−8 | 0 / 1 | Medio |
| `RegistrationEntry/registrar.partial.obs` | +47/−14 | 0 / 0 | Bajo |
| `RegistrationEntry/intro.partial.obs` | +21/−17 | 1 / 1 | Bajo (fix doble tarjeta) |
| `RegistrationEntry/configurePaymentPlanModal.partial.obs` | +19/−17 | 0 / 0 | Bajo |
| `RegistrationEntry/registrantPersonField.partial.obs` | +19/−18 | 0 / 3 | Medio |
| `RegistrationEntry/sessionRenewal.partial.obs` | +10/−9 | 1 / 1 | Bajo |
| `RegistrationEntry/types.partial.ts` | +8/−0 | 1 / 1 | Bajo (campos NIT en el estado) |
| `RegistrationEntry/registrationEnd.partial.obs`, `registrationStart.partial.obs`, `registrants.partial.obs` | +5/−4, +5/−4, +4/−3 | 0 / 0 | Bajo |

**Security (Login, AccountEntry, ConfirmAccount, ForgotUserName, CodeBox)** — traducción completa,
rediseño visual VidaReal (HTML nativo en lugar de `RockButton`/`NotificationBox`, sistema visual
2026-07), flujo passwordless con selector Email/Teléfono y prefijos de Centroamérica, modal de
confirmación, OTP solo numérico. **La lógica de servidor no cambia** salvo lo de A.1/A.2.
Docs: `src/Security/CHANGES.md`, `src/Security/Login/CHANGES.md`, `src/Security/AccountEntry/CHANGES.md`.

| Archivo (bajo `src/Security/`) | Δ | Up 18.7 / 19.7 | Riesgo |
|---|---|---|---|
| `accountEntry.obs` | +778/−173 | 1 / 2 | **Alto** (prácticamente reescrito) |
| `Login/passwordlessLoginVerifyStep.partial.obs` | +588/−41 | 0 / 0 | Alto (reescrito; depende de `Nombre|Edad` de `Login.cs`) |
| `Login/passwordlessLoginStartStep.partial.obs` | +461/−96 | 0 / 0 | Alto (reescrito) |
| `Login/passwordlessLogin.partial.obs` | +82/−4 | 0 / 0 | Medio |
| `login.obs` | +22/−13 | 0 / 0 | Medio |
| `AccountEntry/duplicatePersonSelectionStep.partial.obs` | +69/−39 | 1 / 1 | Medio |
| `AccountEntry/existingAccountStep.partial.obs` | +30/−35 | 1 / 1 | Medio |
| `AccountEntry/registrationStep.partial.obs` | +22/−46 | 1 / 1 | Medio |
| `AccountEntry/phoneNumberDetails.partial.obs` | +18/−28 | 1 / 1 | Medio |
| `AccountEntry/registrationStepAccountInfo.partial.obs` | +13/−19 | 1 / 1 | Medio |
| `AccountEntry/registrationStepPersonInfo.partial.obs`, `AccountEntry/completedStep.partial.obs` | +11/−18, +15/−12 | 0 / 0 | Bajo |
| `ConfirmAccount/accountConfirmation.partial.obs`, `ConfirmAccount/changePassword.partial.obs`, `ConfirmAccount/deleteConfirmation.partial.obs`, `confirmAccount.obs` | ≤5 líneas c/u | 0 / 0 | Bajo (textos) |
| `forgotUserName.obs` | +9/−9 | 1 / 2 | Bajo (textos) |
| `Login/credentialLogin.partial.obs`, `Login/loginMethodPicker.partial.obs` | +6/−6, +2/−2 | 0 / 0 | Bajo (textos) |
| `codeBox.obs`, `codeBoxCharacter.partial.obs` | +1/−1, +2/−0 | 0 / 0 | Bajo — `allowedChars` `/^[0-9]$/` e `inputmode="numeric"`; debe ir junto con `RemoteAuthenticationSessionService.cs` |

**Crm / FamilyPreRegistration** — i18n con diccionario `{en, es}` en `utils.partial.ts`. Doc: `AI_HANDOFF_ROCK18_EVENT_CRM.md`.

| Archivo (bajo `src/Crm/`) | Δ | Up 18.7 / 19.7 | Riesgo |
|---|---|---|---|
| `familyPreRegistration.obs` | +236/−75 | 2 / 3 | Medio-alto |
| `FamilyPreRegistration/utils.partial.ts` | +172/−13 | 0 / 1 | Medio |
| `FamilyPreRegistration/preRegistrationChild.partial.obs` | +38/−29 | 0 / 2 | Medio |
| `FamilyPreRegistration/preRegistrationChildren.partial.obs` | +8/−7 | 0 / 0 | Bajo |

**Otros bloques Obsidian (solo traducción del encabezado de validación según `<html lang>`)**

| Archivo | Δ | Up 18.7 / 19.7 | Riesgo |
|---|---|---|---|
| `src/Communication/CommunicationEntry/communicationMediumEmail.partial.obs` | +4/−2 | 2 / 2 | Bajo |
| `src/Communication/CommunicationEntry/communicationMediumSms.partial.obs` | +4/−2 | 0 / 0 | Bajo |
| `src/Communication/CommunicationEntry/communicationMediumPushNotification.partial.obs` | +4/−2 | 0 / 0 | Bajo |
| `src/Engagement/achievementTypeDetail.obs` | +3/−1 | 1 / 1 | Bajo |
| `src/Finance/financialAccountDetail.obs` | +3/−1 | 0 / 1 | Bajo |

### A.5 Bloques WebForms `RockWeb/Blocks/`

**CheckIn** (42 archivos). Doc: `RockWeb/Blocks/CheckIn/CHANGES.md`. Patrones:
(1) traducción de textos del kiosko; (2) **prevención de check-in duplicado** en `PersonSelect` y
`MultiPersonSelect`; (3) autoselección del próximo horario si empieza en <15 min (`TimeSelect`);
(4) logout limpio del kiosko preservando el tema `vidaventuracheckin` (`Welcome`); (5) `Admin` filtra
tipos de check-in por permiso VIEW; (6) `Manager/PersonLeft` envía el aviso al padre por WhatsApp vía
el pipeline estándar de SMS (`Rock.WhatsApp`). **En Rock 19.x varios de estos bloques fueron
reemplazados por versiones Obsidian** (p. ej. `Manager/Roster.ascx` ya no existe en `19.7.0`).

| Archivo (bajo `RockWeb/Blocks/CheckIn/`) | Δ | Up 18.7 / 19.7 | Qué | Riesgo |
|---|---|---|---|---|
| `TimeSelect.ascx.cs` | +90/−2 | 0 / 0 | `ApplyAutoSelectUpcomingScheduleWindow`, `GetFallbackSchedulesFromSelectedLocations`, orden de `base.OnLoad` | Alto (lógica) |
| `MultiPersonSelect.ascx.cs` | +47/−4 | 0 / 1 | Bloqueo de doble check-in, reset de `PreSelected`, fix de `SelectedForSchedule` | Alto (lógica) |
| `Manager/PersonLeft.ascx.cs` | +43/−29 | 1 / 3 | Aviso al padre por WhatsApp, errores visibles | Medio-alto |
| `Welcome.ascx.cs` / `Welcome.ascx` | +34/−4, +17/−12 | 2 / 2, 0 / 0 | Botón "Iniciar", logout de kiosko, oculta "Schedule Locations" | Medio |
| `PersonSelect.ascx.cs` | +29/−1 | 0 / 0 | Modal de doble check-in | Medio |
| `EditFamily.ascx` | +22/−22 | 0 / 0 | Textos | Bajo |
| `Admin.ascx.cs` / `Admin.ascx` | +18/−14, +16/−3 | 0 / 0 | Filtro por permisos; JS de áreas alternas | Medio |
| `ActionSelect.ascx.cs`, `CheckOutPersonSelect.ascx.cs`, `MobileLauncher.ascx.cs`, `Search.ascx.cs`, `Manager/Person.ascx.cs` | 4–8 líneas c/u | `MobileLauncher.ascx.cs` 4 / 4; resto 0–1 | Textos y ajustes menores | Bajo (MobileLauncher medio) |
| `AbilityLevelSelect.ascx`, `ActionSelect.ascx`, `AttendanceSelfEntry.ascx`, `CheckOutPersonSelect.ascx`, `CheckinScheduledLocations.ascx`, `CheckoutSuccess.ascx`, `Config/CheckinAreas.ascx`, `Config/CheckinTypeDetail.ascx`, `Config/EditLabel.ascx`, `FamilySelect.ascx`, `GroupSelect.ascx`, `GroupTypeSelect.ascx`, `LocationSelect.ascx`, `Manager/AttendanceDetail.ascx`, `Manager/LiveMetrics.ascx`, `Manager/Locations.ascx`, `Manager/Person.ascx`, `Manager/PersonLeft.ascx`, `Manager/RoomSettings.ascx`, `Manager/Roster.ascx`, `MobileLauncher.ascx`, `MultiPersonSelect.ascx`, `PersonSelect.ascx`, `ProcessOnly.ascx`, `RapidAttendanceEntry.ascx`, `Search.ascx`, `Success.ascx`, `TimeSelect.ascx` | 1–6 líneas c/u | 0–2 (`CheckinTypeDetail` 2 / 5) | Textos en español | Bajo; `Roster.ascx` **borrado en 19.x** |

**Crm, Event, Finance**

| Archivo | Δ | Up 18.7 / 19.7 | Qué se cambió y por qué | Riesgo |
|---|---|---|---|---|
| `RockWeb/Blocks/Crm/PersonMerge.ascx.cs` / `.ascx` | +101/−16, +9/−1 | **5 / 8**, 1 / 2 | Agregar persona al merge **por Person ID** (registros `Nameless` del passwordless no aparecen en el buscador), fallecidos, refactor `AddPersonToMerge`. Doc: `RockWeb/Blocks/Crm/CHANGES.md` §1 | **Alto** |
| `RockWeb/Blocks/Crm/PersonDetail/GivingOverview.ascx.cs` / `.ascx` | +97/−27, +1/−5 | 0 / 1 | Totales y KPIs por moneda (no mezcla GTQ con USD). Doc: `RockWeb/Blocks/Crm/CHANGES.md` §2 | Medio |
| `RockWeb/Blocks/Event/RegistrationDetail.ascx.cs` | +54/−10 | 4 / 4 | `GetRegistrationPaymentSummary`: saldo y pagos sin el `FeeCoverageAmount` de cuotas. Doc: `RockWeb/Blocks/Event/CHANGES.md` | Medio-alto |
| `RockWeb/Blocks/Event/RegistrationInstanceRegistrationList.ascx.cs` | +17/−3 | 0 / 1 | Columna "Fee" y pagos sin fee coverage | Medio |
| `RockWeb/Blocks/Finance/TransactionList.ascx.cs` / `.ascx` | +84/−31, +9/−7 | 2 / 2, 1 / 1 | Totales agrupados por cuenta **y moneda**; monto de fila con símbolo de la moneda extranjera. Doc: `RockWeb/Blocks/Finance/CHANGES.md` | Medio-alto |
| `RockWeb/Blocks/Finance/TransactionDetail.ascx.cs` | +13/−6 | 2 / 2 | Siempre carga la moneda de la transacción para formatear montos | Medio |

### A.6 `RockWeb/` — App_Code, scripts, temas, contenido, configuración del repo

| Archivo | Δ | Up 18.7 / 19.7 | Qué se cambió y por qué | Riesgo |
|---|---|---|---|---|
| `RockWeb/App_Code/GetImage.ashx.cs` | +8/−0 | 2 / 6 | No redimensiona `image/webp` (System.Drawing no lo decodifica; stickers de WhatsApp). Recordar: tocar `App_Code` en prod exige reinicio completo | Medio |
| `RockWeb/Scripts/Rock/Controls/datePicker.js` | +25/−0 | 0 / 0 | Locale español para bootstrap-datepicker (WebForms). Doc: `RockWeb/Scripts/CHANGES.md` | Alto (todos los date pickers legacy) |
| `RockWeb/Themes/Rock/Layouts/Blank.aspx`, `RockManager/Layouts/Blank.aspx`, `LandingPage/Layouts/Blank.aspx`, `Stark/Layouts/Blank.aspx` | +17–21 c/u | 0 / 0 | Meta viewport, `overflow-x: hidden`, safe-area de iOS, fuente 16px para evitar zoom en iOS. Doc: `RockWeb/Themes/CHANGES.md` | Bajo |
| `RockWeb/Themes/RockNextGen/Layouts/Blank.aspx` | +50/−6 | 0 / 1 | Igual que arriba + extras | **Alto en 19.x: el archivo fue borrado upstream** |
| `RockWeb/Themes/RockNextGen/Layouts/Site.Master` | +29/−0 | 1 / 2 | CSS de íconos sin bloquear el primer render (PageSpeed móvil) | Alto en 19.x (ruta ya no existe) |
| `RockWeb/Themes/RockNextGen/Styles/theme.css` | +11/−1 | **39 / 120** | `--base-primary: #073642` (color de marca) + ícono VidaReal en `.navbar-brand-corner`. Es un CSS **compilado**; en 19.x los temas se compilan desde el nuevo proyecto `Rock.Frontend.Styles` | **Alto** — re-aplicar como override, no como merge |
| `RockWeb/Content/EmailTemplates/placeholder-logo.png`, `RockWeb/Content/ExternalSite/Icons/*` (5), `RockWeb/Content/ExternalSite/readme.txt`, `RockWeb/Content/InternalSite/readme.txt` | borrados | 0 / 0 | Se sacaron del índice al agregar `RockWeb/Content/` al `.gitignore` (el contenido subido por usuarios no se versiona) | Bajo; un merge los volverá a traer |
| `.gitignore` | +12/−0 | 0 / 1 | Ignora `bin/*/Debug|Release`, **todo `RockWeb/Content/`**, `PrecompiledWeb/` y binarios de `Dev Tools/Deploy` | Bajo; ver advertencia sobre `RockWeb/Content/` |
| `RockWeb/Plugins/.gitignore` | +4/−2 | 0 / 0 | Se quitó la regla `*/*`: el fork **versiona** `RockWeb/Plugins` a propósito (decisión 2026-07-15, incidente de corrupción). No restaurar la regla | Bajo |
| `.githooks/commit-msg` | borrado | 4 / 7 | Hook de upstream que exige formato de mensaje de Spark | Bajo; el merge lo puede re-crear: borrarlo de nuevo |
| `Rock.sln` | +8/−0 | 2 / 6 | Agrega el proyecto `Rock.WhatsApp` (GUID `{B8E5A3C7-2F4D-4E91-A1B6-9C5D8F2E7034}`) | Medio |

---

## B. Código nuevo dentro de proyectos core

Archivos que **no existen upstream** pero viven dentro de proyectos core (se compilan dentro de
`Rock.dll`, `Rock.Blocks.dll`, etc.). No generan conflictos de merge de texto, pero **sí pueden
romperse** si upstream cambia APIs internas. Las entidades nuevas están en el namespace `Rock.Model`
con tablas prefijadas `_com_vidareal_*` y se registran solas en `RockContext`
(`modelBuilder.Configurations.AddFromAssembly(typeof(RockContext).Assembly)`; no se tocó `RockContext.cs`).

| Módulo | Archivos | Qué es | Docs |
|---|---|---|---|
| **Eventos / Boletería** | `Rock/Model/Eventos/` (7 entidades + enums + 19 servicios), `Rock/Jobs/EventsMaintenance.cs`, `Rock.Blocks/Eventos/` (7 bloques + bags), `Rock.ViewModels/Blocks/Eventos/`, `src/Eventos/` (8 `.obs` + 8 partials del checkout) | Boletería propia end-to-end (no usa `Registration*`): checkout con hold, ePay, FEL vía Odoo, PDF/correo, Wallet, scanner, reportería, calendario público | `Rock/Model/Eventos/ARCHITECTURE.md`, `docs/eventos-custom/` |
| **QR Generator** | `Rock/Model/Qr/` (entidades + 3 servicios), `Rock.Blocks/Qr/` (4), `Rock.ViewModels/Blocks/Qr/` (8), `src/Qr/` (4 `.obs` + 5 `types.partial.ts`), `Rock.Tests/Model/Qr/` (2, 116 tests MSTest) | Generador de QR institucionales con short links y métricas. **Sin commitear (working tree):** `Rock.Blocks/Qr/QrMetrics.cs`, `Rock.ViewModels/Blocks/Qr/QrMetrics/QrMetricsBags.cs`, `src/Qr/qrMetrics.obs`, `src/Qr/qrCodeList.obs`, `src/Qr/QrMetrics/types.partial.ts` (+480/−41: tabla de códigos y filtro por QR en «Uso»; en producción, commiteado en `36fa46789a`). **En producción** (confirmado 2026-10-15; `q.vidareal.tv` operativo) | `Rock/Model/Qr/ARCHITECTURE.md`, `docs/qr-custom/` |
| **Wallet (Apple/Google)** | `Rock/Model/Wallet/` (4 + 5 servicios), `Rock/Lava/Filters/LavaFilters.VidaRealWallet.cs` (filtro `WalletPassUrl`), `Rock.Rest/VidaReal/WalletPassKitController.cs`, `Rock.Blocks/Wallet/` (2), `src/Wallet/` (2) | Pases self-hosted, pkpass firmado, APNs, PassKit Web Service | `docs/wallet-module/RESEARCH_Y_PLAN.md` |
| **QREVENT / Servicio dominical** | `Rock.Blocks/QREVENT/` (5 + `RealTime/SundayServiceTopic.cs`), `src/QREVENT/` (5 `.obs` + `vendor/zxing.lib.ts`) | Reservas del servicio dominical, scanners QR, Celebremos, cupos y métricas, «Bienvenido» por RealTime. Depende de SPs/tablas de `Dev Tools/Sql` | `Rock.Blocks/QREVENT/CHANGES.md`, `src/QREVENT/CHANGES.md` |
| **Donaciones (Dar)** | `Rock.Blocks/Dar/` (2 + plantilla de correo), `src/Dar/` (2) | Formulario de donación Cybersource/ePay multi-moneda con reCAPTCHA y anti-fraude; dashboard | `Rock.Blocks/Dar/CHANGES.md`, `src/Dar/CHANGES.md` |
| **FamilyHub** | `Rock.Blocks/FamilyHub/FamilyHub.cs`, `src/FamilyHub/FamilyHub.obs` | Portal "Mi Familia" | `Rock.Blocks/FamilyHub/FamilyHub.md` |
| **Layout propio** | `Rock.Blocks/LayoutCustom/{Header,Footer}.cs`, `src/LayoutCustom/{header,footer}.obs` | Header/footer de vidareal.tv (CSS embebido, ~28 k líneas c/u) | `Rock.Blocks/LayoutCustom/CHANGES.md` |
| **Seguridad** | `Rock.Blocks/Security/VRSimpleRegistration.cs`, `src/Security/vrSimpleRegistration.obs` | Registro simplificado post-passwordless | `Rock.Blocks/Security/CHANGES.md` |
| **DupDetect (UI)** | `Rock.Blocks/Crm/PersonDuplicateReview.cs`, `src/Crm/personDuplicateReview.obs` | Revisión de duplicados (el motor está en `Plugin.VidaRealDupDetect`) | — |
| **Translator (UI)** | `src/Translator/translatorDashboard.obs` | Dashboard del traductor (backend en `Plugin.VidaRealTranslator`) | `Plugin.VidaRealTranslator/CHANGES.md` |
| **Direcciones GT** | `Rock/Model/Core/Location/AddressCascade.cs` | Regla única de la cascada Departamento→Municipio | `CHANGES.md` raíz |
| **WebForms nuevos** | `RockWeb/Blocks/QREVENT/{EventParticipants,QRScanner}.ascx(.cs)`, `RockWeb/Blocks/SundayService/SundayServiceCapacityAdmin.ascx(.cs)`, `RockWeb/Blocks/CheckIn/CheckInOutView.ascx(.cs)`, `RockWeb/Blocks/Asistencia/{CheckIn.ashx,CheckInFromProfile.ascx(.cs)}` | Bloques legacy propios | `RockWeb/Blocks/CheckIn/CHANGES.md` |
| **WhatsApp webhook** | `RockWeb/Webhooks/WhatsAppSms.ashx`, `RockWeb/App_Code/WhatsAppSms.ashx.cs` | Entrada de mensajes de Meta (firma HMAC) | `Rock.WhatsApp/CHANGES.md` |

---

## C. Proyectos y plugins propios

Proyectos fuera de los proyectos core. Los 7 `Plugin.*` **no** están en `Rock.sln`: se compilan
después de la solución porque referencian `Rock.dll` por `HintPath` (ver `CHANGES.md` raíz,
"Cómo construir").

| Proyecto | Assembly | Qué hace | En `Rock.sln` |
|---|---|---|---|
| `Rock.WhatsApp/` | `Rock.WhatsApp.dll` | Transporte de comunicación WhatsApp Business Cloud API (Meta), acción de workflow "WhatsApp Send", OTP por plantilla Authentication | Sí (`CopyToRockWeb=True`) |
| `Plugin.VidaRealEvents/` | `com.vidareal.Events.dll` | **Solo migraciones** del módulo Eventos (el código está en `Rock/Model/Eventos`) | No |
| `Plugin.VidaRealWallet/` | `com.vidareal.Wallet.dll` | **Solo migraciones** del módulo Wallet | No |
| `Plugin.VidaRealQr/` | `com.vidareal.Qr.dll` | **Solo migraciones** del módulo QR | No |
| `Plugin.VidaRealDupDetect/` | — | Motor de detección de duplicados (fonética española, fuzzy, adjudicador Azure OpenAI), jobs `DuplicateScanJob` y `WeeklyDuplicateReportJob`, migraciones | No |
| `Plugin.VidaRealTranslator/` | — | Traductor del sitio con Azure OpenAI: REST, inyección JS, store, migraciones, bloque dashboard | No |
| `Plugin.OdooEventSale/` | — | Workflow action `PostEventSaleToOdoo` (orden + factura FEL + pago en Odoo) | No |
| `Plugin.EpayVisanetGateway/` | — | Gateway ePay Visanet Guatemala (SOAP) + control Obsidian | No |
| `Plugin.CybersourceInlineRestGateway/` | — | Gateway Cybersource REST (Microform v2) + control Obsidian | No |

Las carpetas `Plugin.*/Dependencies/` y `Plugin.*/Deploy/` versionan DLLs de Rock y terceros
(`Rock.dll`, `EntityFramework.dll`, `Newtonsoft.Json.dll`…) para compilar sin la solución. **Tras
actualizar Rock hay que refrescar esos DLLs** o los plugins compilarán contra el Rock viejo.

**`RockWeb/Plugins/` versionado** (62 archivos; resumen):

| Carpeta | Origen | Contenido |
|---|---|---|
| `com_vidareal/Translator/` | Propio | 7 archivos (`.ascx`, `.js`, `.obs.js`). **Única copia de su fuente** |
| `EpayVisanetGateway/`, `CybersourceInlineRestGateway/` | Propio | `.obs` fuente + `.obs.js` compilado del control de captura de tarjeta |
| `Qrgenerador/bin/` | Propio (sin fuente en el repo) | `com.vidareal.WorkflowActions.GenerateQrRegistrant…dll` |
| `TwilioOverrideWhatsApp/bin/` | Propio/terceros (sin fuente en el repo) | `TwilioOverride.dll` |
| `com_bemaservices/MailChimp` (12), `com_blueboxmoon/AcmeCertificate` (8), `com_blueboxmoon/DataToolkit` (4), `com_centralaz/Utility` (2), `com_mineCartStudio/MinePass` (11), `tech_triumph/MinistryPass` (11) | Terceros (Rock Shop) | Archivos instalados por los plugins; no hay fuente |

---

## D. Scripts SQL, temas, App_Code, assets, Dev Tools y documentación

| Ruta | Qué es | Estado según docs |
|---|---|---|
| `Scripts/VidaReal/direcciones-gt.sql` | Seed idempotente: país GT, 22 departamentos, DT Municipio con 340 municipios (correr con `sqlcmd -f 65001`) | En producción (confirmado 2026-10-15); falta revisar la lista contra el INE. Si se restaura la BD hay que volver a correrlo |
| `Dev Tools/Sql/QREVENT_SundayService_Hardening.sql` | Constraints + SPs del servicio dominical (primera instalación del módulo) | Requisito del módulo (en uso en prod) |
| `Dev Tools/Sql/QREVENT_SundayService_StoredProcedures_DB.sql` | SPs + limpieza de holds | Ver `Dev Tools/Sql/CHANGES.md` |
| `Dev Tools/Sql/QREVENT_SundayService_PersonAlias_Step1.sql`, `…_Step2.sql`, `…_Step1_Blocks.patch` | Migración de identidad a `PersonAliasId` (expandir/contraer) | **Aplicados en prod 2026-09-06**. El DLL actual de `Rock.Blocks` falla contra SPs anteriores a Step1 |
| `Dev Tools/Sql/QREVENT_SundayService_PersonAliasFix.sql` | Diagnóstico/reparación de reservas huérfanas | Prod: 0 huérfanas (2026-09-04) |
| `Dev Tools/Deploy/SundayService_PersonAlias/README.md` | Bitácora del despliegue anterior | — |
| `Dev Tools/EventsLoadTest/` | Prueba de carga del checkout de eventos (lee `web.ConnectionStrings.config` local; no trae credenciales) | Herramienta |
| `RockWeb/Themes/VidAventuracheckin/` | Tema completo de check-in infantil (LESS/CSS, sonidos, globos) | En uso |
| `RockWeb/Assets/Fonts/BrujulaVR/`, `RockWeb/Assets/Fonts/Montserrat/` | Fuentes self-hosted con licencias | — |
| `Asistencia/` (raíz del repo) | **Copia idéntica** de `RockWeb/Blocks/Asistencia/` | Duplicado; candidato a borrar |
| `.claude/`, `Rock.Blocks/.claude/` | Contexto e índice para sesiones de Claude Code, skill `design-to-obs`, permisos locales | Sin secretos (revisado) |
| `*.md` de la raíz, `docs/eventos-custom/`, `docs/gps-custom/`, `docs/qr-custom/`, `docs/wallet-module/`, `CHANGES.md` por carpeta | Documentación | `docs/gps-custom/` es solo diseño, no hay código GPS |

---

## E. Migraciones de base de datos propias

**No hay ninguna migración en `Rock.Migrations`** (el proyecto de migraciones del core no se tocó).
Todas son *Plugin Migrations* de Rock (`Rock.Plugin.Migration`, atributo `[MigrationNumber(n, "18.1")]`),
registradas por assembly en la tabla `[PluginMigration]` y ejecutadas al arrancar Rock cuando el DLL
está en `RockWeb/Bin`. Además existen los scripts SQL manuales de la sección D.

Consulta para saber qué corrió en un ambiente:

```sql
SELECT PluginAssemblyName, MigrationNumber, MigrationName, CreatedDateTime
FROM [PluginMigration]
WHERE PluginAssemblyName LIKE '%vidareal%' OR PluginAssemblyName LIKE '%DupDetect%' OR PluginAssemblyName LIKE '%Translator%'
ORDER BY PluginAssemblyName, MigrationNumber;
```

| Proyecto (assembly) | Migraciones | Próximo número | Estado en prod (confirmado por Rodolfo, 2026-10-15) |
|---|---|---|---|
| `Plugin.VidaRealEvents` (`com.vidareal.Events`) | `001`–`016` = pasos históricos **sin** `[MigrationNumber]`, ejecutados dentro de la consolidada **`017_ProductionSetup`**; `017_PromoCodeUniqueAndMaintenanceJob` (paso 17); luego `018_EventSessions`, `019_OrderDeliveryEmail`, `020_EventVisibilityAndCalendar`, `021_EventWorkflows`, `022_EventSpeakersBannerMinistry`, `023_EventLogo`, `024_EventTypeCatalog`, `025_MyTicketsBlankLayout` | 26 | En producción hasta la **025** (confirmado 2026-10-15) |
| `Plugin.VidaRealWallet` (`com.vidareal.Wallet`) | `001_WalletSetup` … `016_PaseDigitalCampus` (16) | 17 | En producción (confirmado 2026-10-15; tráfico real desde 2026-08-28) |
| `Plugin.VidaRealQr` (`com.vidareal.Qr`) | `001_QrSetup`, `002_QrMetricsIndex` (neutralizada), `003_QrPages`, `004_QrMetricsPage`, `005_QrDashboardPage`, `006_QrCrossLinks`, `007_QrDropRedundantIndex` | 8 | En producción, 001–007 aplicadas (confirmado 2026-10-15) |
| `Plugin.VidaRealDupDetect` | `001_DupDetectSchema`, `002_DupDetectJobs`, `003_DupDetectReviewPage`, `004_DupDetectPageToSubmenu`, `005_DupDetectImportLocalAppIgnores` | 6 | Sin registro en el repo: verificar |
| `Plugin.VidaRealTranslator` | `001_TranslatorSetup`, `002_TranslatorSettingsPage`, `003_TranslationListBlock`, `004_TranslatorDashboard` | 5 | Módulo en producción (confirmado 2026-10-15) |

Reglas que no hay que romper (de los README de cada plugin): nunca editar una migración que ya corrió
en algún ambiente; nunca reutilizar números (en Eventos, prod solo registró el 17 consolidado); los
cambios de seed/plantilla siempre van en migración nueva; desde la 022 de Eventos, `Rock.dll` espera
columnas que crean las migraciones, así que **`Rock.dll`, `Rock.ViewModels.dll`, `Rock.Blocks.dll` y
`com.vidareal.Events.dll` se suben juntos y del mismo build**.

Impacto en upgrades de Rock: el segundo argumento de `[MigrationNumber(n, "18.1")]` es la versión
mínima de Rock; en una versión mayor siguen corriendo. Las tablas `_com_vidareal_*` no las toca
ninguna migración de Rock.

---

## Ruido excluido del análisis

| Excluido | Motivo |
|---|---|
| `RockWeb/Bin/`, `RockWeb/Obsidian/` (bundles compilados de Obsidian), `PrecompiledWeb/`, `node_modules/`, `packages/` | Están en `.gitignore`; se generan compilando. **No aparecen en el diff**: el fork no versiona bundles compilados de bloques propios (excepto los `.obs.js` de plugins dentro de `RockWeb/Plugins` y `Plugin.*/Deploy/`) |
| DLL/PDB en `Plugin.*/Dependencies/` y `Plugin.*/Deploy/` | Binarios para compilar/desplegar los plugins sin la solución (≈35 archivos) |
| Archivos de terceros en `RockWeb/Plugins/` | Resumidos en la sección C |
| Imágenes, fuentes, sonidos, PDFs | Assets |

---

## Cómo actualizar a una nueva versión de Rock

> **Procedimiento recomendado por Rodolfo (dueño saliente, 2026-10-15): NO actualizar este repo.**
> Se baja una copia de la BD de prod, se clona Rock limpio en otra carpeta, se sube la BD **de
> versión mayor en versión mayor** con Rock sin modificar (aplicando en cada salto las migraciones y
> actualizaciones de Rock) y **solo al final** se mete el desarrollo propio. Este repo queda como
> referencia de solo lectura.

**Por qué no un merge sobre este repo:** hay 148 archivos core modificados, varios con decenas de
commits upstream encima (ver [alto riesgo](#archivos-core-de-alto-riesgo)). De `18.1.0` a `19.7.0`
cambian 5 417 archivos, desaparece `RockNextGen/Layouts/Blank.aspx`, la compilación de temas se
mueve y los bloques de check-in WebForms pasan a Obsidian. Un merge obliga a resolver conflictos
sobre código que en la versión nueva ya no existe o ya no hace falta; portar desde cero obliga a
decidir, cambio por cambio, si se rehace, si la versión nueva ya lo resuelve o si se descarta.

Últimas versiones al 2026-10-15: **`18.7.0`** y **`19.7.0`** (13-oct-2026). Ruta desde prod (18.1):
`18.1 → 18.7.0 → 19.7.0` (y así con cada versión mayor que salga después).

### 0. Antes de empezar

1. Leer las notas de versión de Rock de **cada** versión mayor del camino: requisitos de .NET
   Framework, SQL Server e IIS, bloques WebForms reemplazados por Obsidian y bloques retirados.
2. Servidor de staging separado de prod (nunca el de prod). Las migraciones de Rock **no tienen
   vuelta atrás**: cada salto se hace sobre copia y se guarda un respaldo antes del siguiente.
3. Aislar staging para que no envíe nada real: deshabilitar transportes de comunicación (SendGrid,
   WhatsApp), jobs que envían correo/SMS, gateways de pago en modo real y la integración con
   Odoo/FEL. Ver `docs/HANDOFF/SETUP_DESARROLLO.md` (cómo aislar la BD de dev).
4. Etiquetar este repo en el estado que corre en prod: `git tag vidareal-prod-<AAAAMMDD>` y pushear el
   tag. Desde ahí se porta todo. **Ya existe `vidareal-prod-20261015`** (commit `36fa46789a`, estado
   de prod al traspaso); si prod cambia después, crear una etiqueta nueva.

### 1. Bajar la BD de prod

1. Respaldo `COPY_ONLY` de `Rock18` en el servidor SQL de prod (no rompe la cadena de respaldos):
   ```sql
   BACKUP DATABASE [Rock18] TO DISK = N'<ruta>\Rock18_upgrade.bak' WITH COPY_ONLY, COMPRESSION, CHECKSUM;
   ```
2. Restaurarla en staging con otro nombre (p. ej. `RockUpgrade`).
3. Copiar también `RockWeb\Content` de prod (archivos subidos; no está en git).
4. Antes de arrancar Rock, correr la consulta de `[PluginMigration]` de la sección E y guardar el
   resultado: sirve para comprobar al final que las migraciones propias quedaron al día.

### 2. Clonar Rock limpio en otra carpeta

```bash
git clone https://github.com/SparkDevNetwork/Rock.git C:/repos/Rock-upgrade
cd C:/repos/Rock-upgrade
git checkout 18.7.0          # primer salto
```

Este clon es **Rock sin ningún cambio**. Compilar `Rock.sln` en Release con MSBuild y el framework
Obsidian (`npm ci && npm run build` en `Rock.JavaScript.Obsidian` y `Rock.JavaScript.Obsidian.Blocks`).
Apuntar `RockWeb/web.ConnectionStrings.config` a `RockUpgrade`.

### 3. Saltar de versión mayor en versión mayor (solo Rock)

Para cada versión del camino (`18.7.0`, luego `19.7.0`, …):

1. `git checkout <versión>` y compilar.
2. Arrancar RockWeb contra `RockUpgrade`. Rock corre sus migraciones al iniciar; esperar a que
   termine y revisar el log de excepciones.
3. **Esperar a que terminen los jobs post-actualización** que crea cada versión (*Admin → System
   Settings → Jobs*: los jobs de migración de datos / de arranque de esa versión). No saltar a la
   siguiente versión mayor con jobs de migración pendientes.
4. Revisar que el sitio interno arranca y que el login funciona.
5. Respaldar `RockUpgrade` (`RockUpgrade_<versión>.bak`) antes del siguiente salto. Si un salto
   falla, se vuelve a este respaldo y no a prod.

Qué esperar en esta etapa, porque **el código propio todavía no está**:

- Páginas con bloques propios (Eventos, QR, QREVENT, Dar, FamilyHub, LayoutCustom…) muestran error
  de bloque o de tipo no encontrado. Es normal; esa lista es el checklist de lo que falta portar.
- `EntityType`/`BlockType`/`FieldType` cuyas clases no existen quedan huérfanos en la BD. **No
  borrarlos**: al volver el código propio con el mismo nombre de clase, Rock los vuelve a enlazar y se
  conservan atributos y configuración.
- Las tablas `_com_vidareal_*` y sus datos no las toca ninguna migración de Rock. Si una migración
  core falla por una llave foránea de una tabla propia hacia una tabla core (p. ej. `PersonAlias` o
  `Group`), quitar temporalmente esa FK en staging, terminar el salto y anotarla para recrearla en el
  paso 4.

### 4. Meter el desarrollo propio

Con la BD ya en la versión final y Rock limpio funcionando, portar lo propio en este orden:

| Orden | Qué | De dónde sale | Cómo |
|---|---|---|---|
| 1 | Plugins (`Plugin.*`, `Rock.WhatsApp`) | Sección C | Copiar el proyecto, refrescar `Dependencies/` con los DLL de la versión nueva, compilar y corregir lo que cambió de API. Sus migraciones ya corrieron en prod: Rock no las repite (están registradas en `[PluginMigration]`) |
| 2 | Código nuevo dentro de proyectos core | Sección B | **Recomendado: sacarlo a proyectos `Plugin.*`** (entidades, servicios, bloques, bags y `.obs`) en lugar de volver a meterlo en `Rock.dll`/`Rock.Blocks.dll`. Mantener el mismo nombre de clase y namespace, o actualizar `EntityType`/`BlockType` en la BD con una migración. Así el siguiente upgrade casi no toca el core |
| 3 | Parches al core | Sección A + [`core-files-modified.txt`](core-files-modified.txt) | Uno por uno: ver el cambio propio con `git diff 18.1.0 vidareal-prod-<fecha> -- <archivo>`, confirmar si la versión nueva ya lo resuelve y solo si hace falta re-aplicarlo sobre el archivo nuevo. Si upstream borró o migró el bloque a Obsidian, rehacer el cambio en el bloque nuevo o descartarlo |
| 4 | Scripts, temas, App_Code, fuentes | Sección D | Copiar y probar. El tema `VidAventuracheckin` y los overrides de `RockNextGen` se revisan contra el nuevo sistema de temas |
| 5 | Plugins de terceros del Rock Shop | Sección C (`RockWeb/Plugins`) | Instalar desde el Rock Shop las versiones compatibles con la versión nueva; no copiar las viejas |

Para consultar el código viejo desde el repo nuevo:

```bash
git remote add legacy https://github.com/<org>/Rock15.5.git
git fetch legacy --tags
git show vidareal-prod-<fecha>:Rock.Blocks/Event/RegistrationEntry.cs
git diff 18.1.0 vidareal-prod-<fecha> -- <archivo>   # el cambio propio, aislado
```

Verificaciones del código propio en la versión nueva:

1. **Colisión de nombres en `Rock.Model`.** Las entidades propias usan nombres genéricos (`Event`,
   `Order`, `Ticket`, `TicketType`, `PromoCode`, `CheckinLog`, `EventStaff`, `QrCode`, `QrDesign`,
   `WalletPass`, `WalletTemplate`, `WalletDeviceRegistration`). Al 2026-10-15 ninguno existe upstream,
   pero hay que repetir el chequeo en cada versión (otra razón para moverlas a un namespace propio):
   ```bash
   for n in Event Order Ticket TicketType PromoCode CheckinLog EventStaff QrCode QrDesign WalletPass WalletTemplate WalletDeviceRegistration; do
     git grep -l -E "public (partial )?class $n\b" <tag> -- Rock/Model; done
   ```
2. Volver a correr la consulta de `[PluginMigration]` y compararla con la del paso 1.4.
3. Que no queden bloques con error en las páginas de los módulos propios.

### 5. Probar y pasar a prod

1. Smoke tests: `docs/eventos-custom/SMOKE_TESTS.md`, `docs/qr-custom/SMOKE_TESTS.md`,
   `docs/gps-custom/SMOKE_TESTS.md` (cuando exista código), más estos flujos que dependen de parches
   al core:
   - Login passwordless por teléfono con y sin código de país; selección entre varias personas
     (foto y edad); OTP numérico.
   - Inscripción a evento de Rock con NIT/factura y pago en cuotas (saldo sin fee coverage).
   - Editar dirección de una familia en GT (cascada Departamento→Municipio) en WebForms y Obsidian.
   - Date pickers en español (Obsidian y WebForms).
   - Check-in de kiosko: doble check-in bloqueado, autoselección de horario, logout del kiosko.
   - Lista de transacciones y perfil de donaciones con GTQ y USD.
   - Merge de personas por ID.
   - Respuesta de WhatsApp atribuida a la persona correcta; sticker WebP visible.
   - Boletería completa con pago de prueba, FEL en Odoo y pase de Wallet.
2. **Corte a prod:** ensayar el proceso completo al menos una vez. El día del corte, repetir los
   pasos 1 y 3 con un respaldo fresco de prod (los datos cambiaron desde el ensayo), desplegar el
   código propio ya portado y validado, y correr los smoke tests en prod. Ventana de mantenimiento
   anunciada y respaldo de prod justo antes.
3. El repo nuevo pasa a ser el oficial; este queda archivado (solo lectura) como referencia.

### Alternativa: merge sobre este repo (solo versiones menores)

Para una actualización **menor dentro de la misma versión mayor** (p. ej. 18.1 → 18.7: 1 251
archivos cambiados, mismo modelo de temas y check-in) un merge de 3 vías también es viable, porque
`18.1.0` es ancestro común:

```bash
git fetch upstream --tags
git checkout -b upgrade/18.7.0 hotfix-18.1
git merge --no-ff 18.7.0
```

Revisar **todo** archivo de `core-files-modified.txt` aunque git no marque conflicto. Técnica por
archivo: `git diff 18.1.0 hotfix-18.1 -- "$f" > vr.patch; git checkout 18.7.0 -- "$f"; git apply -3 vr.patch`.
En `package-lock.json`, `*.d.ts`, `Rock.sln`/`*.csproj` y `theme.css` tomar upstream y re-agregar lo
propio; no resucitar archivos que upstream borró; conservar `RockWeb/Plugins/.gitignore` del fork.
Luego compilar (`Rock.sln` → refrescar `Plugin.*/Dependencies/` → plugins → Obsidian) y probar en
staging como en el paso 5. **Para saltos de versión mayor usar el procedimiento principal.**

---

## Archivos core de alto riesgo

Ordenados por riesgo de conflicto o de regresión al actualizar (churn upstream × tamaño del cambio
propio × criticidad):

| # | Archivo | Por qué |
|---|---|---|
| 1 | `Rock.Blocks/Event/RegistrationEntry.cs` | +202 líneas propias (NIT/FEL + passthrough al workflow); 32 commits upstream hasta 18.7 y 59 hasta 19.7 |
| 2 | `Rock.Rest/v2/ControlsController.cs` | Cambio chico, pero el archivo es de los más activos de Rock (35 / 82 commits) |
| 3 | `Rock.JavaScript.Obsidian.Blocks/src/Event/registrationEntry.obs` + `RegistrationEntry/payment.partial.obs` (y demás partials) | Rediseño + i18n + NIT en ~17 archivos acoplados al backend #1 |
| 4 | `Rock.JavaScript.Obsidian/Framework/Controls/datePartsPicker.obs`, `datePickerBase.obs`, `datePicker.obs`, `rockValidation.obs` | Controles del framework usados por casi todos los bloques; error aquí rompe fechas en todo el sitio |
| 5 | `Rock/Web/UI/Controls/AddressControl.cs` + `Framework/Controls/addressControl.obs` | +238 / +131 líneas en el control de dirección (WebForms y Obsidian) |
| 6 | `Rock/Security/Authentication/PasswordlessAuthentication.cs` + `Rock/Model/Security/RemoteAuthenticationSessionService.cs` | Autenticación de todos los usuarios; formato del OTP |
| 7 | `Rock.JavaScript.Obsidian.Blocks/src/Security/accountEntry.obs` + `Login/passwordlessLoginStartStep.partial.obs` + `Login/passwordlessLoginVerifyStep.partial.obs` | Prácticamente reescritos (+778/+461/+588); cualquier cambio upstream obliga a re-portar a mano |
| 8 | `RockWeb/Themes/RockNextGen/Styles/theme.css` (+ `Layouts/Site.Master`, `Layouts/Blank.aspx`) | 39 / 120 commits upstream; en 19.x se movió la compilación de temas y `Blank.aspx` desapareció |
| 9 | `RockWeb/Blocks/Crm/PersonMerge.ascx.cs` | +101 líneas; 5 / 8 commits upstream; operación destructiva sobre personas |
| 10 | `RockWeb/Blocks/CheckIn/TimeSelect.ascx.cs`, `MultiPersonSelect.ascx.cs`, `PersonSelect.ascx.cs`, `Welcome.ascx.cs`, `Manager/PersonLeft.ascx.cs` | Lógica de negocio del check-in infantil en bloques que upstream está migrando a Obsidian |
| — | También vigilar: `Rock/Rock.csproj` (12 commits hasta 19.7), `Rock.sln`, `RockWeb/Blocks/Event/RegistrationDetail.ascx.cs` (4 / 4), `RockWeb/Blocks/Finance/TransactionList.ascx.cs`, `RockWeb/App_Code/GetImage.ashx.cs` (2 / 6), `Rock.Blocks/Security/Login.cs` (contrato `Nombre|Edad` con el front) |

---

## Hallazgos y advertencias

1. **Sin secretos en el código versionado del fork.** Se revisó el diff completo contra `18.1.0`
   buscando connection strings, contraseñas, API keys, tokens (Meta, Azure, Google, SendGrid, AWS),
   claves privadas y JWT. Las credenciales se leen de Global Attributes o de atributos cifrados
   (`EncryptedTextField`, `Encryption.DecryptString`), y `web.ConnectionStrings.config` no está
   versionado (solo el `.example` de upstream). Datos de infraestructura (no secretos) que sí están
   en el repo: IPs públicas por defecto de los servidores de ePay en
   `Plugin.EpayVisanetGateway/EpayVisanetGateway/EpayVisanetGateway.cs` y la IP pública del web
   server de prod en `docs/qr-custom/DEPLOY.md`.
2. **OTP solo numérico.** `RemoteAuthenticationSessionService.cs` bajó el alfabeto del código de 23
   símbolos a 10 (de ~1.5·10⁸ a 10⁶ combinaciones con 6 caracteres). Es aceptable solo si Rock limita
   los intentos de verificación; conviene confirmarlo antes de la próxima actualización.
3. **`.gitignore` ignora todo `RockWeb/Content/`.** Si una versión futura de Rock agrega archivos
   bajo `Content/`, git no los mostrará como nuevos. Revisar esa carpeta a mano tras el merge.
4. **Entidades propias dentro de `Rock.dll`.** Eventos, QR y Wallet viven en el core y en el
   namespace `Rock.Model`: no hay conflicto de texto, pero sí riesgo de colisión de nombres o de
   cambios de API interna (`Model<T>`, `Service<T>`, `RockBlockType`). Ver la verificación del paso 3.
5. **Documentación con base incorrecta.** Varios `CHANGES.md` usan `ca2ca0ec94` como base; la base
   real es `18.1.0`.
6. **Duplicado** `Asistencia/` en la raíz = copia exacta de `RockWeb/Blocks/Asistencia/`.
7. **Binarios sin fuente** en `RockWeb/Plugins/Qrgenerador/bin/` y
   `RockWeb/Plugins/TwilioOverrideWhatsApp/bin/`: si hay que modificarlos, no hay código en el repo.
8. **Global Attributes huérfanos** documentados en `RockWeb/Blocks/CheckIn/CHANGES.md`
   (`TwilioAccountSid`, `TwilioAuthToken`, `TwilioWhatsAppFrom`, `TwilioWhatsAppTemplateSid`): el código
   que los usaba se eliminó en agosto 2026; las credenciales siguen guardadas en la BD. Conviene
   borrarlos o rotarlos.
