<#
.SYNOPSIS
    Genera el web.config de la 19 para producción: plantilla de la 19 + los valores propios de prod.

.DESCRIPTION
    Entre 18.1 y 19.8.1 upstream cambió en web.config sobre todo redirecciones de ensamblados (bindingRedirect) y la
    lista de ensamblados a compilar. Por eso la fusión parte de la PLANTILLA de la 19 (RockWeb/web.config del repo,
    rama del upgrade) y le copia de prod:
      - TODOS los valores de appSettings (las llaves DataEncryptionKey, PasswordKey, OldDataEncryptionKey*, etc.).
      - El elemento machineKey completo.
      - customErrors (mode, defaultRedirect) y compilation/@debug.
    Luego pone RunJobsInIISContext=False para la ventana (anota el valor original para devolverlo al final).

    Además, si se indica la plantilla de la 18.1 (-WebConfig181), compara prod contra ella y LISTA todo lo que prod
    tiene distinto fuera de appSettings/machineKey/assemblyBinding (reglas, cabeceras, handlers, location…): eso no se
    copia solo y hay que revisarlo a mano. Los valores con nombre sensible (key, pass, secret, token, connection)
    se muestran enmascarados.

    Verificación final obligatoria: los hashes de las llaves del archivo generado deben ser IDÉNTICOS a los de prod;
    si no, el script falla y no deja el archivo.

    No toca el web.config de prod: solo lo lee. Escribe únicamente -Salida (por omisión, junto a este script).

.PARAMETER WebConfigProd
    El web.config actual de producción (18.1). Solo se lee.

.PARAMETER WebConfig19
    Plantilla de la 19: RockWeb/web.config del repo en la rama Test_Update_18.1_a_19.8.1 (viene en el kit como
    web.config.19-plantilla).

.PARAMETER WebConfig181
    Opcional. Plantilla de la 18.1: RockWeb/web.config de hotfix-18.1 (en el kit como web.config.18.1-plantilla).

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File .\New-WebConfigFusionado.ps1 -WebConfigProd "D:\inetpub\RockWeb\web.config" -WebConfig19 .\web.config.19-plantilla -WebConfig181 .\web.config.18.1-plantilla

.NOTES
    Windows PowerShell 5.1. Responsable del upgrade: Fredy Ramirez. El archivo generado contiene las llaves de prod:
    tratarlo como secreto (no copiarlo fuera del servidor, no subirlo al repo).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$WebConfigProd,
    [Parameter(Mandatory = $true)][string]$WebConfig19,
    [string]$WebConfig181,
    [string]$Salida
)

$ErrorActionPreference = 'Stop'
# En Windows PowerShell 5.1 $PSScriptRoot llega vacío en los valores por defecto de param() con -File (falló en prod
# el 2026-11-24); se resuelve aquí.
if (-not $Salida) { $Salida = Join-Path $PSScriptRoot 'web.config.19-fusionado' }
if (-not [IO.Path]::IsPathRooted($Salida)) { $Salida = Join-Path (Get-Location).ProviderPath $Salida }
$Salida = [IO.Path]::GetFullPath($Salida)

function Read-Xml([string]$ruta) {
    if (-not (Test-Path -LiteralPath $ruta)) { throw "No existe: $ruta" }
    $d = New-Object System.Xml.XmlDocument
    $d.PreserveWhitespace = $true
    $d.Load((Resolve-Path -LiteralPath $ruta).ProviderPath)
    return $d
}
function Get-HashCorto([string]$v) {
    if ([string]::IsNullOrEmpty($v)) { return '(vacío)' }
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $b = $sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($v)) } finally { $sha.Dispose() }
    return (-join ($b[0..5] | ForEach-Object { $_.ToString('x2') })) + " (largo $($v.Length))"
}
function Get-Llaves([xml]$x) {
    $r = [ordered]@{}
    foreach ($a in @($x.SelectNodes('/configuration/appSettings/add'))) {
        $k = $a.GetAttribute('key')
        if ($k -in 'DataEncryptionKey', 'PasswordKey' -or $k -like 'OldDataEncryptionKey*') { $r[$k] = Get-HashCorto $a.GetAttribute('value') }
    }
    $mk = $x.SelectSingleNode('/configuration/system.web/machineKey')
    if ($mk) { $r['machineKey.validationKey'] = Get-HashCorto $mk.GetAttribute('validationKey'); $r['machineKey.decryptionKey'] = Get-HashCorto $mk.GetAttribute('decryptionKey') }
    return $r
}
$sensible = '(?i)key|pass|secret|token|connection|pwd'

$prod = Read-Xml $WebConfigProd
$nuevo = Read-Xml $WebConfig19

Write-Host "Fusión: plantilla 19 = $WebConfig19 ; valores de prod = $WebConfigProd"

# 1. appSettings -------------------------------------------------------------------------------------
$apNuevo = $nuevo.SelectSingleNode('/configuration/appSettings')
$copiadas = 0; $agregadas = @()
foreach ($a in @($prod.SelectNodes('/configuration/appSettings/add'))) {
    $k = $a.GetAttribute('key'); $v = $a.GetAttribute('value')
    $dest = $apNuevo.SelectSingleNode("add[@key='$k']")
    if (-not $dest) {
        $dest = $nuevo.CreateElement('add'); $dest.SetAttribute('key', $k)
        $apNuevo.AppendChild($nuevo.CreateWhitespace("`r`n    ")) | Out-Null
        $apNuevo.AppendChild($dest) | Out-Null
        $agregadas += $k
    }
    $dest.SetAttribute('value', $v); $copiadas++
}
$soloEn19 = @($apNuevo.SelectNodes('add') | ForEach-Object { $_.GetAttribute('key') } | Where-Object { -not $prod.SelectSingleNode("/configuration/appSettings/add[@key='$_']") })
Write-Host "appSettings copiados de prod: $copiadas (agregados porque la plantilla no los tenía: $($agregadas -join ', '))"
if ($soloEn19) { Write-Host "Solo en la plantilla de la 19 (quedan con el valor de la plantilla; revisar): $($soloEn19 -join ', ')" }

# 2. RunJobsInIISContext=False para la ventana --------------------------------------------------------
$rj = $apNuevo.SelectSingleNode("add[@key='RunJobsInIISContext']")
$rjOriginal = if ($rj) { $rj.GetAttribute('value') } else { '(no existía)' }
if (-not $rj) { $rj = $nuevo.CreateElement('add'); $rj.SetAttribute('key', 'RunJobsInIISContext'); $apNuevo.AppendChild($rj) | Out-Null }
$rj.SetAttribute('value', 'False')
Write-Host "RunJobsInIISContext: en prod era '$rjOriginal' -> en el fusionado 'False' (devolverlo al final de la ventana, CHECKLIST fase F)"

# 3. machineKey y system.web propios de prod ----------------------------------------------------------
$swNuevo = $nuevo.SelectSingleNode('/configuration/system.web')
$mkProd = $prod.SelectSingleNode('/configuration/system.web/machineKey')
$mkNuevo = $swNuevo.SelectSingleNode('machineKey')
if ($mkProd) {
    $importado = $nuevo.ImportNode($mkProd, $true)
    if ($mkNuevo) { $swNuevo.ReplaceChild($importado, $mkNuevo) | Out-Null } else { $swNuevo.AppendChild($importado) | Out-Null }
    Write-Host 'machineKey: copiado de prod.'
} else { Write-Host 'machineKey: prod no tiene; queda el de la plantilla (REVISAR: la plantilla trae llaves de dev).' }
foreach ($par in @(@('customErrors', 'mode'), @('customErrors', 'defaultRedirect'), @('compilation', 'debug'))) {
    $p = $prod.SelectSingleNode("/configuration/system.web/$($par[0])"); $n = $swNuevo.SelectSingleNode($par[0])
    if ($p -and $n -and $p.HasAttribute($par[1])) { $n.SetAttribute($par[1], $p.GetAttribute($par[1])); Write-Host ("{0}/@{1} = {2} (de prod)" -f $par[0], $par[1], $p.GetAttribute($par[1])) }
}

# 4. Diferencias de prod contra la plantilla 18.1 (lo que no se copia solo) --------------------------
if ($WebConfig181) {
    $ref = Read-Xml $WebConfig181
    function Get-Firmas([xml]$d) {
        $out = New-Object System.Collections.Generic.HashSet[string]
        foreach ($e in $d.SelectNodes('//*')) {
            $ruta = @(); $p = $e; while ($p -and $p.NodeType -eq 'Element') { $ruta = ,$p.LocalName + $ruta; $p = $p.ParentNode }
            $rs = $ruta -join '/'
            if ($rs -match '^configuration/(appSettings|runtime)(/|$)' -or $rs -eq 'configuration/system.web/machineKey') { continue }
            $attrs = @($e.Attributes | Sort-Object Name | ForEach-Object { if ($_.Name -match $sensible) { "$($_.Name)=***" } else { "$($_.Name)=$($_.Value)" } }) -join ' '
            [void]$out.Add("$rs [$attrs]")
        }
        return ,$out
    }
    $fp = Get-Firmas $prod; $fr = Get-Firmas $ref
    $soloProd = @($fp | Where-Object { -not $fr.Contains($_) } | Sort-Object)
    $soloRef = @($fr | Where-Object { -not $fp.Contains($_) } | Sort-Object)
    Write-Host ''
    Write-Host "== Prod vs plantilla 18.1 (fuera de appSettings, machineKey y assemblyBinding): $($soloProd.Count) líneas solo en prod, $($soloRef.Count) solo en la plantilla"
    Write-Host '   Lo que está SOLO EN PROD es configuración propia del servidor: decidir si se agrega a mano al fusionado.'
    $soloProd | ForEach-Object { Write-Host "   + prod : $_" }
    $soloRef | ForEach-Object { Write-Host "   - plant: $_" }
}

# 5. Verificación de llaves y guardado ---------------------------------------------------------------
$hp = Get-Llaves $prod; $hn = Get-Llaves $nuevo
$distintas = @($hp.Keys | Where-Object { $hp[$_] -ne $hn[$_] })
Write-Host ''
Write-Host '== Llaves (hash corto): prod vs fusionado'
$hp.Keys | ForEach-Object { Write-Host ('   {0,-28} prod {1,-26} fusionado {2}' -f $_, $hp[$_], $hn[$_]) }
if ($distintas.Count -gt 0 -or $hp.Count -eq 0) { throw "Las llaves del fusionado NO coinciden con prod ($($distintas -join ', ')). No se guardó nada." }
if (Test-Path -LiteralPath $Salida) { throw "Ya existe $Salida (no se sobrescribe)." }
$nuevo.Save($Salida)
Write-Host ''
Write-Host "OK: llaves idénticas a prod. Guardado en: $Salida"
Write-Host 'Siguiente: revisar las líneas «solo en prod» de arriba; en la ventana copiar este archivo como RockWeb\web.config (CHECKLIST fase C).'
