<#
.SYNOPSIS
    Build completo del fork Rock (Iglesia Vida Real): Rock.sln + 8 plugins + bundles Obsidian.

.DESCRIPTION
    Versión versionada del procedimiento probado (memoria "build_procedure_complete", 2026-07-15,
    ampliado con Plugin.VidaRealQr el 2026-09-28). Orden obligatorio:

      1. Rock.sln (Release)  -> llena RockWeb\Bin (Rock.dll, Rock.Blocks.dll, Rock.ViewModels.dll,
                                Rock.Rest.dll, Rock.WhatsApp.dll, ...). Los .esproj de la solución
                                corren además `npm run build-fast` de los proyectos JS.
      2. Plugins Plugin.*    -> referencian RockWeb\Bin\Rock.dll por HintPath, por eso van DESPUÉS.
                                Se copia a RockWeb\Bin SOLO el DLL propio de cada plugin.
      3. Obsidian (opcional) -> `npm run build` completo de Rock.JavaScript.Obsidian y .Blocks
                                (más lento que el build-fast del paso 1; usar con -FullObsidian).

    No contiene rutas personales ni credenciales. Se ejecuta desde cualquier carpeta: la raíz del
    repo se calcula a partir de la ubicación del script.

.PARAMETER Configuration
    Release (default, es lo que va a producción) o Debug.

.PARAMETER SkipCore
    No compila Rock.sln (útil si solo cambiaste un plugin).

.PARAMETER SkipPlugins
    No compila los Plugin.*.

.PARAMETER FullObsidian
    Corre además `npm ci` (si falta node_modules) y `npm run build` en los proyectos Obsidian.

.PARAMETER NoCopy
    Compila sin escribir en RockWeb\Bin (pasa CopyToRockWeb=False al core y no copia los DLL de
    plugins). Sirve para verificar que todo compila sin pisar los binarios de un ambiente.
    OJO: con -NoCopy el core se compila proyecto por proyecto (Rock.Rest, Rock.Blocks,
    Rock.WhatsApp) en vez de Rock.sln, para no disparar el sitio web ni los .esproj.

.EXAMPLE
    .\"Dev Tools\Build\build-all.ps1"
    .\"Dev Tools\Build\build-all.ps1" -SkipCore
    .\"Dev Tools\Build\build-all.ps1" -NoCopy -SkipCore
#>
[CmdletBinding()]
param(
    [ValidateSet('Release', 'Debug')]
    [string]$Configuration = 'Release',
    [switch]$SkipCore,
    [switch]$SkipPlugins,
    [switch]$FullObsidian,
    [switch]$NoCopy
)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$rockWebBin = Join-Path $repo 'RockWeb\Bin'

# --- Localizar MSBuild (VS 2022 o VS 2026 / v18) con vswhere -------------------------------
function Find-MSBuild {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (Test-Path $vswhere) {
        $path = & $vswhere -latest -prerelease -products * -requires Microsoft.Component.MSBuild `
            -find 'MSBuild\**\Bin\amd64\MSBuild.exe' | Select-Object -First 1
        if ($path) { return $path }
    }
    $cmd = Get-Command msbuild.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    throw 'No se encontró MSBuild. Instalar Visual Studio con la carga "ASP.NET y desarrollo web". Ver docs/HANDOFF/SETUP_DESARROLLO.md'
}

$msbuild = Find-MSBuild
Write-Host "Repo    : $repo"
Write-Host "MSBuild : $msbuild"
Write-Host "Config  : $Configuration$(if ($NoCopy) { ' (NoCopy: RockWeb\Bin no se toca)' })"
$failures = @()
$t0 = Get-Date

# --- Paso 1: core ---------------------------------------------------------------------------
if (-not $SkipCore) {
    if ($NoCopy) {
        foreach ($proj in 'Rock.Rest\Rock.Rest.csproj', 'Rock.Blocks\Rock.Blocks.csproj', 'Rock.WhatsApp\Rock.WhatsApp.csproj') {
            Write-Host "`n[1] Compilando $proj (sin copiar a RockWeb)" -ForegroundColor Cyan
            & $msbuild (Join-Path $repo $proj) -restore "-p:Configuration=$Configuration" -p:CopyToRockWeb=False -m -v:m -nologo
            if ($LASTEXITCODE -ne 0) { $failures += $proj }
        }
    }
    else {
        Write-Host "`n[1] Compilando Rock.sln ($Configuration) -> RockWeb\Bin" -ForegroundColor Cyan
        & $msbuild (Join-Path $repo 'Rock.sln') -restore "-p:Configuration=$Configuration" -m -v:m -nologo
        if ($LASTEXITCODE -ne 0) { $failures += 'Rock.sln' }
    }
    if ($failures.Count -gt 0) {
        Write-Host "`nFalló el core: $($failures -join ', '). Los plugins dependen de Rock.dll; se detiene aquí." -ForegroundColor Red
        exit 1
    }
}

# --- Paso 2: plugins ------------------------------------------------------------------------
# Ninguno está en Rock.sln a propósito: referencian RockWeb\Bin\Rock.dll por HintPath y meterlos
# en la solución crearía un ciclo de orden de build.
$plugins = @(
    @{ Path = 'Plugin.VidaRealEvents\VidaRealEvents';                           Dll = 'com.vidareal.Events.dll' },
    @{ Path = 'Plugin.VidaRealWallet\VidaRealWallet';                           Dll = 'com.vidareal.Wallet.dll' },
    @{ Path = 'Plugin.VidaRealDupDetect\VidaRealDupDetect';                     Dll = 'com.vidareal.DupDetect.dll' },
    @{ Path = 'Plugin.VidaRealTranslator\VidaRealTranslator';                   Dll = 'com.vidareal.Translator.dll' },
    @{ Path = 'Plugin.VidaRealQr\VidaRealQr';                                   Dll = 'com.vidareal.Qr.dll' },
    @{ Path = 'Plugin.OdooEventSale\OdooEventSale';                             Dll = 'OdooEventSale.dll' },
    @{ Path = 'Plugin.EpayVisanetGateway\EpayVisanetGateway';                   Dll = 'EpayVisanetGateway.dll' },
    @{ Path = 'Plugin.CybersourceInlineRestGateway\CybersourceInlineRestGateway'; Dll = 'CybersourceInlineRestGateway.dll' }
)

if (-not $SkipPlugins) {
    if (-not (Test-Path (Join-Path $rockWebBin 'Rock.dll'))) {
        Write-Host "`nNo existe RockWeb\Bin\Rock.dll: compilar el core primero (sin -SkipCore)." -ForegroundColor Red
        exit 1
    }
    foreach ($p in $plugins) {
        $projDir = Join-Path $repo $p.Path
        $proj = Get-ChildItem $projDir -Filter *.csproj | Select-Object -First 1
        $out = Join-Path $projDir "bin\$Configuration\net472\$($p.Dll)"
        Write-Host "`n[2] $($p.Path)" -ForegroundColor Cyan
        & $msbuild $proj.FullName -restore "-p:Configuration=$Configuration" -v:m -nologo
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path $out)) {
            Write-Host "    FALLÓ" -ForegroundColor Red
            $failures += $p.Path
            continue
        }
        if ($NoCopy) {
            Write-Host "    OK -> $out (no copiado)" -ForegroundColor Green
        }
        else {
            Copy-Item $out $rockWebBin -Force
            Write-Host "    OK -> RockWeb\Bin\$($p.Dll)" -ForegroundColor Green
        }
    }
}

# --- Paso 3: Obsidian completo (opcional) ----------------------------------------------------
if ($FullObsidian) {
    foreach ($js in 'Rock.JavaScript.Obsidian', 'Rock.JavaScript.Obsidian.Blocks') {
        $dir = Join-Path $repo $js
        Write-Host "`n[3] npm run build en $js" -ForegroundColor Cyan
        Push-Location $dir
        try {
            if (-not (Test-Path 'node_modules')) { npm ci; if ($LASTEXITCODE -ne 0) { $failures += "$js (npm ci)" } }
            npm run build
            # OJO: `npm run build` puede devolver 0 aunque un tsconfig falle. Verificar fecha/tamaño
            # de los .obs.js en RockWeb\Obsidian\Blocks\<Modulo>\ tras el build.
            if ($LASTEXITCODE -ne 0) { $failures += "$js (npm run build)" }
        }
        finally { Pop-Location }
    }
}

# --- Resumen --------------------------------------------------------------------------------
$elapsed = (Get-Date) - $t0
Write-Host ("`nDuración: {0:hh\:mm\:ss}" -f $elapsed)
if ($failures.Count -gt 0) {
    Write-Host "FALLARON: $($failures -join ', ')" -ForegroundColor Red
    exit 1
}
Write-Host 'BUILD OK' -ForegroundColor Green
Write-Host 'Recordatorio: los DLL de terceros del Rock Shop (BEMA, Blue Box Moon, MinePass, MinistryPass) NO salen de este build; ver ONBOARDING.md §2.'
