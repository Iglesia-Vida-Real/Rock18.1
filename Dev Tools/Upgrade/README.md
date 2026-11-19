# Dev Tools/Upgrade — herramientas del upgrade de Rock

Creado para el upgrade 18.1 → 19.8.1 (2026-11-19). Contexto: `docs/HANDOFF/UPGRADE_19.8.1.md`.

| Archivo | Dónde se corre | Qué hace | ¿Modifica algo? |
|---|---|---|---|
| `Get-RockWebInventario.ps1` | Servidor de prod (y dev, para la referencia con `-SinValidarBin`) | CSV de `RockWeb` con ruta, tamaño, fecha y SHA256. `Content`, `App_Data` y `Cache` solo se cuentan. No lee `web.config` ni connection strings. Se niega a escribir dentro de `RockWeb` | No (solo lectura) |
| `Compare-RockWebInventario.ps1` | Máquina de desarrollo | Compara el CSV del servidor contra el de la referencia (`hotfix-18.1`) y clasifica `DISTINTO` / `SOLO_SERVIDOR` / `SOLO_REFERENCIA` | No (solo lee los CSV) |
| `Test-TiposRock.ps1` | Dev o prod, contra un `RockWeb` compilado | Verifica que cada BlockType/EntityType de la BD resuelve: `.ascx` en disco o tipo cargable desde `Bin` | No (solo lectura; carga DLLs en un proceso propio) |
| `19.8.1_job_reemplazo_bloques_huerfanos.sql` | BD ya migrada a 19.x | **Propuesta, no aplicada.** Crea un job de reemplazo WebForms → Obsidian para las páginas «System Phone Numbers» y «Experience Administration» (UPGRADE §11.4) | Sí: crea un `ServiceJob` (no lo corre) |

Uso detallado: UPGRADE §13 (comparación) e `INVENTARIO_DESARROLLOS_VR.md` §5 (verificación de tipos).
