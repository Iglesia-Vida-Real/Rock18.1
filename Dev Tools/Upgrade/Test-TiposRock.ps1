<#
.SYNOPSIS
    Verifica que cada BlockType (o EntityType) de una BD de Rock resuelve contra un RockWeb compilado:
    los .ascx existen en disco y los tipos Obsidian/componentes cargan desde RockWeb\Bin. SOLO LECTURA.

.DESCRIPTION
    Entrada: archivo de texto separado por '|' con 9 columnas, sin encabezado:
        Id|Guid|Nombre|Path|Tipo|AssemblyName|Instancias|Categoria|IsSystem
    Se genera con sqlcmd (ver docs/HANDOFF/INVENTARIO_DESARROLLOS_VR.md §5):
        sqlcmd -S localhost -d Rock19Test -E -C -s "|" -W -h -1 -Q "SET NOCOUNT ON; SELECT bt.Id, bt.Guid, bt.Name,
          ISNULL(bt.Path,''), ISNULL(et.Name,''), ISNULL(et.AssemblyName,''), (SELECT COUNT(*) FROM Block b WHERE
          b.BlockTypeId=bt.Id), ISNULL(bt.Category,''), bt.IsSystem FROM BlockType bt LEFT JOIN EntityType et ON
          et.Id=bt.EntityTypeId ORDER BY bt.Id" > blocktypes.txt
    Estados: OK, FALTA_ASCX, FALTA_DLL, TIPO_NO_RESUELVE, SIN_PATH_NI_TIPO.
    Carga los ensamblados en un proceso PowerShell propio: correrlo con
        powershell -NoProfile -ExecutionPolicy Bypass -File Test-TiposRock.ps1 -Entrada ... -RockWeb ... -Salida x.csv
#>
param([string]$Entrada, [string]$RockWeb, [string]$Salida)
$bin = Join-Path $RockWeb 'Bin'
[AppDomain]::CurrentDomain.add_AssemblyResolve({
    param($s, $e)
    $n = (New-Object Reflection.AssemblyName($e.Name)).Name
    $p = Join-Path $bin "$n.dll"
    if (Test-Path $p) { return [Reflection.Assembly]::LoadFrom($p) }
    return $null
})
$cache = @{}
$res = foreach ($line in Get-Content $Entrada -Encoding UTF8) {
    $c = $line.Split('|')
    if ($c.Count -lt 9) { continue }
    $id, $guid, $name, $path, $type, $asm, $inst, $cat, $sys = $c
    $estado = ''; $detalle = ''
    if ($path) {
        $rel = $path -replace '^~/', '' -replace '/', '\'
        $full = Join-Path $RockWeb $rel
        if (Test-Path -LiteralPath $full) { $estado = 'OK' } else { $estado = 'FALTA_ASCX'; $detalle = $rel }
    } elseif ($type) {
        $an = ($asm -split ',')[1]
        if ($an) { $an = $an.Trim() } else { $an = 'Rock' }
        if (-not $cache.ContainsKey($an)) {
            $p = Join-Path $bin "$an.dll"
            try { $cache[$an] = if (Test-Path $p) { [Reflection.Assembly]::LoadFrom($p) } else { $null } } catch { $cache[$an] = $null }
        }
        $a = $cache[$an]
        if (-not $a) { $estado = 'FALTA_DLL'; $detalle = "$an.dll" }
        else {
            try { $t = $a.GetType($type, $false) } catch { $t = $null; $detalle = $_.Exception.Message }
            if ($t) { $estado = 'OK' } else { $estado = 'TIPO_NO_RESUELVE'; if (-not $detalle) { $detalle = "$type en $an" } }
        }
    } else { $estado = 'SIN_PATH_NI_TIPO' }
    [pscustomobject]@{ Id = $id; Guid = $guid; Nombre = $name; Path = $path; Tipo = $type; Instancias = [int]$inst; Categoria = $cat; IsSystem = $sys; Estado = $estado; Detalle = $detalle }
}
$res | Export-Csv $Salida -NoTypeInformation -Encoding UTF8
$res | Group-Object Estado | Select-Object Name, Count | Format-Table -AutoSize
