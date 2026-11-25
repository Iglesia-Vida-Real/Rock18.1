<#
.SYNOPSIS
    Corre un archivo .sql contra la BD de Rock DESDE EL SERVIDOR WEB, con la misma conexión que usa el sitio
    (RockWeb\web.ConnectionStrings.config, nombre RockContext). No muestra ni guarda la cadena de conexión.

.DESCRIPTION
    Pensado para cuando no hay Escritorio remoto ni SSMS en el servidor SQL (2026-11-25: el acceso a la VM SQL no se
    transfirió en el traspaso). Lo usa la CHECKLIST para el preflight (A2) y, si los permisos alcanzan, para el
    respaldo y la reversa de la ventana.

    - Lee la cadena RockContext y solo cambia Application Name (y, con -BaseMaster, Initial Catalog=master).
    - Muestra y guarda los PRINT, los mensajes de progreso (BACKUP ... STATS) y los resultados en texto con '|'.
    - Los errores de SQL se muestran en rojo y quedan en el archivo; no detienen el resto del archivo .sql.
    - Sin tiempo límite por consulta (un BACKUP puede tardar varios minutos).
    - El archivo .sql no debe usar GO (si lo trae, se parte en lotes por cada línea 'GO').
    - Guarda la salida en el Escritorio (nunca dentro de RockWeb).

    Lo que haga depende del .sql: el preflight es solo lectura; los de respaldo/restauración NO.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File .\Invoke-SqlDesdeWeb.ps1 -Archivo .\19.8.1_preflight_bd_prod.sql

.NOTES
    Windows PowerShell 5.1. Responsable del upgrade: Fredy Ramirez.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Archivo,
    [string]$RockWeb = 'C:\inetpub\wwwroot',
    [switch]$BaseMaster,
    [string]$Salida
)
$ErrorActionPreference = 'Stop'
$sqlPath = (Resolve-Path -LiteralPath $Archivo).ProviderPath
$cfg = Join-Path $RockWeb 'web.ConnectionStrings.config'
if (-not (Test-Path -LiteralPath $cfg)) { throw "No existe $cfg" }
if (-not $Salida) {
    $Salida = Join-Path ([Environment]::GetFolderPath('Desktop')) (
        [IO.Path]::GetFileNameWithoutExtension($sqlPath) + '_resultado_' + (Get-Date -Format 'yyyyMMdd_HHmm') + '.txt')
}
$raiz = (Resolve-Path -LiteralPath $RockWeb).ProviderPath.TrimEnd('\')
if (([IO.Path]::GetFullPath($Salida)).StartsWith($raiz + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'La salida no puede quedar dentro de RockWeb.' }

[xml]$x = Get-Content -LiteralPath $cfg -Raw
$nodo = $x.SelectSingleNode("//connectionStrings/add[@name='RockContext']")
if (-not $nodo) { throw "No hay una cadena 'RockContext' en $cfg" }
$csb = New-Object System.Data.SqlClient.SqlConnectionStringBuilder($nodo.GetAttribute('connectionString'))
$csb['Application Name'] = 'Upgrade19-Invoke-SqlDesdeWeb'
if ($BaseMaster) { $csb['Initial Catalog'] = 'master' }
$baseDestino = $csb['Initial Catalog']

$sb = New-Object System.Text.StringBuilder
function Out-Linea([string]$t, [string]$color) {
    [void]$sb.AppendLine($t)
    if ($color) { Write-Host $t -ForegroundColor $color } else { Write-Host $t }
}
Out-Linea ("Invoke-SqlDesdeWeb — {0} — {1} — BD: {2} (cadena RockContext del sitio; no se muestra)" -f
    (Split-Path $sqlPath -Leaf), (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $baseDestino)

$con = New-Object System.Data.SqlClient.SqlConnection($csb.ConnectionString)
$con.FireInfoMessageEventOnUserErrors = $true
$con.add_InfoMessage({
    param($s, $e)
    foreach ($er in $e.Errors) {
        if ($er.Class -gt 10) { Out-Linea ("ERROR SQL {0} (nivel {1}, línea {2}): {3}" -f $er.Number, $er.Class, $er.LineNumber, $er.Message) 'Red' }
        else { Out-Linea $er.Message }
    }
})
$con.Open()
try {
    $texto = [IO.File]::ReadAllText($sqlPath)
    $lotes = [regex]::Split($texto, '(?im)^\s*GO\s*$') | Where-Object { $_.Trim() }
    foreach ($lote in $lotes) {
        $cmd = $con.CreateCommand(); $cmd.CommandText = $lote; $cmd.CommandTimeout = 0
        $rd = $cmd.ExecuteReader()
        try {
            do {
                if ($rd.FieldCount -gt 0) {
                    $cols = @(0..($rd.FieldCount - 1) | ForEach-Object { $rd.GetName($_) })
                    Out-Linea ($cols -join '|')
                    while ($rd.Read()) {
                        $vals = @(0..($rd.FieldCount - 1) | ForEach-Object { if ($rd.IsDBNull($_)) { 'NULL' } else { [string]$rd.GetValue($_) } })
                        $linea = $vals -join '|'
                        Out-Linea $linea $(if ($linea -match 'REVISAR') { 'Yellow' } elseif ($linea -match '\bOK\b') { 'Green' } else { $null })
                    }
                }
            } while ($rd.NextResult())
        } finally { $rd.Close() }
    }
} finally { $con.Close() }

[IO.File]::WriteAllText($Salida, $sb.ToString(), (New-Object System.Text.UTF8Encoding($true)))
$revisar = ([regex]::Matches($sb.ToString(), 'REVISAR')).Count
$errores = ([regex]::Matches($sb.ToString(), 'ERROR SQL')).Count
Write-Host ''
Write-Host "LISTO. Resultado: $Salida   (líneas REVISAR: $revisar, errores SQL: $errores)" -ForegroundColor Green
