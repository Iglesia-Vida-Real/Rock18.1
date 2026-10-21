# Setup del ambiente de desarrollo

> Objetivo: que un dev nuevo pase de "máquina limpia" a "Rock corriendo en `http://localhost:6229`
> con los módulos de Vida Real" sin ayuda. Verificado en la máquina del dev saliente el
> **2026-10-15** (ver §9, "Qué se verificó").
>
> Credenciales, cadenas de conexión y respaldos de BD **no están en el repo**. Se piden a TI
> (serviciosit@vidareal.tv) o se toman de `ACCESOS_Y_SECRETOS.md` del paquete zip de handoff.

---

## 1. Prerequisitos (versiones exactas de referencia)

Estas son las versiones con las que el build funciona hoy. Versiones más nuevas de lo mismo
probablemente funcionan; más viejas, no garantizado.

| Herramienta | Versión de referencia | Notas |
|---|---|---|
| Windows | 10/11 o Server 2016+ | Obligatorio: Wallet usa `System.Net.Http.WinHttpHandler` (APNs/HTTP2). |
| Visual Studio | **Community 2026 (18.8)** — MSBuild 18.8.2 | VS 2022 (17.x) también sirve. Carga de trabajo **"ASP.NET y desarrollo web"** + componente **".NET Framework 4.7.2 targeting pack"**. Los `.esproj` (proyectos JS de la solución) usan `Microsoft.VisualStudio.JavaScript.Sdk` y necesitan Node en el PATH. |
| .NET Framework | Runtime 4.8 + targeting pack **4.7.2** | Todo el core y los plugins apuntan a `net472` / `targetFramework="4.7.2"`. |
| .NET SDK | 10.0.302 | Solo para `restore` de los proyectos SDK-style (plugins). |
| Node.js | **22.15.1** (mínimo 18) | Para los bundles Obsidian (Vue 3/TypeScript). |
| npm | 10.9.2 | Viene con Node. |
| git | 2.55 | Cualquier 2.4x+ sirve. |
| SQL Server | Developer/Express 2019+ (instancia por defecto `MSSQLSERVER`) | + **SSMS** y **sqlcmd** (los scripts de `Dev Tools\Sql` y `Scripts\VidaReal` usan `sqlcmd -f 65001`). |
| IIS Express | El que trae VS | El sitio corre en `http://localhost:6229` (puerto fijado en `Rock.sln`, `VWDPort = "6229"`). |
| Disco | **≥ 15 GB libres** | `.git` pesa 2.3 GB; `node_modules` + `bin/obj` + `RockWeb\Bin` suman varios GB más. |

Verificación automática (solo lectura, no instala nada):

```powershell
powershell -ExecutionPolicy Bypass -File ".\Dev Tools\Build\check-prereqs.ps1"
```

Sale con código 0 si no hay `[FAIL]`. Los `[WARN]` dicen qué falta copiar o compilar.

---

## 2. Clonar

```powershell
git clone https://github.com/rodobriones/Rock15.5.git C:\repos\Rock15.5
cd C:\repos\Rock15.5
git checkout hotfix-18.1          # rama de trabajo (NO develop; ver ESTADO_REPO.md)
git remote add upstream https://github.com/SparkDevNetwork/Rock.git   # opcional, para comparar con Rock oficial
```

> El nombre de la carpeta dice "Rock15.5" por historia: el código es **Rock RMS 18.1** + módulos
> propios. El repo de GitHub es privado; pedir acceso de colaborador a TI.

---

## 3. Lo que NO viene en el clon

| Qué | Dónde va | Cómo se obtiene |
|---|---|---|
| Cadena de conexión | `RockWeb\web.ConnectionStrings.config` | Copiar `RockWeb\web.ConnectionStrings.config.example` y llenar (§5). |
| Binarios del sitio | `RockWeb\Bin\*.dll` | Se generan al compilar (§6). |
| DLLs de terceros del Rock Shop | `RockWeb\Bin\` | **No salen del build.** Vienen en el zip de traspaso (`dll-terceros\RockWeb-Bin\`, con `SHA256SUMS.txt`); si no, copiarlas de prod (lista en `ONBOARDING.md` §3.1). Sin ellas el sitio puede no arrancar. |
| Bundles Obsidian | `RockWeb\Obsidian\` | Se generan al compilar (§6.3). |
| `node_modules` | `Rock.JavaScript.Obsidian*\` | `npm ci` (§6.3). |
| Media subida | `RockWeb\Content\` | Opcional; copiar del ambiente origen si se necesitan imágenes reales. |
| Respaldo de la BD | — | Pedir a TI (§4). |

`RockWeb\Plugins\` **sí está versionado** (decisión 2026-07-15, ver `RockWeb\Plugins\.gitignore`):
el clon ya trae el Translator, Qrgenerador, TwilioOverride, el front de los gateways y los plugins
de terceros. No restaurar la regla `*/*` de upstream.

---

## 4. Base de datos de desarrollo

**No arrancar contra una BD vacía.** Los módulos propios asumen Global Attributes, páginas,
defined types y tablas `_com_vidareal_*` existentes. Se trabaja sobre una **copia de prod**.

1. Pedir a TI un `.bak` reciente de la BD de producción (nombre de la BD en prod y en dev:
   `Rock18`). El respaldo contiene datos personales de miembros y de menores: es
   confidencial, no sale de la máquina de desarrollo, no se sube a ningún lado.
2. Restaurar en el SQL Server local (SSMS → *Restore Database*, o):

   ```sql
   RESTORE DATABASE [Rock18]
   FROM DISK = N'C:\ruta\al\respaldo.bak'
   WITH MOVE '<logical_data>' TO N'C:\SQLData\Rock18.mdf',
        MOVE '<logical_log>'  TO N'C:\SQLData\Rock18_log.ldf',
        REPLACE, STATS = 10;
   -- RESTORE FILELISTONLY FROM DISK = N'...' para ver los nombres lógicos
   ```

3. Crear un login SQL para el sitio (o usar autenticación integrada) con `db_owner` sobre
   `Rock18`. **El usuario/contraseña no van al repo.**
4. **Aislar dev de prod — obligatorio antes de arrancar el sitio:**
   - Correr `Dev Tools\Sql\Enable_LocalhostDevTesting.sql` (apunta los Global Attributes de URL a
     `http://localhost:6229/` y el SMTP a localhost; usar [Papercut](https://github.com/ChangemakerStudios/Papercut-SMTP) para ver correos).
   - Revisar en *Admin Tools → Communications → Communication Transports* que **WhatsApp, SMS
     (Twilio) y SendGrid** no tengan credenciales de prod activas. Una copia de prod manda mensajes
     reales a miembros reales. Además, con la misma API key de SendGrid, dev marcaría aperturas en
     prod (los GUID de destinatario coinciden entre bases).
   - Gateways de pago (*Admin → Finance → Financial Gateways*): Epay/Cybersource en modo
     sandbox o inactivos.
   - Jobs (*Admin → System Settings → Jobs*): desactivar los que envían comunicaciones o
     sincronizan con Odoo.
5. Al arrancar por primera vez contra una copia de prod, las `[PluginMigration]` que dev tenga
   más nuevas que prod se aplicarán solas (§7). Eso es esperado.

---

## 5. Cadena de conexión

```powershell
Copy-Item RockWeb\web.ConnectionStrings.config.example RockWeb\web.ConnectionStrings.config
```

Editar y poner servidor (`localhost`), BD (`Rock18`), usuario y contraseña. El archivo está en
`.gitignore`; **nunca** commitearlo. (Ver en `ESTADO_REPO.md` el aviso sobre una contraseña local
que quedó en la historia de `hotfix-1.15.5`.)

---

## 6. Compilar

### 6.1 Script único (recomendado)

```powershell
cd C:\repos\Rock15.5
.\"Dev Tools\Build\build-all.ps1"                 # Rock.sln (Release) + 8 plugins, copia a RockWeb\Bin
.\"Dev Tools\Build\build-all.ps1" -SkipCore       # solo plugins
.\"Dev Tools\Build\build-all.ps1" -FullObsidian   # además npm ci/run build completo de Obsidian
.\"Dev Tools\Build\build-all.ps1" -NoCopy         # compila todo SIN tocar RockWeb\Bin (verificación)
```

Si PowerShell bloquea el script: `powershell -ExecutionPolicy Bypass -File ".\Dev Tools\Build\build-all.ps1"`.

### 6.2 Qué hace, en orden (y por qué el orden importa)

1. **`Rock.sln` en Release con MSBuild de VS** (no `dotnet build`: `RockWeb` es un *Web Site
   Project* de ASP.NET WebForms). Llena `RockWeb\Bin` con `Rock.dll`, `Rock.Blocks.dll`,
   `Rock.ViewModels.dll`, `Rock.Rest.dll`, `Rock.WhatsApp.dll`, etc. La copia la hace el target
   `CopyToRockWeb` de `Directory.Build.targets`. Los `.esproj` de la solución corren
   `npm run build-fast` de los proyectos JS (instalan `node_modules` si falta).
   Primera vez: estimado 10–20 min con restore de NuGet (no medido en clon limpio, ver §9).
   Incremental: 1–2 min (medido).
2. **Los 8 plugins** (`Plugin.*`), que **no** están en `Rock.sln` a propósito: referencian
   `RockWeb\Bin\Rock.dll` por HintPath, así que van **después** del core. Se copia a
   `RockWeb\Bin` solo el DLL propio de cada uno:

   | Proyecto | DLL |
   |---|---|
   | `Plugin.VidaRealEvents\VidaRealEvents` | `com.vidareal.Events.dll` |
   | `Plugin.VidaRealWallet\VidaRealWallet` | `com.vidareal.Wallet.dll` |
   | `Plugin.VidaRealDupDetect\VidaRealDupDetect` | `com.vidareal.DupDetect.dll` |
   | `Plugin.VidaRealTranslator\VidaRealTranslator` | `com.vidareal.Translator.dll` |
   | `Plugin.VidaRealQr\VidaRealQr` | `com.vidareal.Qr.dll` (solo migraciones; el módulo QR vive en el core) |
   | `Plugin.OdooEventSale\OdooEventSale` | `OdooEventSale.dll` |
   | `Plugin.EpayVisanetGateway\EpayVisanetGateway` | `EpayVisanetGateway.dll` |
   | `Plugin.CybersourceInlineRestGateway\CybersourceInlineRestGateway` | `CybersourceInlineRestGateway.dll` |

### 6.3 Obsidian (frontend Vue 3 / TypeScript)

El paso 1 ya corre `build-fast`. Para un build completo, o cuando solo cambiaste `.obs`:

```powershell
cd Rock.JavaScript.Obsidian;        npm ci; npm run build
cd ..\Rock.JavaScript.Obsidian.Blocks; npm ci; npm run build
```

Salida: `RockWeb\Obsidian\Blocks\<Módulo>\*.obs.js`.

- **`npm run build` puede devolver 0 aunque un tsconfig falle.** Verificar siempre fecha y tamaño
  del `.obs.js` que te interesa.
- Los avisos "Can't resolve original location" de rollup vienen de `@zxing/browser` (vendor de
  QREVENT), no de nuestros bloques.
- Tras tocar partials de Eventos, confirmar que el bundle servido es el nuevo (historial del bug en
  `docs/eventos-custom/RESEARCH_Y_PLAN.md`).

### 6.4 Avisos esperados del build (no son errores)

- `NU1902/NU1903` por `MessagePack 2.5.198` y `SixLabors.ImageSharp 2.1.10`: vienen de upstream.
- `CS0618 AddPageRoute is obsolete` en migraciones de Events/Wallet.

### 6.5 Soluciones que NO compilan (y no hacen falta)

`Rock.Client.sln`, `Rock.CodeGeneration.sln`, `Applications\RockCloudPrint`,
`Applications\Wpf\*`, `Installers\RockInstaller`: fallan por configuración/WiX/nativos. No
bloquean Rock. No intentar arreglarlas salvo que se necesiten.

---

## 7. Correr local

1. Abrir `Rock.sln` en Visual Studio, proyecto de inicio **`RockWeb`**, F5 (IIS Express,
   `http://localhost:6229`). Alternativa: sitio en IIS completo apuntando a `RockWeb\`.
2. **El primer arranque tarda varios minutos**: `Rock.WebStartup` corre las migraciones core y las
   `[PluginMigration]` de cada plugin. Copiar cualquier DLL a `RockWeb\Bin` reinicia el sitio y la
   primera carga vuelve a tardar 2+ minutos.
3. Logs: `RockWeb\App_Data\Logs\` (`RockExceptions.csv`, `Rock.log`).
4. La primera generación de PDF de boletos descarga Chromium (~150 MB) a `App_Data\ChromeEngine`.
   Necesita salida a internet.
5. Entrar con un usuario admin de la copia de prod (el tuyo, creado por TI).

---

## 8. Problemas típicos

| Síntoma | Causa | Arreglo |
|---|---|---|
| En `RockExceptions.csv` al arrancar: *"A configuration for type 'Rock.Model.AIAgentSessionAnchor' has already been added"* | Las entidades custom del core implementan `IRockEntity`; EF intenta re-registrar configs. Inofensivo (try/catch). | **Ignorar. No parchear `RockContext.cs`**: se probó y se revirtió a propósito para mantener el core igual a upstream. |
| `BadImageFormatException` al arrancar | DLL corrupta en `RockWeb\Bin`, típicamente `com.bemaservices.WorkflowExtensions.dll` (terceros, no está en el repo). | Reemplazarla por la copia del zip de traspaso (`dll-terceros\`, verificar contra `SHA256SUMS.txt`) o por una de prod. |
| Archivo "en blanco" con tamaño normal | Corrupción por apagón: rellenado con bytes nulos (incidente 2026-08-05 en `RockWeb\Plugins`). | `check-prereqs.ps1` lo detecta. Restaurar desde git o respaldo; **verificar bytes nulos después de copiar desde discos externos** (la copia también puede corromperse). |
| Plugin no compila: no encuentra `Rock.dll` | Se compiló el plugin antes que el core. | Compilar `Rock.sln` primero. |
| Página con bloque vacío o `TypeLoadException` / `MissingMethodException` sobre `Rock.ViewModels.Blocks.*` | DLLs del fork desparejadas (p.ej. `Rock.Blocks.dll` nuevo con `Rock.ViewModels.dll` viejo). | Copiar juntos `Rock.dll`, `Rock.Blocks.dll`, `Rock.ViewModels.dll`, `Rock.Rest.dll` del mismo build. |
| Error genérico "/Error.aspx" sin detalle | `web.config` tiene `customErrors mode="On"`. | Ver `RockExceptions.csv` o el Visor de eventos (origen ASP.NET). |
| Un texto en español sale distinto al del código ("Reportería" → "Reportes") o un botón Vue se queda congelado en "Procesando…" | El plugin Translator reemplaza nodos de texto del DOM. | Envolver texto dinámico en `<span class="notranslate">`. |
| Un `.obs.js` no refleja tus cambios | `npm run build` devolvió 0 pero un tsconfig falló; o caché del navegador. | Revisar fecha/tamaño del bundle; recargar sin caché. El fingerprint se recalcula al reiniciar el sitio. |
| Se mandaron correos/WhatsApp reales desde dev | BD copiada de prod sin aislar. | §4 paso 4, antes de arrancar. |

---

## 9. Qué se verificó el 2026-10-15

En la máquina del dev saliente (Windows 11 Pro, VS Community 2026 18.8, Node 22.15.1):

- `check-prereqs.ps1`: 0 FAIL (1 WARN: poco espacio en disco en esa máquina).
- Core con `-p:CopyToRockWeb=False` (Rock.Rest, Rock.Blocks, Rock.WhatsApp en Release): **exit 0**,
  build incremental, solo avisos NU190x.
- `build-all.ps1 -SkipCore -NoCopy`: **los 8 plugins compilan en Release** (1 min 39 s).
- **No** se corrió un build desde cero de `Rock.sln` en un clon limpio (falta de espacio en disco en
  esa máquina). El primer dev que lo haga: anotar aquí tiempo y resultado.
