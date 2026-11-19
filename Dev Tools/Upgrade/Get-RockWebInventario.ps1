<#
.SYNOPSIS
    Inventario de SOLO LECTURA de la carpeta RockWeb (ruta, tamaño, fecha y SHA256 de cada archivo).

.DESCRIPTION
    Pensado para correrse en el SERVIDOR DE PRODUCCIÓN antes del upgrade a Rock 19.8.1, para detectar
    archivos que existen o cambiaron en prod y no están en el repo (ver docs/HANDOFF/UPGRADE_19.8.1.md §11).

    Garantías:
      - No modifica, mueve ni borra nada dentro de RockWeb. Solo lee metadatos y calcula hashes.
      - Se niega a escribir la salida dentro de RockWeb.
      - NO lee web.config ni ningún *ConnectionStrings*.config (se listan con tamaño y fecha, sin hash).
      - Content\, App_Data\ y Cache\ no se recorren archivo por archivo: solo se cuentan archivos y
        tamaño total (por subcarpeta de primer nivel).
      - No sale a la red ni toca IIS, la BD ni el registro.

    Salida (en -CarpetaSalida):
      RockWeb_inventario_<equipo>_<fecha>.csv   Ruta,Bytes,Modificado,SHA256
      RockWeb_excluidas_<equipo>_<fecha>.csv    Carpeta,Archivos,Bytes
      RockWeb_inventario_<equipo>_<fecha>.txt   resumen (totales, duración, errores de lectura)

.PARAMETER RockWeb
    Carpeta RockWeb del sitio (la que IIS sirve). Obligatorio.

.PARAMETER CarpetaSalida
    Dónde escribir los CSV. Por omisión, el Escritorio del usuario. No puede estar dentro de RockWeb.

.PARAMETER SinValidarBin
    No exige Bin\Rock.dll. Solo para inventariar la referencia (worktree de hotfix-18.1) en la máquina
    de desarrollo; en el servidor no hace falta.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File .\Get-RockWebInventario.ps1 -RockWeb "D:\inetpub\RockWeb"

.NOTES
    Compatible con Windows PowerShell 5.1 (Windows Server). Con ~25 000 archivos tarda unos minutos;
    se puede correr con el sitio arriba (los DLL de Bin se leen sin bloquearlos).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$RockWeb,
    [string]$CarpetaSalida = [Environment]::GetFolderPath('Desktop'),
    # Para inventariar un worktree de git (referencia), que no tiene Bin\Rock.dll compilado.
    [switch]$SinValidarBin
)

$ErrorActionPreference = 'Stop'

$raiz = (Resolve-Path -LiteralPath $RockWeb).ProviderPath.TrimEnd('\')
if (-not $SinValidarBin -and -not (Test-Path -LiteralPath (Join-Path $raiz 'Bin\Rock.dll'))) {
    throw "No parece una carpeta RockWeb (no existe Bin\Rock.dll): $raiz"
}
if (-not (Test-Path -LiteralPath $CarpetaSalida)) { throw "No existe la carpeta de salida: $CarpetaSalida" }
$salida = (Resolve-Path -LiteralPath $CarpetaSalida).ProviderPath.TrimEnd('\')
if (($salida + '\').StartsWith($raiz + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw "La carpeta de salida no puede estar dentro de RockWeb: $salida"
}

# Carpetas de primer nivel que solo se cuentan.
$excluidas = @('Content', 'App_Data', 'Cache')
# Archivos que no se leen (sin hash): configuración con secretos.
function Test-SinHash([string]$nombre) {
    return ($nombre -ieq 'web.config') -or ($nombre -like '*ConnectionStrings*') -or ($nombre -ieq 'web.ConnectionStrings.config')
}

$sello = Get-Date -Format 'yyyy-MM-dd_HHmm'
$equipo = $env:COMPUTERNAME
$csv = Join-Path $salida "RockWeb_inventario_${equipo}_$sello.csv"
$csvEx = Join-Path $salida "RockWeb_excluidas_${equipo}_$sello.csv"
$txt = Join-Path $salida "RockWeb_inventario_${equipo}_$sello.txt"

$inicio = Get-Date
$errores = New-Object System.Collections.Generic.List[string]
$sha = [System.Security.Cryptography.SHA256]::Create()

function Get-Sha256([string]$ruta) {
    # FileShare.ReadWrite para poder leer archivos que IIS tiene abiertos; acceso solo de lectura.
    $fs = [System.IO.File]::Open($ruta, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite -bor [System.IO.FileShare]::Delete)
    try { return ([BitConverter]::ToString($sha.ComputeHash($fs))).Replace('-', '') }
    finally { $fs.Dispose() }
}

# 1. Carpetas excluidas: solo conteo y tamaño, por subcarpeta de primer nivel.
$filasEx = foreach ($c in $excluidas) {
    $p = Join-Path $raiz $c
    if (-not (Test-Path -LiteralPath $p)) { [pscustomobject]@{ Carpeta = $c; Archivos = 0; Bytes = 0 }; continue }
    $grupos = @{}
    Get-ChildItem -LiteralPath $p -Recurse -File -Force -ErrorAction SilentlyContinue -ErrorVariable +errLectura | ForEach-Object {
        $rel = $_.FullName.Substring($raiz.Length + 1)
        $partes = $rel.Split('\')
        $clave = if ($partes.Count -gt 2) { $partes[0] + '\' + $partes[1] } else { $partes[0] + '\(archivos sueltos)' }
        if (-not $grupos.ContainsKey($clave)) { $grupos[$clave] = @(0, [int64]0) }
        $grupos[$clave][0]++
        $grupos[$clave][1] += $_.Length
    }
    if ($grupos.Count -eq 0) { [pscustomobject]@{ Carpeta = $c; Archivos = 0; Bytes = 0 } }
    foreach ($k in ($grupos.Keys | Sort-Object)) { [pscustomobject]@{ Carpeta = $k; Archivos = $grupos[$k][0]; Bytes = $grupos[$k][1] } }
}
$filasEx | Export-Csv -LiteralPath $csvEx -NoTypeInformation -Encoding UTF8

# 2. Todo lo demás: ruta, tamaño, fecha, SHA256.
$n = 0
# Se recorren solo las carpetas de primer nivel no excluidas (Content, App_Data y Cache ni se abren).
$origen = @(Get-ChildItem -LiteralPath $raiz -File -Force) +
          @(Get-ChildItem -LiteralPath $raiz -Directory -Force | Where-Object { $excluidas -notcontains $_.Name } |
            ForEach-Object { Get-ChildItem -LiteralPath $_.FullName -Recurse -File -Force -ErrorAction SilentlyContinue -ErrorVariable +errLectura })
$filas = $origen |
    ForEach-Object {
        $n++
        if ($n % 2000 -eq 0) { Write-Host "  $n archivos..." }
        $rel = $_.FullName.Substring($raiz.Length + 1)
        $hash = ''
        if (Test-SinHash $_.Name) { $hash = '(omitido: configuracion)' }
        else {
            try { $hash = Get-Sha256 $_.FullName }
            catch { $hash = '(error de lectura)'; $errores.Add("$rel :: $($_.Exception.Message)") }
        }
        [pscustomobject]@{
            Ruta       = $rel
            Bytes      = $_.Length
            Modificado = $_.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')
            SHA256     = $hash
        }
    }
$filas | Sort-Object Ruta | Export-Csv -LiteralPath $csv -NoTypeInformation -Encoding UTF8
$sha.Dispose()

foreach ($e in $errLectura) { $errores.Add("listado :: $($e.TargetObject) :: $($e.Exception.Message)") }

$dur = (Get-Date) - $inicio
$resumen = @(
    "Inventario de RockWeb (solo lectura)"
    "Equipo:            $equipo"
    "RockWeb:           $raiz"
    "Fecha:             $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    "Archivos con hash: $(@($filas).Count)"
    "Bytes (con hash):  $((@($filas) | Measure-Object Bytes -Sum).Sum)"
    "Excluidas:         $($excluidas -join ', ') (ver $([IO.Path]::GetFileName($csvEx)))"
    "Duracion:          $([int]$dur.TotalSeconds) s"
    "Errores:           $($errores.Count)"
) + ($errores | ForEach-Object { "  $_" })
$resumen | Set-Content -LiteralPath $txt -Encoding UTF8
$resumen | Select-Object -First 9 | ForEach-Object { Write-Host $_ }
Write-Host "Salida:"
Write-Host "  $csv"
Write-Host "  $csvEx"
Write-Host "  $txt"
