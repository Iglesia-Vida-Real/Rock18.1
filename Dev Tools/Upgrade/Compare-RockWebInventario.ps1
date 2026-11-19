<#
.SYNOPSIS
    Compara el inventario de RockWeb del servidor contra el de una referencia (repo) y clasifica las
    diferencias. Se corre en la MÁQUINA DE DESARROLLO, no en el servidor. Solo lee los dos CSV.

.DESCRIPTION
    Entrada: dos CSV generados por Get-RockWebInventario.ps1 (columnas Ruta,Bytes,Modificado,SHA256):
      -Servidor    el que se corrió en prod.
      -Referencia  el de un worktree limpio de la rama que se supone está en prod (hotfix-18.1):
                     git worktree add ..\Rock-ref-prod hotfix-18.1
                     .\Get-RockWebInventario.ps1 -RockWeb ..\Rock-ref-prod\RockWeb -SinValidarBin -CarpetaSalida <x>
                   (El worktree hace checkout con core.autocrlf igual que esta máquina.)

    Salida: un CSV con Categoria,Ruta,Bytes servidor/referencia,Fecha servidor y un resumen en consola.
      SOLO_SERVIDOR     existe en prod y no en el repo: candidato a "cambio hecho en prod" o a archivo de
                        terceros/generado (Bin, Obsidian, temas compilados). Revisar uno por uno lo que no
                        sea Bin\ ni Obsidian\.
      DISTINTO          existe en ambos con distinto SHA256: editado en prod, o desplegado desde otro commit.
      SOLO_REFERENCIA   está en el repo y no en prod: no se desplegó (o se borró en prod).
      IGUAL             (solo se cuenta).

    Carpetas que en el repo no tienen sus binarios (Bin\*.dll, Obsidian\*.obs.js, temas compilados)
    salen como SOLO_SERVIDOR por diseño; se marcan con Generado=Si para filtrarlas.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Servidor,
    [Parameter(Mandatory = $true)][string]$Referencia,
    [string]$Salida = (Join-Path ([IO.Path]::GetDirectoryName((Resolve-Path $Servidor).ProviderPath)) 'RockWeb_comparacion.csv')
)
$ErrorActionPreference = 'Stop'

$srv = @{}; Import-Csv -LiteralPath $Servidor | ForEach-Object { $srv[$_.Ruta.ToLowerInvariant()] = $_ }
$ref = @{}; Import-Csv -LiteralPath $Referencia | ForEach-Object { $ref[$_.Ruta.ToLowerInvariant()] = $_ }

function Test-Generado([string]$ruta) {
    return ($ruta -match '^(?i)(Bin\\|Obsidian\\|obj\\)') -or
           ($ruta -match '(?i)\.(dll|pdb|xml|obs\.js|obs\.js\.map|refresh)$' -and $ruta -match '^(?i)(Bin|Plugins)\\') -or
           ($ruta -match '^(?i)Themes\\(RockNextGen|RockManagerNextGen|NextGenCheckin)\\') -or
           ($ruta -match '^(?i)Styles\\styles-v2\\') -or
           ($ruta -match '(?i)\.css$' -and $ruta -match '^(?i)Themes\\')   # CSS compilado desde LESS en runtime
}

$filas = New-Object System.Collections.Generic.List[object]
$iguales = 0
foreach ($k in $srv.Keys) {
    $s = $srv[$k]
    if ($ref.ContainsKey($k)) {
        $r = $ref[$k]
        if ($s.SHA256 -eq $r.SHA256) { $iguales++; continue }
        $cat = 'DISTINTO'
    } else { $r = $null; $cat = 'SOLO_SERVIDOR' }
    $filas.Add([pscustomobject]@{
        Categoria = $cat; Ruta = $s.Ruta; Generado = $(if (Test-Generado $s.Ruta) { 'Si' } else { 'No' })
        BytesServidor = $s.Bytes; BytesReferencia = $(if ($r) { $r.Bytes } else { '' }); FechaServidor = $s.Modificado
    })
}
foreach ($k in $ref.Keys) {
    if (-not $srv.ContainsKey($k)) {
        $r = $ref[$k]
        $filas.Add([pscustomobject]@{
            Categoria = 'SOLO_REFERENCIA'; Ruta = $r.Ruta; Generado = $(if (Test-Generado $r.Ruta) { 'Si' } else { 'No' })
            BytesServidor = ''; BytesReferencia = $r.Bytes; FechaServidor = ''
        })
    }
}
$filas | Sort-Object Categoria, Generado, Ruta | Export-Csv -LiteralPath $Salida -NoTypeInformation -Encoding UTF8

Write-Host "Iguales: $iguales"
$filas | Group-Object Categoria, Generado | Sort-Object Name | Format-Table @{n='Categoria, Generado';e={$_.Name}}, Count -AutoSize | Out-String | Write-Host
Write-Host "Lo que importa revisar (Generado=No), por carpeta de primer nivel:"
$filas | Where-Object { $_.Generado -eq 'No' } | Group-Object Categoria, { $_.Ruta.Split('\')[0] } |
    Sort-Object Count -Descending | Select-Object -First 30 | Format-Table Name, Count -AutoSize | Out-String | Write-Host
Write-Host "Detalle: $Salida"
