<#
.SYNOPSIS
    Verifica (SOLO LECTURA) que la máquina tenga lo necesario para compilar y correr el fork Rock
    de Iglesia Vida Real. No instala, no modifica nada.

.DESCRIPTION
    Revisa toolchain (Visual Studio/MSBuild, .NET Framework 4.7.2 targeting pack, .NET SDK, Node,
    npm, git), SQL Server, IIS Express, espacio en disco y los archivos que NO vienen en el clon
    (web.ConnectionStrings.config, DLLs de terceros del Rock Shop, node_modules, bundles).
    También detecta archivos rellenados con bytes nulos en RockWeb\Plugins (incidente 2026-08-05).

    Versiones de referencia = máquina del dev original al 2026-10-15:
      VS Community 2026 (18.8) / MSBuild 18.8, .NET SDK 10.0.302, Node 22.15.1, npm 10.9.2,
      git 2.55, SQL Server (instancia MSSQLSERVER) + sqlcmd, IIS Express.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File ".\Dev Tools\Build\check-prereqs.ps1"
#>
[CmdletBinding()]
param()

$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$script:fails = 0
$script:warns = 0

function Ok($msg)   { Write-Host "  [OK]   $msg" -ForegroundColor Green }
function Warn($msg) { Write-Host "  [WARN] $msg" -ForegroundColor Yellow; $script:warns++ }
function Fail($msg) { Write-Host "  [FAIL] $msg" -ForegroundColor Red; $script:fails++ }

Write-Host "Repo: $repo`n"

# --- Sistema operativo ----------------------------------------------------------------------
Write-Host 'Sistema'
$os = Get-CimInstance Win32_OperatingSystem
Ok "$($os.Caption) $($os.Version)"
$drive = (Get-Item $repo).PSDrive
$freeGb = [math]::Round($drive.Free / 1GB, 1)
if ($freeGb -lt 10) { Warn "Solo $freeGb GB libres en $($drive.Name): (build + node_modules piden ~10 GB)" } else { Ok "$freeGb GB libres en $($drive.Name):" }

# --- Visual Studio / MSBuild ----------------------------------------------------------------
Write-Host "`nVisual Studio / MSBuild"
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
$msbuild = $null
if (Test-Path $vswhere) {
    # -requires MSBuild: sin esto -latest puede devolver SQL Server Management Studio (también usa el instalador de VS)
    $vs = & $vswhere -latest -prerelease -products * -requires Microsoft.Component.MSBuild -format json | ConvertFrom-Json
    if ($vs) { Ok "$($vs.displayName) $($vs.installationVersion)" }
    $msbuild = & $vswhere -latest -prerelease -products * -requires Microsoft.Component.MSBuild -find 'MSBuild\**\Bin\amd64\MSBuild.exe' | Select-Object -First 1
}
if ($msbuild) {
    $v = (& $msbuild -version -nologo | Select-Object -Last 1)
    Ok "MSBuild $v ($msbuild)"
} else {
    Fail 'MSBuild no encontrado. Instalar Visual Studio 2022+ con "ASP.NET y desarrollo web".'
}

# --- .NET Framework -------------------------------------------------------------------------
Write-Host "`n.NET"
$release = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -ErrorAction SilentlyContinue).Release
if ($release -ge 528040) { Ok ".NET Framework runtime 4.8+ (release $release)" } else { Fail ".NET Framework 4.8 runtime no detectado (release=$release)" }
$ref472 = "${env:ProgramFiles(x86)}\Reference Assemblies\Microsoft\Framework\.NETFramework\v4.7.2"
if (Test-Path $ref472) { Ok 'Targeting pack .NET Framework 4.7.2' } else { Fail 'Falta el targeting pack .NET Framework 4.7.2 (componente de VS Installer)' }
$dotnet = Get-Command dotnet -ErrorAction SilentlyContinue
if ($dotnet) { Ok ".NET SDK $(& dotnet --version)" } else { Warn '.NET SDK no encontrado (lo usan los restore de los plugins SDK-style)' }

# --- Node / npm / git -----------------------------------------------------------------------
Write-Host "`nNode / npm / git"
$node = Get-Command node -ErrorAction SilentlyContinue
if ($node) {
    $nv = (& node --version).TrimStart('v')
    $major = [int]($nv.Split('.')[0])
    if ($major -ge 18) { Ok "Node $nv" } else { Fail "Node ${nv}: se requiere 18+ (referencia: 22.15.1)" }
} else { Fail 'Node.js no encontrado (necesario para los bundles Obsidian)' }
$npm = Get-Command npm -ErrorAction SilentlyContinue
if ($npm) { Ok "npm $(& npm --version)" } else { Fail 'npm no encontrado' }
$git = Get-Command git -ErrorAction SilentlyContinue
if ($git) { Ok (& git --version) } else { Fail 'git no encontrado' }

# --- SQL Server / IIS Express ---------------------------------------------------------------
Write-Host "`nSQL Server / IIS Express"
$sql = Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq 'MSSQLSERVER' -or $_.Name -like 'MSSQL$*' }
if ($sql) { $sql | ForEach-Object { if ($_.Status -eq 'Running') { Ok "Servicio $($_.Name) corriendo" } else { Warn "Servicio $($_.Name) en estado $($_.Status)" } } }
else { Warn 'No hay SQL Server local (válido si se usa uno remoto)' }
if (Get-Command sqlcmd -ErrorAction SilentlyContinue) { Ok 'sqlcmd disponible' } else { Warn 'sqlcmd no encontrado (lo usan los scripts de Dev Tools\Sql y Scripts\VidaReal)' }
if (Test-Path "$env:ProgramFiles\IIS Express\iisexpress.exe") { Ok 'IIS Express instalado' } else { Warn 'IIS Express no encontrado (alternativa: sitio en IIS completo)' }

# --- Archivos que NO vienen en el clon ------------------------------------------------------
Write-Host "`nArchivos locales (no versionados)"
$cs = Join-Path $repo 'RockWeb\web.ConnectionStrings.config'
if (Test-Path $cs) { Ok 'RockWeb\web.ConnectionStrings.config existe (contenido no revisado)' } else { Fail 'Falta RockWeb\web.ConnectionStrings.config (copiar del .example y llenar; ver SETUP_DESARROLLO.md)' }

$bin = Join-Path $repo 'RockWeb\Bin'
if (Test-Path (Join-Path $bin 'Rock.dll')) { Ok 'RockWeb\Bin\Rock.dll presente (core compilado)' } else { Warn 'RockWeb\Bin\Rock.dll no existe: correr Dev Tools\Build\build-all.ps1' }

$ownDlls = 'com.vidareal.Events.dll','com.vidareal.Wallet.dll','com.vidareal.DupDetect.dll','com.vidareal.Translator.dll','com.vidareal.Qr.dll','OdooEventSale.dll','EpayVisanetGateway.dll','CybersourceInlineRestGateway.dll'
$missingOwn = $ownDlls | Where-Object { -not (Test-Path (Join-Path $bin $_)) }
if ($missingOwn) { Warn "Faltan DLLs de plugins propios en RockWeb\Bin: $($missingOwn -join ', ')" } else { Ok 'DLLs de los 8 plugins propios presentes' }

$shopDlls = 'com.bemaservices.MailChimp.dll','com.bemaservices.WorkflowExtensions.dll','com.blueboxmoon.AcmeCertificate.dll','com.blueboxmoon.DataToolkit.dll','com.minecartstudio.MinePass.Client.dll','com.minecartstudio.MinePassCommon.dll','MailChimp.Net.dll','MailChimp.Net.V3.dll','tech.triumph.MinistryPass.Client.dll','tech.triumph.MinistryPass.Common.dll'
$missingShop = $shopDlls | Where-Object { -not (Test-Path (Join-Path $bin $_)) }
if ($missingShop) { Warn "Faltan DLLs de terceros (Rock Shop) en RockWeb\Bin: $($missingShop -join ', ') -- copiarlas del ambiente origen (ONBOARDING §2)" } else { Ok 'DLLs de terceros del Rock Shop presentes' }

foreach ($js in 'Rock.JavaScript.Obsidian','Rock.JavaScript.Obsidian.Blocks') {
    if (Test-Path (Join-Path $repo "$js\node_modules")) { Ok "$js\node_modules presente" } else { Warn "$js\node_modules no existe: correr npm ci en esa carpeta" }
}
if (Test-Path (Join-Path $repo 'RockWeb\Obsidian\Blocks')) { Ok 'RockWeb\Obsidian\Blocks presente (bundles compilados)' } else { Warn 'RockWeb\Obsidian\Blocks no existe: compilar Obsidian' }

# --- Corrupción por bytes nulos (incidente 2026-08-05) -------------------------------------
Write-Host "`nIntegridad de RockWeb\Plugins (bytes nulos)"
$nulled = @()
Get-ChildItem (Join-Path $repo 'RockWeb\Plugins') -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Length -gt 0 } | ForEach-Object {
    $fs = [IO.File]::OpenRead($_.FullName)
    try {
        $buf = New-Object byte[] ([Math]::Min(4096, $_.Length))
        [void]$fs.Read($buf, 0, $buf.Length)
        if (-not ($buf | Where-Object { $_ -ne 0 } | Select-Object -First 1)) { $nulled += $_.FullName }
    } finally { $fs.Dispose() }
}
if ($nulled) { $nulled | ForEach-Object { Fail "Archivo con solo bytes nulos: $_" } } else { Ok 'Ningún archivo de RockWeb\Plugins está rellenado con ceros' }

# --- Resumen --------------------------------------------------------------------------------
Write-Host ''
if ($script:fails -gt 0) { Write-Host "Resultado: $($script:fails) FAIL, $($script:warns) WARN" -ForegroundColor Red; exit 1 }
Write-Host "Resultado: 0 FAIL, $($script:warns) WARN" -ForegroundColor Green
exit 0
