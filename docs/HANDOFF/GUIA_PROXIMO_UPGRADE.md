# Guía para el próximo upgrade de Rock — lo aprendido en 18.1 → 19.8.1

Escrita el 2026-11-25, con la fase A de producción completa y el upgrade a 19.8.1 listo para su ventana.
Responsable del upgrade 19.8.1: **Fredy Ramirez**. Para el detalle de cada paso de este upgrade:
[`UPGRADE_19.8.1.md`](UPGRADE_19.8.1.md) (runbook), [`PLAN_PRUEBAS_19.8.1.md`](PLAN_PRUEBAS_19.8.1.md) y
[`upgrade-19.8.1/CHECKLIST_PRODUCCION_19.8.1.md`](upgrade-19.8.1/CHECKLIST_PRODUCCION_19.8.1.md) (el día de prod).

Este documento resume **cómo se hizo, qué sirvió, qué falló y qué hacer distinto** la próxima vez (20.x u otra). El
procedimiento «ideal» de largo plazo (Rock limpio + mover lo propio a plugins) sigue en
[`CAMBIOS_VS_UPSTREAM.md`](CAMBIOS_VS_UPSTREAM.md) § «Cómo actualizar a una nueva versión de Rock».

---

## 1. Cómo se hizo el 19.8.1 (en orden, con tiempos reales)

| Fase | Qué | Dónde | Cuándo |
|---|---|---|---|
| 1. BD de prueba | Copia de la BD de prod (`.bacpac`) restaurada en local (`Rock19Test`, `Rock18Base`) y **aislada** (transportes, gateways en modo prueba, jobs: `Dev Tools/Sql/Aislar_BD_Dev.sql`) | PC de desarrollo | 19-nov |
| 2. Merge | Rama `Test_Update_18.1_a_19.8.1` = `hotfix-18.1` + tag upstream `19.8.1` (merge de 3 vías; conflictos resueltos archivo por archivo) | repo | 19-nov |
| 3. Build y arranque | `build-all.ps1 -FullObsidian`; Rock corre las migraciones solo al arrancar (~2 min) | local, sitio 6229 | 19-nov |
| 4. Pruebas | `PLAN_PRUEBAS_19.8.1.md` C1–C20 comparando 18.1 (sitio 6230) y 19 (6229) lado a lado; jobs post-actualización ensayados; pagos con gateway de prueba | local | 19 al 24-nov |
| 5. Kit | `New-KitUpgrade.ps1`: copia lo que va a prod + manifiesto SHA256 + lista de retiro + `herramientas\` | fuera del repo | 23-nov |
| 6. Fase A en prod | Diagnóstico, inventario, muestras, preflight de BD, `web.config` fusionado, ensayo de respaldo — **todo sin cortar el servicio** | servidor web de prod | 24 y 25-nov |
| 7. Ventana | Respaldo BD + RockWeb, retirar lo que la 19 quitó, copiar kit, `web.config`, arrancar, jobs, verificación | prod | pendiente de fecha (~2 h + 45 min) |

Lo que más tiempo ahorró: **probar 18.1 y 19 lado a lado** con la misma copia de BD (cada diferencia es de la 19, no
de los datos) y hacer **todo el análisis de prod antes de la ventana**, con el sitio arriba.

---

## 2. Datos fijos del ambiente de producción (sin secretos)

Comprobados el 2026-11-24/25. Verificarlos de nuevo con `Get-DiagnosticoServidor.ps1` antes de cada upgrade.

| Tema | Valor |
|---|---|
| Servidor web | VM de Azure, Windows Server 2022 Datacenter, IIS 10, .NET 4.8, PowerShell 5.1, zona horaria Central America |
| Sitio de IIS | **Un solo sitio, `Default Web Site`**, pool **`DefaultAppPool`** (CLR v4.0, Integrated, identidad LocalSystem, AlwaysRunning), bindings comodín `*:80` / `*:443` (+ `q.vidareal.tv` en 443). El nombre del sitio **no** contiene «personas» |
| RockWeb de prod | **`C:\inetpub\wwwroot`** (junto hay una `wwwroot_15` vieja: no tocar) |
| Discos del servidor web | `C:` (255 GB) y **«Temporary Storage» `D:`: disco temporal de Azure, SE BORRA** al reiniciar por mantenimiento o mover la VM. Nunca poner kit ni respaldos ahí |
| Servidor SQL | Otra VM de Azure, SQL Server 2022 Standard, BD `Rock18`, compatibilidad 160, recuperación SIMPLE. Archivos en `…\MSSQL16.MSSQLSERVER\MSSQL\DATA`, respaldos por defecto en `…\MSSQL\Backup` |
| Respaldos automáticos | Un respaldo completo diario a las **~12:39** (dispositivo con nombre GUID: servicio externo, probablemente Azure Backup). Restaurarlo requiere acceso a Azure |
| Accesos que **sí** hay | Escritorio remoto al servidor web (cuenta de administrador local) |
| Accesos que **no** se transfirieron (2026-11-25) | Escritorio remoto a la VM SQL, login sysadmin de SQL, suscripción de Azure (`ACCESOS_Y_SECRETOS.md` §2 del paquete de handoff) |
| Cuenta SQL del sitio | Dueña (dbo) de `Rock18`, `db_owner`, **sin** sysadmin/dbcreator/VIEW SERVER STATE. Alcanza para respaldar y restaurar `Rock18` |
| `web.config` de prod | Propio de prod y **distinto** de la plantilla del repo en: llaves (`PasswordKey`, `DataEncryptionKey`, `machineKey`), `RunJobsInIISContext=True`, `customErrors=On`, `compilation debug=true`, **`<globalization culture="es-GT" uiCulture="es">`** y **límites de subida de 500 MB** (`maxRequestLength=512000`, `maxAllowedContentLength=524288000`) |
| Uso | Hay check-ins **también entre semana** (119 abiertos un miércoles a las 9 h): la ventana se elige con quien conoce los horarios |

---

## 3. Herramientas reutilizables (`Dev Tools/Upgrade/`)

Ver la tabla completa en [`Dev Tools/Upgrade/README.md`](../../Dev%20Tools/Upgrade/README.md). Las que se usan en prod
van dentro del kit, en `herramientas\`.

| Herramienta | Para qué | Qué cambiar para la próxima versión |
|---|---|---|
| `Get-DiagnosticoServidor.ps1` | Diagnóstico de solo lectura del servidor web (IIS, .NET, DLLs, hashes de llaves, discos, inventario) | Nada; revisar la lista de DLLs del fork si cambian los plugins |
| `Get-RockWebInventario.ps1` + `Compare-RockWebInventario.ps1` | Qué archivos de prod difieren del repo | Referencia = worktree de la rama que está en prod (`git worktree add ..\Rock-ref-prod hotfix-…`) |
| `Get-MuestrasProd.ps1` | Trae de prod (solo lectura) lo que el inventario marcó, para probarlo en local | Actualizar la lista con lo que salga en el inventario nuevo |
| `New-WebConfigFusionado.ps1` | `web.config` de la versión nueva = plantilla del repo + llaves y ajustes propios de prod; falla si las llaves no quedan idénticas | Nada; pasarle la plantilla vieja con `-WebConfig181` para que aplique lo propio de prod |
| `Invoke-SqlDesdeWeb.ps1` | Corre un `.sql` contra la BD **desde el servidor web** con la conexión del sitio, sin mostrarla | Nada |
| `19.8.1_preflight_bd_prod.sql` | 14 revisiones de la BD de prod (versión SQL, migraciones = copia probada, cifrados V2, bloques sobre `.ascx` retirados, permisos de respaldo/restauración…) | **Copiar con el nombre nuevo** y actualizar los valores esperados: última migración del core, filas de `PluginMigration` por plugin, lista de `.ascx` retirados (de la nueva `quitar_del_servidor.txt`) y sus conteos |
| `19.8.1_respaldo_bd.sql`, `19.8.1_reversa_restaurar_bd.sql`, `19.8.1_linea_base.sql` | Respaldo COPY_ONLY verificado, reversa y línea base, vía `Invoke-SqlDesdeWeb.ps1` | Nombre del `.bak` y, en la reversa, la última migración esperada de la versión vieja |
| `New-KitUpgrade.ps1` | Arma el kit y su manifiesto | `-Base` = la rama de prod; regenerar `quitar_del_servidor.txt` (punto de partida: `git diff --diff-filter=D --name-only <base> <tag> -- RockWeb`, más DLLs y bundles que el build nuevo ya no produce; ver `UPGRADE_19.8.1.md` §7) |

---

## 4. Lecciones y trampas (qué pasó y cómo evitarlo)

### Del servidor
1. **El disco `D:` de una VM de Azure es temporal.** El plan original ponía kit y respaldos en `D:`. Siempre en `C:`.
2. **El sitio de IIS se llama `Default Web Site`**, no «personas». Los scripts que buscan el sitio por nombre fallan;
   el diagnóstico ahora toma el único sitio que haya.
3. **Prod tiene cosas que nunca estuvieron en git** y que la prueba local no tuvo: código en `App_Code`
   (`GetMinePass.cs`, `GetMinistryPass.cs`, y un `WhatsAppSms.ashx.cs` más viejo que el del repo), DLLs del Rock
   Shop **más nuevas** que las de dev, y 11 DLLs viejas de instalaciones anteriores (`Rock.MyWell`,
   `Rock.Lava.DotLiquid`, `Rock.Tests.Shared`…). `App_Code` se compila todo junto: si un archivo no compila con la
   versión nueva **se cae el sitio entero**. Por eso existe `Get-MuestrasProd.ps1`: traerlas y arrancar la versión
   nueva local **con todo lo de prod junto** antes de la ventana.
4. **Las DLLs del fork en prod eran de builds distintos** (fechas distintas; trampa 8 de `CLAUDE.md`). El kit las
   reemplaza todas juntas; no desplegar DLLs sueltas.
5. **El `web.config` de prod tenía ajustes que el repo no** (idioma es-GT, límites de subida). La primera versión del
   fusionado los perdía; se vio solo porque se leyó la lista «solo en prod». Leer siempre esa salida, no solo el «OK».
6. **No hay acceso a la VM SQL**: el preflight, el respaldo y la reversa se hacen desde el servidor web con la cuenta
   del sitio (`Invoke-SqlDesdeWeb.ps1`). Antes de confiar en eso: el bloque 14 del preflight dice si alcanza el
   permiso, y se **probó en local** con una cuenta de permisos idénticos (`CREATE LOGIN` + `ALTER AUTHORIZATION ON
   DATABASE` + `EXECUTE AS LOGIN`): respaldo, cambio, restauración y vuelta al estado anterior.
7. **El ensayo del respaldo en prod** (días antes, con el sitio arriba) resolvió lo que el preflight no podía ver
   (espacio en el disco SQL) y dio el tiempo real (52 s, 1.8 GB comprimido para 7.9 GB). Con `INIT, FORMAT` el de la
   ventana reemplaza al del ensayo.
8. **La reversa no se puede ensayar en prod** sin sobrescribirla. Mitigación: probarla en local con los mismos
   permisos y conseguir el acceso a Azure/SQL como segunda vía.

### De los datos
9. **Inventarios: casi todo el «distinto» son saltos de línea** (LF en prod, CRLF en el checkout). Normalizar antes de
   juzgar; de 124 «distintos» solo 27 tenían contenido distinto, y los que el kit pisaba eran idénticos a git.
10. **Bloques sobre `.ascx` que la versión nueva retira** (204 en 88 tipos, 69 de `PageMenu`): las migraciones y los
    jobs «Replace WebForms Blocks» los cambian solos; en local quedaron 0. Contarlos antes y después; los que no tienen
    reemplazo (páginas 327 y 740) necesitan un job propio (`19.8.1_job_reemplazo_bloques_huerfanos.sql`).
11. **Cifrado V2 de la 19**: un valor viejo que termine en `0x5632` se leería vacío. Revisarlo (bloque 12) en cada
    versión que cambie `Encryption.cs`.
12. **Los secretos de prod no se descifran en dev** (llaves distintas): los pagos reales (Dar/Cybersource, ePay) solo
    se prueban en prod. Se dejó una donación de Q1 como verificación del día.

### De PowerShell 5.1 y git (tiempo perdido)
13. `$PSScriptRoot` llega **vacío** en los valores por defecto de `param()` con `-File`: resolverlo en el cuerpo.
14. Scripts con acentos: **UTF-8 con BOM**, o PowerShell 5.1 los lee mal.
15. `H` es alias de `Get-History`: no nombrar funciones con alias existentes.
16. Mensajes de commit: escribirlos a un archivo y `git commit -F`; `Set-Content -Encoding UTF8` mete un BOM que
    termina en el asunto del commit.
17. En T-SQL, `RAISERROR` no acepta funciones como argumento (`DB_NAME()`): usar una variable. Lo encontró la prueba
    local de la reversa: **por eso se prueba todo script que vaya a prod**.
18. Si el código cambia después de armar el kit, hay que rearmarlo. Comprobar con
    `git diff --name-only <commit del kit> HEAD` que solo cambiaron documentos y herramientas.

### De la forma de trabajar
19. En prod **ejecuta una persona** (Fredy) y Claude revisa: capturas y `.txt` de salida. Nunca se pasan contraseñas,
    llaves ni el `web.config` fusionado (es secreto y no sale del servidor). Las salidas con nombres o rutas de
    servidores se quedan **fuera del repo** (es público).
20. Un paso a la vez, explicando qué hace y para qué, y verificando antes de seguir (barra de direcciones: ¿servidor o
    PC? `Windows (C:)` = servidor, `C on DESKTOP-…` / `\\tsclient\C` = PC).
21. Cualquier rojo se manda en captura antes de reintentar: un script que falla al inicio no alcanzó a hacer nada.

---

## 5. Checklist corta para el próximo upgrade

1. Pedir **antes de empezar** los accesos que faltan (VM SQL, Azure) — ver §2.
2. Copia de la BD de prod a local, **aislada**; tag `vidareal-prod-<fecha>` del estado de prod.
3. Rama de prueba con la versión nueva (merge o Rock limpio, según `CAMBIOS_VS_UPSTREAM.md`); build; arranque.
4. Plan de pruebas lado a lado (copiar `PLAN_PRUEBAS_19.8.1.md` como base), incluido el check-in real.
5. Kit con `New-KitUpgrade.ps1` y lista de retiro regenerada.
6. Fase A en prod: diagnóstico + inventario → muestras probadas en local → preflight actualizado → `web.config`
   fusionado → ensayo de respaldo → ir / no ir.
7. Ventana con la checklist (copiar `CHECKLIST_PRODUCCION_19.8.1.md` y actualizar nombres y valores esperados).
8. Al terminar: registrar resultado en el runbook y `ESTADO_REPO.md`; unir la rama del upgrade a la de prod en un paso
   aparte y aprobado.

---

## 6. Pendientes que conviene resolver antes del próximo upgrade

- **Accesos no transferidos**: VM SQL, login sysadmin, Azure (sin ellos no se pueden usar los respaldos automáticos).
- **Mover el código propio del core a plugins** (recomendación de `CAMBIOS_VS_UPSTREAM.md`): cada upgrade sería mucho
  más corto.
- **`App_Code\WhatsAppSms.ashx.cs`**: prod tiene una versión anterior a la del repo (sin la atribución del remitente
  por wamid). Decidir si se despliega la del repo, en una ventana propia.
- **Archivos solo de prod**: `Blocks\QREVENT\TestCybersource.ascx` (bloque de prueba de pagos), plugins Apollos y
  `Asistencia`, DLLs viejas en `Bin`: decidir si se retiran.
- **Higiene del servidor web**: hay software y archivos personales que no tienen que ver con Rock en el escritorio del
  administrador; revisarlos con TI.
- Versiones de los plugins del Rock Shop compatibles con la siguiente versión de Rock.
