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
    Y la carpeta herramientas\ (scripts de análisis y fusión del web.config, SQL del día, plantillas de web.config del
    repo y los documentos de la checklist), para usarla en el servidor (CHECKLIST_PRODUCCION_19.8.1.md).

.PARAMETER Destino
    Carpeta nueva FUERA del repo (no debe existir). Con -SoloHerramientas: un kit ya armado.

.PARAMETER Base
    Rama o commit de referencia para los archivos versionados cambiados. Default: hotfix-18.1.

.PARAMETER SoloHerramientas
    No arma RockWeb\: solo agrega herramientas\ a un kit existente (no toca RockWeb\ ni el manifiesto).

.EXAMPLE
    .\"Dev Tools\Upgrade\New-KitUpgrade.ps1" -Destino ..\kit_19.8.1_2026-11-24
.EXAMPLE
    .\"Dev Tools\Upgrade\New-KitUpgrade.ps1" -Destino ..\kit_19.8.1_2026-11-23 -SoloHerramientas
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Destino,
    [string]$Base = 'hotfix-18.1',
    [switch]$SoloHerramientas
)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path

# Carpeta herramientas\ del kit: lo que se usa en el servidor el día del upgrade.
function New-Herramientas([string]$kit) {
    $h = Join-Path $kit 'herramientas'
    if (Test-Path -LiteralPath $h) { throw "Ya existe $h (borrarla a mano si se quiere regenerar)." }
    New-Item -ItemType Directory $h | Out-Null
    foreach ($f in 'Dev Tools\Upgrade\Get-DiagnosticoServidor.ps1', 'Dev Tools\Upgrade\Get-RockWebInventario.ps1',
                   'Dev Tools\Upgrade\New-WebConfigFusionado.ps1', 'Dev Tools\Upgrade\Get-MuestrasProd.ps1',
                   'Dev Tools\Upgrade\19.8.1_preflight_bd_prod.sql',
                   'Dev Tools\Upgrade\19.8.1_job_reemplazo_bloques_huerfanos.sql', 'Dev Tools\Sql\QREVENT_SundayService_SlotSettings.sql',
                   'docs\HANDOFF\upgrade-19.8.1\CHECKLIST_PRODUCCION_19.8.1.md', 'docs\HANDOFF\upgrade-19.8.1\GUIA_FALLAS_PAGOS_19.8.1.md') {
        Copy-Item -LiteralPath (Join-Path $repo $f) -Destination $h
    }
    # Plantillas de web.config tal como están en git (bytes exactos): la de la 19 (HEAD) y la de la 18.1 ($Base).
    foreach ($par in @(@('HEAD', 'web.config.19-plantilla'), @($Base, 'web.config.18.1-plantilla'))) {
        $destino = Join-Path $h $par[1]
        cmd /c "git show $($par[0]):RockWeb/web.config > `"$destino`""
        if ($LASTEXITCODE -ne 0 -or (Get-Item -LiteralPath $destino).Length -eq 0) { throw "No se pudo extraer $($par[0]):RockWeb/web.config" }
    }
    Write-Host "herramientas\: $((Get-ChildItem -LiteralPath $h -File).Count) archivos -> $h" -ForegroundColor Green
}

Push-Location $repo
try {
    if (git status --porcelain) { throw 'El repo tiene cambios sin commitear: el kit debe salir de un commit (ver la ayuda: checkin-theme.css).' }
    if (-not [IO.Path]::IsPathRooted($Destino)) { $Destino = Join-Path (Get-Location) $Destino }
    $Destino = [IO.Path]::GetFullPath($Destino)
    if ($Destino.StartsWith($repo + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'El destino debe quedar fuera del repo.' }
    if ($SoloHerramientas) {
        if (-not (Test-Path -LiteralPath (Join-Path $Destino 'MANIFIESTO_SHA256.csv'))) { throw "$Destino no parece un kit (falta MANIFIESTO_SHA256.csv)." }
        New-Herramientas $Destino
        return
    }
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
    New-Herramientas $Destino
    Write-Host "KIT OK: $($man.Count) archivos, $([math]::Round($bytes / 1MB)) MB -> $Destino" -ForegroundColor Green
}
finally { Pop-Location }
