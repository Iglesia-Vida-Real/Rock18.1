<#
.SYNOPSIS
    Arma el kit del upgrade a Rock 19.8.1 (UPGRADE_19.8.1.md §7.1 paso 7) desde RockWeb ya compilado.

.DESCRIPTION
    Requisitos ANTES de correrlo (si no, el kit no sale de un solo build):
      1. Repo limpio, en el commit que va a producción (el script se niega si hay cambios sin commitear).
         Ojo: Rock recompila Themes\VidAventuracheckin\Styles\checkin-theme.css al arrancar el sitio
         (UPGRADE §14.3); si aparece modificado, restaurarlo con git checkout antes de correr esto.
      2. .\"Dev Tools\Build\build-all.ps1" -FullObsidian, más `npm run build` en
         Rock.JavaScript.Obsidian.Reporting (build-all no lo recompila completo).
      3. Prueba rápida en el sitio local que apunta a este RockWeb.

    Copia a <Destino>\RockWeb:
      - Bin\ completo, SIN las DLLs del Rock Shop (se conservan en el servidor, §7.2) ni SignNow (§7.3 paso 3).
      - Obsidian\, Plugins\{com_vidareal,EpayVisanetGateway,CybersourceInlineRestGateway}\,
        Themes\{RockNextGen,RockManagerNextGen,NextGenCheckin}\, Styles\styles-v2\ (salida del build).
      - Los archivos versionados de RockWeb que cambiaron entre hotfix-18.1 y HEAD, menos web.config.
    Deja además quitar_del_servidor.txt, MANIFIESTO_SHA256.csv (rutas relativas a RockWeb\) y LEEME.txt.
    No copia web.config, web.ConnectionStrings.config, Content\, Cache\ ni secretos; lo verifica al final.

.PARAMETER Destino
    Carpeta nueva FUERA del repo (no debe existir).

.PARAMETER Base
    Rama o commit de referencia para los archivos versionados cambiados. Default: hotfix-18.1.

.EXAMPLE
    .\"Dev Tools\Upgrade\New-KitUpgrade.ps1" -Destino ..\kit_19.8.1_2026-11-24
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Destino,
    [string]$Base = 'hotfix-18.1'
)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Push-Location $repo
try {
    if (git status --porcelain) { throw 'El repo tiene cambios sin commitear: el kit debe salir de un commit (ver la ayuda: checkin-theme.css).' }
    $Destino = [IO.Path]::GetFullPath((Join-Path (Get-Location) $Destino))
    if ($Destino.StartsWith($repo + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'El destino debe quedar fuera del repo.' }
    if (Test-Path $Destino) { throw "Ya existe $Destino" }

    $rw = Join-Path $repo 'RockWeb'
    $dst = Join-Path $Destino 'RockWeb'
    New-Item -ItemType Directory -Force $dst | Out-Null

    function Copy-Relativo([string]$rel) {
        $d = Join-Path $dst $rel
        New-Item -ItemType Directory -Force (Split-Path $d) | Out-Null
        Copy-Item -LiteralPath (Join-Path $rw $rel) -Destination $d -Force
    }

    # 1. Bin sin Rock Shop ni SignNow
    $excluirBin = '^(com\.bemaservices\.|MailChimp\.Net|com\.blueboxmoon\.|com\.minecartstudio\.|tech\.triumph\.|Rock\.SignNow|SignNowSDK)'
    Get-ChildItem (Join-Path $rw 'Bin') -Recurse -File | Where-Object { $_.Name -notmatch $excluirBin } |
        ForEach-Object { Copy-Relativo $_.FullName.Substring($rw.Length + 1) }

    # 2. Carpetas completas (bundles, plugins propios, temas y estilos compilados)
    foreach ($c in 'Obsidian', 'Plugins\com_vidareal', 'Plugins\EpayVisanetGateway', 'Plugins\CybersourceInlineRestGateway',
                   'Themes\RockNextGen', 'Themes\RockManagerNextGen', 'Themes\NextGenCheckin', 'Styles\styles-v2') {
        Get-ChildItem (Join-Path $rw $c) -Recurse -File -Force | ForEach-Object { Copy-Relativo $_.FullName.Substring($rw.Length + 1) }
    }

    # 3. Versionados cambiados contra la base (web.config lo fusiona TI)
    git diff --name-only --diff-filter=AMR $Base HEAD -- RockWeb | Where-Object { $_ -ne 'RockWeb/web.config' } |
        ForEach-Object { Copy-Relativo ($_.Substring('RockWeb/'.Length) -replace '/', '\') }

    # 4. Control: nada que no deba viajar
    $malos = Get-ChildItem $dst -Recurse -File -Force | Where-Object {
        ($_.Name -eq 'web.config' -and $_.DirectoryName -eq $dst) -or $_.Name -eq 'web.ConnectionStrings.config' -or
        $_.Name -match $excluirBin -or $_.FullName -match '\\RockWeb\\(Content|Cache)\\' -or
        $_.Extension -in '.p12', '.pfx', '.bak', '.bacpac' }
    if ($malos) { $malos | ForEach-Object { Write-Host "NO DEBE IR: $($_.FullName)" -ForegroundColor Red }; throw 'El kit trae archivos prohibidos.' }

    # 5. Lista de retiro, manifiesto y LEEME
    Copy-Item 'docs\HANDOFF\upgrade-19.8.1\quitar_del_servidor.txt' $Destino
    $man = Get-ChildItem $dst -Recurse -File -Force | ForEach-Object {
        [pscustomobject]@{ Ruta = $_.FullName.Substring($dst.Length + 1); Bytes = $_.Length; SHA256 = (Get-FileHash $_.FullName -Algorithm SHA256).Hash }
    } | Sort-Object Ruta
    $man | Export-Csv (Join-Path $Destino 'MANIFIESTO_SHA256.csv') -NoTypeInformation -Encoding UTF8
    $bytes = ($man | Measure-Object Bytes -Sum).Sum
    @(
        'Kit del upgrade a Rock 19.8.1'
        "Commit: $(git rev-parse HEAD) ($(git log -1 --format=%s))"
        "Armado: $(Get-Date -Format 'yyyy-MM-dd HH:mm')   Base de los versionados: $Base"
        "Archivos: $($man.Count)   Bytes: $bytes   Hashes: MANIFIESTO_SHA256.csv (rutas relativas a RockWeb\)"
        ''
        'Uso: docs/HANDOFF/UPGRADE_19.8.1.md §7.3: mover lo de quitar_del_servidor.txt (paso 3), copiar RockWeb\ de'
        'este kit ENCIMA del RockWeb del servidor (paso 4) y poner el web.config fusionado por TI (paso 5).'
        'No trae (§7.2): web.config, web.ConnectionStrings.config, Content\, App_Data\ (salvo archivos de upstream'
        'versionados), Cache\, DLLs del Rock Shop, Plugins de terceros.'
    ) | Out-File (Join-Path $Destino 'LEEME.txt') -Encoding utf8
    Write-Host "KIT OK: $($man.Count) archivos, $([math]::Round($bytes / 1MB)) MB -> $Destino" -ForegroundColor Green
}
finally { Pop-Location }
