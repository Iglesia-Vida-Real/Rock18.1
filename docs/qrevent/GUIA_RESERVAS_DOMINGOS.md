# Guía de reservas dominicales (para quien configura)

Pantallas (sitio interno):

| Página | Nombre | Para qué |
|---|---|---|
| 862 | Configuración de Domingos | Cupos de la semana, servicios especiales, horario de la puerta, visibilidad, métricas |
| 860 | Registro Domingos App | Donde la gente reserva (la app) |
| 863 | Domingos Scanner | Puerta: lee el QR de la reserva |

Detalle técnico: `Rock.Blocks/QREVENT/CHANGES.md` y `Rock.JavaScript.Obsidian.Blocks/src/QREVENT/CHANGES.md`.

## Ideas básicas

- **Horario** (Schedule de Rock): el día de la semana y la hora («Domingo 9:00 h»).
- **Cupo**: una **fecha concreta** de ese horario, con sus lugares. La app y la puerta trabajan con cupos.
- **Puerta**: por omisión abre **15 min antes** y cierra **1 h 20 min después** del inicio. La app deja de aceptar
  reservas a la misma hora en que cierra la puerta. Se puede cambiar en cada cupo.
- **Visible en la app**: si un cupo está oculto, no aparece en la página de reservas y nadie nuevo puede
  reservarlo; **quien ya reservó entra igual** con su QR.
- **Desactivar**: el cupo no existe ese día (ni app ni puerta). Solo se puede si **no tiene reservas**.

## Pestaña «Semana normal»

1. Elige la **Sede** y el rango **Desde / Hasta** (atajos: esta semana, 4 semanas, 3 meses…).
2. **Plantilla de horarios:** marca los horarios, su **Capacidad** y si quedan **Visibles en la app**.
3. Opciones:
   - **Sobrescribir capacidad y «visible en la app»** de las fechas que ya existen (nunca por debajo de lo tomado).
   - **Desactivar horarios fuera de la plantilla** (solo sin reservas; nunca toca un servicio especial).
4. **Aplicar plantilla.**
5. En la lista, cada servicio muestra lugares, reservas y «Puerta 8:45 a 10:20». Con **Editar** cambias:
   lugares, **a qué hora abre y cierra la puerta** y **Mostrar en la app de reservas**. «Puerta normal» vuelve a
   15 min antes / 1 h 20 min después (y se guarda con «Guardar»).

Mientras un día tenga un servicio especial activo, «Aplicar plantilla» **no** vuelve a activar los servicios
normales de ese día.

## Pestaña «Servicios especiales» (Nochebuena, Año Nuevo, un domingo distinto)

Botón **+ Nuevo servicio especial** y responde:

1. **¿Cuándo es?** Fecha y hora de inicio.
2. **¿Cómo se llama y cuántos lugares?** La hora se agrega sola al nombre («Nochebuena 20:00 h»).
3. **¿A qué hora abre y cierra la puerta?** Viene con lo normal; cámbiala si hace falta (por ejemplo, abrir 1 h
   antes o cerrar a las 15:00 en un servicio largo).
4. **¿Se muestra en la página de reservas?** Desmárcalo para prepararlo con tiempo y publicarlo después con
   «Editar».
5. **Los otros servicios de ese día** (solo los activos): «Sí habrá» / «No habrá». Los que tienen reservas no se
   pueden quitar. Los ya desactivados no cambian.

Revisa la **línea de tiempo** «Así quedará la puerta ese día» y el **Resumen**, y pulsa **Crear servicio especial**.
Abajo, en **Programados**, están todos los especiales desde hoy con **Editar** y **Desactivar**.

## Reglas que conviene saber

| Regla | Por qué |
|---|---|
| La app muestra los servicios de los **próximos 7 días** | Un especial se puede reservar desde 6 días antes |
| Si alguien llega antes de que abra la puerta, el escáner le dice a qué hora abre **su** servicio | Cada QR se valida con su propio servicio |
| Dos puertas pueden estar abiertas a la vez | El escáner reconoce el servicio de cada reserva |
| Después de su check-in, una persona no puede reservar otro servicio durante **30 min** | Regla de septiembre, para no apartar dos lugares |
| Un servicio con reservas **no se puede desactivar** | Protege a quien ya reservó: ocúltalo de la app y avisa |
| Ocultar en la app **no apaga la puerta** | Para apagarla: desactivar (sin reservas) o cambiar la hora de cierre |

### Un domingo con un solo servicio o con otro horario

**Antes de que abra la reserva** (7 días antes; para el domingo 27, antes del lunes 21): «Servicios especiales»
→ «+ Nuevo servicio especial» con la fecha del domingo → en el paso 5 marca «No habrá» en los normales → Crear.
Si alguno ya tiene reservas, ocúltalo de la app («Semana normal» → Editar) y avisa a quienes reservaron.

### El horario especial en Rock

Los especiales quedan en Rock en la categoría de horarios **«Servicios especiales (Reservas)»**
(Administración → General → Horarios). Es solo el registro de la hora; todo se maneja desde la 862:

- **No moverlos a otra categoría:** la puerta los reconoce por esa categoría.
- **No usar «Eliminar» ahí:** el cupo y las reservas quedarían apuntando a un horario que ya no existe.
- **No llenar «Enable Check-in / Close Check-in» ni ligarlos a grupos:** así el check-in de Rock (VidAventura y
  demás) nunca los ve. El horario de la puerta de reservas se configura en la 862, no ahí.
- Si cambia la **hora de inicio** de un especial con reservas: pedir a TI que cambie en Rock la hora **y el
  nombre** (lleva la hora) y avisar a quienes reservaron. La ventana de la puerta se mueve sola con el inicio.

## Ejemplo: Navidad

| Fecha | Qué hacer en la 862 |
|---|---|
| Jueves 24 dic, Nochebuena | Nuevo servicio especial: 24/12, hora, «Nochebuena», lugares; puerta como se necesite. Se puede reservar desde el viernes 18 |
| Domingo 27 dic con un solo servicio | Antes del lunes 21: nuevo especial el 27/12 y «No habrá» en los normales |
