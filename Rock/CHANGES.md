# Rock Core Library — Cambios VidaReal

> **Última actualización:** 2026-10-15 (revisión de traspaso: este documento solo cubría passwordless; se agrega el inventario completo de cambios al core verificado con `git log` — ver "Inventario completo al 2026-10-15" al final)

## Qué es este proyecto

`Rock/` es la librería núcleo (core) de **Rock CMS**, el sistema de gestión de iglesias desarrollado por Spark Development Network. Contiene los modelos de dominio, servicios de datos, lógica de negocio y proveedores de seguridad que sustentan toda la plataforma.

Este fork (`hotfix-18.1`) es mantenido por **VidaReal**, una iglesia latinoamericana, y extiende o modifica el core de Rock para adaptarlo a sus necesidades operativas (idioma español, formatos de teléfono latinoamericanos, UX personalizada).

---

## Advertencia: cambios al core son de alto impacto

> **ATENCION:** Los archivos dentro de `Rock/` son la base de toda la plataforma. Un cambio incorrecto aquí puede afectar la autenticación de todos los usuarios, el envío de OTPs, los bloques de login, las APIs v2 y cualquier bloque Obsidian que dependa de estos servicios. Revisar con cuidado antes de hacer merge hacia `develop`.

---

## Resumen de cambios realizados al core

Los cambios listados abajo eran originalmente **modificaciones no comprometidas** (working tree); desde junio 2026 están commiteados en la rama (`c205d270a3`, `33d05949b7`). Son cambios sobre la base del tag/branch `hotfix-18.1` del upstream de Spark. Son personalizaciones propias de VidaReal y **no deben fusionarse ciegamente** con actualizaciones futuras de upstream sin resolver conflictos.

### Area: Autenticación sin contraseña (Passwordless / OTP)

Los tres archivos modificados forman un conjunto coherente: mejoran el flujo de inicio de sesión sin contraseña para usuarios latinoamericanos con números de teléfono que incluyen código de país, y añaden la foto de perfil al paso de selección de persona cuando hay múltiples coincidencias.

---

## Tabla de archivos modificados

| Archivo | Lineas cambiadas | Categoria | Impacto |
|---|---|---|---|
| `Rock/Security/Authentication/PasswordlessAuthentication.cs` | ~60 lineas | Logica principal | Alto — afecta todo el flujo OTP |
| `Rock/Model/Security/RemoteAuthenticationSessionService.cs` | 5 lineas | Generador de codigos | Medio — cambia el formato del codigo OTP |
| `Rock/Security/Authentication/OneTimePasscode/MatchingPersonResult.cs` | 5 lineas | Modelo de datos | Bajo — agrega propiedad `PhotoUrl` |

Para el detalle tecnico de cada archivo, ver:
- [`Rock/Security/Authentication/CHANGES.md`](Security/Authentication/CHANGES.md)

---

## Inventario completo al 2026-10-15

Verificado con `git log --since=2026-02-09 -- Rock/`. No hay cambios sin commitear bajo `Rock/` a esta fecha.

### Modificaciones a archivos de upstream (re-verificar en cada merge con Spark)

| Archivo | Commit(s) | Qué cambia | Documentación |
|---|---|---|---|
| `Security/Authentication/PasswordlessAuthentication.cs`, `Security/Authentication/OneTimePasscode/MatchingPersonResult.cs`, `Model/Security/RemoteAuthenticationSessionService.cs` | `c205d270a3`, `33d05949b7` | Passwordless/OTP (tabla de arriba) | `Security/Authentication/CHANGES.md` |
| `Communication/Medium/Sms.cs` + `Communication/SmsActions/SmsActionConversations.cs` | `0c44380057` (2026-08-12) | Overload `ProcessResponse(..., Person resolvedFromPerson, ...)` para que la atribución de remitente del webhook de WhatsApp no la pise la acción Conversations | `Rock.WhatsApp/CHANGES.md` ("Atribución del remitente") |
| `Model/Event/Registration/RegistrationService.cs` | `ebe7f8d459` (2026-02-23) | Excluye `FeeCoverageAmount` del balance | `Rock.Blocks/Event/CHANGES.md` §3 |
| `Model/Finance/FinancialTransaction/FinancialTransactionService.cs`, `MonthlyAccountGivingHistory.cs` | `67a5c34e4e` (2026-04-27) | El historial mensual de ofrendas agrupa también por `ForeignCurrencyCodeValueId` (nueva propiedad; null = moneda por defecto) — soporte GTQ/USD del módulo DAR | `Rock.Blocks/Dar/CHANGES.md` §8 |
| `Web/UI/Controls/AddressControl.cs`, `SystemGuid/DefinedType.cs` | `4e7cf2264c` (2026-08-26) | Cascada Departamento → Municipio (WebForms) | `CHANGES.md` raíz, fila "Direcciones Guatemala" |
| `Rock.csproj` (proyecto SDK) | varios | `PackageReference System.Net.Http.WinHttpHandler 8.0.0` y `Reference System.IO.Compression` | — |

### Archivos y carpetas nuevos de VidaReal (no existen en upstream)

| Ruta | Módulo | Documentación |
|---|---|---|
| `Model/Core/Location/AddressCascade.cs` | Cascada de direcciones GT (regla `AddressCascade.Get(country, state)`) | `CHANGES.md` raíz; `Rock.JavaScript.Obsidian/Framework/Controls/CHANGES.md` §6 |
| `Model/Eventos/` (Event, Order, Ticket, TicketType, PromoCode, EventStaff, CheckinLog, enums, `Services/`) + `Jobs/EventsMaintenance.cs` | Eventos (venta de entradas, FEL vía Odoo; el job reintenta POSTs a Odoo cada 5 min) | `Model/Eventos/ARCHITECTURE.md`, `docs/eventos-custom/` |
| `Model/Qr/` (QrCode, QrDesign, enums, payloads, `Services/` Render/Catalog/Metrics) | QR Generator | `Model/Qr/ARCHITECTURE.md`, `docs/qr-custom/` |
| `Model/Wallet/` (WalletTemplate, WalletPass, WalletDeviceRegistration, enums, `Services/` Apple/Google) + `Lava/Filters/LavaFilters.VidaRealWallet.cs` | Pases de Apple/Google Wallet | `docs/wallet-module/`, `Plugin.VidaRealWallet/README.md` |

Las tablas de estos módulos las crean las migraciones de los plugins `Plugin.VidaReal*` (no hay migraciones de core).

### Estado de despliegue

Todos los módulos de arriba están **en producción** (confirmado por Rodolfo, 2026-10-15), incluido el QR Generator. Detalle por módulo en `docs/eventos-custom/`, `docs/qr-custom/` y `Rock.Blocks/QREVENT/CHANGES.md`; resumen en `docs/HANDOFF/DEPLOY_PRODUCCION.md` §8. Cualquier DLL `Rock.dll` que se compile desde este árbol incluye TODOS los módulos de arriba.
