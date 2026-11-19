# Guía para colaboradores — cómo funciona este repo

> Para quien llega nuevo al proyecto. Explica en lenguaje simple cómo está armado el fork de Rock de
> Iglesia Vida Real, cómo llega un cambio a producción y dónde vive cada módulo. Los detalles
> técnicos están en los documentos enlazados; aquí solo está el mapa.
>
> Primera versión: 2026-10-26. Para montar el ambiente local ver `SETUP_DESARROLLO.md`.

---

## 1. Qué es este repositorio

- Es un **fork** de Rock RMS oficial (`SparkDevNetwork/Rock`), versión **18.1**, con módulos
  propios de Vida Real (eventos, QR, reservas dominicales, donaciones, Wallet, etc.).
- **Rama principal: `hotfix-18.1`.** Es lo que corre en producción.
- El repo tiene ~314 ramas, pero **casi todas son copias heredadas de Rock oficial** que llegaron
  al crear el fork (`feature-*`, `hotfix-*`, `bugfix-*`, `release-*`…). No tienen trabajo de Vida
  Real. Detalle en `ESTADO_REPO.md` §2.
- En GitHub **no usar los botones "Sync fork" ni "Contribute"**: comparan contra Rock oficial y
  meterían miles de commits ajenos o abrirían un PR hacia el proyecto público de Rock.
- Al crear un Pull Request, verificar siempre que la base sea **`hotfix-18.1` de
  `Iglesia-Vida-Real/Rock18.1`** (en un fork, GitHub a veces propone el repo de Rock oficial).

## 2. Cómo llega un cambio a producción

```text
GitHub (código fuente)
   │  clonar / rama de trabajo
   ▼
Máquina de desarrollo:  Rock.sln ──compilar──► RockWeb\Bin\*.dll  +  RockWeb\Obsidian\...\*.obs.js
   │                                           (el resultado cae DENTRO de RockWeb)
   │  copia manual de SOLO los archivos que cambiaron ("kit")
   ▼
Servidor web de producción:  carpeta RockWeb  ◄── IIS la sirve
                                   │
                                   ▼
                       BD Rock18 (servidor SQL aparte)
```

- **`Rock.sln` se usa solo para compilar**, en la máquina de desarrollo. Agrupa todos los
  proyectos (Rock, Rock.Blocks, Rock.Rest, Rock.ViewModels…).
- **`RockWeb` es el sitio web.** Es la única carpeta que existe en el servidor. Todo lo demás del
  repo es código fuente que termina compilado dentro de `RockWeb`.
- **El servidor no está conectado a GitHub.** No hay CI/CD: los cambios se copian a mano. Por eso
  **GitHub es el único registro de qué hay en producción** y la regla es *desplegar siempre desde
  un commit*. Procedimiento completo: `DEPLOY_PRODUCCION.md`.

### Nunca copiar la carpeta `RockWeb` completa a producción

| Archivo local | Qué rompería en producción |
|---|---|
| `web.ConnectionStrings.config` | Apunta a la BD local: el sitio pierde la base de datos. |
| `web.config` | Llaves de cifrado distintas: nadie puede iniciar sesión y se pierden credenciales cifradas. |
| DLLs de terceros (Rock Shop) | Pueden ser versiones más viejas que las de prod. |
| `App_Code\*.cs` | Copiarlo con el sitio arriba lo tumba (pasó el 2026-07-29). Requiere ventana y reinicio completo. |
| `Content\` | Archivos que suben los usuarios en prod; no se tocan. |

## 3. Anatomía de un bloque

En Rock cada página se arma con **bloques** (una lista, un formulario, un tablero). El
administrador los agrega desde *Admin* a cualquier página. Casi todo el trabajo de Vida Real son
bloques nuevos tipo **Obsidian** (C# en el servidor + Vue en el navegador).

Un bloque se reparte en varias carpetas. Ejemplo real: **QR Metrics**.

| Pieza | Carpeta / archivo | Qué hace | Se compila en |
|---|---|---|---|
| Datos | `Rock/Model/Qr/QrCode.cs` | Define la tabla y sus servicios. | `Rock.dll` |
| Contrato ("bags") | `Rock.ViewModels/Blocks/Qr/QrMetrics/` | Formato de los datos entre servidor y navegador. | `Rock.ViewModels.dll` |
| Servidor | `Rock.Blocks/Qr/QrMetrics.cs` | Consulta la BD y responde. | `Rock.Blocks.dll` |
| Pantalla | `Rock.JavaScript.Obsidian.Blocks/src/Qr/qrMetrics.obs` | Lo que ve el usuario (Vue 3). | `RockWeb/Obsidian/Blocks/Qr/qrMetrics.obs.js` |
| Tablas / migraciones | `Plugin.VidaRealQr` | Crea las tablas al arrancar el sitio. | `com.vidareal.Qr.dll` |

Dentro de `QrMetrics.cs`:

- `[DisplayName("QR Metrics")]` y `[Category("Vida Real > QR")]`: cómo lo encuentra el
  administrador al agregarlo a una página.
- `GetObsidianBlockInitialization()`: los datos que se envían al abrir la página.
- `[BlockAction] Refresh(...)`: una acción que la pantalla le pide al servidor (como una mini API).
  La seguridad se valida aquí, en el servidor (`CurrentPerson`), nunca solo en la pantalla.

Flujo: el usuario abre la página → Rock ejecuta `QrMetrics.cs` → arma los datos en el bag → el
navegador carga `qrMetrics.obs.js` y dibuja → al cambiar un filtro, la pantalla llama a
`Refresh()` → el servidor responde con datos nuevos.

## 4. Dónde vive cada módulo de Vida Real

| Módulo | Datos (`Rock/Model/`) | Servidor (`Rock.Blocks/`) | Pantalla (`…Obsidian.Blocks/src/`) | Otros | Leer primero |
|---|---|---|---|---|---|
| Eventos / Boletería | `Eventos/` | `Eventos/` | `Eventos/` | `Plugin.VidaRealEvents`, `Plugin.OdooEventSale` (FEL) | `Rock/Model/Eventos/ARCHITECTURE.md`, `docs/eventos-custom/RESEARCH_Y_PLAN.md` |
| QR Generator | `Qr/` | `Qr/` | `Qr/` | `Plugin.VidaRealQr` | `Rock/Model/Qr/ARCHITECTURE.md`, `docs/qr-custom/DEPLOY.md` |
| Wallet (Apple/Google) | `Wallet/` | `Wallet/` | `Wallet/` | `Plugin.VidaRealWallet`, `Rock.Rest/VidaReal/` | `docs/wallet-module/RESEARCH_Y_PLAN.md` |
| QREVENT (reservas dominicales, check-in QR) | — | `QREVENT/` | `QREVENT/` | SPs en `Dev Tools/Sql/` | `Rock.Blocks/QREVENT/CHANGES.md`, `Dev Tools/Sql/CHANGES.md` |
| DAR (donaciones) | — | `Dar/` | `Dar/` | `Plugin.EpayVisanetGateway`, `Plugin.CybersourceInlineRestGateway` | `Rock.Blocks/Dar/CHANGES.md` |
| FamilyHub | — | `FamilyHub/` | `FamilyHub/` | — | `Rock.Blocks/FamilyHub/CHANGES.md` |
| LayoutCustom (encabezado/pie) | — | `LayoutCustom/` | `LayoutCustom/` | — | `Rock.Blocks/LayoutCustom/CHANGES.md` |
| WhatsApp | — | — | — | `Rock.WhatsApp/` (transporte SMS → WhatsApp) | `Rock.WhatsApp/CHANGES.md` |
| Traductor ES/EN | — | — | — | `Plugin.VidaRealTranslator`, `RockWeb/Plugins/com_vidareal/Translator/` | `Plugin.VidaRealTranslator/README.md` |

Las demás carpetas de `Rock.Blocks/` (`Administration`, `CheckIn`, `Cms`, `Finance`…) son de Rock
oficial. Si algún cambio de Vida Real toca archivos de Rock oficial, está anotado en `CHANGES.md`
(raíz) y en `CAMBIOS_VS_UPSTREAM.md`, que es el **inventario completo de lo que Vida Real ha
cambiado** respecto a Rock oficial.

## 5. Qué se despliega según lo que cambies

| Si cambias… | Se genera… | Se copia a producción… |
|---|---|---|
| Un `.cs` en `Rock/`, `Rock.Blocks/`, `Rock.ViewModels/` o `Rock.Rest/` | `Rock.dll`, `Rock.Blocks.dll`, `Rock.ViewModels.dll`, `Rock.Rest.dll` | `RockWeb\Bin\` — **los 4 juntos, del mismo build** |
| Un `.obs` | `*.obs.js` | `RockWeb\Obsidian\Blocks\<Módulo>\` |
| Servidor y pantalla del mismo bloque | Ambos | **DLL y bundle juntos**, o falla en silencio |
| Un plugin (`Plugin.*`) | `com.vidareal.*.dll`, etc. | `RockWeb\Bin\`; sus migraciones corren solas al arrancar |
| `RockWeb\App_Code\*.cs` | Nada (compila en el servidor) | Solo con ventana, `app_offline.htm` y **reinicio completo** |

Ojo: `Rock.Blocks.dll` y `Rock.dll` llevan **todos** los módulos. Si el árbol tiene cambios a
medias de otro módulo, viajan en el mismo DLL. Por eso se compila para prod solo desde un commit
limpio.

## 6. Forma de trabajo

1. Cada colaborador trabaja en **su propia rama**, creada desde `hotfix-18.1`.
2. Commits en español, pequeños y con mensaje claro. Nunca commitear `web.ConnectionStrings.config`,
   respaldos de BD, DLLs ni los `package-lock.json` que regenera el build local.
3. Antes de dar algo por terminado: compilar, probar en local y hacer la revisión de regresiones de
   `CLAUDE.md`.
4. Para pasar a `hotfix-18.1`: Pull Request revisado y aprobado. **Nada se sube directo a la rama
   principal.**
5. Para producción: seguir `DEPLOY_PRODUCCION.md` y el runbook del módulo, y registrar el deploy
   en el `CHANGES.md` del módulo.

## 7. Dónde seguir leyendo

| Necesito… | Documento |
|---|---|
| Montar el ambiente y compilar | `docs/HANDOFF/SETUP_DESARROLLO.md` |
| Desplegar a producción | `docs/HANDOFF/DEPLOY_PRODUCCION.md` |
| Ramas y estado del repo | `docs/HANDOFF/ESTADO_REPO.md` |
| Todo lo que Vida Real cambió frente a Rock oficial | `docs/HANDOFF/CAMBIOS_VS_UPSTREAM.md` |
| Convenciones y trampas conocidas | `CLAUDE.md` |
| Índice de documentación por módulo | `.claude/CONTEXT_INDEX.md` |
