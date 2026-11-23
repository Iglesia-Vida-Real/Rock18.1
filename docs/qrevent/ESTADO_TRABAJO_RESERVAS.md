# Reservas dominicales — estado del trabajo (al lunes 2026-11-23)

Trabajo sobre las reservas dominicales (QREVENT, no nativo de Rock). Va **aparte del upgrade a la 19**: se
programa sobre la 18.1 (producción) y, verificado, se pasa a la 19. **Nada está en producción.**

## Dónde está

| | |
|---|---|
| Carpeta | `Documents\GitHub\Rock18Reservas-wt` (worktree) |
| Rama | `reservas-servicios-especiales` (sale de `hotfix-18.1` `81ed172522`), **solo local, sin push** |
| BD de prueba | `Rock18Reservas` (bacpac de prod del 19-nov, aislada con `dev-isolation\aislar_dev_Rock18Reservas.sql`; ya tiene el script `SlotSettings`) |
| Sitio | `http://localhost:6231` |
| Levantar el sitio | `& "C:\Program Files\IIS Express\iisexpress.exe" "/path:C:\Users\Servr local Rock RMS\Documents\GitHub\Rock18Reservas-wt\RockWeb" /port:6231 /clr:v4.0` (primera carga ~2 min) |

La 19 (`Rock18.1`, 6229, `Rock19Test`) y la 18.1 base de comparación (`Rock18Base-wt`, 6230, `Rock18Base`)
**no se tocaron**.

## Hecho

1. **Servicios especiales de una sola fecha** (pestaña «Servicios especiales» de la 862, formulario guiado).
2. **Horario de la puerta por cupo** (abre / cierra en horas de reloj); la app deja de reservar cuando cierra la
   puerta.
3. **Visible en la app** por cupo, por fila de plantilla y al crear un especial.
4. **Escáner:** cada QR se valida con su propio servicio; avisa «abre a las…» / «cerró a las…».
5. Probado por Fredy en 6231 (crear, reservar, cambiar horario, check-in, ocultar). Regresión encontrada y
   corregida: el formulario reactivaba servicios desactivados (ver CHANGES).
6. Compila 0 errores en la 18.1 y contra la 19.8.1 (worktree temporal).

Detalle: `Rock.Blocks/QREVENT/CHANGES.md` (últimas dos secciones), `src/QREVENT/CHANGES.md`,
guía `GUIA_RESERVAS_DOMINGOS.md`.

## Estado al cierre del 2026-11-23

- Todas las pruebas pasaron en 18.1 (6231): ocultar/mostrar (servicio y plantilla al instante), Editar
  (lugares, puerta, «Puerta normal»), cierre tardío, llegar temprano, ventanas cruzadas.
- **Ya está en la rama de la 19** (`Test_Update_18.1_a_19.8.1`, cherry-pick limpio), compilado y publicado en 6229;
  script corrido en `Rock19Test`; probado: crear especial, reservar, escanear, ocultar. Respaldo previo de la DLL
  y las pantallas de la 19 en `dev-isolation\respaldo_19_antes_reservas_2026-11-23`.
- `Rock18Reservas` y `Rock19Test` quedaron idénticas al original de prod en sábados y domingos (comparadas
  contra `Rock18Base`); los especiales de prueba quedaron ocultos.

## Pendiente

1. Paquete para TI: `DESPLIEGUE_RESERVAS_SERVICIOS_ESPECIALES.md` (qué subir, orden, verificación, reversa,
   fecha límite 11-dic / 18-dic).
2. Con aprobación: push de las ramas y unir `reservas-servicios-especiales` a `hotfix-18.1`.
3. Agregar al runbook del upgrade (`UPGRADE_19.8.1.md`, lo edita la sesión de la 19) el paso del script.
