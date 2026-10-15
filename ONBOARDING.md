# ONBOARDING — Puerta de entrada

> Fork de **Rock RMS 18.1** de Iglesia Vida Real con módulos propios: Eventos/Boletería, Wallet
> (Apple/Google), QR Generator, QREVENT (reservas dominicales y check-in QR), DAR (donaciones),
> FamilyHub, DupDetect, Odoo FEL, Translator, gateways Epay/Cybersource y WhatsApp.
>
> Última revisión: **2026-10-15** (traspaso del proyecto a un nuevo dev).
> **Mantener actualizado:** si agregás un plugin, una dependencia manual o un paso de setup,
> actualizá este archivo y el doc de `docs/HANDOFF/` que corresponda en el mismo commit.

---

## 1. Ruta de lectura (en este orden)

| # | Documento | Para qué |
|---|---|---|
| 1 | Este archivo | Qué es, qué no viene en el clon, dónde está todo. |
| 2 | [`docs/HANDOFF/SETUP_DESARROLLO.md`](docs/HANDOFF/SETUP_DESARROLLO.md) | Prerequisitos con versiones, clonar, BD de dev, compilar, correr, problemas típicos. |
| 3 | [`docs/HANDOFF/ESTADO_REPO.md`](docs/HANDOFF/ESTADO_REPO.md) | Ramas (cuál es nuestra), commits y cambios pendientes, limpieza recomendada. |
| 4 | [`docs/HANDOFF/DEPLOY_PRODUCCION.md`](docs/HANDOFF/DEPLOY_PRODUCCION.md) | Cómo se despliega, rollback, verificación, y **el último despliegue conocido** (todo en prod al 2026-10-15). |
| 5 | [`CLAUDE.md`](CLAUDE.md) | Arquitectura en una pantalla, comandos, convenciones y **trampas conocidas**. Lo lee Claude Code automáticamente. |
| 6 | [`.claude/CONTEXT_INDEX.md`](.claude/CONTEXT_INDEX.md) | Índice de toda la documentación por módulo. |

Accesos y secretos (GitHub, RDP a prod, SQL, Global Attributes sensibles, certificados) **no están
en el repo**: pedir a TI (serviciosit@vidareal.tv) o ver `ACCESOS_Y_SECRETOS.md` del paquete zip de
handoff.

---

## 2. Arranque rápido

```powershell
git clone https://github.com/rodobriones/Rock15.5.git C:\repos\Rock15.5
cd C:\repos\Rock15.5
git checkout hotfix-18.1                                              # rama viva (NO develop)
powershell -ExecutionPolicy Bypass -File ".\Dev Tools\Build\check-prereqs.ps1"   # solo lectura
Copy-Item RockWeb\web.ConnectionStrings.config.example RockWeb\web.ConnectionStrings.config   # y llenarlo
# restaurar la BD de dev (copia de prod, pedirla a TI) y AISLARLA (SETUP §4)
.\"Dev Tools\Build\build-all.ps1"                                     # Rock.sln + 8 plugins, Release
# copiar a RockWeb\Bin las DLLs de terceros del Rock Shop (§3.1)
# abrir Rock.sln en VS, proyecto de inicio RockWeb, F5 -> http://localhost:6229
```

---

## 3. Qué NO viene en el clon

| No versionado | Qué es | Cómo se repone |
|---|---|---|
| `RockWeb/Bin/*.dll` | Binarios del sitio | `build-all.ps1` (core + plugins propios). Las de terceros: §3.1. |
| `RockWeb/Obsidian/` | Bundles JS de los bloques | Los genera el build (`build-fast`) o `npm run build`. |
| `RockWeb/web.ConnectionStrings.config` | Cadena de conexión | Desde el `.example`; credenciales de TI. |
| `RockWeb/Content/` | Media subida | Opcional, copiar del ambiente origen. |
| Respaldo de BD | `Rock18` | TI. Confidencial. |
| `node_modules`, `bin/`, `obj/` | Artefactos | Se regeneran. |

`RockWeb/Plugins/` **sí está versionado** desde 2026-07-15 (a diferencia de Rock upstream): trae el
front del Translator, `Qrgenerador`, `TwilioOverrideWhatsApp`, el front de los gateways y los
plugins de terceros. No restaurar la regla `*/*` en `RockWeb/Plugins/.gitignore`.

### 3.1 DLLs de terceros que ningún build regenera

Plugins del Rock Shop con DLL en `RockWeb\Bin`. Copiarlas del ambiente origen (prod o la máquina
anterior):

`com.bemaservices.MailChimp.dll`, `com.bemaservices.WorkflowExtensions.dll`,
`com.blueboxmoon.AcmeCertificate.dll`, `com.blueboxmoon.DataToolkit.dll`,
`com.minecartstudio.MinePass.Client.dll`, `com.minecartstudio.MinePassCommon.dll`,
`MailChimp.Net.dll`, `MailChimp.Net.V3.dll`,
`tech.triumph.MinistryPass.Client.dll`, `tech.triumph.MinistryPass.Common.dll`.

`check-prereqs.ps1` avisa si falta alguna. (`Twilio.dll` y `System.Net.Http.WinHttpHandler.dll`
sí las restaura NuGet.) Cuidado: `BranchCleanup.bat` borra todo `RockWeb\Bin\*.dll`.

---

## 4. Mapa de módulos

| Módulo | Código | Doc principal |
|---|---|---|
| Eventos / Boletería | `Rock/Model/Eventos/`, `Rock.Blocks/Eventos/`, `src/Eventos/`, `Plugin.VidaRealEvents` | `docs/eventos-custom/RESEARCH_Y_PLAN.md`, `Rock/Model/Eventos/ARCHITECTURE.md` |
| Wallet | `Rock/Model/Wallet/`, `Rock.Blocks/Wallet/`, `Rock.Rest/VidaReal/`, `Plugin.VidaRealWallet` | `docs/wallet-module/RESEARCH_Y_PLAN.md` |
| QR Generator | `Rock/Model/Qr/`, `Rock.Blocks/Qr/`, `src/Qr/`, `Plugin.VidaRealQr` | `docs/qr-custom/DEPLOY.md`, `Rock/Model/Qr/ARCHITECTURE.md` |
| QREVENT (reservas dominicales, check-in QR) | `Rock.Blocks/QREVENT/`, `src/QREVENT/`, `Dev Tools/Sql/` | `Rock.Blocks/QREVENT/CHANGES.md`, `Dev Tools/Sql/CHANGES.md` |
| GPS (diseño, sin código) | — | `docs/gps-custom/` |
| DAR (donaciones) | `Rock.Blocks/Dar/`, `src/Dar/` | `Rock.Blocks/Dar/CHANGES.md` |
| FamilyHub | `Rock.Blocks/FamilyHub/`, `src/FamilyHub/` | `Rock.Blocks/FamilyHub/CHANGES.md` |
| Odoo FEL | `Plugin.OdooEventSale` + repo `custom_event_sale_api` (addon Odoo 17) | `Plugin.OdooEventSale/CONTEXT.md` |
| Gateways | `Plugin.EpayVisanetGateway`, `Plugin.CybersourceInlineRestGateway` | sus `README.md`/`CHANGES.md` |
| WhatsApp | `Rock.WhatsApp/` | `Rock.WhatsApp/CHANGES.md` |
| Translator | `Plugin.VidaRealTranslator`, `RockWeb/Plugins/com_vidareal/Translator/` | `Plugin.VidaRealTranslator/README.md` |
| DupDetect | `Plugin.VidaRealDupDetect` | `.claude/CONTEXT_INDEX.md` |

---

## 5. Configuración que vive fuera del repo

Viene "gratis" con la copia de la BD, pero hay que saber que existe (valores: TI / paquete de
handoff):

- **Wallet / Apple:** Global Attributes `AppleWalletPassP12` + `AppleWalletPassP12Password`
  (Pass Type ID `pass.tv.vidareal.eventos`, **vence 2027-08-05**). Google:
  `GoogleWalletIssuerId` / `GoogleWalletServiceAccountJson` (cuenta emisor pendiente).
- **Odoo FEL:** credenciales y Global Attributes de NIT (`Plugin.OdooEventSale/README.md`).
- **Gateways Epay/Cybersource:** *Admin → Finance → Financial Gateways*.
- **WhatsApp:** tokens en el transporte; webhook `RockWeb/Webhooks/WhatsAppSms.ashx` registrado en
  Meta for Developers con el dominio del ambiente.
- **SendGrid:** Event Webhook → `https://personas.vidareal.tv/Webhooks/TwilioSendGrid.ashx`
  (habilitado 2026-09-09). Usar otra API key en dev.
- **Dominio corto QR `q.vidareal.tv`:** certificado Let's Encrypt emitido con *Certify The Web* en
  el web server, **vence 2026-12-28**; el binding de IIS se creó a mano — revisar que la renovación
  lo actualice.
- **PDF de boletos:** primera generación descarga Chromium (~150 MB) a `App_Data/ChromeEngine`
  (alternativa: System Setting `PDF_EXTERNAL_RENDER_ENDPOINT`).

---

## 6. Fechas y pendientes que el dev entrante hereda

- **Actualizar Rock a otra versión:** no se hace sobre este repo. Procedimiento recomendado por
  Rodolfo: bajar una copia de la BD de prod, clonar Rock limpio en otra carpeta, subir la BD de
  versión mayor en versión mayor con Rock sin modificar (migraciones y jobs post-actualización en
  cada salto) y solo al final meter el desarrollo propio, idealmente movido a plugins. Detalle en
  `docs/HANDOFF/CAMBIOS_VS_UPSTREAM.md` § «Cómo actualizar a una nueva versión de Rock».

- **Todo lo desarrollado está en producción** (confirmado por Rodolfo, 2026-10-15), incluido el
  módulo QR Generator, operativo en `q.vidareal.tv` (reemplazó la plataforma externa antes de su
  vencimiento del 22-oct-2026). Ver `docs/qr-custom/DEPLOY.md`.
- El repo refleja producción: todo commiteado y pusheado (`36fa46789a`, 2026-10-15), incluido el filtro de
  Uso del módulo QR. Ver `docs/HANDOFF/ESTADO_REPO.md` §4.
- Último despliegue conocido: `docs/HANDOFF/DEPLOY_PRODUCCION.md` §8.
- **2026-12-28** vence el certificado de `q.vidareal.tv`; **2027-08-05** el de Apple Wallet.
- El repo de GitHub está en una cuenta personal: transferirlo (ESTADO_REPO §6.1).
