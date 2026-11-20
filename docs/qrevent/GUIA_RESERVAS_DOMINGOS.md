# Guía de reservas dominicales (para quien configura)

Pantallas (sitio interno):

| Página | Nombre | Para qué |
|---|---|---|
| 862 | Configuracion Domingos | Crear y ajustar los cupos; servicios especiales; métricas |
| 860 | Registro Domingos App | Donde la gente reserva (la app) |
| 863 | Domingos Scanner | Puerta: lee el QR de la reserva |

Detalle técnico: `Rock.Blocks/QREVENT/CHANGES.md` y `Rock.JavaScript.Obsidian.Blocks/src/QREVENT/CHANGES.md`.

## Dos piezas: horario y cupo

- **Horario** (Schedule de Rock): el día de la semana y la hora. Lo de siempre («Domingo 9:00 h»).
- **Cupo** (slot): una **fecha concreta** con su capacidad. La app (860) y la puerta (863) **solo trabajan
  con cupos**. Cambiar la hora de un horario no crea cupos.

## Uso semanal: la plantilla (página 862)

1. Elige la **Sede** y el rango **Desde / Hasta** (atajos: 4 semanas, 3 meses, 6 meses).
2. En **Plantilla de horarios** marca los horarios y su **Capacidad** (se prellena con la última usada).
3. Opciones:
   - **Sobrescribir la capacidad**: cambia el cupo de fechas que ya existen (nunca por debajo de lo ya tomado).
   - **Desactivar horarios fuera de la plantilla**: apaga los no marcados, solo si no tienen reservas.
     Nunca apaga un servicio especial.
4. **Aplicar plantilla**. Abajo, en **Disponibilidad del rango**, se ajusta un día suelto (capacidad,
   Desactivar / Reactivar).

## Servicio especial (Nochebuena, Año Nuevo, un domingo distinto)

En la misma página 862, tarjeta **«Servicio especial»**. No hace falta tocar horarios de Rock ni la
configuración de los bloques.

1. **Fecha**: al elegirla aparece «Lo que ya hay» ese día, con botón Desactivar / Reactivar en cada horario.
2. **Hora de inicio**, **Nombre** opcional (sin hora: se agrega sola, p. ej. «Nochebuena 20:00 h») y **Capacidad**.
3. La barra de abajo resume cómo quedará: nombre, desde cuándo se puede reservar y a qué hora lee la puerta.
4. **Crear servicio especial**. Aparece en la lista con la etiqueta **Especial**.
5. Abajo, en **Próximos servicios especiales**, se ven todos los especiales desde hoy (sin mover el rango),
   con cuántos reservaron, **Ver día** y Desactivar / Reactivar.

Si algo choca (otro horario activo ese día a menos de 1 h 35 min), la pantalla lo marca en naranja como
**Choca** y no deja crear hasta desactivarlo o cambiar la hora.

### Un domingo con un solo servicio o con otro horario

1. Elige la fecha en la tarjeta «Servicio especial».
2. **Desactiva** los horarios normales que no habrá. Solo se puede si **no tienen reservas**: hazlo
   **antes de que abra la reserva** (la app muestra los próximos 7 días; para el domingo 27, antes del lunes 21).
3. Crea el servicio especial.

### Reglas que conviene saber

| Regla | Por qué |
|---|---|
| La app muestra los servicios de los **próximos 7 días** | El servicio especial aparece para reservar 6 días antes |
| La puerta abre **15 min antes** y cierra **1 h 20 min después** del inicio; la reserva cierra a la misma hora | Fijo en el código |
| Dos servicios **activos** del mismo día deben empezar con **1 h 35 min** de diferencia como mínimo | Si no, las ventanas de la puerta se cruzan y rechaza reservas válidas. La pantalla no deja crear ni reactivar un horario que choque con un especial |
| Mientras un día tenga un servicio especial activo, **Aplicar plantilla no crea ni reactiva** horarios normales ese día | Para no deshacer lo que se desactivó a mano |
| Un horario con reservas **no se puede desactivar** | Protege a quien ya reservó |
| Para quitar un servicio especial: **Desactivar** en la lista (si no tiene reservas) | El horario queda guardado en Rock, inactivo para reservas |

Los servicios especiales quedan en Rock en la categoría de horarios **«Servicios especiales (Reservas)»**
(Administración → General → Horarios). Es solo el registro de la hora; todo se maneja desde la 862:

- **No moverlos a otra categoría:** la puerta los reconoce por esa categoría.
- **No usar «Eliminar» ahí:** el cupo y las reservas quedarían apuntando a un horario que ya no existe.
  Para quitar un especial, **Desactivar** en la 862.
- **No llenar «Enable Check-in / Close Check-in» ni ligarlos a grupos:** así el check-in de Rock
  (VidAventura y demás) nunca los ve. El escaneo de reservas no usa esos campos.

### Si cambia la hora de un servicio especial ya creado

- **Sin reservas:** desactívalo y crea otro con la hora correcta.
- **Con reservas:** no se puede desactivar. Pedir a TI que cambie en Rock la hora **y el nombre** del
  horario (el nombre lleva la hora y la app ordena por ella), en Administración → Horarios →
  «Servicios especiales (Reservas)». Desde ahí la pantalla no valida choques: revisar que quede a
  1 h 35 min o más de otros horarios activos de ese día. Avisar a quienes reservaron: el QR sigue
  siendo válido, pero la puerta abrirá con la hora nueva.

## Ejemplo: Navidad

| Fecha | Qué hacer en la 862 |
|---|---|
| Jueves 24 dic, Nochebuena | Servicio especial: fecha 24/12, hora, nombre «Nochebuena», capacidad. Se puede reservar desde el viernes 18 |
| Domingo 27 dic con un solo servicio | Antes del lunes 21: elegir 27/12, desactivar los horarios normales, crear el especial |

