# Upgrade de Rock 18.1 → 19.8.1 (prueba local y runbook del cambio real)

> **Responsable y aprobador del upgrade:** Fredy Ramirez (desde el 2026-11-23; antes, TI/Rodolfo).
>
> **Para el próximo upgrade:** lo aprendido en este está resumido en [`GUIA_PROXIMO_UPGRADE.md`](GUIA_PROXIMO_UPGRADE.md).
>
> **✅ EN PRODUCCIÓN DESDE EL 2026-11-27** (ventana 21:52–23:38, ejecutada por Fredy Ramirez): prod corre Rock
> 19.8.1 con el kit `c190618011` de la rama `Test_Update_18.1_a_19.8.1`. **`hotfix-18.1` ya NO es lo que corre en
> prod** hasta que se una la rama del upgrade. Resultado completo en la CHECKLIST, § «Resultado de la ventana».
>
> **Estado (2026-11-24):** pruebas **locales completas** (PC de desarrollo, BD `Rock19Test`). **El orden de trabajo del día en prod está en
> [`upgrade-19.8.1/CHECKLIST_PRODUCCION_19.8.1.md`](upgrade-19.8.1/CHECKLIST_PRODUCCION_19.8.1.md)** (análisis previo
> con el sitio arriba, ir/no ir, ventana con comandos, verificación, reversa); este documento queda como referencia.
>
> | Fase | Estado |
> |---|---|
> | 1. BD nueva aislada | ✅ 2026-11-19 |
> | 2. Merge de código + build | ✅ commiteado; rama `Test_Update_18.1_a_19.8.1` en GitHub desde el 2026-11-23; core + 8 plugins compilan; precompilación completa de `RockWeb` sin errores (§14.2) |
> | 3. Arranque y migraciones | ✅ migraciones aplicadas y sitio arriba (§5b); jobs post-actualización ensayados el 2026-11-23 (§11.3) |
> | 3b. Análisis previo a las pruebas | ✅ 2026-11-19: diagnósticos locales (§5c), inventario (`INVENTARIO_DESARROLLOS_VR.md`), jobs (§11), check-in (§12), comparación servidor vs repo preparada (§13) |
> | 3c. Prueba comparativa de check-in 18.1 vs 19 | ✅ C1–C20 iguales (PLAN_PRUEBAS §15) |
> | 4. Pruebas de humo | ✅ local (PLAN_PRUEBAS §16); en prod: CHECKLIST fase D |
> | 5. Kit | ✅ `kit_19.8.1_2026-11-23\` + `herramientas\` (CHECKLIST, «Qué hay en herramientas») |
> | 6. Producción | ✅ **Upgrade hecho el 2026-11-27** (fase A 24–25 nov, ensayo de respaldo, ventana 21:52–23:38). Pendiente: prueba de impresión en el iPad del Mostrador, recargar kioscos, monitoreo de la primera semana, unir la rama a la de producción (CHECKLIST § «Resultado de la ventana») |

---

## 0. Cómo retomar (cierre del 2026-11-19)

**Estado actual**
- Todo es **local** (PC de desarrollo). Nada en producción.
- Rama `Test_Update_18.1_a_19.8.1` (antes `Test_Update_18.1_a_18.8`; renombrada el 2026-11-23). Desde ese día está
  en GitHub con upstream configurado; la rama vieja se borró del remoto.
- **2026-11-23:** el trabajo de reservas dominicales (QREVENT: servicios especiales, puerta por servicio, «visible en
  la app») se pasó a esta rama (cherry-pick), se publicó en 6229 (`Rock.Blocks.dll` y bundles) y se corrió
  `Dev Tools/Sql/QREVENT_SundayService_SlotSettings.sql` en `Rock19Test`. Respaldo previo en
  `dev-isolation\respaldo_19_antes_reservas_2026-11-23`. Estado: `docs/qrevent/ESTADO_TRABAJO_RESERVAS.md`.
- 6229 está abierto a la red local (§15).
- BDs locales (se dejaron como están):
  - `Rock19Test`: bacpac de prod del 18-nov, aislada, **migrada a 19.8.1**; job 234 ya corrido (páginas 327 y 740
    con bloques Obsidian); preparación de la prueba de check-in aplicada (§14.4).
  - `Rock18Base`: mismo bacpac, aislada, **sin migrar** (18.1); misma preparación de check-in.
  - Respaldo: `Rock19Test_migrada_sin_jobs_2026-11-19.bak` (carpeta Backup de SQL Server; antes del job 234).
- Worktree 18.1 compilado: `Documents\GitHub\Rock18Base-wt` (desacoplado en `hotfix-18.1`; sus `package-lock.json`
  cambiados por npm no se commitean; se descarta con `git worktree remove`).
- Fuera del repo (no es repo git): `Documents\GitHub\dev-isolation\` con `aislar_dev_Rock19Test.sql`,
  `aislar_dev_Rock18Base.sql`, `preparar_prueba_checkin_vidaventura.sql`, `impresora_falsa_zpl.ps1` y
  `etiquetas_capturadas\` (vacía).
- Sin versionar a propósito: `RockWeb/Themes/VidAventuracheckin/Styles/_css-overrides.less` (vacío, excluido con
  `.git/info/exclude`, solo para la prueba; §12).
- Servidores **detenidos** (6229, 6230 e impresora falsa).

**Commits del 2026-11-19** (hechos en la rama cuando se llamaba `Test_Update_18.1_a_18.8`; hoy en
`Test_Update_18.1_a_19.8.1`):

| Commit | Qué |
|---|---|
| `b61a80a019` | Merge `origin/Rock_RMS_Rama_Fredy` (guía de colaboradores, aislamiento de BD dev) |
| `43177d0e3e` | Merge del tag 19.8.1 de upstream |
| `f2c736e48d` | Docs: Fase 3 (migraciones medidas, SignNow, jobs) |
| `9ea5e52f2b` | Docs: inventario, jobs, check-in, runbook; scripts de `Dev Tools/Upgrade` |
| `079976f92b` | Docs: prueba comparativa de check-in 18.1 vs 19 |
| `4b42dd6521` | Código: modales del Roster Obsidian en español (+ docs de PIN, CSS, checklist con tildes) |
| `51f2581c6f` | Docs: job 234 corrido; los jobs de reemplazo se autoeliminan |

**2026-11-23 (Claude, `PLAN_PRUEBAS_19.8.1.md` §16):** C1–C15 hechos (sin diferencias de comportamiento; etiquetas
idénticas); los 12 jobs de actualización ensayados en Rock19Test sin errores (respaldo previo
`Rock19Test_antes_jobs_2026-11-23.bak`); barrido de ~70 páginas sin excepciones nuevas; 327, 740, 433 y 451 cargan.
Desde ese día el responsable es el único aprobador y fijó el upgrade de prod para el 2026-11-24.

**Qué falta**
1. ~~C16–C20 de §15~~ — hechos en 18.1 y 19, iguales (PLAN_PRUEBAS §15 y §16); C20 en la 19 el 2026-11-24 07:50.
   **Pruebas locales completas.** El horario de prueba (Schedule 35) abre check-in **lunes a viernes de 09:00 a 15:00** (cierra al
   terminar el evento, no a las 21:00 como se anotó antes). Para C16–C19 hace falta «Registration Mode» en el
   dispositivo 26 (se activó y se quitó al terminar; el kiosco real «Kiosko Mostrador» lo tiene activado).
2. ~~Comparar etiquetas y `ExceptionLog`~~ — hecho el 2026-11-23 para C1–C15.
3. ~~Abrir 327 y 740 con sesión~~ — hecho el 2026-11-23: cargan sin error.
4. Según la comparación visual: aplicar la propuesta B de CSS del kiosco (§14.9a, probar con dotless) y decidir el
   tema del Check-in Manager (§14.9b).
5. Script del servidor (§13): lo corre el responsable en prod y trae los 3 archivos + `_css-overrides.less` y
   `checkin-theme.css` del tema del kiosco.
6. `RunJobsInIISContext` de prod: lo revisa el responsable (§11.5).
7. ~~Jobs post-actualización de upstream (§11.3)~~ — ensayados en Rock19Test el 2026-11-23 (ver §11.3).
8. ~~Kit del día~~ — armado y probado el 2026-11-23 (PLAN_PRUEBAS §16, «Kit»): build completo en 6229, prueba rápida
   sin errores nuevos, kit fuera del repo en `kit_19.8.1_2026-11-23\` (3556 archivos, commit `c190618011`, hash del
   manifiesto `CD7C955F…37FA`). Si se cambia código antes de la ventana, **rehacer** build + prueba + kit
   (`Dev Tools/Upgrade/New-KitUpgrade.ps1`).
9. En prod, antes de la ventana: correr `Dev Tools/Upgrade/19.8.1_preflight_bd_prod.sql` (solo lectura) y que
   todo salga «OK».

**Comandos para volver a levantar** (cada uno en su propia consola de PowerShell; SQL Server local debe estar arriba):

```powershell
# 19.8.1 en http://localhost:6229 (BD Rock19Test; ver Initial Catalog en RockWeb\web.ConnectionStrings.config)
# Desde el 2026-11-20 está abierto a la red local (§15): mientras exista la reserva http://*:6229/, arrancarlo así:
& "C:\Program Files\IIS Express\iisexpress.exe" /site:Rock19-6229
# Cerrado el acceso (§15.2), vuelve a ser:
# & "C:\Program Files\IIS Express\iisexpress.exe" /path:"C:\Users\Servr local Rock RMS\Documents\GitHub\Rock18.1\RockWeb" /port:6229 /clr:v4.0

# 18.1 en http://localhost:6230 (BD Rock18Base; connection string en el worktree)
& "C:\Program Files\IIS Express\iisexpress.exe" /path:"C:\Users\Servr local Rock RMS\Documents\GitHub\Rock18Base-wt\RockWeb" /port:6230 /clr:v4.0

# Impresora falsa (escucha solo en 127.0.0.1:9100 y :9101; guarda el ZPL en dev-isolation\etiquetas_capturadas)
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Users\Servr local Rock RMS\Documents\GitHub\dev-isolation\impresora_falsa_zpl.ps1"
```

- Primera carga: ~70 s (6229) y ~100 s (6230). Entrar por `/checkin` y `/checkinmanager`.
- Al arrancar 6229, Rock **vuelve a recompilar** `VidAventuracheckin/Styles/checkin-theme.css` (porque existe el
  `_css-overrides.less` local): git lo mostrará modificado. **No commitearlo**; al terminar:
  `git checkout -- RockWeb/Themes/VidAventuracheckin/Styles/checkin-theme.css`.
- Verificación rápida antes de probar: `sqlcmd -S localhost -E -C -Q "SELECT name FROM sys.databases WHERE name IN ('Rock19Test','Rock18Base')"`.

---

## 1. Versiones y refs

| | Valor |
|---|---|
| Origen | Rock **18.1** con el fork de Vida Real (rama `hotfix-18.1`) |
| Base común del merge | tag `18.1.0` = `f8e5bcf161` |
| Destino | tag upstream **`19.8.1`** = `85705ceb0b` (SparkDevNetwork/Rock; mismo commit que `19.8.1-alpha`) |
| Rama de prueba | `Test_Update_18.1_a_19.8.1` (antes `Test_Update_18.1_a_18.8`) |
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
| Roster del Check-in Manager en español: títulos `Confirmar`, botones `Registrar Entrada` / `Registrar Salida` (3 modales) | `RockWeb/Blocks/CheckIn/Manager/Roster.ascx` (borrado en la 19) | **Reaplicado** el 2026-11-19 en los 3 modales del Roster Obsidian (mismos 6 textos), §14.6 |
| Página «Room Settings» del Check-in Manager | La migración `UpdateCheckinManagerToNextGen` la borra (y «Room Manager» pasa a ser el Roster) | La traducción de `RoomSettings.ascx` queda sin uso; nada que reaplicar |

El diff completo de lo perdido quedó en la carpeta temporal de la sesión; se puede regenerar con
`git diff 18.1.0 b61a80a019 -- RockWeb/Themes/RockNextGen RockWeb/Blocks/CheckIn/Manager/Roster.ascx`.

---

## 7. Runbook para producción (borrador; leer junto con `DEPLOY_PRODUCCION.md`)

**Principio:** en prod el sitio es la carpeta `RockWeb` del servidor. El upgrade se aplica como **kit copiado
encima** de esa carpeta (igual que cualquier deploy, `DEPLOY_PRODUCCION.md` §3). **Nunca** se reemplaza ni se
vacía `RockWeb`: tiene carpetas y archivos que solo existen en el servidor (§5c).

### 7.1 Días antes

> Desde el 2026-11-24 los pasos 2, 4, 5, 6, 6b y 6c tienen herramienta y orden en
> `upgrade-19.8.1/CHECKLIST_PRODUCCION_19.8.1.md` fase A: `Get-DiagnosticoServidor.ps1` (diagnóstico de solo lectura +
> inventario + hash de llaves) y `New-WebConfigFusionado.ps1` (web.config de la 19 con los valores de prod; falla si
> las llaves no quedan idénticas). **Hallazgo:** el `RockWeb/web.config` versionado (repo público) trae llaves de
> **dev** con valor; la checklist exige comprobar que las de prod son otras (criterio 3).

1. Confirmar que la 19.8.1 es **estable** (notas de versión de Rock; en git el tag es el mismo commit que `-alpha`).
2. Correr en el servidor `Dev Tools\Upgrade\Get-RockWebInventario.ps1` (solo lectura) y comparar contra el repo
   (§13). Todo lo que salga como «cambiado en prod / solo en prod» se resuelve **antes**: o se trae al repo, o se
   agrega a «Qué se conserva».
   Además, traer de prod `Themes\VidAventuracheckin\Styles\_css-overrides.less` (si existe) y `checkin-theme.css`
   y compararlos con el repo antes de decidir qué hacer con el tema del kiosco (§12, riesgo 1). **No** subir un
   `_css-overrides.less` vacío.
3. Plugins del Rock Shop: revisar en **Admin > Rock Shop > Installed Plugins** de prod si hay versión para la 19
   (`INVENTARIO_DESARROLLOS_VR.md` §3). En local cargan las versiones actuales.
4. Pedir a TI el **valor** de `RunJobsInIISContext` en el `web.config` de prod (solo el valor; no copiar el archivo).
5. Preparar el `web.config` de la 19 con las llaves de prod (`PasswordKey`, `DataEncryptionKey`, `machineKey`…)
   fusionadas; lo hace TI en el servidor. Ponerle `RunJobsInIISContext=False` para la ventana (§7.3, paso 5).
6. Reservas dominicales (QREVENT): preguntar a TI si ya se desplegó en prod el paquete de servicios especiales
   (`docs/qrevent/DESPLIEGUE_RESERVAS_SERVICIOS_ESPECIALES.md`) y si ya se corrió su script. Se comprueba con
   `SELECT COL_LENGTH('dbo.SundayServiceSlot', 'ShowInApp')`: `NULL` = falta correrlo (§7.3, paso 5b).
6b. Correr en el SQL de prod `Dev Tools/Upgrade/19.8.1_preflight_bd_prod.sql` (solo lectura, con el sitio arriba) y
   guardar la salida. Todo debe decir «OK»: SQL Server ≥ 2016, nivel de compatibilidad ≥ 130, espacio para el
   `.bak`, migraciones del core y de plugins iguales a la copia probada. Cualquier «REVISAR» detiene el upgrade
   hasta entenderlo. (El bloque 8 del script responde el paso 6; el bloque 12 revisa que la 19 pueda descifrar los
   secretos de pagos, ver `upgrade-19.8.1/GUIA_FALLAS_PAGOS_19.8.1.md` §3.)
6c. TI confirma, sin mostrar los valores (p. ej. comparando su hash), que `DataEncryptionKey` y `PasswordKey` del
   `web.config` de la 19 son **idénticas** a las de la 18.1. Si difieren, fallan todos los cobros (Dar, ePay).
7. Armar el kit (fuera del repo) **desde un commit**, con `build-all.ps1 -FullObsidian` + `npm run build` en
   `Rock.JavaScript.Obsidian.Reporting` (build-all no lo recompila completo), prueba rápida en 6229 y luego
   `Dev Tools/Upgrade/New-KitUpgrade.ps1 -Destino <carpeta fuera del repo>`, que hace todo lo de esta lista y verifica
   que no viaje nada prohibido. Antes de correrlo: si `Themes/VidAventuracheckin/Styles/checkin-theme.css` aparece
   modificado (Rock lo recompila al arrancar, §14.3), `git checkout` de ese archivo. **No** lanzar `build-all.ps1`
   con `*>&1` redirigido en PowerShell 5.1: con `ErrorActionPreference=Stop` el primer aviso de npm corta el script.
   Contenido:
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
   $rw = '<ruta>\RockWeb'; $dst = 'C:\deploy-backup\<fecha>\retirados'
   Get-Content quitar_del_servidor.txt | Where-Object { $_ -and -not $_.StartsWith('#') } | ForEach-Object {
       $rel = $_ -replace '/', '\'; $src = Join-Path $rw $rel
       if (Test-Path -LiteralPath $src) {
           $d = Join-Path $dst $rel; New-Item -ItemType Directory -Force (Split-Path $d) | Out-Null
           Move-Item -LiteralPath $src -Destination $d } }
   ```
4. Copiar el kit **encima** de `RockWeb` (todo en la misma pasada: DLLs, bundles, `App_Code`, temas compilados).
5. Poner el `web.config` fusionado con `RunJobsInIISContext=False`.
5b. Reservas dominicales: correr `Dev Tools/Sql/QREVENT_SundayService_SlotSettings.sql` (idempotente) **si no se
   corrió antes en prod** (§7.1, paso 6). Con el sitio todavía detenido:
   `sqlcmd -S <servidor> -E -d Rock18 -I -f 65001 -i QREVENT_SundayService_SlotSettings.sql` (segundos; agrega 3
   columnas NULL a `SundayServiceSlot`, sin cambiar filas). Si ya se había corrido, no cambia nada. La
   `Rock.Blocks.dll` de la 19 también funciona sin las columnas (usa 15 min / 1 h 20 min / todo visible y la 862
   avisa que falta el script), pero no se deben dejar sin correr. Detalle, verificación y reversa:
   `docs/qrevent/DESPLIEGUE_RESERVAS_SERVICIOS_ESPECIALES.md`.
6. Quitar `app_offline.htm`, arrancar y esperar migraciones. Medido en local: ~1 min de compilación en frío +
   46 s de 67 migraciones core + 5 s de 45 hotfixes; segundo arranque 72 s. Vigilar
   `App_Data\Logs\MigrationLog.csv`, `RockExceptions.csv` y `ExceptionLog`. Anotar el `ExceptionLog.Id` máximo
   como línea base para las pruebas.
7. Jobs post-actualización con «Run Now», en el orden de §11.3, más el job propuesto para los 2 bloques huérfanos
   (§11.4, `Dev Tools\Upgrade\19.8.1_job_reemplazo_bloques_huerfanos.sql`). **Ojo:** los jobs «Replace WebForms
   Blocks» (incluido el nuestro) **se autoeliminan al terminar bien** y no dejan historial; que desaparezcan de la
   lista es la señal de éxito. Verificar el resultado en las páginas (File Manager 433, Weekly Metrics 451, System
   Phone Numbers 327, Experience Administration 740). Si uno falla, queda en la lista con el error.
8. Pruebas: `PLAN_PRUEBAS_19.8.1.md`, columna P.
   **Dar (decidido el 2026-11-23):** el cobro contra Cybersource no se pudo probar en local (secretos cifrados con la
   llave de prod; PLAN_PRUEBAS §16). Se verifica aquí con una donación de **Q1.00** con la tarjeta del responsable
   (la teclea él) en `https://personas.vidareal.tv/dar`. Ojo: el monto se escribe desde la derecha («100» = Q1.00).
   Debe pasar: mensaje de éxito; en la BD, la `FinancialTransaction` nueva con `Status='Approved'`, `BatchId` no
   nulo (lote «… (GTQ)»), sin fila `Pending` sobrante; el correo de confirmación llega; el workflow de donación (si
   está configurado) se lanza; `ExceptionLog` sin entradas nuevas de `CybersourceDonationEntry`. Si falla: anotar el
   mensaje exacto y la hora; **no** reintentar con otra tarjeta sin revisar primero (la idempotencia evita doble
   cobro con la misma solicitud, no entre intentos distintos).
   **Si falla cualquier pago (Dar, Eventos, inscripciones):** `docs/HANDOFF/upgrade-19.8.1/GUIA_FALLAS_PAGOS_19.8.1.md`
   (síntoma → dónde mirar → qué hacer, consultas de solo lectura y líneas base). La causa más probable de que fallen
   **todos** es que `DataEncryptionKey` del `web.config` fusionado no sea idéntica a la de la 18.1 (guía §2).
   Avisar a los supervisores de check-in de cada sede, antes del primer domingo, del límite nuevo de la 19: tras
   **10 PIN fallidos en 10 min desde la misma red**, el PIN de supervisor queda bloqueado hasta 10 min, incluso el
   correcto (§14.8). Que cada supervisor confirme su PIN antes del servicio.
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
- **Check-in Manager:** Roster: modales traducidos de nuevo (§14.6, verificar en la comparación); pasa al tema
  `RockManagerNextGen` (propuesta en §14.9b, según la comparación visual).
- **CSS del kiosco:** propuesta B (§14.9a), pendiente de la comparación visual y de probarla con dotless.
- **Límite de PIN (§14.8):** no configurable; avisar a supervisores antes del primer domingo.
- **Defectos que ya existen en 18.1 (§14.5):** solo documentados, no se tocan (decisión del responsable).
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

**Ensayo en Rock19Test (2026-11-23):** en este orden y con «Run Now» (con `RunJobsInIISContext=False` funciona):
231, 233, 232 → 220, 221, 225, 228, 230 → 222 → 227, 223, 226. Cada uno terminó en segundos y se autoeliminó; 433 y
451 quedaron con sus bloques Obsidian; cero excepciones. Detalle en `PLAN_PRUEBAS_19.8.1.md` §16. En prod, para
confirmar que un job terminó, mirar que desapareció de la lista (si falla, se queda con el error en el estado).

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
`OccurrenceChooserPage`). `Dev Tools\Upgrade\19.8.1_job_reemplazo_bloques_huerfanos.sql` crea un job más del
mismo tipo de upstream (Chop) con esos dos pares; se corre con «Run Now». Vale igual para prod (mismos GUIDs).
Alternativa manual: borrar el bloque de cada página y agregar el Obsidian, reconfigurando la página de detalle.

**Qué hace exactamente el job (verificado en `PostUpdateDataMigrationsReplaceWebFormsBlocksWithObsidianBlocks.cs`
y en la BD, 2026-11-19):**
- Alcance: todos los bloques de los 2 BlockTypes viejos. En toda la BD hay **exactamente 2**: bloque 1325 (página
  327, zona Main, orden 2) y bloque 1209 (página 740, Main, orden 0); ninguno en layouts ni a nivel de sitio; 0
  permisos y 0 preferencias propias.
- Por cada uno crea una copia con el BlockType Obsidian en la misma página, zona y orden, y copia los 3 valores de
  atributo (`SystemPhoneNumberDetailPage`; `DetailPage`, `OccurrenceChooserPage`); valida antes que las llaves del
  viejo existan en el nuevo (si no, no hace nada y deja el error en el job).
- Chop: borra los BlockTypes 788 y 768 (la FK `Block → BlockType` es `CASCADE`, así que se van los 2 bloques
  viejos) e intenta borrar sus `.ascx` del disco (ya no existen). Todo en una transacción; al terminar bien, el job
  se borra solo.
- **Correr el SQL dos veces no hace daño:** la segunda vez solo reescribe los mismos 2 valores del job (verificado:
  1 job, 2 valores). Si el job ya corrió, los BlockTypes viejos ya no existen y el script se detiene sin hacer nada.

**Estado en Rock19Test:** SQL aplicado el 2026-11-19 → **job 234** creado (activo; con `RunJobsInIISContext=False`
solo corre con «Run Now»). El responsable le dio «Run Now» el 2026-11-19. Resultado verificado por SQL:
- Página 327: bloque **2231** «System Phone Number List» (`Rock.Blocks.Communication.SystemPhoneNumberList`), zona
  Main, orden 2 (igual que el viejo 1325); `SystemPhoneNumberDetailPage` copiado con el mismo valor.
- Página 740: bloque **2232** «Interactive Experience List»
  (`Rock.Blocks.Event.InteractiveExperiences.InteractiveExperienceList`), Main, orden 0 (igual que el viejo 1209);
  `DetailPage` y `OccurrenceChooserPage` copiados con los mismos valores.
- BlockTypes viejos 788 y 768: borrados; bloques 1325 y 1209: borrados (cascada). Bundles
  `systemPhoneNumberList.obs.js` e `interactiveExperienceList.obs.js` presentes.
- `ExceptionLog`: **ninguna excepción nueva** después del job (ni de esas páginas en ningún momento).
- **El job se autoelimina al terminar bien** (`DeleteJob()`), igual que los «Replace WebForms Blocks» de upstream: no
  queda en la lista de jobs ni deja historial. Para confirmar que corrió, mirar las páginas (o
  `SELECT … FROM Block WHERE PageId IN (327,740)`), no la lista de jobs. Si falla, **no** se borra: queda como
  no-sistema con el error en «Last Status Message».

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
   que no está en el repo (el defecto viene de `hotfix-18.1`). Al cambiar `RockWeb/Styles` en la 19, Rock intenta
   recompilar y falla (`ExceptionLog` 1630300). Se sigue sirviendo el `checkin-theme.css` compilado antes, así que
   el kiosco se ve igual pero no recibe cambios.
   - `_css-overrides.less` es el archivo donde **el Theme Styler de Rock guarda los ajustes hechos desde la
     interfaz** (`RockWeb/Blocks/Cms/ThemeStyler.ascx.cs:130-134`): **prod podría tenerlo con contenido**. Por eso
     **no se versiona uno vacío** (pisaría el de prod). Decisión del responsable, 2026-11-19.
   - Cuándo recompila Rock: al arrancar (`RockTheme.CompileAll(onlyCompileIfNeeded)` desde `Global.asax.cs`), un
     tema se recompila si cualquier archivo de `RockWeb/Styles` o del tema es más nuevo que su `.css`
     (`Rock/Web/UI/RockTheme.cs:122-200`). El día del upgrade pasa seguro (los `Styles` de la 19 son nuevos): si
     prod tiene `_css-overrides.less`, su `checkin-theme.css` se **regenera con los estilos de la 19**; si no, falla
     y queda el `.css` viejo.
   - **Antes de decidir (§7.1):** traer de prod `Themes\VidAventuracheckin\Styles\_css-overrides.less` (si existe) y
     `checkin-theme.css` y comparar ese `.css` con el del repo (`git hash-object`). El inventario del servidor
     (§13) ya dice si el archivo existe y su hash.
   - **En local** se creó `_css-overrides.less` **vacío y sin versionar** (excluido con `.git/info/exclude`) solo
     para la prueba comparativa (§14). El `.css` previo quedó respaldado en la carpeta temporal de la sesión. Al
     reiniciar la 19, Rock regenera `checkin-theme.css` (archivo versionado): **no commitear ese cambio**; después
     de la prueba se restaura con `git checkout -- RockWeb/Themes/VidAventuracheckin/Styles/checkin-theme.css`.
   - **Los demás temas de check-in no tienen el problema:** `CheckinPark` (tema del sitio «Rock Check-in»),
     `CheckinAdventureKids`, `CheckinAero`, `CheckinBlueCrystal`, `CheckinElectric` y los otros 6 temas que importan
     `_css-overrides.less` lo traen versionado desde upstream. En el `ExceptionLog` de prod (copia del 18-nov) no hay
     ningún error de `.less` anterior al upgrade.
2. Check-in Manager pasa a `RockManagerNextGen`: el kit debe traer ese tema compilado (§7.1).
3. Roster en inglés (§6).
4. Los `.ascx` compilan al primer request: un error de compilación solo aparece al abrir la página.

Recomendación: no migrar el kiosco a Obsidian ahora; probar el flujo completo (`PLAN_PRUEBAS_19.8.1.md` §8) y
planear la migración a next-gen antes de la 20.x.

---

## 13. Comparación servidor vs repo (preparada, no ejecutada)

Objetivo: detectar archivos cambiados o agregados en prod que no están en el repo, antes de copiar el kit.

1. **En el servidor** (solo lectura; no lee `web.config` ni connection strings; Content/App_Data/Cache solo se
   cuentan). Lo corre el responsable:
   1. Copiar `Dev Tools\Upgrade\Get-RockWebInventario.ps1` al Escritorio del servidor.
   2. Ubicar la ruta física de `RockWeb`: *Administrador de IIS > Sitios > (sitio de personas.vidareal.tv) >
      Configuración básica > Ruta de acceso física* (no está documentada en el repo).
   3. En una consola de PowerShell (no hace falta como administrador si la cuenta puede leer `RockWeb`):
      ```powershell
      powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\Desktop\Get-RockWebInventario.ps1" -RockWeb "<ruta física de RockWeb>"
      ```
      La salida va al Escritorio por omisión. Tarda unos minutos; se puede correr con el sitio arriba.
   4. Traer de vuelta (3 archivos, todos en el Escritorio):
      `RockWeb_inventario_<equipo>_<fecha>.csv`, `RockWeb_excluidas_<equipo>_<fecha>.csv`,
      `RockWeb_inventario_<equipo>_<fecha>.txt`. Además, para el tema del kiosco (§12):
      `<RockWeb>\Themes\VidAventuracheckin\Styles\_css-overrides.less` (si existe) y `checkin-theme.css`.
   El CSV solo contiene rutas, tamaños, fechas y hashes (ningún contenido de archivo).
   Probado en la máquina de dev: 5 768 archivos, 197 s, 0 errores.
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

---

## 14. Prueba comparativa de check-in 18.1 vs 19 (2026-11-19, local)

Prioridad: que el check-in de VidAventura funcione y se vea **igual** que hoy en prod. Se montaron las dos
versiones lado a lado con la misma BD de origen.

### 14.1 Entorno

| | 18.1 (referencia) | 19.8.1 |
|---|---|---|
| URL | `http://localhost:6230` | `http://localhost:6229` |
| Código | `git worktree add --detach ..\Rock18Base-wt hotfix-18.1` (commit `81ed172522`); la rama de prueba no se tocó | `Test_Update_18.1_a_19.8.1` |
| BD | `Rock18Base`: import del mismo `Rock18_Prod_20261119.bacpac` (8 min 40 s), sin migrar | `Rock19Test` |
| Aislamiento | `dev-isolation\aislar_dev_Rock18Base.sql` (copia con guarda `Rock18Base`, URLs y frame domain en `localhost:6230`). Corrida 1: mismos conteos que Rock19Test (URLs 3, SMTP 1, kiosco 1, transportes 13, pasarelas 7+1, Odoo 8, Wallet 2, Azure 2, jobs 95, frame domains 1); corrida 2: todo 0. 0 jobs activos; SendGrid/Twilio/WhatsApp/OneSignal `Active=False` | ya aislada (Fase 1) |

Build del worktree 18.1 desde clon limpio — **trampas encontradas** (útiles para cualquier clon nuevo):
1. `SignNowSDK` no compila sin `nuget restore Rock.sln` (usa `packages.config`; `msbuild -restore` no lo cubre).
2. Faltan en `Bin` las DLLs que llegan por `.refresh` (p. ej. Ical.Net): copiarlas desde `packages\` (las rutas de
   los `.refresh` son relativas a `RockWeb\`).
3. El paso `RockWeb.metaproj` de `Rock.sln` compila `RockWeb/Plugins/com_vidareal/Translator/*.ascx.cs`, que
   necesitan `com.vidareal.Translator.dll`, pero los plugins se compilan **después** del core. En un clon limpio hay
   que correr `build-all.ps1 -SkipCore` primero (contra el `Rock.dll` ya compilado) y luego el build completo.
4. Las DLLs del Rock Shop se copian de `Handoff_VidaReal_2026-10-15\dll-terceros\RockWeb-Bin\`.

### 14.2 Precompilación completa de la 19 (aspnet_compiler)

`aspnet_compiler -v / -p RockWeb -c -errorstack <salida>`: **0 errores**, 45 advertencias (CS0618, APIs
obsoletas: `EditLabel`, `RestActionDetail`, `StarkDetail/List`, `SendLegacyProviderDocument` en
`RegistrationDetail`/`GroupMemberDetail`/`GroupDetail`, `HasMergeFields` en DataToolkit, `Get/SetUserPreference`
en LavaTester). 521 páginas/controles compilados en 2,0 min: **todos los `.ascx` de check-in, QREVENT,
Asistencia, SundayService, Translator y de los plugins del Rock Shop compilan con la 19.** (El primer intento
falló solo al copiar estáticos por una ruta de `App_Data\ChromeEngine` de más de 260 caracteres; con una carpeta de
salida corta pasa.)

### 14.3 CSS del tema del kiosco en la 19 (hallazgo)

Con `_css-overrides.less` presente (en local, vacío y sin versionar), la 19 recompiló
`VidAventuracheckin/Styles/checkin-theme.css`: de 368 614 a 262 515 bytes, **~1 400 clases menos**. Causa: upstream
movió las utilidades (`d-*`, `flex-*`, `m*-*`, `p*-*`, `gap-*`, grid, ratios) de `Styles/_helpers.less` a
`Styles/_helpers-rock.less` (commit `aea467741b`), que solo importa `_rock-core.less` (temas principales). Los temas
de check-in legacy importan `_helpers.less`, así que **todos** (también `CheckinPark` de upstream) pierden esas
clases al recompilarse.

Impacto en el flujo del kiosco (cruce de las clases perdidas contra `RockWeb/Blocks/CheckIn/*`, el layout del tema
y las plantillas Lava del tipo 49/área 50): **solo `ml-3`**, en el texto «Count: N» de `MultiPersonSelect.ascx.cs:120`
(margen izquierdo). Las demás clases perdidas que usamos están en bloques que no van en el kiosco
(`RapidAttendanceEntry`, `AttendanceSelfEntry`, `AttendanceAnalytics`, `MobileLauncher`). Se confirma
visualmente en la prueba (PLAN_PRUEBAS §15, C5). Si prod tiene `_css-overrides.less`, esto pasará en prod.

### 14.4 Preparación de la prueba (idéntica en las dos BDs)

`dev-isolation\preparar_prueba_checkin_vidaventura.sql` (guardas de máquina y BD; idempotente: segunda corrida 0
cambios en las dos):
- Familia **ficticia** «Familia PruebaUpgrade»: 1 adulta + 3 niños con edades para cada grupo de VidAventura
  Ilumina (tipo 49, área 50: Descubridores 0–3.99, Exploradores 4–6.99, Defensores 7–12.6).
- Horario 35 «Check In - Prueba» activado (L–V, check-in 09:00–21:00; ya asignado a los 3 grupos).
- Kiosco nuevo «Kiosko Prueba Upgrade» (Id 26 en ambas) = copia del «Kiosko Mostrador» (12) con las salas 133–135
  e impresión **desde el servidor**.
- Impresora 14 → `127.0.0.1:9100` (18.1) / `:9101` (19). **Antes apuntaba a una impresora de la red interna**:
  si esta máquina está en esa red, cualquier impresión desde el servidor habría salido en papel.
  La IP original quedó anotada en la descripción del dispositivo.
- `dev-isolation\impresora_falsa_zpl.ps1`: listener solo en `127.0.0.1` que guarda cada etiqueta en
  `dev-isolation\etiquetas_capturadas\<puerto>_<hora>.zpl`. `ZebraPrint` (envío por socket, acepta `ip:puerto`) es
  idéntico en 18.1 y 19.
- Etiquetas del área: `papa_final.prn` (BinaryFile 1079) y `nino_final.prn` (1081).

Checklist del recorrido: `PLAN_PRUEBAS_19.8.1.md` §15.

### 14.5 Auditoría de código del check-in: 18.1.0 → 19.8.1

Diff de todo lo que usan los 47 bloques de check-in (`Rock/CheckIn`, `CheckInState`, `KioskDevice`, etiquetas,
acciones `Rock.Workflow.Action.CheckIn.*`, `Schedule`, `Attendance*`, caches, Lava). **[V]** = verificado en el
código; **[I]** = inferido, se confirma en la prueba.

**Sin cambios [V]:** `ZebraPrint.cs`, `KioskLabel.cs`, `CheckInLabel.cs`, `KioskDevice.cs`, `CheckInState.cs`,
`CheckInBlock*.cs`, `CheckInEditFamilyBlock.cs`, `CheckInSearchBlock.cs`, `CheckinManagerHelper.cs`,
`LocalDeviceConfiguration.cs`, `CreateLabels.cs`, `ParseZebraLabel.cs`, `ScheduleCache.cs`, `LocationCache.cs`,
`AttendanceCodeService.cs`, `GroupLocation.cs`, `Scripts/CheckinClient/ZebraPrint.js` y `checkin-core.js`; la
lógica de horarios activos (`IsCheckInActive`/`GetCheckInTimes`) y de edad/grado. 33 de las 35 acciones de check-in
idénticas. Ninguna migración de la 19 toca el sitio de check-in, su WorkflowType, los Devices ni las etiquetas.

| Cambio | Commit | Impacto en VidAventura | Se prueba en |
|---|---|---|---|
| `FindFamilies.cs`: `WithRecompile` en búsquedas por nombre < 7 caracteres | 780ab66a77 | Rendimiento; mismos resultados [V] | C3 (buscar «PruebaUpgrade» y por teléfono) |
| Validación de strings en **cada** `SaveChanges` (`StringValueValidator`): `Attendance.SearchValue`, `AttendanceCode.Code`, `Device.IPAddress`, nombres de persona (rechaza HTML, `{{ }}`, `{% %}`, caracteres de control) | 9c42887787, b637c95592 | Alta/edición de familias desde el kiosco con caracteres raros podría fallar donde antes pasaba [V] | Alta de un niño desde el kiosco con tildes |
| Motor Lava Fluid 2.5 → 2.25 (merge fields de etiquetas) | fcb660f62f, 22a111205a | Formato de los campos de la etiqueta podría variar [I] | C8: ZPL 18.1 vs 19 byte a byte |
| `Welcome.ascx.cs`: límite de 10 PIN fallidos por IP cada 10 min (`PinAttemptLimiter`); reimpresión solo de asistencias de la persona desde ayer | d845679932, 17a3c96917 | Si los kioscos salen a internet por una misma IP (proxy/NAT), un PIN mal tecleado 10 veces bloquea el admin de **todos** 10 min [I] | PIN incorrecto; reimprimir |
| Nombres codificados como HTML en Person/MultiPerson/Group/Location/TimeSelect/Success/EditFamily | b297e18a06 | Nombres con `&` o tildes deben verse igual [V] | C5 |
| `EditFamily`: persona nueva toma el ConnectionStatus de la configuración | 17a3c96917 | Equivalente en la práctica [V] | Alta desde kiosco |
| `Manager/Person*.ascx.cs`: reimpresión solo de la persona | 17a3c96917 | — | C11 |
| `Schedule`: texto «Once on …» para horarios de una fecha; tabla `ScheduleDate` | ee7fa962e3, 202603232352001 | Solo si una etiqueta usa el texto del horario | C8 |
| Utilidades CSS fuera de `_helpers.less` | aea467741b | §14.3: margen del «Count: N» | C5 |
| `UpdateCheckinManagerToNextGen` | migración | Check-in Manager con `RockManagerNextGen` (tema nuevo). Nota: sus páginas usan `FullWidth`/`LeftSidebar`, no `Blank.aspx` (§14.9b) | C10 en el móvil |

**Etiquetas [V]:** el contenido (merge por regex `(?<=\^FD)KEY(?=\^FS)` sobre `KioskLabel.FileContent`) y el
transporte (`Rock.Utility.ZebraPrint.OpenSocket`, UTF-8, una conexión por impresora, acepta `ip:puerto` con IP
literal) son idénticos. Lo único que puede cambiar el ZPL es el motor Lava de los merge fields. Con `PrintFrom=Client`
(como el kiosco 12 real) el ZPL no pasa por el servidor: la app del kiosco lo baja de `GetFile.ashx`, que en la 19
agrega un header CSP `sandbox` (no debería afectar a una descarga nativa [I]; se confirma en prod).

**Nuestro código sobre la 19 [V]:** sin llamadas a APIs eliminadas (la precompilación §14.2 lo confirma).
**Defectos que ya están en prod (no los trae el upgrade; no se tocan sin decisión):**
1. `MultiPersonSelect.ascx.cs:504-506`: `SelectedForSchedule[scheduleId] = 1` sobre una `List<int>` (upstream:
   `.Add( scheduleId, true )`) lanzaría `ArgumentOutOfRangeException`. Solo en modo de auto check-in completo; en la
   copia de prod **no hay ninguna** excepción de ese tipo en páginas de check-in desde agosto.
2. `CheckInOutView.ascx.cs:27` lee `Session["CheckInKioskState"]`; la clave real de Rock es `"CheckInState"`.
3. Valores fijos: `ActionSelect.ascx.cs:105` (`deviceId == 25`), `Admin.ascx.cs:215` (tema `vidaventuracheckin`).
4. El tema propio no importa los íconos Tabler (upstream sí lo hizo en sus temas, `1291dc2dd2`): los íconos `ti`
   salen vacíos (ya pasaba en 18.1).

### 14.6 Roster del Check-in Manager en español (aplicado en local el 2026-11-19)

En la 19 el Roster es Obsidian (`Rock.Blocks/CheckIn/Manager/Roster.cs` + `src/CheckIn/Manager/`), conserva el
BlockTypeGuid (`EA5C2CF9…`) y sus valores; pierde el atributo `EnableGroupColumn`; **no tiene atributos de texto**.
Hay ~60 textos visibles en inglés en 14 archivos (+~9 mensajes del servidor). En 18.1 traducíamos solo 3 modales
de `Roster.ascx` (`git diff 18.1.0 hotfix-18.1 -- RockWeb/Blocks/CheckIn/Manager/Roster.ascx`).

Opciones evaluadas: (i) traducir el `.obs`; (ii) el Traductor (descartado: excluye `.grid-row/.grid-cell` y congela
textos de Vue, trampa 4); (iii) volver a montar el `Roster.ascx` viejo (pierde el tiempo real de la 19).
**Aprobado por el responsable: (i), cambio mínimo, solo los mismos textos que en 18.1.**

| Modal (19) | Título | Botón |
|---|---|---|
| `stayingModal.partial.obs` | «Stay for Service» → «Confirmar» | «Check In» → «Registrar Entrada» |
| `checkoutAllModal.partial.obs` | «Mark All as Checked-Out» → «Confirmar» | «Confirm» → «Registrar Salida» |
| `checkoutModal.partial.obs` | «Mark as Checked-Out» → «Confirmar» | «Confirm» → «Registrar Salida» |

- El nombre de la persona dentro del texto del modal quedó en `<span class="notranslate">` (dato dinámico). El resto
  de los textos del cuerpo sigue en inglés, igual que en 18.1.
- Auditoría del diff antes de compilar: 8 líneas, solo atributos de texto y los dos `<span>`; sin cambios de lógica,
  `v-if`, flags ni timers. El texto «Checked-Out» del filtro de `rosterMenu.partial.obs` no se tocó (en 18.1 tampoco
  estaba traducido).
- `npm run build` (Rock.JavaScript.Obsidian.Blocks): «DONE»; `RockWeb/Obsidian/Blocks/CheckIn/Manager/roster.obs.js`
  regenerado (14:58, 104 942 bytes) con «Registrar Entrada» ×1 y «Registrar Salida» ×2, sin los títulos en inglés.
  No cambia `Rock.Blocks.dll`. En local (`compilation debug="true"`) Rock recalcula la huella de Obsidian solo: basta
  recargar.
- Registrado en `CHANGES.md` (sección CheckIn), `Rock.JavaScript.Obsidian.Blocks/CHANGES.md` y
  `docs/HANDOFF/core-files-modified.txt`. **Despliegue:** `roster.obs.js` en el kit (`Obsidian\` completo).

### 14.7 Traductor

Fuera del alcance de este documento (lo ve otra persona). Verificado el 2026-11-19: en Rock18Base y Rock19Test la
clave de Azure del Traductor (`AzureApiKey`) está **vacía**, así que en las pruebas locales no sale nada.

### 14.8 Límite de PIN fallidos del kiosco (nuevo en la 19)

- Código: `Rock/CheckIn/PinAttemptLimiter.cs` (usado por `RockWeb/Blocks/CheckIn/Welcome.ascx.cs:1108-1186` y por
  `CheckInDirector` del check-in next-gen). **No es configurable**: `MaxFailuresPerIpAddress = 10` y
  `Window = 10 min` son constantes; no hay atributo de bloque, de sitio ni global. Cambiarlo es modificar el core.
- Cómo cuenta: por **IP del cliente** (`RockPage.GetClientIpAddress()`), en memoria de cada servidor web. Cada PIN
  cuenta como fallo antes de validarse; un PIN correcto **reinicia** el contador. Al llegar a 10, también el PIN
  correcto se rechaza («Too many failed PIN attempts…») hasta que pasa la ventana (empieza con el primer intento y
  no se reinicia). Reiniciar el sitio lo limpia (no recomendado en domingo).
- Solo afecta al **PIN de supervisor** (Admin/override del kiosco, Check-in Manager legacy). El check-in de las
  familias no usa PIN.
- Datos de la copia de prod (sitio «Rock Check-in», 20-ago → 18-nov, solo conteos): 1 046 intentos, 313 fallidos;
  PIN exitosos desde 25 IPs distintas (cada sede sale con su IP; no hay un proxy que las junte). **En 2 días** una
  misma IP llegó a ≥ 10 fallos en 10 min (máximo 14, sábado 6-sep a las 14:40): con la 19, ese día el PIN de esa sede
  habría quedado bloqueado hasta 10 min.
- **Recomendación:** dejar el valor de upstream (10/10 min; protege contra adivinar PINs, que son la credencial
  completa) y **no** modificar el core. Mitigación operativa en el runbook: avisar a los supervisores de cada sede
  antes del primer domingo que, tras 10 PIN fallidos, hay que **esperar 10 minutos** (o entrar desde otra sede/red); y
  que cada supervisor confirme su PIN antes del servicio. Si después se ve que molesta, la alternativa sería un
  cambio en el core para leer el límite de un atributo global (requiere aprobación).

### 14.9 Propuestas para que el kiosco y el Check-in Manager se vean igual que en 18.1 (no aplicadas)

**a) Clases perdidas en el CSS del kiosco (§14.3).** Se midió compilando el tema fuera del repo con `less.js` 4.4.2
(calibrado: produce exactamente las mismas clases que el `checkin-theme.css` 18.1 del repo):

| Variante | Clases que faltan vs 18.1 | Clases extra |
|---|---|---|
| 19 sin arreglo | 1 419 | 106 (nuevas de la 19, igual con cualquier arreglo) |
| A: `@import "../../../Styles/_helpers-rock.less";` | 20 | 196 (+90 de colores/espaciado/texto propios de la 19) |
| **B: solo las utilidades que la 18.1 tenía en `_helpers.less`** | **20** | **106** |

Las 20 que faltan con B son de componentes que upstream borró (`.card-schedule`, `.panel-worksurface`, `.tox`,
`.ant-select-*`…). La única que usamos, `btn-square`, está en `RapidAttendanceEntry`/`AttendanceAnalytics`, que no
van en el kiosco. **Propuesta: B**, en un archivo nuevo del tema (sin tocar archivos de upstream):

`RockWeb/Themes/VidAventuracheckin/Styles/_utilidades-18.less` (nuevo) importado en `checkin-theme.less` justo antes de
`@import "_css-overrides.less";`:

```less
// [VidaReal] Upgrade 19.x: upstream sacó estas utilidades de Styles/_helpers.less (commit aea467741b) y ahora solo
// las importan los temas principales (_rock-core.less -> _helpers-rock.less). Se repiten aquí para que el kiosco
// conserve las mismas clases que en 18.1 (d-*, flex-*, m*-*, p*-*, grid, ratios, text-align).
@import "../../../Styles/rock-utilities/_cssgrid.less";
@import "../../../Styles/rock-utilities/_ratios.less";
.util-mix-display(); .util-mix-css-grid(); .util-mix-flex(); .util-mix-order(); .util-mix-ratios(); .util-mix-spacing(); .util-mix-text-align();
@media (min-width: @screen-sm-min) { .util-mix-display("sm"); .util-mix-css-grid("sm"); .util-mix-flex("sm"); .util-mix-order("sm"); .util-mix-ratios("sm"); .util-mix-spacing("sm"); .util-mix-text-align("sm"); }
@media (min-width: @screen-md-min) { .util-mix-display("md"); .util-mix-css-grid("md"); .util-mix-flex("md"); .util-mix-order("md"); .util-mix-ratios("md"); .util-mix-spacing("md"); .util-mix-text-align("md"); }
@media (min-width: @screen-lg-min) { .util-mix-display("lg"); .util-mix-css-grid("lg"); .util-mix-flex("lg"); .util-mix-order("lg"); .util-mix-ratios("lg"); .util-mix-spacing("lg"); .util-mix-text-align("lg"); }
@media print { .util-mix-display("print"); }
```

Pendiente antes de aplicarlo: (1) la comparación visual del responsable; (2) confirmar que compila con **dotless**
(el compilador de Rock), no solo con less.js; (3) solo surte efecto si el tema llega a compilar, es decir, si existe
`_css-overrides.less` (§12, riesgo 1). Si prod no lo tiene, en prod queda el `.css` viejo, que ya trae todas las
clases.

**b) Check-in Manager.** Corrección a la auditoría (§14.5): el Check-in Manager **no usa `Blank.aspx`** ni en 18.1 ni
en la 19 (sus páginas usan `FullWidth` 13–15 y `LeftSidebar` 2), así que nuestro `Blank.aspx` responsivo nunca le
aplicó. El `<meta name="viewport">` es idéntico en `RockManager/Layouts/Site.Master` (18.1) y en
`RockManagerNextGen` (19). La diferencia visual viene del **tema nuevo** que pone la migración
`UpdateCheckinManagerToNextGen`. Propuesta, según lo que muestre la comparación:
- Si la 19 se ve aceptable (también en el móvil): no hacer nada.
- Si hay que dejarlo igual que en 18.1: volver el sitio 5 al tema `RockManager` (configuración del sitio, sin
  código; reversible) y probar que el Roster Obsidian y el `CheckInContextSetter` nuevos se vean bien con ese tema,
  porque upstream los diseñó para `RockManagerNextGen`. Probarlo en local antes de decidir.

---

## 15. Acceso a 6229 desde la red local (abierto el 2026-11-20)

Con autorización del responsable, otras personas de la red local prueban la 19 en **`http://<IP de la PC de desarrollo>:6229/`**
(la IP no se anota en el repo; está en los scripts de `dev-isolation`). Solo 6229 (Rock19Test); **6230 (18.1) sigue solo en `localhost`**. Rock19Test es una copia
de prod con datos de miembros: solo deben entrar personas autorizadas, con sus propios usuarios.

### 15.1 Cómo se abrió

| Capa | Cambio | Quién |
|---|---|---|
| Windows (http.sys) | Reserva `netsh http add urlacl url=http://*:6229/ user=Todos` | Responsable (admin) |
| Firewall | Regla de entrada TCP 6229 solo para `LocalSubnet` | Responsable (admin) |
| IIS Express | Sitio **`Rock19-6229`** (id 2) en `%USERPROFILE%\Documents\IISExpress\config\applicationhost.config`, con un único binding `*:6229:` (todos los hosts) y el pool `Clr4IntegratedAppPool`. Respaldo previo: `applicationhost.config.antes-binding-6229_2026-11-20.bak` en la misma carpeta | Claude |
| Rock19Test | `dev-isolation\red_local_6229_abrir.sql` (guarda de máquina y BD, idempotente): `SiteDomain` con la IP de la PC en el sitio «Rock RMS» (Order 3, el último) e `<IP>:6229` en su `AllowedFrameDomains` | Claude |

**Arranque de 6229 desde ahora** (sustituye al comando con `/path` de §0 mientras el acceso siga abierto):

```powershell
& "C:\Program Files\IIS Express\iisexpress.exe" /site:Rock19-6229
```

Notas de lo que se encontró al abrirlo:
- **Binding por host no arranca sin elevar.** El primer intento fue `:6229:localhost` + `:6229:<IP>`: IIS
  Express dio «Acceso denegado (0x80070005)» en **las dos** URLs (incluida `localhost`, que sin la reserva sí se
  registraba). http.sys solo permite registrar con una reserva de comodín débil `http://*:6229/` exactamente esa URL.
  Por eso el binding es `*:6229:`, que registra `http://*:6229/`. La exposición la limita el firewall (`LocalSubnet`).
  Si se quiere aceptar solo el host de la IP: el responsable crea (como admin) las reservas
  `http://<IP>:6229/` y `http://localhost:6229/`, borra la de `*`, y se vuelve a los dos bindings por host.
- **Sin el `SiteDomain`, `/checkin` daba 404 entrando por IP.** `RockRouteHandler.GetSite` busca el sitio por el host y,
  si no lo encuentra, por la cookie `last_site`; sin ninguno de los dos, `GetPageIdFromDataTokens` no asigna página y
  las rutas con nombre (`/checkin`, `/checkinmanager`) devuelven «Page Not Found». `/page/N` sí funcionaba (no depende
  del sitio). Es el mismo motivo por el que prod tiene la IP de su servidor como dominio. El dominio nuevo va al final del
  orden: `localhost` sigue siendo el primero, que es el que usa `Site.DefaultDomainUri` (CLAUDE.md, trampa 7).
- **Modales:** Rock arma `frame-ancestors` con el `AllowedFrameDomains` del sitio de la página (`Global.asax.cs`), no
  del host. Ya incluía `'self'`, que cubre el mismo origen; la IP queda además explícita.
- **Verificado desde esta PC, sin cookies** (2026-11-20 ~08:40): `http://<IP>:6229/` → 302 a `/page/3`
  (200, «Log In | Rock RMS», CSP con `<IP>:6229`); `/checkin` → 302 a `/Login`; `/checkinmanager` → 302 a
  `/page/387`; `localhost:6229` y `localhost:6230` igual que antes. `ExceptionLog` de los reinicios: solo ruido de
  arranque conocido (base nueva de Rock19Test: **1630439**).
- **Limitación conocida:** `PublicApplicationRoot`, `InternalApplicationRoot` y `OrganizationWebsite` siguen en
  `http://localhost:6229/`. Lo que Rock arme con esos valores (correos, enlaces absolutos, algunos redirects) apunta a
  `localhost`, que en otra PC no abre. No se cambiaron para no afectar esta PC ni las pruebas en curso.

### 15.2 Cómo se cierra

1. Detener 6229 (el proceso `iisexpress.exe ... /site:Rock19-6229`).
2. Rock19Test: `sqlcmd -S localhost -E -C -d Rock19Test -I -f 65001 -i red_local_6229_cerrar.sql` (en
   `dev-isolation`; quita el `SiteDomain` y la IP de `AllowedFrameDomains`).
3. IIS Express: quitar el bloque `<site name="Rock19-6229">` de `applicationhost.config` (o restaurar el `.bak`) y
   volver a arrancar 6229 con el comando `/path` de §0.
4. Responsable (como admin): `netsh http delete urlacl url=http://*:6229/` y borrar la regla de firewall del puerto
   6229. **Hace falta quitar la reserva**: mientras exista, `/path ... /port:6229` tampoco registra `localhost:6229`.
5. Verificar: `netsh http show urlacl url=http://*:6229/` no muestra nada, y `http://localhost:6229/` abre.
