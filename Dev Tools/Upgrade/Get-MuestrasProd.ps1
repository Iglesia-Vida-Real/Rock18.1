<#
.SYNOPSIS
    Copia de RockWeb de prod (solo lectura) los archivos que el inventario del 2026-11-24 marco como distintos al repo
    o propios de prod, para probarlos en la 19 local antes de la ventana (CHECKLIST fase A, paso A1b).

.DESCRIPTION
    No modifica RockWeb: solo copia a <Escritorio>\muestras_prod_<fecha>\ y arma un .zip.
    No copia web.config, web.ConnectionStrings.config, App_Data, Content ni nada con secretos conocidos.
    Excluye a proposito Blocks\QREVENT\TestCybersource.ascx(.cs): bloque de prueba de pagos que puede traer llaves
    escritas en el codigo; su riesgo (solo afecta su propia pagina) se documenta sin copiarlo.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File .\Get-MuestrasProd.ps1 -RockWeb C:\inetpub\wwwroot

.NOTES
    Windows PowerShell 5.1. Responsable del upgrade: Fredy Ramirez.
#>
[CmdletBinding()]
param(
    [string]$RockWeb = 'C:\inetpub\wwwroot',
    [string]$CarpetaSalida = [Environment]::GetFolderPath('Desktop')
)
$ErrorActionPreference = 'Stop'
$raiz = (Resolve-Path -LiteralPath $RockWeb).ProviderPath.TrimEnd('\')
if (-not (Test-Path -LiteralPath (Join-Path $raiz 'Bin\Rock.dll'))) { throw "No parece RockWeb (falta Bin\Rock.dll): $raiz" }
$dst = Join-Path $CarpetaSalida ('muestras_prod_' + (Get-Date -Format 'yyyyMMdd_HHmm'))
if (($dst + '\').StartsWith($raiz + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'La salida no puede quedar dentro de RockWeb.' }

$archivos = @(
    # App_Code: se compila todo junto; si algo no compila con la 19, se cae el sitio entero (trampa 1)
    'App_Code\WhatsAppSms.ashx.cs', 'App_Code\GetMinePass.cs', 'App_Code\GetMinistryPass.cs',
    'GetMinePass.ashx', 'GetMinistryPass.ashx',
    # Distintos al repo y el kit los sobrescribe con la version de la 19
    'Blocks\CheckIn\TimeSelect.ascx.cs', 'Blocks\Crm\PersonMerge.ascx', 'Blocks\Crm\PersonMerge.ascx.cs',
    'Blocks\Event\RegistrationDetail.ascx.cs', 'Blocks\Event\RegistrationInstanceRegistrationList.ascx.cs',
    'Plugins\CybersourceInlineRestGateway\ObsidianSource\cybersourceInlineRestGatewayControl.obs',
    'Plugins\CybersourceInlineRestGateway\Obsidian\cybersourceInlineRestGatewayControl.obs.js',
    # Distintos al repo y se quedan como estan en prod (el kit no los trae)
    'Scripts\Rock\Controls\datePicker.js',
    'Themes\Rock\Layouts\Blank.aspx', 'Themes\RockManager\Layouts\Blank.aspx', 'Themes\Stark\Layouts\Blank.aspx',
    'Themes\LandingPage\Layouts\Blank.aspx', 'Themes\VidAventuracheckin\Styles\_variable-overrides.less',
    # DLLs que solo existen en prod (restos de instalaciones anteriores; la prueba local no las tuvo)
    'Bin\Apollos.OneSignal.RestAPIv3.Client.dll', 'Bin\apollosProject.OneSignal.dll', 'Bin\ICSharpCode.SharpZipLib.dll',
    'Bin\Microsoft.AspNetCore.WebUtilities.dll', 'Bin\Microsoft.VisualStudio.TestPlatform.TestFramework.dll',
    'Bin\Microsoft.VisualStudio.TestPlatform.TestFramework.Extensions.dll', 'Bin\Rock.Lava.DotLiquid.dll',
    'Bin\Rock.MyWell.dll', 'Bin\Rock.Tests.Shared.dll', 'Bin\System.Reflection.dll', 'Bin\System.Reflection.Extensions.dll',
    'Bin\System.Resources.ResourceManager.dll', 'Bin\System.Runtime.dll', 'Bin\System.Runtime.InteropServices.dll',
    'Bin\System.Threading.dll',
    # DLLs del Rock Shop que usan App_Code\GetMinistryPass.cs / GetMinePass.cs y los .ascx de MinistryPass. Prod tiene
    # una version mas nueva que la de dev (2026-11-24: TemplateDetail.ascx.cs de prod no compila con la DLL de dev).
    'Bin\tech.triumph.MinistryPass.Client.dll', 'Bin\tech.triumph.MinistryPass.Common.dll',
    'Bin\com.minecartstudio.MinePass.Client.dll', 'Bin\com.minecartstudio.MinePassCommon.dll'
)
# Carpetas completas de plugins (codigo de terceros, sin configuracion)
foreach ($c in 'Plugins\tech_triumph\MinistryPass', 'Plugins\apollosproject', 'Plugins\Asistencia') {
    $p = Join-Path $raiz $c
    if (Test-Path -LiteralPath $p) { Get-ChildItem -LiteralPath $p -Recurse -File -Force | ForEach-Object { $archivos += $_.FullName.Substring($raiz.Length + 1) } }
}

New-Item -ItemType Directory $dst | Out-Null
$ok = 0; $faltan = @()
foreach ($r in $archivos) {
    $s = Join-Path $raiz $r
    if (-not (Test-Path -LiteralPath $s)) { $faltan += $r; continue }
    $d = Join-Path $dst $r
    New-Item -ItemType Directory -Force (Split-Path $d) | Out-Null
    Copy-Item -LiteralPath $s -Destination $d
    $ok++
}
$zip = "$dst.zip"
Compress-Archive -Path (Join-Path $dst '*') -DestinationPath $zip
Write-Host "Copiados: $ok archivos (solo lectura sobre $raiz)"
if ($faltan) { Write-Host "No existen en este servidor: $($faltan -join ', ')" -ForegroundColor Yellow }
Write-Host "LISTO. Zip: $zip   <- traer este archivo a la PC de desarrollo (fuera del repo)" -ForegroundColor Green
