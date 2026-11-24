<#
.SYNOPSIS
    Diagnóstico de SOLO LECTURA del servidor web de producción antes del upgrade a Rock 19.8.1.

.DESCRIPTION
    Junta en una carpeta (y un .zip) lo que hace falta para decidir «ir / no ir» y preparar la ventana
    (docs/HANDOFF/upgrade-19.8.1/CHECKLIST_PRODUCCION_19.8.1.md, fase A):

      1. Equipo: Windows, PowerShell, .NET Framework (la 19 exige 4.7.2+), IIS, zona horaria.
      2. IIS: sitios, bindings y ruta física; app pool del sitio de Rock (CLR, pipeline, identidad, reciclado).
      3. RockWeb: versión y hash de las DLL del fork y de los plugins; DLL del Rock Shop; tamaños por carpeta;
         si hay app_offline.htm.
      4. web.config: SOLO valores no secretos (RunJobsInIISContext, customErrors, debug, targetFramework…), la
         lista de NOMBRES de appSettings (para la fusión con el de la 19) y un hash corto de cada llave
         (DataEncryptionKey, PasswordKey, OldDataEncryptionKey*, machineKey) para comparar después sin verlas.
      5. web.ConnectionStrings.config: solo servidor y base (sin usuario ni contraseña), para correr el preflight.
      6. Discos: espacio libre.
      7. Tema del kiosco: copia _css-overrides.less (si existe), checkin-theme.less y checkin-theme.css.
      8. ¿Hay sqlcmd en este equipo? Errores de ASP.NET en el Visor de eventos (solo conteos).
      9. Opcional (-ConInventario): corre Get-RockWebInventario.ps1 si está en la misma carpeta.

    Garantías: no modifica nada (ni IIS, ni RockWeb, ni el registro); no imprime ningún secreto; escribe solo en
    la carpeta de salida (por omisión, el Escritorio) y se niega a escribir dentro de RockWeb.

.PARAMETER RockWeb
    Ruta física de RockWeb. Si se omite, se toma la del sitio de IIS cuyo binding contiene -Sitio.

.PARAMETER Sitio
    Texto para encontrar el sitio en IIS por binding o nombre. Por omisión: 'personas'.

.PARAMETER SoloLlaves
    Solo calcula los hashes de las llaves del web.config indicado en -WebConfig (paso 6c: comparar el
    web.config fusionado de la 19 contra el de la 18.1 sin mostrar las llaves).

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\Desktop\Get-DiagnosticoServidor.ps1"
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File .\Get-DiagnosticoServidor.ps1 -RockWeb "D:\inetpub\RockWeb" -ConInventario
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File .\Get-DiagnosticoServidor.ps1 -SoloLlaves -WebConfig "D:\upgrade\web.config.19"

.NOTES
    Windows PowerShell 5.1 (Windows Server). Se puede correr con el sitio arriba. Responsable del upgrade:
    Fredy Ramirez. La salida contiene el nombre del servidor SQL: no subirla al repo.
#>
[CmdletBinding()]
param(
    [string]$RockWeb,
    [string]$Sitio = 'personas',
    [string]$CarpetaSalida = [Environment]::GetFolderPath('Desktop'),
    [switch]$ConInventario,
    [switch]$SoloLlaves,
    [string]$WebConfig
)

$ErrorActionPreference = 'Stop'
$lineas = New-Object System.Collections.Generic.List[string]
function Add-Linea([string]$t = '') { $lineas.Add($t); Write-Host $t }
function Add-Titulo([string]$t) { Add-Linea ''; Add-Linea ('== ' + $t) }

# Hash corto (12 hex) de un secreto: sirve para comparar dos valores sin revelarlos.
function Get-HashCorto([string]$valor) {
    if ([string]::IsNullOrEmpty($valor)) { return '(vacío)' }
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $b = $sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($valor)) } finally { $sha.Dispose() }
    return (-join ($b[0..5] | ForEach-Object { $_.ToString('x2') })) + " (largo $($valor.Length))"
}

function Get-LlavesWebConfig([string]$ruta) {
    [xml]$x = Get-Content -LiteralPath $ruta -Raw -Encoding UTF8
    $res = [ordered]@{}
    foreach ($add in @($x.configuration.appSettings.add)) {
        if ($add -and ($add.key -in 'DataEncryptionKey', 'PasswordKey' -or $add.key -like 'OldDataEncryptionKey*')) {
            $res[$add.key] = Get-HashCorto $add.value
        }
    }
    $mk = $x.configuration.'system.web'.machineKey
    if ($mk) {
        $res['machineKey.validationKey'] = Get-HashCorto $mk.validationKey
        $res['machineKey.decryptionKey'] = Get-HashCorto $mk.decryptionKey
    }
    return $res
}

# ---------------------------------------------------------------------------------------------------
if ($SoloLlaves) {
    if (-not $WebConfig -or -not (Test-Path -LiteralPath $WebConfig)) { throw 'Con -SoloLlaves hay que indicar -WebConfig con un archivo existente.' }
    Add-Linea "Hashes cortos de las llaves de: $WebConfig"
    Add-Linea 'Comparar con los del web.config de la 18.1 (diagnóstico, sección 4). Deben ser IDÉNTICOS.'
    (Get-LlavesWebConfig $WebConfig).GetEnumerator() | ForEach-Object { Add-Linea ('  {0,-28} {1}' -f $_.Key, $_.Value) }
    return
}

$equipo = $env:COMPUTERNAME
$sello = Get-Date -Format 'yyyyMMdd_HHmm'
if (-not (Test-Path -LiteralPath $CarpetaSalida)) { throw "No existe la carpeta de salida: $CarpetaSalida" }
$salida = Join-Path (Resolve-Path -LiteralPath $CarpetaSalida).ProviderPath "Diagnostico_Rock_${equipo}_$sello"

Add-Linea "Diagnóstico del servidor para el upgrade a Rock 19.8.1 — $equipo — $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
Add-Linea 'Solo lectura. No contiene secretos (las llaves aparecen solo como hash corto).'

# 1. Equipo ------------------------------------------------------------------------------------------
Add-Titulo '1. Equipo'
try {
    $os = Get-CimInstance Win32_OperatingSystem
    Add-Linea "Windows: $($os.Caption) $($os.Version)  | Encendido desde: $($os.LastBootUpTime)"
} catch { Add-Linea "Windows: no se pudo leer ($($_.Exception.Message))" }
Add-Linea "PowerShell: $($PSVersionTable.PSVersion)"
$rel = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -ErrorAction SilentlyContinue).Release
$netOk = if ($rel -ge 461808) { 'OK (>= 4.7.2)' } else { 'REVISAR: la 19 exige .NET Framework 4.7.2 o más nuevo' }
Add-Linea ".NET Framework release: $rel -> $netOk"
$iis = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\InetStp' -ErrorAction SilentlyContinue
Add-Linea "IIS: $(if ($iis) { "$($iis.MajorVersion).$($iis.MinorVersion)" } else { 'no instalado o sin permiso de lectura' })"
Add-Linea "Zona horaria: $((Get-TimeZone).Id)"

# 2. IIS ---------------------------------------------------------------------------------------------
Add-Titulo '2. IIS (sitios y app pool)'
$sitioRock = $null
try {
    Import-Module WebAdministration -ErrorAction Stop
    foreach ($s in Get-ChildItem IIS:\Sites) {
        $binds = ($s.bindings.Collection | ForEach-Object { "$($_.protocol) $($_.bindingInformation)" }) -join '; '
        Add-Linea ("Sitio: {0} | estado {1} | pool {2} | ruta {3}" -f $s.Name, $s.State, $s.applicationPool, $s.physicalPath)
        Add-Linea ("       bindings: {0}" -f $binds)
        if (-not $sitioRock -and ($s.Name -like "*$Sitio*" -or $binds -like "*$Sitio*")) { $sitioRock = $s }
    }
    # Prod (2026-11-24) sirve personas.vidareal.tv desde «Default Web Site» con bindings comodín (*:80, *:443):
    # si hay un solo sitio, es ese.
    $todos = @(Get-ChildItem IIS:\Sites)
    if (-not $sitioRock -and $todos.Count -eq 1) { $sitioRock = $todos[0]; Add-Linea "Único sitio de IIS: se toma '$($sitioRock.Name)'." }
    if ($sitioRock) {
        $pool = Get-Item ("IIS:\AppPools\" + $sitioRock.applicationPool)
        Add-Linea "Sitio de Rock: $($sitioRock.Name)"
        Add-Linea ("App pool {0}: CLR {1} | pipeline {2} | identidad {3} | estado {4}" -f $pool.Name, $pool.managedRuntimeVersion, $pool.managedPipelineMode, $pool.processModel.identityType, $pool.state)
        Add-Linea ("   reciclado periódico: {0} | idle timeout: {1} | inicio: {2}" -f $pool.recycling.periodicRestart.time, $pool.processModel.idleTimeout, $pool.startMode)
        if (-not $RockWeb) { $RockWeb = [Environment]::ExpandEnvironmentVariables($sitioRock.physicalPath) }
    } else { Add-Linea "No se encontró un sitio cuyo nombre o binding contenga '$Sitio' (usar -Sitio o -RockWeb)." }
} catch { Add-Linea "Módulo WebAdministration no disponible: $($_.Exception.Message). Indicar -RockWeb a mano." }

if (-not $RockWeb) { throw 'No se pudo determinar RockWeb. Correr de nuevo con -RockWeb "<ruta física>".' }
$raiz = (Resolve-Path -LiteralPath $RockWeb).ProviderPath.TrimEnd('\')
if (-not (Test-Path -LiteralPath (Join-Path $raiz 'Bin\Rock.dll'))) { throw "No parece RockWeb (falta Bin\Rock.dll): $raiz" }
if (($salida + '\').StartsWith($raiz + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'La salida no puede quedar dentro de RockWeb.' }
New-Item -ItemType Directory -Force $salida | Out-Null

# 3. RockWeb -----------------------------------------------------------------------------------------
Add-Titulo "3. RockWeb: $raiz"
Add-Linea "app_offline.htm presente: $(Test-Path -LiteralPath (Join-Path $raiz 'app_offline.htm'))  | plantilla app_offline-template.htm: $(Test-Path -LiteralPath (Join-Path $raiz 'app_offline-template.htm'))"
$bin = Join-Path $raiz 'Bin'
Add-Linea 'DLL del fork y de los plugins (deben ser de un mismo build; hoy 18.1):'
$propias = 'Rock.dll', 'Rock.Blocks.dll', 'Rock.ViewModels.dll', 'Rock.Rest.dll', 'Rock.Common.dll', 'Rock.Enums.dll', 'Rock.WhatsApp.dll',
           'com.vidareal.Events.dll', 'com.vidareal.Wallet.dll', 'com.vidareal.DupDetect.dll', 'com.vidareal.Translator.dll', 'com.vidareal.Qr.dll',
           'OdooEventSale.dll', 'EpayVisanetGateway.dll', 'CybersourceInlineRestGateway.dll', 'Rock.SignNow.dll', 'SignNowSDK.dll'
foreach ($n in $propias) {
    $f = Join-Path $bin $n
    if (Test-Path -LiteralPath $f) {
        $i = Get-Item -LiteralPath $f
        Add-Linea ('  {0,-34} ver {1,-12} {2,10:N0} B  {3:yyyy-MM-dd HH:mm}  sha {4}' -f $n, $i.VersionInfo.FileVersion, $i.Length, $i.LastWriteTime, (Get-FileHash -LiteralPath $f -Algorithm SHA256).Hash.Substring(0, 12))
    } else { Add-Linea ('  {0,-34} (no existe)' -f $n) }
}
Add-Linea 'DLL del Rock Shop (se conservan; el kit no las trae):'
Get-ChildItem -LiteralPath $bin -File | Where-Object { $_.Name -match '^(com\.bemaservices\.|MailChimp\.Net|com\.blueboxmoon\.|com\.minecartstudio\.|tech\.triumph\.)' } |
    ForEach-Object { Add-Linea ('  {0,-44} ver {1}' -f $_.Name, $_.VersionInfo.FileVersion) }
Add-Linea 'Carpetas de Plugins\:'
Get-ChildItem -LiteralPath (Join-Path $raiz 'Plugins') -Directory -ErrorAction SilentlyContinue | ForEach-Object { Add-Linea "  $($_.Name)" }
Add-Linea 'Tamaño por carpeta de primer nivel (MB, archivos):'
$totalMB = 0
foreach ($d in Get-ChildItem -LiteralPath $raiz -Directory) {
    $m = Get-ChildItem -LiteralPath $d.FullName -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum
    $mb = [math]::Round(($m.Sum / 1MB), 1); $totalMB += $mb
    Add-Linea ('  {0,-24} {1,10:N1} MB {2,9:N0}' -f $d.Name, $mb, $m.Count)
}
Add-Linea ('  TOTAL carpetas: {0:N1} MB (la copia de respaldo de RockWeb necesita al menos esto libre)' -f $totalMB)

# 4. web.config --------------------------------------------------------------------------------------
Add-Titulo '4. web.config (sin secretos)'
$wc = Join-Path $raiz 'web.config'
[xml]$x = Get-Content -LiteralPath $wc -Raw -Encoding UTF8
$app = @{}; foreach ($a in @($x.configuration.appSettings.add)) { if ($a) { $app[$a.key] = $a.value } }
foreach ($k in 'RunJobsInIISContext', 'AllowDuplicateGroupMembers', 'EnableRestApi', 'CacheManagerEnableStatistics') {
    if ($app.ContainsKey($k)) { Add-Linea ('  {0} = {1}' -f $k, $app[$k]) }
}
$sw = $x.configuration.'system.web'
Add-Linea ('  customErrors mode = {0} | compilation debug = {1} targetFramework = {2} | httpRuntime targetFramework = {3}, maxRequestLength = {4}' -f $sw.customErrors.mode, $sw.compilation.debug, $sw.compilation.targetFramework, $sw.httpRuntime.targetFramework, $sw.httpRuntime.maxRequestLength)
Add-Linea ('  machineKey presente: {0} (validation {1}, decryption {2})' -f [bool]$sw.machineKey, $sw.machineKey.validation, $sw.machineKey.decryption)
Add-Linea '  Hash corto de las llaves (paso 6c: el web.config de la 19 debe dar EXACTAMENTE los mismos):'
(Get-LlavesWebConfig $wc).GetEnumerator() | ForEach-Object { Add-Linea ('    {0,-28} {1}' -f $_.Key, $_.Value) }
Add-Linea "  Nombres de appSettings ($($app.Count)), para la fusión con el web.config de la 19 (sin valores):"
Add-Linea ('    ' + (($app.Keys | Sort-Object) -join ', '))

# 5. Conexión a la BD (sin credenciales) -------------------------------------------------------------
Add-Titulo '5. Base de datos (solo servidor y nombre; sin usuario ni contraseña)'
$cs = Join-Path $raiz 'web.ConnectionStrings.config'
if (Test-Path -LiteralPath $cs) {
    [xml]$c = Get-Content -LiteralPath $cs -Raw -Encoding UTF8
    foreach ($e in @($c.connectionStrings.add)) {
        if (-not $e) { continue }
        $b = New-Object System.Data.Common.DbConnectionStringBuilder; $b.set_ConnectionString($e.connectionString)
        $srv = foreach ($k in 'Data Source', 'Server', 'Address') { if ($b.ContainsKey($k)) { $b[$k]; break } }
        $bd = foreach ($k in 'Initial Catalog', 'Database') { if ($b.ContainsKey($k)) { $b[$k]; break } }
        $integ = $b.ContainsKey('Integrated Security') -and "$($b['Integrated Security'])" -match '^(true|sspi|yes)$'
        Add-Linea ('  {0}: servidor = {1} | base = {2} | autenticación = {3}' -f $e.name, $srv, $bd, $(if ($integ) { 'Windows' } else { 'SQL (usuario en el archivo; no se muestra)' }))
    }
} else { Add-Linea '  No existe web.ConnectionStrings.config en RockWeb.' }
$sqlcmd = Get-Command sqlcmd.exe -ErrorAction SilentlyContinue
Add-Linea "  sqlcmd en este equipo: $(if ($sqlcmd) { $sqlcmd.Source } else { 'NO (correr el preflight desde SSMS en el servidor SQL)' })"

# 6. Discos ------------------------------------------------------------------------------------------
Add-Titulo '6. Discos'
Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | ForEach-Object {
    Add-Linea ('  {0} libre {1,8:N1} GB de {2,8:N1} GB' -f $_.DeviceID, ($_.FreeSpace / 1GB), ($_.Size / 1GB))
}
Add-Linea '  Se necesita libre en el disco de RockWeb: copia de RockWeb (sección 3) + ~0.6 GB del kit + margen.'

# 7. Tema del kiosco ---------------------------------------------------------------------------------
Add-Titulo '7. Tema del kiosco (VidAventuracheckin)'
$estilos = Join-Path $raiz 'Themes\VidAventuracheckin\Styles'
foreach ($n in '_css-overrides.less', 'checkin-theme.less', 'checkin-theme.css') {
    $f = Join-Path $estilos $n
    if (Test-Path -LiteralPath $f) {
        Copy-Item -LiteralPath $f -Destination (Join-Path $salida $n)
        $i = Get-Item -LiteralPath $f
        Add-Linea ('  {0,-22} {1,9:N0} B  {2:yyyy-MM-dd HH:mm}  (copiado)' -f $n, $i.Length, $i.LastWriteTime)
    } else { Add-Linea ('  {0,-22} NO EXISTE' -f $n) }
}

# 8. Visor de eventos --------------------------------------------------------------------------------
Add-Titulo '8. Errores de ASP.NET en el Visor de eventos (últimos 7 días; solo conteos)'
try {
    $ev = Get-WinEvent -FilterHashtable @{ LogName = 'Application'; Level = 2, 3; StartTime = (Get-Date).AddDays(-7) } -ErrorAction Stop |
          Where-Object { $_.ProviderName -like 'ASP.NET*' }
    $ev | Group-Object Id | Sort-Object Count -Descending | ForEach-Object { Add-Linea ('  Id {0}: {1} eventos' -f $_.Name, $_.Count) }
    if (-not $ev) { Add-Linea '  Ninguno.' }
} catch { Add-Linea "  Sin eventos o sin permiso: $($_.Exception.Message)" }

# 9. Inventario (opcional) ---------------------------------------------------------------------------
if ($ConInventario) {
    Add-Titulo '9. Inventario de RockWeb'
    $inv = Join-Path $PSScriptRoot 'Get-RockWebInventario.ps1'
    if (Test-Path -LiteralPath $inv) { & $inv -RockWeb $raiz -CarpetaSalida $salida; Add-Linea '  Inventario generado en la carpeta de salida.' }
    else { Add-Linea "  No está Get-RockWebInventario.ps1 junto a este script ($PSScriptRoot)." }
}

$reporte = Join-Path $salida "diagnostico_${equipo}_$sello.txt"
$lineas | Out-File -LiteralPath $reporte -Encoding utf8
$zip = "$salida.zip"
Compress-Archive -Path (Join-Path $salida '*') -DestinationPath $zip -Force
Add-Linea ''
Add-Linea "LISTO. Carpeta: $salida"
Add-Linea "      Zip:     $zip   <- traer este archivo (no subirlo al repo: trae el nombre del servidor SQL)."
