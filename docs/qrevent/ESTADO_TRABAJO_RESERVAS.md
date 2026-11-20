# Reservas dominicales — estado del trabajo (cierre del viernes 2026-11-20)

Trabajo en curso sobre las reservas dominicales (QREVENT, no nativo de Rock). Va **aparte del upgrade a
la 19**: se programa sobre la 18.1 (producción) y, verificado, se pasa a la 19.

## Dónde está

| | |
|---|---|
| Carpeta | `Documents\GitHub\Rock18Reservas-wt` (worktree) |
| Rama | `reservas-servicios-especiales` (sale de `hotfix-18.1` `81ed172522`), **solo local, sin push** |
| BD de prueba | `Rock18Reservas` (bacpac de prod del 19-nov, aislada con `dev-isolation\aislar_dev_Rock18Reservas.sql`) |
| Sitio | `http://localhost:6231` |
| Levantar el sitio | `& "C:\Program Files\IIS Express\iisexpress.exe" "/path:C:\Users\Servr local Rock RMS\Documents\GitHub\Rock18Reservas-wt\RockWeb" /port:6231 /clr:v4.0` (primera carga ~2 min) |

La 19 (`Rock18.1`, 6229, `Rock19Test`) y la 18.1 base de comparación (`Rock18Base-wt`, 6230,
`Rock18Base`) **no se tocaron**.

## Hecho

1. **Servicios especiales de una sola fecha** (commit `8d1c644263`, probado por Fredy en 6231: crear,
   reservar, escanear, «Bienvenido», métricas). Guía: `GUIA_RESERVAS_DOMINGOS.md`.
2. **Ventana de la puerta configurable por servicio** (servidor terminado y compilado):
   - Script `Dev Tools/Sql/QREVENT_SundayService_DoorWindow.sql`: columnas `CheckInOpensMinutesBefore`
     (NULL = 15) y `CheckInClosesMinutesAfter` (NULL = 80) en `SundayServiceSlot`. **Todavía no se corrió
     en `Rock18Reservas`.** El código funciona con y sin las columnas (sin ellas: 15/80 fijos).
   - **Escáner (863):** cada QR se valida contra la ventana de **su propio** servicio (ya no contra un
     único horario «activo»): las ventanas que se cruzan no rechazan reservas válidas; si llega antes, le
     dice a qué hora abre su servicio; si llega tarde, a qué hora cerró. Apertura y cierre por cupo.
   - **App de reservas (860):** deja de aceptar reservas a la misma hora en que cierra la puerta de ese
     cupo (los 4 puntos: lista, reserva activa, apartar, confirmar).
   - **Configuración (862):** `UpdateSlot` y `CreateSpecialService` aceptan apertura y cierre; se quitó el
     bloqueo de «choque» de horarios (ya no hace falta con la validación por reserva).
   - Compila 0 errores en la 18.1. La parte de **apertura** se auditó contra la 19.8.1 (0 errores); la del
     **cierre** se audita en este cierre (ver commit).

## Pendiente para el lunes

1. **Rehacer la pantalla 862 (Fredy: «confunde bastante»).** Diseño acordado:
   - Pestañas: **Semana normal** · **Servicios especiales** · Métricas.
   - «Servicios especiales»: botón **+ Nuevo servicio especial** → formulario guiado con preguntas:
     1 ¿Cuándo es? (fecha, hora) · 2 ¿Cómo se llama y cuántos lugares? · 3 ¿A qué hora abre y cierra la
     puerta? (**horas de reloj**, ya llenas con lo normal) · 4 Ese día también hay estos servicios, ¿se
     mantienen? (Se mantiene / No habrá) · línea de tiempo «Así quedará la puerta ese día» · resumen en
     frases · Crear / Cancelar. Debajo, **Programados** con Editar (lugares, abre, cierra) y Desactivar.
   - «Semana normal»: plantilla + lista del rango; en cada servicio, **Editar** (lugares y horario de la
     puerta en horas de reloj). Quitar la tarjeta «Planificar un día».
   - Borrador del template de la pestaña nueva: `borradores/pestana_servicios_especiales.template.html`.
     Falta escribir el script (estado del formulario, editores por servicio, aplicar «No habrá» después de
     crear) y los estilos. El script del planificador anterior queda en `borradores/` como referencia
     (línea de tiempo, carga del día, próximos especiales).
   - Hoy el `.obs` del repo todavía tiene la tarjeta «Planificar un día» (solo apertura, en minutos).
2. Compilar, publicar en 6231, correr el script DoorWindow en `Rock18Reservas` y probar: sin columnas,
   con columnas, llegar temprano, ventanas cruzadas, cierre tardío (servicio 13:00 que cierra 15:00),
   reservar después del cierre normal.
3. Auditoría contra la 19 (worktree temporal, ver memoria/CLAUDE.md) y documentar en `Rock.Blocks/QREVENT/CHANGES.md`
   y `src/QREVENT/CHANGES.md` (ventana configurable + validación por reserva + cierre de la reserva por cupo).
4. Commit; después decidir el paso a la 19 (cherry-pick) y el despliegue a producción con Rodolfo/TI
   (orden: script SQL → `Rock.Blocks.dll` + `SundayServiceCapacityAdmin.obs.js`).
