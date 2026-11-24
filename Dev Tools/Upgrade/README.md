# Dev Tools/Upgrade — herramientas del upgrade de Rock

Creado para el upgrade 18.1 → 19.8.1 (2026-11-19). Contexto: `docs/HANDOFF/UPGRADE_19.8.1.md`.

| Archivo | Dónde se corre | Qué hace | ¿Modifica algo? |
|---|---|---|---|
| `Get-RockWebInventario.ps1` | Servidor de prod (y dev, para la referencia con `-SinValidarBin`) | CSV de `RockWeb` con ruta, tamaño, fecha y SHA256. `Content`, `App_Data` y `Cache` solo se cuentan. No lee `web.config` ni connection strings. Se niega a escribir dentro de `RockWeb` | No (solo lectura) |
| `Compare-RockWebInventario.ps1` | Máquina de desarrollo | Compara el CSV del servidor contra el de la referencia (`hotfix-18.1`) y clasifica `DISTINTO` / `SOLO_SERVIDOR` / `SOLO_REFERENCIA` | No (solo lee los CSV) |
| `Test-TiposRock.ps1` | Dev o prod, contra un `RockWeb` compilado | Verifica que cada BlockType/EntityType de la BD resuelve: `.ascx` en disco o tipo cargable desde `Bin` | No (solo lectura; carga DLLs en un proceso propio) |
| `19.8.1_preflight_bd_prod.sql` | SQL de prod, antes del upgrade (UPGRADE §7.1 paso 6b) | Revisa versión y nivel de compatibilidad de SQL, espacio, respaldos, migraciones del core y de plugins contra la copia probada, script de reservas. Cada bloque dice OK o REVISAR | No (solo lectura) |
| `Get-DiagnosticoServidor.ps1` | Servidor web de prod (fase A de la checklist) | Equipo, .NET, IIS/app pool, DLLs, valores no secretos del `web.config`, hash corto de las llaves, nombres de `appSettings`, BD (sin credenciales), discos, tema del kiosco, Visor de eventos; con `-ConInventario` corre también el inventario. `-SoloLlaves -WebConfig <archivo>` compara llaves sin mostrarlas | No (solo lectura; escribe en el Escritorio) |
| `Get-MuestrasProd.ps1` | Servidor web de prod (fase A, paso A1b) | Copia a un zip los archivos que el inventario marcó como distintos o propios de prod (código de App_Code, bloques, plugins, DLLs viejas), sin `web.config` ni secretos conocidos, para probarlos en la 19 local | No (solo lectura; escribe en el Escritorio) |
| `New-WebConfigFusionado.ps1` | Servidor web de prod (fase A, paso A4) | Genera el `web.config` de la 19: plantilla del repo + appSettings, machineKey, customErrors y debug de prod; `RunJobsInIISContext=False`; lista lo propio de prod que no se copia solo. Falla si las llaves no quedan idénticas a prod | Solo escribe el archivo nuevo (secreto) |
| `New-KitUpgrade.ps1` | Máquina de desarrollo, después del build completo y la prueba local | Arma el kit (UPGRADE §7.1 paso 7) fuera del repo, con `MANIFIESTO_SHA256.csv`. Se niega si el repo tiene cambios sin commitear o si el kit trae `web.config`, connection strings, `Content`, `Cache`, DLLs del Rock Shop o certificados | Solo escribe en la carpeta destino |
| `19.8.1_job_reemplazo_bloques_huerfanos.sql` | BD ya migrada a 19.x | **Propuesta, no aplicada.** Crea un job de reemplazo WebForms → Obsidian para las páginas «System Phone Numbers» y «Experience Administration» (UPGRADE §11.4) | Sí: crea un `ServiceJob` (no lo corre) |

Uso detallado: UPGRADE §13 (comparación) e `INVENTARIO_DESARROLLOS_VR.md` §5 (verificación de tipos).
