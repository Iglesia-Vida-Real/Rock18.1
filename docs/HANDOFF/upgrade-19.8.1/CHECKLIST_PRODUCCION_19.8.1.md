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
- [ ] En el servidor web, crear la carpeta de trabajo `C:\upgrade-19.8.1\` (**fuera de RockWeb**) y copiar ahí, desde
      `\\tsclient\C\Users\Servr local Rock RMS\Documents\GitHub\`, la carpeta `kit_19.8.1_2026-11-23\` completa
      (≈ 550 MB; ya trae dentro `herramientas\`, ver «Qué hay en herramientas»).
  > **No usar la unidad «Temporary Storage» (D:) del servidor web.** Es el disco temporal de la VM de Azure: se borra
  > al reiniciar por mantenimiento, redimensionar o mover la VM. Ni el kit ni los respaldos van ahí. Todo en `C:`
  > (verificado en el servidor el 2026-11-24: solo tiene `C:` y el disco temporal). Ojo con el espacio de `C:`:
  > criterio 6.
  >
  > Prod tiene RockWeb en `C:\inetpub\wwwroot` (visto el 2026-11-24; A1 lo confirma con la ruta física del sitio de
  > IIS). Junto a él existe `C:\inetpub\wwwroot_15` (aparentemente una copia vieja de la época de Rock 15): no tocarla.

---

## Fase A — Análisis previo, con el sitio arriba (sin cortar servicio; 30–45 min)

Todo es **solo lectura**. Se puede hacer horas antes de la ventana.

- [ ] **A1. Diagnóstico del servidor web** (2–5 min):
  ```powershell
  powershell -NoProfile -ExecutionPolicy Bypass -File "C:\upgrade-19.8.1\kit_19.8.1_2026-11-23\herramientas\Get-DiagnosticoServidor.ps1" -ConInventario
  ```
  En prod el sitio se llama **`Default Web Site`** (pool `DefaultAppPool`, ruta `C:\inetpub\wwwroot`, bindings comodín
  `*:80` y `*:443`; visto el 2026-11-24), así que hay que agregar `-Sitio "Default Web Site"` (las versiones del script
  posteriores al 2026-11-24 toman solas el único sitio). Si no encuentra el sitio, agregar `-RockWeb "<ruta física de RockWeb>"` (IIS → Sitios → sitio de
  personas.vidareal.tv → *Configuración básica* → *Ruta de acceso física*). Deja en el Escritorio
  `Diagnostico_Rock_<equipo>_<fecha>.zip` con: versión de .NET, IIS y app pool, versiones/hashes de las DLL,
  `RunJobsInIISContext`, hash corto de las llaves, nombres de `appSettings`, espacio en disco, archivos del tema del
  kiosco y el inventario de `RockWeb` (§13 del runbook). **Traer ese .zip a esta PC** (copiarlo a `\\tsclient\C\...`)
  y pasárselo a Claude. No subirlo al repo (trae el nombre del servidor SQL).
- [ ] **A1b. Muestras de lo que el inventario marcó** (1 min; agregado el 2026-11-24 tras analizar A1). Copiar
      `Get-MuestrasProd.ps1` a la carpeta `herramientas\` del servidor y correr:
  ```powershell
  powershell -NoProfile -ExecutionPolicy Bypass -File "C:\upgrade-19.8.1\kit_19.8.1_2026-11-23\herramientas\Get-MuestrasProd.ps1"
  ```
  Copia (solo lectura) los ~45 archivos de código y DLLs que prod tiene distintos al repo o que solo existen en prod,
  y deja `muestras_prod_<fecha>.zip` en el Escritorio. Traerlo a la PC (fuera del repo). Con eso Claude los prueba en
  la 19 local (App_Code compilando, DLLs viejas cargadas) y compara qué cambios de prod pisaría el kit.
  Resultado del análisis de A1: ver «Resultados de la fase A» al final.
- [ ] **A2. Preflight de la BD** (1 min). **Usar el `19.8.1_preflight_bd_prod.sql` del repo del 2026-11-25 o
      posterior** (trae el bloque 13, bloques sobre `.ascx` que la 19 retira, y el 14, permisos para respaldar y
      restaurar; la copia que quedó en el servidor web el 24-nov es anterior).
  - **Cómo se corre (decidido 2026-11-25):** el acceso a la VM SQL (Escritorio remoto, login sysadmin) **no se
    transfirió** en el traspaso (`ACCESOS_Y_SECRETOS.md` §2 sin marcar). Se corre **desde el servidor web** con
    `Invoke-SqlDesdeWeb.ps1`, que usa la conexión del propio sitio (`web.ConnectionStrings.config`) sin mostrarla.
    Copiar a `herramientas\` del servidor `Invoke-SqlDesdeWeb.ps1` y el preflight nuevo (reemplazar), y en
    PowerShell de administrador:
    ```powershell
    cd C:\upgrade-19.8.1\kit_19.8.1_2026-11-23\herramientas
    powershell -NoProfile -ExecutionPolicy Bypass -File .\Invoke-SqlDesdeWeb.ps1 -Archivo .\19.8.1_preflight_bd_prod.sql
    ```
    Deja `19.8.1_preflight_bd_prod_resultado_<fecha>.txt` en el Escritorio. Traerlo a la PC (fuera del repo: trae
    rutas del servidor SQL). Si algún bloque da «ERROR SQL» por permisos (p. ej. el 5, historial de respaldos en
    `msdb`), no es grave: se anota.
  - Si más adelante se consigue el acceso a la VM SQL, también vale con SSMS (*Resultados a texto*, `Ctrl+T`, `F5`).
  - **El bloque 14 decide cómo se hará el respaldo (C3) y la reversa (E2):** si la cuenta del sitio puede respaldar y
    restaurar, se harán con el mismo `Invoke-SqlDesdeWeb.ps1`; si no, **no hay ventana** hasta conseguir una cuenta
    con esos permisos (o el acceso a la VM SQL / a Azure).
- [ ] **A3. Rock Shop:** en prod, *Admin → Rock Shop → Installed Plugins*: captura de pantalla con nombre y versión de
      cada plugin (BEMA MailChimp/Workflow Extensions, Blue Box Moon ACME/Data Toolkit, MinePass, MinistryPass).
- [ ] **A4. web.config de la 19** (5 min, en el servidor web; genera un archivo **secreto**: no sacarlo del servidor):
  ```powershell
  cd C:\upgrade-19.8.1\kit_19.8.1_2026-11-23\herramientas
  powershell -NoProfile -ExecutionPolicy Bypass -File .\New-WebConfigFusionado.ps1 -WebConfigProd "C:\inetpub\wwwroot\web.config" -WebConfig19 .\web.config.19-plantilla -WebConfig181 .\web.config.18.1-plantilla
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

> Comandos de IIS en PowerShell **como administrador** en el servidor web. Datos reales del servidor (A1 §2,
> 2026-11-24): RockWeb = `C:\inetpub\wwwroot`, sitio `Default Web Site`, pool `DefaultAppPool`. Carpeta de respaldo:
> `C:\deploy-backup\upgrade-19.8.1\` (en `C:`, fuera de RockWeb; nunca en el disco temporal D:).

- [ ] **C1. Mantenimiento:** copiar `C:\inetpub\wwwroot\app_offline-template.htm` como `C:\inetpub\wwwroot\app_offline.htm`. Comprobar en
      el navegador que el sitio muestra la página de mantenimiento.
- [ ] **C2. Detener el sitio:**
  ```powershell
  Import-Module WebAdministration
  Stop-Website 'Default Web Site'; Stop-WebAppPool 'DefaultAppPool'
  ```
- [ ] **C3. Respaldo de la BD** (desde el servidor web; minutos con ~7.9 GB de datos):
  ```powershell
  cd C:\upgrade-19.8.1\kit_19.8.1_2026-11-23\herramientas
  powershell -NoProfile -ExecutionPolicy Bypass -File .\Invoke-SqlDesdeWeb.ps1 -Archivo .\19.8.1_respaldo_bd.sql
  ```
  Respaldo COPY_ONLY con CHECKSUM y compresión en la carpeta de respaldos por defecto del servidor SQL
  (`…\MSSQL16.MSSQLSERVER\MSSQL\Backup\Rock18_antes_19.8.1.bak`). Debe terminar en **«OK: respaldo de esta corrida,
  con checksum»**. `VERIFYONLY` probablemente diga que no se pudo correr (la cuenta del sitio no tiene CREATE DATABASE):
  es esperado. **Sin ese OK no se sigue.** Anotar el tamaño y los segundos.
- [ ] **C4. Respaldo completo de RockWeb** (incluye `Content`, `App_Data`, `Bin`, `Plugins`, `web.config`):
  ```powershell
  robocopy "C:\inetpub\wwwroot" "C:\deploy-backup\upgrade-19.8.1\RockWeb" /E /COPY:DAT /R:1 /W:1 /NP /LOG:"C:\deploy-backup\upgrade-19.8.1\respaldo_rockweb.log"
  ```
  Códigos de salida 0–7 = bien; 8 o más = revisar el log antes de seguir.
- [ ] **C5. Retirar lo que la 19 eliminó** (mover, no borrar), con la lista del kit (runbook §7.3 paso 3):
  ```powershell
  $rw = 'C:\inetpub\wwwroot'; $dst = 'C:\deploy-backup\upgrade-19.8.1\retirados'
  Get-Content 'C:\upgrade-19.8.1\kit_19.8.1_2026-11-23\quitar_del_servidor.txt' | Where-Object { $_ -and -not $_.StartsWith('#') } | ForEach-Object {
      $rel = $_ -replace '/', '\'; $src = Join-Path $rw $rel
      if (Test-Path -LiteralPath $src) { $d = Join-Path $dst $rel; New-Item -ItemType Directory -Force (Split-Path $d) | Out-Null; Move-Item -LiteralPath $src -Destination $d } }
  ```
  Obligatorio que salgan `Bin\Rock.SignNow.dll`, `Bin\SignNowSDK.dll` (+ `.pdb`) y `Webhooks\SignNow.ashx`.
- [ ] **C6. Copiar el kit encima** (sin `/MIR` ni `/PURGE`: no se borra nada de prod):
  ```powershell
  robocopy "C:\upgrade-19.8.1\kit_19.8.1_2026-11-23\RockWeb" "C:\inetpub\wwwroot" /E /R:1 /W:1 /NP /LOG:"C:\deploy-backup\upgrade-19.8.1\copia_kit.log"
  ```
  Verificar que lo copiado es idéntico al kit (debe decir `distintos: 0`):
  ```powershell
  $k='C:\upgrade-19.8.1\kit_19.8.1_2026-11-23'; $m = Import-Csv "$k\MANIFIESTO_SHA256.csv"
  $mal = $m | Where-Object { (Get-FileHash -LiteralPath (Join-Path 'C:\inetpub\wwwroot' $_.Ruta) -Algorithm SHA256).Hash -ne $_.SHA256 }
  "archivos: $($m.Count)  distintos: $(@($mal).Count)"; $mal | Select-Object -First 20 Ruta
  ```
- [ ] **C7. web.config de la 19:** copiar `C:\upgrade-19.8.1\kit_19.8.1_2026-11-23\herramientas\web.config.19-fusionado` (de A4) como
      `C:\inetpub\wwwroot\web.config` (el original ya está en el respaldo C4). Lo «solo en prod» ya viene aplicado
      (A4, 2026-11-24). Comprobar las llaves:
      `powershell -NoProfile -ExecutionPolicy Bypass -File C:\upgrade-19.8.1\kit_19.8.1_2026-11-23\herramientas\Get-DiagnosticoServidor.ps1 -SoloLlaves -WebConfig "C:\inetpub\wwwroot\web.config"`
      → los hashes deben ser **los mismos** que A1 §4.
- [ ] **C8. Reservas dominicales** (el preflight del 2026-11-25, bloque 8, dio `NULL`: **sí hace falta**). Segundos,
      idempotente; probado con el ejecutor en una BD de prueba:
      `powershell -NoProfile -ExecutionPolicy Bypass -File .\Invoke-SqlDesdeWeb.ps1 -Archivo .\QREVENT_SundayService_SlotSettings.sql`
      → «Columna … agregada» ×3, «Restricción … agregada» ×2 y la fila `1|1|1|2`.
- [ ] **C9. Arrancar:** borrar `C:\inetpub\wwwroot\app_offline.htm`, luego
  ```powershell
  Start-WebAppPool 'DefaultAppPool'; Start-Website 'Default Web Site'
  ```
  Abrir el sitio **desde el propio servidor** (`http://localhost/` o la URL interna): la primera carga compila y corre
  las migraciones (en local: ~1 min de compilación + ~1 min de migraciones; en prod puede ser más). Vigilar
  `C:\inetpub\wwwroot\App_Data\Logs\MigrationLog.csv` y `RockExceptions.csv`. Si no levanta: runbook `DEPLOY_PRODUCCION.md` §4
  (`customErrors` oculta el error: verlo desde el servidor o en *Visor de eventos → Aplicación*); si en 30 min no se
  resuelve → **Fase E (reversa)**.
- [ ] **C10. Línea base** (guía de pagos, consulta 6.0): conviene correrla **antes de C9** (con el sitio detenido) y
      anotar `MaxTx`, `MaxExc`, `MaxOrden`:
      `powershell -NoProfile -ExecutionPolicy Bypass -File .\Invoke-SqlDesdeWeb.ps1 -Archivo .\19.8.1_linea_base.sql`
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
      Administration»: correr `19.8.1_job_reemplazo_bloques_huerfanos.sql` con `Invoke-SqlDesdeWeb.ps1` (igual que C8)
      y luego «Run Now» del job que crea. Probado en local (Rock19Test): las dos páginas quedaron bien. Si no se aprueba, esas dos páginas de
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

- [ ] E1. `app_offline.htm` en `C:\inetpub\wwwroot` y detener sitio y pool (C2).
- [ ] E2. Restaurar la BD (desde el servidor web, **con `-BaseMaster`**; sobrescribe Rock18 con el respaldo de C3):
  ```powershell
  cd C:\upgrade-19.8.1\kit_19.8.1_2026-11-23\herramientas
  powershell -NoProfile -ExecutionPolicy Bypass -File .\Invoke-SqlDesdeWeb.ps1 -Archivo .\19.8.1_reversa_restaurar_bd.sql -BaseMaster
  ```
  Debe terminar en **«OK: Rock18 restaurada al estado de 18.1»** (ONLINE, MULTI_USER, última migración de 18.1).
  Probado el 2026-11-25 en local con una cuenta con los mismos permisos que la del sitio (dueña de la BD, sin
  sysadmin ni dbcreator): respaldó y restauró bien. Hacer E2 **antes** de E3 (el script lee la conexión de
  `C:\inetpub\wwwroot\web.ConnectionStrings.config`; si la carpeta ya se renombró, agregar
  `-RockWeb C:\inetpub\wwwroot_19_fallido`).
- [ ] E3. Restaurar `RockWeb`: renombrar la carpeta actual a `wwwroot_19_fallido` y copiar el respaldo C4 a la ruta
      original:
  ```powershell
  Rename-Item 'C:\inetpub\wwwroot' 'wwwroot_19_fallido'
  robocopy "C:\deploy-backup\upgrade-19.8.1\RockWeb" "C:\inetpub\wwwroot" /E /COPY:DAT /R:1 /W:1 /NP /LOG:"C:\deploy-backup\upgrade-19.8.1\reversa.log"
  ```
- [ ] E4. Arrancar (C9) y comprobar que el sitio y el check-in funcionan como antes.
- [ ] E5. Anotar qué falló (hora, mensaje, pantalla) para analizarlo con calma. No reintentar el mismo día.

Notas: cualquier dato que la gente haya guardado entre C9 y E2 se pierde (por eso el sitio sigue en mantenimiento
durante la verificación). Los secretos que se hayan re-guardado en la 19 quedan en formato V2 (guía de pagos §3): con
la restauración de la BD vuelven los originales.

---

## Fase F — Después

- [ ] F1. Devolver `RunJobsInIISContext` a su valor original (el que mostró A4) en `C:\inetpub\wwwroot\web.config` (reinicia el
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
| `Get-MuestrasProd.ps1` | A1b: copia los archivos que el inventario marcó, para probarlos en local | No (escribe en el Escritorio) |
| `Invoke-SqlDesdeWeb.ps1` | A2, C3, C8, C10, C12, E2: corre un `.sql` con la conexión del sitio, sin mostrarla | Depende del `.sql` |
| `19.8.1_respaldo_bd.sql` | C3 (y el ensayo previo) | Escribe el `.bak` |
| `19.8.1_linea_base.sql` | C10 | No |
| `19.8.1_reversa_restaurar_bd.sql` | E2 (solo en reversa, con `-BaseMaster`) | **Sí: sobrescribe Rock18** |
| `CHECKLIST_PRODUCCION_19.8.1.md`, `GUIA_FALLAS_PAGOS_19.8.1.md` | Para leer en el servidor | — |

---

## Resultados de la fase A

### A1 — diagnóstico del servidor web (2026-11-24 14:27, Fredy Ramirez)

| Tema | Resultado | Criterio |
|---|---|---|
| Equipo | Windows Server 2022 Datacenter Azure, PowerShell 5.1, IIS 10, zona horaria Central America; encendido desde 2026-11-11 | — |
| .NET | release 528449 (4.8) | ✅ 1 |
| Sitio de IIS | Único sitio `Default Web Site`, pool `DefaultAppPool` (CLR v4.0, Integrated, **LocalSystem**, AlwaysRunning, reciclado cada 29 h), ruta `C:\inetpub\wwwroot`, bindings comodín | — |
| DLL del fork | Todas 18.1 pero de **fechas distintas** (Rock.dll 09-29, Rock.Blocks/ViewModels 10-06, Rock.Rest 08-28): prod hoy tiene DLLs de builds distintos (trampa 8). El kit las reemplaza todas juntas | — |
| Llaves | Hashes de prod (`PasswordKey` cec1209c4e45, `DataEncryptionKey` cb63f3c4d33c, `validationKey` dd0af68ee74f, `decryptionKey` 84704e808a4e) **distintos** de los de dev del repo. Sin `OldDataEncryptionKey` | ✅ 3 |
| web.config | `RunJobsInIISContext=True` (devolverlo así en F1); `customErrors=On`; `compilation debug=true` (prod corre en modo debug; se conserva, revisar después); 12 appSettings | — |
| BD | `Rock18` en el servidor SQL de la red interna, autenticación SQL; no hay `sqlcmd` en el servidor web (A2 con SSMS) | — |
| Discos | `C:` 50.3 GB libres de 255 GB; RockWeb ocupa 3.0 GB (App_Data 1.5 GB, LMS 0.8 GB de video). Respaldo de RockWeb + kit ≈ 3.6 GB | ✅ 6 (parte web) |
| Tema del kiosco | `_css-overrides.less` existe pero **vacío (0 B)**: no hay CSS propio que conservar. `_variable-overrides.less` de prod difiere del repo y se queda como está (el kit no lo trae) | — |
| Visor de eventos | 29 eventos 1309 (excepciones ASP.NET) en 7 días: línea base para comparar después | — |

### A1 — inventario contra `hotfix-18.1` (6,411 archivos de prod)

- 3,002 idénticos; 97 solo cambian saltos de línea (LF/CRLF, inofensivo); 3,238 generados (Bin, Obsidian, temas).
- **Contenido distinto que el kit sobrescribe** (se pierde lo de prod, queda la versión 19 probada en local):
  `Blocks\CheckIn\TimeSelect.ascx.cs`, `Blocks\Crm\PersonMerge.ascx(.cs)`, `Blocks\Event\RegistrationDetail.ascx.cs`,
  `Blocks\Event\RegistrationInstanceRegistrationList.ascx.cs`, `Plugins\CybersourceInlineRestGateway\...Control.obs(.js)`
  (Dar), `Themes\RockNextGen\Layouts\Site.Master`. Ninguno coincide con una versión de git salvo Site.Master (= upstream
  de 2025-08-21: el cambio propio del 2026-05-08 nunca se desplegó). **Pendiente A1b**: comparar contra prod.
- **Contenido distinto que se queda** (el kit no los trae): `App_Code\WhatsAppSms.ashx.cs` (**riesgo alto**: App_Code
  se compila entero), `Scripts\Rock\Controls\datePicker.js`, los 4 `Blank.aspx`, `_variable-overrides.less`, 8
  archivos de `Plugins\tech_triumph\MinistryPass` (versión más nueva que la del repo).
- **Solo en prod**: `App_Code\GetMinePass.cs` y `App_Code\GetMinistryPass.cs` (**riesgo alto**, Rock Shop),
  `GetMinePass.ashx`, `GetMinistryPass.ashx`, `Blocks\QREVENT\TestCybersource.ascx(.cs)` (bloque de prueba de pagos en
  prod: no se copia por posible llave en el código; revisar después), `Plugins\apollosproject` (2021),
  `Plugins\Asistencia`, mapas `.js.map` de Monaco, videos de LMS, `.DS_Store`.
- **Bin**: 136 archivos solo en prod. 10 son del Rock Shop (se conservan, ya contemplado); 8 se retiran en C5 (SignNow
  y `.refresh`); el resto son `.xml`/`.pdb` inofensivos y **11 DLLs que la prueba local nunca tuvo** (restos de
  instalaciones anteriores: `Rock.MyWell`, `Rock.Lava.DotLiquid`, `Rock.Tests.Shared`, TestFramework, Apollos,
  `ICSharpCode.SharpZipLib`, `Microsoft.AspNetCore.WebUtilities` y fachadas `System.*`). **Pendiente A1b**: cargarlas
  en la 19 local.

### A1b — muestras de prod probadas en la 19 local (2026-11-24 14:53–15:10)

50 archivos traídos con `Get-MuestrasProd.ps1`; ninguno con llaves escritas en el código.

- **Lo que el kit sobrescribe no pierde nada:** los 7 archivos de pantallas (TimeSelect, PersonMerge, RegistrationDetail,
  RegistrationInstanceRegistrationList, control de Cybersource `.obs`/`.obs.js`) y `datePicker.js` / los 4 `Blank.aspx`
  son **idénticos a `hotfix-18.1`** salvo saltos de línea. No hay cambios hechos a mano en el servidor.
- **`App_Code\WhatsAppSms.ashx.cs` de prod** = versión anterior a `0c44380057` (2026-08-12): no tiene
  `ResolveFromPerson` (atribución del remitente por wamid / número compartido) y usa
  `GetPersonFromMobilePhoneNumber`, que existe en la 19. **Compila con la 19.** Se queda como está: tras el upgrade
  WhatsApp entrante se comporta igual que hoy. Desplegar la versión del repo es un cambio aparte (decisión de Fredy).
- **Prueba en la 19 local** (6229, BD Rock19Test) con App_Code de prod (`WhatsAppSms`, `GetMinePass.cs`,
  `GetMinistryPass.cs`), los `.ashx` de la raíz, `Plugins\apollosproject`, `Plugins\Asistencia`, los `.ascx` de
  MinistryPass de prod y las **11 DLLs viejas** en `Bin`: el sitio **arrancó** (App_Code compiló), `/page/1` = 200,
  los handlers responden («No Pass Template Provided.», como se espera sin parámetros), el panel de Apollos y la lista
  de plantillas de MinistryPass cargan. Excepciones al arrancar: solo las conocidas (AIAgentSessionAnchor, `.ascx`
  inexistentes, OpenID sin https). Las DLLs viejas no generaron ninguna excepción. Después se restauró el local
  (`git status` limpio, `/page/1` = 200, 0 excepciones nuevas).
- **Pendiente (próxima sesión):** `TemplateDetail.ascx.cs` de MinistryPass de prod no compiló en local porque usa
  `MinistryPassApple.RelevantCampusCount`, que está en la DLL **más nueva** de prod (2026-04-08) y no en la de dev. Es un
  artefacto de la prueba (prod tiene DLL y `.ascx` a juego; el kit no los toca), pero para cerrar el riesgo de
  `App_Code\GetMinistryPass.cs` (si no compilara, se cae el sitio entero) hay que repetir la prueba con las 4 DLLs del
  Rock Shop de prod: correr de nuevo `Get-MuestrasProd.ps1` (ya las incluye) y probar en local.
- **Cerrado 2026-11-24 15:13–15:25:** segunda corrida de `Get-MuestrasProd.ps1` (54 archivos, ahora con las 4 DLLs del
  Rock Shop de prod; la de MinistryPass de prod es más nueva que la de dev: 65,536 B vs 64,512 B). Con **todo** lo de
  prod junto en la 19 local (App_Code, plugins, `.ascx` y DLLs de MinistryPass/MinePass, las 11 DLLs viejas): el sitio
  arranca, `/page/1` = 200, `GetMinistryPass.ashx` y `GetMinePass.ashx` compilan y responden, la lista **y el detalle**
  de plantillas de MinistryPass cargan (el error anterior era solo de la DLL de dev), **0 excepciones nuevas**.
  Local restaurado (DLLs de dev devueltas, `git status` limpio, `/page/1` = 200). **El servidor web no tiene nada que
  impida el upgrade.**
- A3 (captura del Rock Shop): cubierto por A1 §3 (versiones de las DLLs) + la prueba anterior con las DLLs reales.

### A4 — web.config de la 19 (2026-11-24 15:27)

- Primera corrida: falló al arrancar sin tocar nada (`$PSScriptRoot` vacío en `param()` con PowerShell 5.1; corregido
  en `c3ad1576f6`). Segunda, con `-Salida` explícito: **llaves idénticas a prod**; 12 appSettings copiados;
  `RunJobsInIISContext` era **True** (devolverlo así en F1); machineKey, `customErrors=On` (`/Error.aspx`) y
  `debug=true` copiados.
- **Lo propio de prod que la plantilla no trae** (3 líneas): `<globalization culture="es-GT" uiCulture="es" …utf-8>`
  (formato de fechas, números y moneda en español de Guatemala; sin él la 19 usaría la cultura del servidor),
  `httpRuntime maxRequestLength=512000` y `requestLimits maxAllowedContentLength=524288000` (subidas de hasta 500 MB; la
  plantilla trae 100 MB, y hay videos de LMS de ese tamaño). Esa primera versión del fusionado **no los tenía**.
- El script ahora los aplica solo (atributos que prod cambió respecto de la 18.1 y elementos únicos que faltan) y
  verifica al final «OK: toda la configuración propia de prod quedó en el fusionado».
- **Regenerado en el servidor a las 15:40** (se borró el incompleto y se copió el script nuevo): los 3 «aplicado»,
  «OK: toda la configuración propia de prod quedó en el fusionado» y llaves idénticas. ✅ **Criterio 4 cumplido.**
  El archivo bueno es `herramientas\web.config.19-fusionado` de las **3:40 PM** (40 KB aprox.); es el que se usa en C7.
- No se probó `Blocks\QREVENT\TestCybersource.ascx` (no se copió a propósito). Si no compila con la 19 solo falla su
  propia página (Rock registra el error al arrancar, como con los `.ascx` inexistentes).

### A5 — comprobaciones extra contra el servidor (2026-11-25, antes del A2)

- **El kit sigue siendo el código actual:** entre c190618011 (commit del kit) y la rama hoy solo cambiaron documentos,
  herramientas y Dev Tools/Sql/Aislar_BD_Dev.sql (de dev). Kit íntegro: 3,556 archivos, 0 con tamaño distinto al
  manifiesto.
- **Lista de retiro (C5):** las 383 entradas de quitar_del_servidor.txt existen en prod. Ninguna sobra.
- **DLLs de terceros (269 en prod):** 230 son idénticas al build 18.1 y la 19 las reemplaza; las 16 que el kit pisa y
  no estaban en el build 18.1 local tienen **el mismo tamaño** en prod y en el kit; 8 del Rock Shop se quedan (la 19
  local corrió con ellas). Del kit, 146 DLLs **suben** de versión respecto de la 18.1, 121 quedan igual y solo 2
  "bajan" en número de archivo: Microsoft.Win32.Registry (4.6.26515 → 4.6.25519, mismo paquete con otra
  compilación) y Slingshot.Core (1.0.7531 → 1.0.0.0, upstream lo compila sin número). Ambas son las que trae Rock
  19.8.1 y con las que pasaron todas las pruebas locales: sin riesgo.
- **Bloques sobre .ascx que la 19 retira:** en la copia probada (19-nov) eran 88 tipos / 204 bloques (69 de
  PageMenu); tras migraciones y jobs en la 19 local quedaron **0**. El preflight ahora lo compara en prod (bloque 13).
- La checklist ya trae los datos reales (C:\inetpub\wwwroot, Default Web Site, DefaultAppPool) y la carpeta de
  respaldo C:\deploy-backup\upgrade-19.8.1\: el día de la ventana no hay que sustituir nada.

### A2 — preflight de la BD de prod (2026-11-25 09:17, desde el servidor web con `Invoke-SqlDesdeWeb.ps1`)

| Bloque | Resultado |
|---|---|
| 1. SQL Server | 16.0.4230.2 (SQL Server 2022) Standard: ✅ (la 19 pide 2016+) |
| 2. BD | Compatibilidad 160, recuperación SIMPLE, ONLINE: ✅ |
| 3. Tamaño | Datos 7,852 MB usados de 20,680 MB reservados; log 88 de 1,032 MB (disco C: del servidor SQL) |
| 4. Espacio libre del disco SQL | **No se pudo ver**: la cuenta del sitio no tiene VIEW SERVER STATE. Se resuelve con el ensayo de respaldo (abajo) |
| 5. Respaldos | Hay un **respaldo completo diario a las ~12:39** (nombres GUID: lo hace un servicio externo, probablemente Azure Backup). Es una red de seguridad extra, pero restaurarlo requiere el acceso a Azure que no se transfirió |
| 6–7. Migraciones core y plugins | **Idénticas a la copia probada** (707 del core; 16 plugins): ✅ |
| 8. Reservas dominicales | `NULL`: C8 **sí** se corre en la ventana |
| 9 y 13. Bloques WebForms | 1,030 bloques; sobre `.ascx` que la 19 retira: **88 tipos / 204 bloques = copia probada** ✅ |
| 10. Actividad | `SesionesALaBD = 0` **no es real** (sin VIEW SERVER STATE solo se ve la propia sesión). **119 check-ins abiertos hoy** (miércoles 09:17): hay uso entre semana; la ventana debe ir en un horario sin check-in |
| 11. Tablas grandes | Como la copia (History 3.8 M, AttributeValue 590 mil) |
| 12. Cifrados V2 | 92 valores cifrados, **0** con el pie V2: ✅ |
| 14. Permisos | sysadmin 0, dbcreator 0, **db_owner 1, dueña de la BD 1, puede respaldar 1**: «OK: puede respaldar y restaurar». Carpeta de respaldos por defecto: `…\MSSQL16.MSSQLSERVER\MSSQL\Backup` |

**Respaldo y reversa sin acceso a la VM SQL (probado 2026-11-25):** `19.8.1_respaldo_bd.sql` (C3) y
`19.8.1_reversa_restaurar_bd.sql` (E2) se corrieron en local, con `Invoke-SqlDesdeWeb.ps1`, como una cuenta con los
mismos permisos que la del sitio (`0|0|1|1|1|0`): el respaldo salió con checksum (VERIFYONLY se niega por permisos,
como se esperaba), un cambio posterior se deshizo al restaurar y las guardas (BD equivocada, sin `-BaseMaster`) no
dejaron hacer nada. También se probó `QREVENT_SundayService_SlotSettings.sql` (C8) con el ejecutor (lotes `GO`,
idempotente) y `19.8.1_linea_base.sql` (C10).

**Pendiente antes de fijar la fecha — ensayo del respaldo en prod** (decisión de Fredy): correr C3 una vez, en un
horario tranquilo y lejos de las 12:39. Deja `Rock18_antes_19.8.1.bak` en el servidor SQL (el de la ventana lo
reemplaza, no se acumulan). Confirma en prod que el permiso funciona y da el tiempo y el tamaño; si el disco no
alcanzara, SQL falla sin dañar nada y lo sabríamos antes de la ventana (cubre el bloque 4).
