# Checklist de producción — upgrade Rock 18.1 → 19.8.1

**Responsable y aprobador:** Fredy Ramirez (desde el 2026-11-23 es el único responsable del sistema).
**Fecha objetivo:** 2026-11-24 (martes). **Rama:** `Test_Update_18.1_a_19.8.1`. **Kit:** `kit_19.8.1_2026-11-23\`
(fuera del repo; LEEME y MANIFIESTO_SHA256 dentro).

Este documento es el **orden de trabajo** del día. El detalle técnico de cada paso está en
[`../UPGRADE_19.8.1.md`](../UPGRADE_19.8.1.md) (runbook §7) y, para pagos, en
[`GUIA_FALLAS_PAGOS_19.8.1.md`](GUIA_FALLAS_PAGOS_19.8.1.md). Claude **no** entra al servidor ni ejecuta nada en
producción: Fredy ejecuta y trae los resultados; Claude los revisa.

Arquitectura de prod (de `DEPLOY_PRODUCCION.md`): una VM Windows con IIS (sitio `personas.vidareal.tv`) y **otra VM**
con SQL Server (BD `Rock18`). Los accesos (Escritorio remoto, cuentas) **no están en el repo**: están en
`ACCESOS_Y_SECRETOS.md` del paquete de handoff. Nunca se pasan contraseñas ni llaves a Claude.

---

## Fase 0 — Entrar a los servidores (5 min)

- [ ] **Servidor web (IIS):** en esta PC, `Win + R` → `mstsc` → *Mostrar opciones*:
  - *Equipo*: la dirección del servidor web (de `ACCESOS_Y_SECRETOS.md`).
  - Pestaña *Recursos locales* → *Más…* → marcar la unidad **C:** de esta PC. Así, dentro del servidor, esta PC se ve
    como `\\tsclient\C` y se pueden copiar el kit y las herramientas sin USB ni carpetas compartidas.
  - *Conectar* y escribir usuario y contraseña (los teclea Fredy).
- [ ] **Servidor SQL:** igual, con la dirección del servidor SQL (o con SSMS desde el servidor web si así se trabaja).
- [ ] En el servidor web, crear una carpeta de trabajo **fuera de RockWeb**, p. ej. `D:\upgrade-19.8.1\` (si no hay D:,
      `C:\upgrade-19.8.1\`), y copiar ahí desde `\\tsclient\C\Users\Servr local Rock RMS\Documents\GitHub\`:
  - la carpeta `kit_19.8.1_2026-11-23\` completa (≈ 550 MB);
  - la carpeta `herramientas\` del kit (scripts y plantillas; ver «Qué hay en herramientas»).

---

## Fase A — Análisis previo, con el sitio arriba (sin cortar servicio; 30–45 min)

Todo es **solo lectura**. Se puede hacer horas antes de la ventana.

- [ ] **A1. Diagnóstico del servidor web** (2–5 min):
  ```powershell
  powershell -NoProfile -ExecutionPolicy Bypass -File "D:\upgrade-19.8.1\herramientas\Get-DiagnosticoServidor.ps1" -ConInventario
  ```
  Si no encuentra el sitio solo, agregar `-RockWeb "<ruta física de RockWeb>"` (IIS → Sitios → sitio de
  personas.vidareal.tv → *Configuración básica* → *Ruta de acceso física*). Deja en el Escritorio
  `Diagnostico_Rock_<equipo>_<fecha>.zip` con: versión de .NET, IIS y app pool, versiones/hashes de las DLL,
  `RunJobsInIISContext`, hash corto de las llaves, nombres de `appSettings`, espacio en disco, archivos del tema del
  kiosco y el inventario de `RockWeb` (§13 del runbook). **Traer ese .zip a esta PC** (copiarlo a `\\tsclient\C\...`)
  y pasárselo a Claude. No subirlo al repo (trae el nombre del servidor SQL).
- [ ] **A2. Preflight de la BD** (1 min), en el servidor SQL:
  - Con SSMS: abrir `herramientas\19.8.1_preflight_bd_prod.sql`, elegir la BD `Rock18`, *Consulta → Resultados a texto*
    (`Ctrl+T`), ejecutar (`F5`) y guardar el resultado como `preflight_resultado.txt`.
  - O con sqlcmd (si A1 dice que hay `sqlcmd`):
    `sqlcmd -S <servidor> -E -d Rock18 -I -f 65001 -W -s "|" -i 19.8.1_preflight_bd_prod.sql -o preflight_resultado.txt`
  - Traer `preflight_resultado.txt` a Claude.
- [ ] **A3. Rock Shop:** en prod, *Admin → Rock Shop → Installed Plugins*: captura de pantalla con nombre y versión de
      cada plugin (BEMA MailChimp/Workflow Extensions, Blue Box Moon ACME/Data Toolkit, MinePass, MinistryPass).
- [ ] **A4. web.config de la 19** (5 min, en el servidor web; genera un archivo **secreto**: no sacarlo del servidor):
  ```powershell
  cd D:\upgrade-19.8.1\herramientas
  powershell -NoProfile -ExecutionPolicy Bypass -File .\New-WebConfigFusionado.ps1 -WebConfigProd "<RockWeb>\web.config" -WebConfig19 .\web.config.19-plantilla -WebConfig181 .\web.config.18.1-plantilla
  ```
  Debe terminar en «OK: llaves idénticas a prod». Pasar a Claude **solo la salida de la pantalla** (no el archivo):
  trae el valor original de `RunJobsInIISContext` y la lista «solo en prod» (configuración propia del servidor que
  hay que decidir si se agrega a mano). Si falla, **no** seguir.
- [ ] **A5. Claude revisa** A1–A4 y entrega por escrito: comparación del inventario (archivos cambiados o propios de
      prod que el kit pisaría), decisión del CSS del kiosco (si prod no tiene `_css-overrides.less`, no hay nada que
      hacer), lista final de «se conserva», y el **ir / no ir**.

### Criterios de ir / no ir (todos deben cumplirse)

| # | Criterio | De dónde sale |
|---|---|---|
| 1 | .NET Framework ≥ 4.7.2 en el servidor web | A1 §1 |
| 2 | Preflight: **todo «OK»** (SQL ≥ 2016, compatibilidad ≥ 130, espacio, migraciones y plugins = copia probada, bloque 12 = 0) | A2 |
| 3 | Las llaves de prod **no** son las de dev que están en el repo público (hashes de dev: `DataEncryptionKey` `93f6c3eae92a`, `PasswordKey` `500de4bd949c`, `machineKey.validationKey` `5a295050f08d`, `machineKey.decryptionKey` `aff2443a1310`). Si alguna coincide, las llaves de prod son públicas: se puede seguir, pero hay que **rotarlas** después (incidente de seguridad) | A1 §4 |
| 4 | El fusionado de A4 terminó en «llaves idénticas» y la lista «solo en prod» está revisada | A4 |
| 5 | Inventario sin archivos «DISTINTO» o «SOLO_SERVIDOR» (no generados) sin decidir | A1 + A5 |
| 6 | Espacio libre en el disco de RockWeb ≥ tamaño de RockWeb + 1 GB; en el disco de respaldos de SQL ≥ 2× la BD | A1 §6, A2 bloque 4 |
| 7 | Nadie usando el sistema: no es sábado noche ni domingo; no hay venta grande de boletos en curso; kioscos sin uso | calendario |
| 8 | Fredy disponible ~3 h seguidas y con acceso a los dos servidores | — |

Si falta cualquiera: **no ir**; se reprograma sin costo (nada se tocó).

---

## Fase B — Avisar (5 min, antes de la ventana)

- [ ] Avisar al equipo que `personas.vidareal.tv` estará en mantenimiento (página de `app_offline.htm`) durante ~2 h.
- [ ] Confirmar que ningún kiosco de check-in esté en uso.

---

## Fase C — Ventana (≈ 1.5–2 h). Anotar la hora de inicio y fin de cada paso.

> Comandos de IIS en PowerShell **como administrador** en el servidor web. Sustituir `<RockWeb>`, `<sitio>` y
> `<pool>` con lo que dio A1 §2. Carpeta de respaldo del día: `D:\deploy-backup\2026-11-24\` (fuera de RockWeb).

- [ ] **C1. Mantenimiento:** copiar `<RockWeb>\app_offline-template.htm` como `<RockWeb>\app_offline.htm`. Comprobar en
      el navegador que el sitio muestra la página de mantenimiento.
- [ ] **C2. Detener el sitio:**
  ```powershell
  Import-Module WebAdministration
  Stop-Website '<sitio>'; Stop-WebAppPool '<pool>'
  ```
- [ ] **C3. Respaldo de la BD** (servidor SQL, SSMS; 5–15 min con ~7 GB):
  ```sql
  BACKUP DATABASE [Rock18] TO DISK = N'<carpeta de respaldos>\Rock18_antes_19.8.1_20261124.bak'
      WITH COPY_ONLY, CHECKSUM, COMPRESSION, STATS = 10;   -- si da error de COMPRESSION (edición Express), quitarla
  RESTORE VERIFYONLY FROM DISK = N'<carpeta de respaldos>\Rock18_antes_19.8.1_20261124.bak' WITH CHECKSUM;
  ```
  Debe decir «The backup set on file 1 is valid». **Sin respaldo verificado no se sigue.**
- [ ] **C4. Respaldo completo de RockWeb** (incluye `Content`, `App_Data`, `Bin`, `Plugins`, `web.config`):
  ```powershell
  robocopy "<RockWeb>" "D:\deploy-backup\2026-11-24\RockWeb" /E /COPY:DAT /R:1 /W:1 /NP /LOG:"D:\deploy-backup\2026-11-24\respaldo_rockweb.log"
  ```
  Códigos de salida 0–7 = bien; 8 o más = revisar el log antes de seguir.
- [ ] **C5. Retirar lo que la 19 eliminó** (mover, no borrar), con la lista del kit (runbook §7.3 paso 3):
  ```powershell
  $rw = '<RockWeb>'; $dst = 'D:\deploy-backup\2026-11-24\retirados'
  Get-Content 'D:\upgrade-19.8.1\kit_19.8.1_2026-11-23\quitar_del_servidor.txt' | Where-Object { $_ -and -not $_.StartsWith('#') } | ForEach-Object {
      $rel = $_ -replace '/', '\'; $src = Join-Path $rw $rel
      if (Test-Path -LiteralPath $src) { $d = Join-Path $dst $rel; New-Item -ItemType Directory -Force (Split-Path $d) | Out-Null; Move-Item -LiteralPath $src -Destination $d } }
  ```
  Obligatorio que salgan `Bin\Rock.SignNow.dll`, `Bin\SignNowSDK.dll` (+ `.pdb`) y `Webhooks\SignNow.ashx`.
- [ ] **C6. Copiar el kit encima** (sin `/MIR` ni `/PURGE`: no se borra nada de prod):
  ```powershell
  robocopy "D:\upgrade-19.8.1\kit_19.8.1_2026-11-23\RockWeb" "<RockWeb>" /E /R:1 /W:1 /NP /LOG:"D:\deploy-backup\2026-11-24\copia_kit.log"
  ```
  Verificar que lo copiado es idéntico al kit (debe decir `distintos: 0`):
  ```powershell
  $k='D:\upgrade-19.8.1\kit_19.8.1_2026-11-23'; $m = Import-Csv "$k\MANIFIESTO_SHA256.csv"
  $mal = $m | Where-Object { (Get-FileHash -LiteralPath (Join-Path '<RockWeb>' $_.Ruta) -Algorithm SHA256).Hash -ne $_.SHA256 }
  "archivos: $($m.Count)  distintos: $(@($mal).Count)"; $mal | Select-Object -First 20 Ruta
  ```
- [ ] **C7. web.config de la 19:** copiar `D:\upgrade-19.8.1\herramientas\web.config.19-fusionado` (de A4) como
      `<RockWeb>\web.config` (el original ya está en el respaldo C4). Agregar a mano lo «solo en prod» que A5 haya
      decidido conservar. Comprobar las llaves:
      `powershell -NoProfile -ExecutionPolicy Bypass -File .\Get-DiagnosticoServidor.ps1 -SoloLlaves -WebConfig "<RockWeb>\web.config"`
      → los hashes deben ser **los mismos** que A1 §4.
- [ ] **C8. Reservas dominicales** (solo si el preflight, bloque 8, dio `NULL`): correr
      `herramientas\QREVENT_SundayService_SlotSettings.sql` en el servidor SQL (segundos; idempotente).
- [ ] **C9. Arrancar:** borrar `<RockWeb>\app_offline.htm`, luego
  ```powershell
  Start-WebAppPool '<pool>'; Start-Website '<sitio>'
  ```
  Abrir el sitio **desde el propio servidor** (`http://localhost/` o la URL interna): la primera carga compila y corre
  las migraciones (en local: ~1 min de compilación + ~1 min de migraciones; en prod puede ser más). Vigilar
  `<RockWeb>\App_Data\Logs\MigrationLog.csv` y `RockExceptions.csv`. Si no levanta: runbook `DEPLOY_PRODUCCION.md` §4
  (`customErrors` oculta el error: verlo desde el servidor o en *Visor de eventos → Aplicación*); si en 30 min no se
  resuelve → **Fase E (reversa)**.
- [ ] **C10. Línea base:** en SQL, anotar `SELECT MAX(Id) FROM ExceptionLog` y las líneas base de pagos (guía de
      pagos, consulta 6.0).
- [ ] **C11. Jobs post-actualización** (*Admin → System Settings → Jobs Administration*, botón «Run Now» de cada uno, en
      este orden; los Id de la copia local eran 220–233 y pueden variar: identificarlos por nombre):
  1. Los que corrigen MIME de imágenes (transacción y persona) y el de limpieza de redes sociales.
  2. Los tres que crean índices (FinancialBatch, Communication, Unsubscribe), el de Achievement Types y el de
     `ConnectedDateTime` de conexiones.
  3. «Replace WebForms Blocks» de **File Manager → File Asset Manager** (Swap) y luego el de **Chop** del mismo.
  4. «Replace WebForms Blocks» de **Registration Entry** y de **Service Metrics Entry**.
  Los «Replace WebForms Blocks» **desaparecen de la lista al terminar bien** (esa es la señal de éxito). Si uno se queda
  con error, anotar el mensaje. Los jobs nuevos normales (Outreach Toolbox, Analytics PostalCode) **no** se corren a mano.
- [ ] **C12. (Decisión de Fredy) Bloques huérfanos** de las páginas 327 «System Phone Numbers» y 740 «Experience
      Administration»: correr `herramientas\19.8.1_job_reemplazo_bloques_huerfanos.sql` en SQL y luego «Run Now» del job
      que crea. Probado en local (Rock19Test): las dos páginas quedaron bien. Si no se aprueba, esas dos páginas de
      administración quedan con error hasta arreglarlas.

---

## Fase D — Verificación (30–45 min)

Recorrido de `../PLAN_PRUEBAS_19.8.1.md` columna **P** (prod). Lo mínimo para dar el upgrade por bueno:

- [ ] Home pública e interna cargan; inicio de sesión de un usuario normal.
- [ ] Páginas 433 (File Manager), 451 (Weekly Metrics), 327, 740 cargan.
- [ ] **Check-in VidAventura:** kiosco Mostrador, una familia de prueba (o la del responsable), etiqueta impresa bien
      en la impresora real, salida desde el kiosco; Check-in Manager (Roster) abre.
- [ ] Reservas dominicales: páginas 860–864 cargan; el escáner 863 abre.
- [ ] Eventos: `/eventos/calendario` y el detalle de un evento cargan (no comprar).
- [ ] **Dar:** donación de **Q1.00** con la tarjeta de Fredy (la teclea él; el campo llena desde la derecha: «100» =
      Q1.00). Comparar con la forma esperada de la guía de pagos §4 (consulta 6.1). Si falla: guía de pagos §2.
- [ ] QR (`/qr`), Wallet (`/wallet/plantillas`), Traductor (página 1008) cargan.
- [ ] `ExceptionLog` con Id mayor a la línea base de C10: solo el ruido conocido (`PLAN_PRUEBAS` §14 / guía §6.4).

**Si algo crítico no funciona** (check-in, pagos, inicio de sesión) y no se arregla en 30 min → **Fase E**.

---

## Fase E — Reversa (rollback; ≈ 30–45 min)

La 19 migra la BD y **no tiene vuelta atrás**: la reversa es **siempre BD + archivos juntos**.

- [ ] E1. `app_offline.htm` en `<RockWeb>` y detener sitio y pool (C2).
- [ ] E2. Restaurar la BD (servidor SQL):
  ```sql
  USE master;
  ALTER DATABASE [Rock18] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
  RESTORE DATABASE [Rock18] FROM DISK = N'<carpeta de respaldos>\Rock18_antes_19.8.1_20261124.bak' WITH REPLACE, CHECKSUM, STATS = 10;
  ALTER DATABASE [Rock18] SET MULTI_USER;
  ```
- [ ] E3. Restaurar `RockWeb`: renombrar la carpeta actual a `RockWeb_19_fallido` y copiar el respaldo C4 a la ruta
      original:
  ```powershell
  Rename-Item '<RockWeb>' 'RockWeb_19_fallido'
  robocopy "D:\deploy-backup\2026-11-24\RockWeb" "<RockWeb>" /E /COPY:DAT /R:1 /W:1 /NP /LOG:"D:\deploy-backup\2026-11-24\reversa.log"
  ```
- [ ] E4. Arrancar (C9) y comprobar que el sitio y el check-in funcionan como antes.
- [ ] E5. Anotar qué falló (hora, mensaje, pantalla) para analizarlo con calma. No reintentar el mismo día.

Notas: cualquier dato que la gente haya guardado entre C9 y E2 se pierde (por eso el sitio sigue en mantenimiento
durante la verificación). Los secretos que se hayan re-guardado en la 19 quedan en formato V2 (guía de pagos §3): con
la restauración de la BD vuelven los originales.

---

## Fase F — Después

- [ ] F1. Devolver `RunJobsInIISContext` a su valor original (el que mostró A4) en `<RockWeb>\web.config` (reinicia el
      sitio). Hasta entonces los jobs programados no corren.
- [ ] F2. Avisar a los supervisores de check-in del límite nuevo de PIN (10 fallos en 10 min bloquean el PIN 10 min;
      runbook §14.8) y que confirmen su PIN antes del domingo.
- [ ] F3. Primera semana: revisar a diario `ExceptionLog` (guía de pagos §6.4) y las transacciones nuevas (§6.1).
- [ ] F4. Decidir los jobs nuevos normales (Outreach Toolbox, Analytics PostalCode) y los pendientes no bloqueantes:
      CSS del kiosco / tema del Check-in Manager (runbook §14.9), workflows 77 y 83 (DLL ausente), defectos previos de
      la guía de pagos §7, rotación del token de Odoo del workflow «Dar Recibo».
- [ ] F5. Registrar en el repo: fecha, hora, commit del kit (`c190618011`), resultado, y quién lo hizo (Fredy Ramirez):
      `UPGRADE_19.8.1.md` §0 y `ESTADO_REPO.md`. Si se aprueba, unir la rama del upgrade a `hotfix-18.1` (o la que pase a
      ser la de producción) **en un paso aparte**, con su aprobación.
- [ ] F6. Cerrar el acceso a 6229 desde la red local (runbook §15.2) cuando ya no haga falta.

---

## Qué hay en `herramientas\` (dentro del kit)

| Archivo | Para qué | ¿Modifica algo? |
|---|---|---|
| `Get-DiagnosticoServidor.ps1` | A1 (y C7 con `-SoloLlaves`) | No |
| `Get-RockWebInventario.ps1` | Inventario de RockWeb (lo llama A1 con `-ConInventario`) | No |
| `New-WebConfigFusionado.ps1` | A4: genera el web.config de la 19 con los valores de prod | Solo escribe el archivo nuevo |
| `web.config.19-plantilla`, `web.config.18.1-plantilla` | Plantillas del repo para A4 (traen llaves de **dev**, que el script reemplaza) | — |
| `19.8.1_preflight_bd_prod.sql` | A2 | No (solo SELECT) |
| `QREVENT_SundayService_SlotSettings.sql` | C8 (si aplica) | Sí: agrega 3 columnas NULL |
| `19.8.1_job_reemplazo_bloques_huerfanos.sql` | C12 (si se aprueba) | Sí: crea un job |
| `CHECKLIST_PRODUCCION_19.8.1.md`, `GUIA_FALLAS_PAGOS_19.8.1.md` | Para leer en el servidor | — |
