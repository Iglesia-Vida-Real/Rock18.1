# Estado del repositorio al 2026-10-15

> Foto tomada el día del traspaso. Se generó con comandos de solo lectura (`git status`,
> `git log`, `git for-each-ref`) en `C:\repos\Rock15.5` del dev saliente. **No se ejecutó ninguna
> limpieza**; las recomendaciones de §6 quedan para el dev entrante.

---

## 1. Remotos

| Remoto | URL | Para qué |
|---|---|---|
| `origin` | `https://github.com/Iglesia-Vida-Real/Rock18.1.git` | **El fork de Vida Real.** Privado. Aquí se hace push. Organización `Iglesia-Vida-Real` (transferido desde `rodobriones/Rock15.5` el 2026-10-21; la URL vieja redirige). Rama por defecto: `hotfix-18.1`. |
| `upstream` | `https://github.com/SparkDevNetwork/Rock.git` | Rock oficial. Solo lectura, para comparar y traer hotfixes. |

---

## 2. Ramas: cuáles son nuestras

`origin` tiene ~314 ramas, pero **casi todas son copias heredadas de upstream** (se crearon al
hacer el fork: `feature-*`, `bugfix-*`, `hotfix-18.2`, `hotfix-18.3`, `release-*`, `master`,
`pre-alpha-release`, etc.). No tienen ningún commit de Vida Real.

Solo **dos** ramas contienen trabajo propio (57 commits de `rodobriones` en total):

| Rama | Base | Commits propios | Último commit | Estado |
|---|---|---|---|---|
| **`hotfix-18.1`** | Rock **18.1** oficial (`upstream/hotfix-18.1` @ `f8e5bcf161`, 2025-12-08) | 44 (2026-02-10 → 2026-10-15) | `36fa46789a` «Paquete de traspaso» (2026-10-15) | **Rama viva. Es la que corre en producción. Trabajar aquí.** |
| `hotfix-1.15.5` | Rock 15.5 | 14 (2026-01-19 → 2026-02-21) | `4e2b65b1e2` «Workflow y Donation entry» | Histórica. Lo que servía se portó a 18.1 (ver `*_Migration_Context.md` en la raíz). No se usa. |

Otras referencias:

- `develop` (local y `origin/develop`): espejo **viejo** del `develop` de upstream (2026-01-16).
  No tiene nada nuestro. Aunque GitHub la muestre como rama por defecto, **no trabajar en
  `develop`** ni abrir PRs contra ella.
- `upstream/hotfix-18.1` no tiene commits nuevos desde la base (`f8e5bcf161`): no hay hotfixes de
  Rock 18.1 pendientes de traer (al último fetch, 2026-10-15).

---

## 3. Commits sin push

```text
git log origin/hotfix-18.1..hotfix-18.1   -> (vacío)
git log origin/develop..develop           -> (vacío)
git stash list                            -> (vacío)
```

Todo lo commiteado está en `origin`. (Los 3 commits de la restauración de `RockWeb\Plugins` del
2026-08-05 —`1e1efd641f`, `0c380daec6`, `42886af837`— ya están pusheados.)

---

## 4. Cambios sin commitear

**Ninguno.** Working tree limpio al 2026-10-15. El commit `36fa46789a` («Paquete de traspaso»,
pusheado a `origin/hotfix-18.1`) incluyó:

### 4.1 Código del módulo QR (en producción)

| Archivo | Cambio |
|---|---|
| `Rock.Blocks/Qr/QrMetrics.cs` | Filtro por código en «Uso» + tabla «Todos los códigos» |
| `Rock.ViewModels/Blocks/Qr/QrMetrics/QrMetricsBags.cs` | Bags nuevos para lo anterior |
| `Rock.JavaScript.Obsidian.Blocks/src/Qr/qrMetrics.obs` | UI del filtro y la tabla (+373 líneas) |
| `Rock.JavaScript.Obsidian.Blocks/src/Qr/QrMetrics/types.partial.ts` | Tipos |
| `Rock.JavaScript.Obsidian.Blocks/src/Qr/qrCodeList.obs` | Enlace «ver métricas» desde el catálogo |

Total: 5 archivos, +480/−41. Es lo que corre en producción (confirmado por Rodolfo, 2026-10-15), así
que un checkout limpio de `hotfix-18.1` reproduce prod. Detalle en `docs/qr-custom/DEPLOY.md` §G.

### 4.2 Documentación y scripts (paquete de traspaso)

`CLAUDE.md`, `ONBOARDING.md` reescrito, `docs/HANDOFF/`, `Dev Tools/Build/` y la actualización de
~57 `.md` de módulos y plugins. Además `.claude/settings.local.json` dejó de versionarse.

### 4.3 Artefactos locales que no están en git (y está bien)

`RockWeb\Bin\*.dll`, `RockWeb\Obsidian\`, `RockWeb\web.ConnectionStrings.config`,
`node_modules`, `bin/obj`, `PrecompiledWeb\` (artefacto viejo; prod **no** es precompilado),
`Dev Tools\Deploy\**\*.dll|*.js` (kits de deploy locales).

---

## 5. Qué rama usar para trabajar

```powershell
git switch hotfix-18.1
git pull
git switch -c feature/<tema>      # recomendado: ramas cortas y merge a hotfix-18.1
```

- Producción se compila desde `hotfix-18.1`.
- No se hace merge hacia upstream (es un fork privado).
- Para traer un hotfix oficial de Rock: `git fetch upstream` y `git merge upstream/hotfix-18.1`
  (o el tag de la versión), resolviendo conflictos en los archivos core que tocamos (lista en
  `CHANGES.md` raíz). Ojo con los parches core documentados: `AddressControl` /
  `ControlsController` (direcciones GT), `Sms.ProcessResponse` + `SmsActionConversations`
  (WhatsApp), `Login.cs`, etc.
- Commits en español. Sin líneas de atribución de IA (`Co-Authored-By: Claude …`).

---

## 6. Recomendaciones de limpieza (NO ejecutadas, salvo §6.1)

### 6.1 Propiedad del repositorio — prioridad alta

- **Hecho 2026-10-21:** el repo se transfirió a la organización `Iglesia-Vida-Real` como
  `Rock18.1` y la rama por defecto ya es `hotfix-18.1`. En clones viejos:
  `git remote set-url origin https://github.com/Iglesia-Vida-Real/Rock18.1.git`.

### 6.2 Secretos

- **La historia de `hotfix-1.15.5` contiene una contraseña de SQL** en
  `RockWeb/web.ConnectionStrings.config.example` (commit `fee32c3bb3`, 2026-01-22, usuario
  `RockUser` de una BD local `Rock155`). No está en `hotfix-18.1`. Acción: confirmar con TI si esa
  credencial existe en algún servidor y **rotarla**; si se decide limpiar la historia, hacerlo con
  `git filter-repo` coordinado (reescribe hashes) o simplemente borrar la rama `hotfix-1.15.5` del
  remoto si ya no se necesita.
- **Resuelto 2026-10-15:** `.claude/settings.local.json` y `Rock.Blocks/.claude/settings.local.json`
  dejaron de versionarse (`**/.claude/settings.local.json` en `.gitignore`) y se quitaron las
  rutas personales de `.claude/settings.json`. Las versiones anteriores siguen en la historia de git
  (solo rutas, sin credenciales).

### 6.3 Ramas

- Borrar del remoto las ~312 ramas heredadas de upstream (no aportan y confunden). Se pueden
  recuperar de `upstream` en cualquier momento. Mantener: `hotfix-18.1`, y `hotfix-1.15.5` solo si
  se quiere conservar como archivo (o crear un tag `archivo/rock-15.5` y borrar la rama).
- Borrar la rama local `develop` o dejarla siguiendo `upstream/develop` en vez de `origin/develop`.

### 6.4 Raíz del repo

Hay varios `.md` de contexto de sesiones en la raíz (`AI_HANDOFF_ROCK18_EVENT_CRM.md`,
`QREVENT_*_Migration_Context.md`, `Migration_Context_ReservationScanner_FamilyHub.md`,
`FamilyHub_KnownRelationship_Fix_Context.md`, `EPAY_FLOW_SUMMARY.md`). Están indexados en
`.claude/CONTEXT_INDEX.md`; moverlos a `docs/historico/` sería más ordenado, actualizando el índice
en el mismo commit.

### 6.5 Trampa: `BranchCleanup.bat`

Es de upstream y **borra `RockWeb\Bin\*.dll`**, incluidas las DLLs de terceros del Rock Shop que
ningún build regenera. No correrlo sin antes respaldar esas DLLs (lista en `ONBOARDING.md` §2).

### 6.6 `.gitignore`

Aplicado 2026-10-15: `**/.claude/settings.local.json`.
Lo demás que es local (`RockWeb/web.ConnectionStrings.config`, `RockWeb/Obsidian/`, `RockWeb/Bin/*.dll`,
`PrecompiledWeb/`, `TestResults/`, binarios de `Dev Tools/Deploy/`) ya está ignorado.
