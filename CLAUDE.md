# CLAUDE.md — Fork de Rock RMS de Iglesia Vida Real

Contexto para Claude Code (y para cualquier dev) que trabaje en este repo. Responder y documentar
en **español**. Política de uso de IA de la iglesia: no procesar consejería/registros pastorales;
no sacar conclusiones sobre menores identificables (el trabajo técnico sobre tablas que contienen
menores sí procede); cero secretos en el repo.

## Qué es

- **Rock RMS 18.1** (ASP.NET WebForms + bloques Obsidian Vue 3, .NET Framework 4.7.2, SQL Server)
  con módulos propios. La carpeta se llama `Rock15.5` por historia.
- Rama de trabajo: **`hotfix-18.1`** (es lo que corre en producción). `develop` es un espejo
  viejo de upstream: no usarla. Estado git y ramas: `docs/HANDOFF/ESTADO_REPO.md`.
- Producción: `personas.vidareal.tv` (IIS en VM Windows) + BD `Rock18`. Dev local:
  `http://localhost:6229` (IIS Express) + copia de `Rock18`.

## Empezar aquí

| Necesito… | Leer |
|---|---|
| Puerta de entrada | `ONBOARDING.md` |
| Montar el ambiente / compilar / correr | `docs/HANDOFF/SETUP_DESARROLLO.md` |
| Desplegar a prod | `docs/HANDOFF/DEPLOY_PRODUCCION.md` (+ runbook del módulo) |
| Estado git, ramas, pendientes | `docs/HANDOFF/ESTADO_REPO.md` |
| Mapa de toda la documentación por módulo | `.claude/CONTEXT_INDEX.md` |
| Contexto técnico transversal (stack, convenciones, zonas delicadas) | `.claude/PROJECT_CONTEXT.md` |
| Qué archivos son nuestros vs upstream | `CHANGES.md` (raíz) y los `CHANGES.md` por carpeta |

## Arquitectura en una pantalla

| Capa | Dónde | Produce |
|---|---|---|
| Dominio y servicios propios dentro del core | `Rock/Model/Eventos/`, `Rock/Model/Wallet/`, `Rock/Model/Qr/` | `Rock.dll` |
| Bloques Obsidian (servidor) | `Rock.Blocks/{Eventos,Wallet,Qr,QREVENT,Dar,FamilyHub,LayoutCustom,Security}/` | `Rock.Blocks.dll` |
| Bags (contratos servidor↔cliente) | `Rock.ViewModels/Blocks/...` | `Rock.ViewModels.dll` |
| REST propio | `Rock.Rest/VidaReal/` | `Rock.Rest.dll` |
| Frontend Vue 3/TS (`.obs`) | `Rock.JavaScript.Obsidian.Blocks/src/<Módulo>/` | `RockWeb/Obsidian/Blocks/<Módulo>/*.obs.js` |
| Transporte WhatsApp | `Rock.WhatsApp/` (dentro de `Rock.sln`) | `Rock.WhatsApp.dll` |
| Plugins (fuera de `Rock.sln`, referencian `RockWeb\Bin\Rock.dll`) | `Plugin.VidaRealEvents`, `.VidaRealWallet`, `.VidaRealDupDetect`, `.VidaRealTranslator`, `.VidaRealQr`, `.OdooEventSale`, `.EpayVisanetGateway`, `.CybersourceInlineRestGateway` | `com.vidareal.*.dll`, etc. (mayormente migraciones y acciones de workflow) |
| WebForms / handlers | `RockWeb/Blocks/`, `RockWeb/App_Code/`, `RockWeb/Webhooks/`, `RockWeb/Plugins/` (versionado) | se compilan en runtime |
| SQL fuera de migraciones | `Dev Tools/Sql/`, `Scripts/VidaReal/` | se corren a mano |

Eventos sigue arquitectura hexagonal: bloques delgados, lógica en `Rock/Model/Eventos/Services/`.
Leer `Rock/Model/Eventos/ARCHITECTURE.md` (y `Rock/Model/Qr/ARCHITECTURE.md`) antes de tocar.

Repo relacionado: addon de Odoo 17 `custom_event_sale_api` (facturación FEL de eventos).

## Comandos

```powershell
# Verificar prerequisitos (solo lectura)
powershell -ExecutionPolicy Bypass -File ".\Dev Tools\Build\check-prereqs.ps1"

# Build completo: Rock.sln (Release) + 8 plugins -> RockWeb\Bin
.\"Dev Tools\Build\build-all.ps1"
.\"Dev Tools\Build\build-all.ps1" -SkipCore          # solo plugins
.\"Dev Tools\Build\build-all.ps1" -NoCopy            # compila sin tocar RockWeb\Bin
.\"Dev Tools\Build\build-all.ps1" -FullObsidian      # + npm run build completo

# Un proyecto core sin pisar RockWeb\Bin
& $msbuild Rock.Blocks\Rock.Blocks.csproj -restore -p:Configuration=Release -p:CopyToRockWeb=False

# Frontend
cd Rock.JavaScript.Obsidian.Blocks; npm run build      # o build-fast / watch

# Tests (solo el módulo QR tiene tests propios: Rock.Tests/Model/Qr/, MSTest)
```

MSBuild de Visual Studio (VS 2022+ / 2026), **no** `dotnet build` para `Rock.sln` (RockWeb es Web
Site Project). Orden obligatorio: core primero, plugins después.

## Convenciones

- Bloques nuevos de Vida Real: preferir Obsidian a WebForms; prefijo `VR` para bloques nuevos;
  categorías `VidaReal > …`, `Custom`, `Dar`, `QREVENT`.
- C#: estilo Rock (espacios, llaves en línea nueva); `RockContext` dentro de `using`; los
  `BlockAction` devuelven `ActionOk()/ActionBadRequest()/...`; validar `CurrentPerson` en servidor.
- `.obs`: `<script setup lang="ts">`, textos en español directo en el template.
- Migraciones de plugin: `[PluginMigration]` con **numeración propia por assembly**. Leer el
  `README.md` del plugin antes de numerar una nueva.
- Al cambiar algo, actualizar el `CHANGES.md` de la carpeta y, si cambia un procedimiento, el doc
  de `docs/HANDOFF/` o del módulo **en el mismo commit**.
- Commits en español, sin líneas de atribución de IA (`Co-Authored-By: Claude …`).
- No hay CI/CD: deploy manual (ver runbook).

## Trampas conocidas (leer antes de diagnosticar)

1. **Copiar `.cs` a `RockWeb\App_Code` en caliente tumba prod.** Compila en runtime, todo-o-nada.
   El 2026-07-29 solo volvió deteniendo y arrancando el servidor completo. Siempre con
   `app_offline.htm` + ventana + reinicio completo. `customErrors="On"` oculta el error real: verlo
   desde `http://localhost/` en el servidor o en el Visor de eventos.
2. **No parchear `RockContext.cs` por el error `AIAgentSessionAnchor`** del log de arranque. Es
   inofensivo (las entidades custom del core implementan `IRockEntity`). Se probó un fix y se
   revirtió a propósito para mantener el core igual a upstream.
3. **Lava parsea dentro de comentarios HTML.** Un `{% if %}` de ejemplo dentro de `<!-- -->`
   revienta la plantilla; `{{ }}` se evalúa y se cuela. Documentar plantillas en un `.md` aparte;
   si hace falta mostrar sintaxis, `{% raw %}…{% endraw %}`.
4. **Traductor vs Vue.** El plugin Translator reemplaza nodos de texto: congela textos dinámicos de
   Vue ("Procesando…" pegado) y "corrige" español (Reportería→Reportes). Todo texto dinámico va en
   `<span class="notranslate">` (también respeta `[data-no-translate]`).
5. **El atributo `Active` de una acción de workflow es inerte.** El motor nunca lo evalúa. Para
   desactivar una acción: quitarla o ponerle un Criteria que nunca se cumpla.
6. **`CreateShortLink` sin `siteId` elige mal el sitio** (ordena ascendente por
   `EnabledForShortening` y puede generar `http://localhost/<token>`). Pasar siempre `siteId`; para
   reusar fila, token determinista + `overwrite:true`. Relacionado: `PageShortLinkService.GetByToken`
   puede devolver el short link de **otro** sitio; validar unicidad con `VerifyUniqueToken`. Un
   sitio de dominio corto necesita `EnableExclusiveRoutes = true`.
7. **`Site.DefaultDomainUri` es el primer `SiteDomain` por `Order`.** En el sitio «Rock RMS» es
   `localhost`. Lo que el módulo QR imprime depende de esto.
8. **DLLs del fork van juntas** (`Rock`, `Rock.Blocks`, `Rock.ViewModels`, `Rock.Rest` del mismo
   build) y **DLL + bundle del mismo bloque van juntos**. Desparejar = `TypeLoadException` o fallos
   silenciosos.
9. **`npm run build` puede salir con 0 aunque un tsconfig falle.** Verificar fecha/tamaño del
   `.obs.js` generado.
10. **Copiar una DLL a `RockWeb\Bin` reinicia el sitio**; la primera carga tarda 2+ min.
11. **Bytes nulos:** un archivo "vacío" con tamaño normal es corrupción por apagón (incidente
    `RockWeb\Plugins` 2026-08-05). Verificar después de copiar de discos externos.
    `check-prereqs.ps1` lo detecta.
12. **`BranchCleanup.bat` (upstream) borra `RockWeb\Bin\*.dll`**, incluidas DLLs de terceros que
    ningún build regenera.
13. **La ruta `RockMessage` (workflows) descarta errores de envío en silencio** (WhatsApp/SMS). Ver
    `Rock.WhatsApp/CHANGES.md`.
14. **Una BD de dev copiada de prod manda mensajes reales** si no se aíslan transportes, gateways y
    jobs (ver `SETUP_DESARROLLO.md` §4).

## Verificar regresiones (obligatorio antes de decir "listo")

Compilar sin errores no alcanza. Releer el diff propio completo buscando específicamente:

- `catch`/`finally` eliminados al reescribir un `try`.
- Flags de carga (`busy`, `polling`, …) que puedan quedar colgados y qué botones deshabilitan.
- El mismo patrón en archivos hermanos que no se tocaron (arreglar uno y no el otro).
- Peores casos de tiempo comparados contra el valor anterior (reintentos × timeout).
- Cadenas `v-if`/`v-else` rotas al insertar elementos.
- Timers/listeners agregados sin limpieza en `onBeforeUnmount`.

Reportar sin adornos las regresiones encontradas, incluidas las propias.

## Pruebas visuales (opcional)

Selenium contra dev: Chrome dedicado con `--remote-debugging-port=9222 --user-data-dir=<carpeta temporal>`,
el humano inicia sesión en esa ventana (nunca pedir contraseñas), el script se conecta con
`debugger_address = "127.0.0.1:9222"`; capturas por CDP (`Emulation.setDeviceMetricsOverride` +
`Page.captureScreenshot` con `captureBeyondViewport`). Ocultar `.cms-admin-footer` (intercepta
clics). Los selects de Obsidian son Ant Select (`.ant-select-selector` → `.ant-select-item-option`).

## Actualizar Rock

**Actualizar Rock a otra versión:** no se hace sobre este repo. Procedimiento recomendado por
Rodolfo: bajar una copia de la BD de prod, clonar Rock limpio en otra carpeta, subir la BD de
versión mayor en versión mayor (`18.7.0 → 19.1.8 → 19.7.0`, parando en la primera estable de
cada mayor) con Rock sin modificar (migraciones y jobs post-actualización en
cada salto) y solo al final meter el desarrollo propio, idealmente movido a plugins. Detalle en
`docs/HANDOFF/CAMBIOS_VS_UPSTREAM.md` § «Cómo actualizar a una nueva versión de Rock».

## Lo que nunca va al repo

Contraseñas, connection strings, API keys, certificados (`.p12`), respaldos de BD, datos de
miembros. Se obtienen de TI o de `ACCESOS_Y_SECRETOS.md` del paquete zip de handoff.
