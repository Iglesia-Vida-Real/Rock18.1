# Runbook de deploy a producción

> No hay CI/CD. El deploy es **copia manual de archivos** al web server de producción (VM Windows
> con IIS, sitio `personas.vidareal.tv`; la BD `Rock18` vive en otra VM con SQL Server).
> Accesos (RDP, cuenta de IIS, SQL) **no están aquí**: pedir a TI o ver `ACCESOS_Y_SECRETOS.md`
> del paquete zip de handoff.
>
> Cada módulo tiene además su runbook propio con la lista exacta de archivos (§6). Este documento
> es el procedimiento común; el del módulo manda en los detalles.

---

## 1. Reglas que no se negocian

1. **Se despliega desde un commit, no desde un árbol sucio.** Antes de compilar para prod:
   `git status` limpio, o al menos saber exactamente qué cambio sin commitear viaja dentro de cada
   DLL. `Rock.Blocks.dll` y `Rock.dll` arrastran **todo** lo que haya en el árbol (p. ej. al
   2026-10-15 arrastran los cambios sin commitear del módulo QR, que ya están en prod pero
   PENDIENTES DE COMMIT: commitearlos antes del próximo build).
2. **Los DLL del fork van juntos.** `Rock.dll`, `Rock.Blocks.dll`, `Rock.ViewModels.dll`,
   `Rock.Rest.dll` del **mismo build**. Mezclar versiones da `TypeLoadException` /
   `MissingMethodException` sobre `Rock.ViewModels.Blocks.*` y páginas vacías.
3. **DLL y bundle `.obs.js` del mismo bloque van juntos.** Un bundle nuevo con un DLL viejo (o
   al revés) suele fallar en silencio (campos que no llegan, tarjetas que no aparecen).
4. **SQL antes que DLL** cuando el DLL nuevo usa columnas/SPs nuevos. Los scripts de
   `Dev Tools\Sql` son idempotentes y abortan con `THROW` si no se cumplen prerrequisitos: si
   abortan, **no seguir**.
5. **`RockWeb\App_Code` nunca en caliente.** Copiar `.cs` a `App_Code` con el sitio arriba lo
   tumbó el 2026-07-29 y solo volvió **deteniendo y arrancando el servidor completo** (reciclar el
   app pool no alcanzó). `App_Code` compila en runtime y es todo-o-nada. Ver §4.
6. **No sobrescribir `web.config` ni `web.ConnectionStrings.config` de prod** con los del repo.
7. **Respaldo antes de tocar:** BD (o al menos de las tablas afectadas) y copia de cada archivo que
   se va a reemplazar.
8. Auditar el propio diff antes de compilar para prod (ver `CLAUDE.md`, "Verificar regresiones").

---

## 2. Tipos de artefacto

| Artefacto | Origen (máquina de build) | Destino en prod | Efecto al copiar |
|---|---|---|---|
| DLLs del core del fork (`Rock.dll`, `Rock.Blocks.dll`, `Rock.ViewModels.dll`, `Rock.Rest.dll`, `Rock.WhatsApp.dll`, …) | `RockWeb\Bin\` tras `build-all.ps1` | `RockWeb\Bin\` | Recicla el app domain. Primera carga 2+ min. |
| DLLs de plugins (`com.vidareal.*.dll`, `OdooEventSale.dll`, `*Gateway.dll`) | `Plugin.*\...\bin\Release\net472\` (el script ya los copia a `RockWeb\Bin`) | `RockWeb\Bin\` | Recicla + corre sus `[PluginMigration]` pendientes al arrancar. |
| Dependencias nuevas vs Rock vanilla | p. ej. `System.Net.Http.WinHttpHandler.dll` (Wallet), `QRCoder.dll` (Eventos/QR) | `RockWeb\Bin\` | Verificar que existan en prod antes de subir un módulo que las use. |
| Bundles Obsidian | `RockWeb\Obsidian\Blocks\<Módulo>\*.obs.js` (+ `.map`) | misma ruta | No recicla. El fingerprint se recalcula al reiniciar; sin reinicio, los clientes pueden seguir con el viejo. |
| Front de gateways | `RockWeb\Plugins\EpayVisanetGateway\Obsidian\*.obs.js`, idem Cybersource | misma ruta | Igual que bundles. |
| WebForms (`.ascx`, `.aspx`, `.ashx`) | `RockWeb\...` | misma ruta | Se compilan al primer request. |
| `App_Code\*.cs` | `RockWeb\App_Code\` | misma ruta | **Requiere ventana + reinicio completo (§4).** |
| Scripts SQL | `Dev Tools\Sql\*.sql`, `Scripts\VidaReal\*.sql` | se corren contra `Rock18` | Correr con `sqlcmd -f 65001` si tienen acentos. |
| Configuración en Rock (Global Attributes, páginas, sitios, permisos) | — | Admin de Rock | Documentar en el runbook del módulo. |

Las `[PluginMigration]` **corren solas** al arrancar el sitio con el DLL nuevo. No hay paso manual,
pero sí hay que verificar en el log que corrieron (§5).

---

## 3. Procedimiento estándar (DLLs + bundles, sin App_Code)

**Ventana:** fuera de horario de uso. Evitar sábados en la noche y domingos (reservas y check-in
dominical de QREVENT); evitar días de venta de un evento grande (checkout de Eventos).

```text
0. En la máquina de build
   a. git status limpio / commit hecho. Anotar el hash del commit.
   b. .\"Dev Tools\Build\build-all.ps1"   (Release)   y, si hay .obs, -FullObsidian.
   c. Armar un kit en una carpeta fuera del repo con SOLO los archivos a subir, respetando rutas
      (Bin\..., Obsidian\Blocks\...). Get-FileHash de cada uno -> anotarlo.
      (Dev Tools\Deploy\<kit>\ está en .gitignore para binarios: sirve de staging local.)

1. En prod: respaldo
   a. Respaldo de BD (o confirmar con TI el respaldo automático del día).
   b. Copiar a una carpeta con fecha (p. ej. D:\deploy-backup\2026-10-20\) cada archivo de prod
      que se va a reemplazar, con su ruta.

2. SQL (si aplica) -> contra Rock18, en el orden del runbook del módulo. Si aborta, parar.

3. Copiar el kit sobre RockWeb\ (DLLs + bundles en la misma pasada).

4. Reinicio
   - Solo DLLs/bundles: el reciclo automático basta, pero un reinicio del app pool asegura que el
     fingerprint de Obsidian se recalcule.
   - Si hubo App_Code o el sitio no levanta: §4.

5. Verificación post-deploy (§5).

6. Registrar: fecha, commit, hashes, quién, resultado -> CHANGES.md del módulo y
   docs/HANDOFF/ESTADO_REPO.md si cambia lo pendiente.
```

---

## 4. Deploy con `App_Code` (o cuando el sitio no levanta)

1. Copiar `RockWeb\app_offline-template.htm` (versionado en el repo) como
   `RockWeb\app_offline.htm` en prod → el sitio muestra la página de mantenimiento.
2. Copiar los `.cs` de `App_Code` (y lo demás del kit).
3. **Detener y arrancar el servidor completo** (o como mínimo `iisreset` + borrar
   `Temporary ASP.NET Files` si TI lo autoriza). Reciclar solo el app pool puede no alcanzar.
4. Quitar `app_offline.htm`.
5. Si no levanta: el error real está oculto por `customErrors mode="On"`. Verlo abriendo
   `http://localhost/` **desde el propio servidor** o en *Visor de eventos → Aplicación* (origen
   ASP.NET).

---

## 5. Verificación post-deploy

- [ ] El sitio carga (home pública y `/page/1` interna) en < 3 min tras el reinicio.
- [ ] `RockWeb\App_Data\Logs\RockExceptions.csv`: sin excepciones nuevas del módulo. (El aviso de
      `AIAgentSessionAnchor` al arrancar es conocido e inofensivo.)
- [ ] `[PluginMigration]` corridas: en SQL,
      `SELECT PluginAssemblyName, MAX(MigrationNumber) FROM PluginMigration WHERE PluginAssemblyName LIKE 'com.vidareal%' GROUP BY PluginAssemblyName`
      — debe coincidir con el número del último archivo en `Plugin.*\...\Migrations\` de cada
      plugin desplegado (p. ej. Events = 25 al 2026-10-15).
- [ ] `Get-FileHash` de los archivos en prod = los anotados en el kit.
- [ ] Smoke tests del módulo (§6). Mínimo: el flujo que el cambio toca, de punta a punta.
- [ ] Pagos (si se tocó Eventos/Dar/gateways): un cobro real de monto mínimo o sandbox, y su
      factura FEL en Odoo.

---

## 6. Rollback

1. Si hay `app_offline.htm` disponible, ponerlo.
2. Restaurar desde la carpeta de respaldo del paso 1b los archivos reemplazados (todos juntos, por
   la regla de "van juntos").
3. Reinicio (completo si hubo App_Code).
4. **Las migraciones de plugin y los scripts SQL no se revierten solos.** Cada runbook de módulo
   dice si su cambio de esquema es compatible hacia atrás (p. ej. la migración PersonAlias de
   QREVENT: Step1 es compatible con el DLL viejo; después de Step2 revertir ya no es trivial).
   Restaurar la BD completa es el último recurso y pierde datos de producción posteriores.

---

## 7. Runbooks por módulo (fuente de verdad de cada lista de archivos)

| Módulo | Runbook |
|---|---|
| QR Generator | `docs/qr-custom/DEPLOY.md` (en producción; dominio `q.vidareal.tv`) |
| Wallet | `docs/wallet-module/RESEARCH_Y_PLAN.md` §8b |
| Eventos / Boletería | `Plugin.VidaRealEvents/README.md` + `docs/eventos-custom/SMOKE_TESTS.md` |
| QREVENT / reservas dominicales | `Dev Tools/Deploy/SundayService_PersonAlias/README.md` + `Dev Tools/Sql/CHANGES.md` |
| Odoo FEL | `Plugin.OdooEventSale/README.md` (+ el addon Odoo en el repo `custom_event_sale_api`: reiniciar Odoo con `-u custom_event_sale_api`) |
| Gateways Epay / Cybersource | `Plugin.EpayVisanetGateway/CHANGES.md`, `Plugin.CybersourceInlineRestGateway/README.md` |
| WhatsApp | `Rock.WhatsApp/CHANGES.md` (webhook `WhatsAppSms.ashx` = App_Code/handler → §4) |
| Translator | `Plugin.VidaRealTranslator/README.md` |

---

## 8. Último despliegue conocido (al 2026-10-15)

> **Todo lo listado abajo ya está en producción** (confirmado por Rodolfo, 2026-10-15). La tabla
> queda como registro del último despliegue conocido y de qué artefactos lleva cada módulo. Antes
> del próximo deploy, igual comparar `Get-FileHash` y la tabla `PluginMigration` contra prod para
> saber exactamente qué build corre.

| Qué | Artefactos | Estado |
|---|---|---|
| **Módulo QR Generator** | `Rock.dll`, `Rock.Blocks.dll`, `Rock.ViewModels.dll`, `com.vidareal.Qr.dll` (migraciones 001–007), bundles `RockWeb\Obsidian\Blocks\Qr\*` | **En producción.** Sitio/dominio `q.vidareal.tv` operativo; reemplazó la plataforma externa antes de su vencimiento (22-oct-2026). El filtro por código en «Uso» (5 archivos) está en prod pero **PENDIENTE DE COMMIT** (ver `ESTADO_REPO.md` §4). Riesgo vigente: el certificado de `q.vidareal.tv` vence el 2026-12-28 y Certify no actualiza el binding. |
| Eventos ajustado a capturas de diseño (2026-10-05, §9.39–§9.40) | `Rock.Blocks.dll`, `com.vidareal.Events.dll` (migraciones hasta 025), bundles `RockWeb\Obsidian\Blocks\Eventos\*`, `RockWeb\Plugins\EpayVisanetGateway\Obsidian\*.obs.js` | **En producción.** |
| QREVENT: ventana «Bienvenido» 30 min + bloqueo de reservas (`-5`) | `Rock.Blocks.dll` + `SundayServiceRegistration.obs.js` + `sundayServiceCapacityAdmin.obs.js` | **En producción.** |
| QREVENT: fix de deadlock del check-in (`sp_SundayServiceCheckIn`), guardado de QR en iOS/WebView, cierre de horarios pasados | SQL + `Rock.Blocks.dll` + bundles QREVENT | **En producción.** |
| QREVENT: migración a `PersonAliasId` (Step1/Step2) | SQL + `Rock.Blocks.dll` + bundles | **En producción** (desde 2026-09-06). El kit `Dev Tools\Deploy\SundayService_PersonAlias` es OBSOLETO: no reusar sus binarios. |
| Direcciones Guatemala (cascada Departamento → Municipio) | DLLs core + bundles + `Scripts\VidaReal\direcciones-gt.sql` (`sqlcmd -f 65001`) | **En producción.** Falta revisar la lista de 340 municipios contra INE. Tocó core (`AddressControl`, `ControlsController`): re-aplicar en upgrades. |
| Epay, Wallet, Translator, passwordless selectivo, Event Webhook de SendGrid | Ver el runbook de cada módulo (§7) | **En producción.** |

**Pendiente de código (no de deploy):** validación de firma ECDSA del webhook de SendGrid — parche
en `RockWeb\App_Code\TwilioSendGrid.ashx.cs`, **no implementado**. Endpoint abierto: un `bounce`
falso desactiva correos reales. Es App_Code → §4.

Como `Rock.Blocks.dll` es uno solo, los cambios de varios módulos **viajan juntos** quieras o no.
Lo sano para el próximo deploy: commitear todo lo que deba ir (empezando por el filtro de Uso de
QR), compilar una vez desde ese commit, desplegar en una sola ventana, y probar los smoke tests de
cada módulo incluido.
