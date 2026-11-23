# Manual de reservas dominicales: funcionamiento y procedimientos

Para quien configura las reservas de los servicios (administración, ministerio, TI). Cubre lo de siempre y las
funciones nuevas de noviembre de 2026: **servicios especiales**, **horario de la puerta por servicio** y
**visible en la app**. Resumen corto: `GUIA_RESERVAS_DOMINGOS.md`. Detalle técnico: `Rock.Blocks/QREVENT/CHANGES.md`.

---

## 1. Las tres pantallas

| Página | Nombre | Quién la usa | Para qué |
|---|---|---|---|
| **862** | Configuración de Domingos | Administración / ministerio | Crear y ajustar los servicios, la puerta, la visibilidad; ver métricas |
| **860** | Registro Domingos App | La congregación (app y web) | Reservar lugar y mostrar su código QR |
| **863** | Domingos Scanner | Equipo de la puerta | Leer los QR al ingresar |

---

## 2. Cómo funciona

### 2.1 Horario, servicio (cupo) y reserva

- **Horario**: un horario de Rock, por ejemplo «Domingo 9:00 h» (semanal) o «Nochebuena 20:00 h» (una sola
  fecha).
- **Servicio** (en la pantalla también «cupo»): una **fecha concreta** de un horario, con su número de
  **lugares**. Es lo que la gente reserva y lo que la puerta lee. Los servicios de la semana normal los crea la
  **plantilla**; los especiales, el formulario de **Servicios especiales**.
- **Reserva**: una persona aparta N lugares en un servicio y recibe un **código QR**.

### 2.2 Ciclo de un servicio

```
   La app lo muestra          La gente reserva           La puerta lee los QR
   (7 días antes)      ───►   hasta el cierre     ───►   de la apertura al cierre
```

1. **La app muestra los servicios de los próximos 7 días.** Un servicio del domingo aparece desde el lunes
   anterior; uno del 24 de diciembre, desde el 18.
2. **Se puede reservar hasta que cierra la puerta** de ese servicio. Después desaparece de la app.
3. **La puerta** de cada servicio abre y cierra a una hora:
   - **Por omisión** abre **15 min antes** del inicio y cierra **1 h 20 min después**.
   - Cada servicio puede tener **su propio horario de puerta** (por ejemplo, Nochebuena abre 1 hora antes, o un
     servicio largo cierra a las 15:00).
   - La app deja de aceptar reservas **a la misma hora** en que cierra la puerta, para que nunca se emita un QR
     que la puerta vaya a rechazar.
4. **No hay check-out.** Al escanear se marca el ingreso y listo.

### 2.3 Qué hace la puerta con cada QR

El escáner reconoce el servicio **de cada reserva** (no hay un único «servicio activo»):

| Situación | Lo que muestra |
|---|---|
| Reserva de hoy, puerta de su servicio abierta | **Asistencia marcada** (y en el teléfono de la persona aparece «¡Bienvenido!») |
| Ya había ingresado | «Este QR ya fue procesado» (no cuenta dos veces) |
| Llegó antes de que abra su puerta | «Esta reserva es del servicio de las 18:00. La puerta abre a las 17:45.» |
| Llegó después del cierre | «El ingreso para el servicio de las 13:00 cerró a las 14:20.» |
| Reserva de otro día | «Esta reserva no es para hoy.» |
| Otra sede, otro horario o servicio desactivado | «Esta reserva es de otro horario.» |
| Código que no existe o reserva cancelada | «El QR no es válido para este ingreso.» |

Si dos servicios tienen la puerta abierta al mismo tiempo, no hay problema: cada QR entra a su propio servicio.
El encabezado del escáner muestra todos los que están abiertos («A + B»).

### 2.4 Visible en la app, desactivado y oculto

| Estado | ¿Sale en la app? | ¿Se puede reservar? | ¿La puerta lo lee? | ¿Cuándo usarlo? |
|---|---|---|---|---|
| **Activo y visible** (normal) | Sí | Sí | Sí | Siempre, salvo lo de abajo |
| **Oculto en la app** | No | No | **Sí** (quien ya reservó entra) | Preparar un especial con tiempo; dejar de recibir reservas sin afectar a quien ya reservó |
| **Desactivado** | No | No | No | Ese servicio no habrá. Solo se puede si **no tiene reservas** |

### 2.5 Reglas que ya existían y siguen igual

- Una persona tiene **una sola reserva activa** a la vez (cambiar de horario reemplaza la anterior).
- Máximo **8 personas** por reserva.
- Mientras alguien aparta lugares tiene un **apartado temporal** de 2–3 min («Holds» en la pantalla).
- Después de su **check-in**, la persona no puede reservar otro servicio durante **30 minutos**.
- La capacidad nunca puede bajar de lo ya reservado.

---

## 3. La pantalla de configuración (862)

Arriba se elige la **Sede**. Hay tres pestañas:

### 3.1 Semana normal

- **Rango** (Desde / Hasta, o los botones Esta semana, 4 semanas, 3 meses, 6 meses): las fechas con las que se
  trabaja.
- **Plantilla de horarios**, una fila por horario semanal:
  - Casilla de la **izquierda**: a qué horarios se aplica la plantilla al pulsar «Aplicar plantilla». **No oculta
    nada.**
  - **Visible en la app**: se aplica **al instante** a todas las fechas de ese horario dentro del rango (de hoy en
    adelante). Si en el rango hay fechas visibles y ocultas, queda a medias y dice «(N ocultas)».
  - **Capacidad**: lugares para las fechas que se creen o actualicen.
  - **Sobrescribir la capacidad** de las fechas que ya existen y **Desactivar los horarios que no estén en la
    plantilla** (solo sin reservas; nunca toca un servicio especial).
- **Disponibilidad del rango**: cada servicio con lugares, reservados, ingresaron, apartados, disponibles y
  «Puerta 8:45 a 10:20». Botones:
  - **Editar**: lugares, «La puerta abre a las», «La puerta cierra a las», «Mostrar en la app de reservas».
    «Puerta normal» vuelve a 15 min antes / 1 h 20 min después (se guarda con «Guardar»).
  - **Desactivar / Reactivar.**

### 3.2 Servicios especiales

- **+ Nuevo servicio especial** abre un formulario por pasos (ver §4.3).
- **Programados**: todos los especiales de hoy en adelante, con **Editar** y **Desactivar / Reactivar**, y la
  etiqueta «Oculto en la app» o «Desactivado» si aplica.
- **¿Cómo funciona?**: resumen plegable de las reglas.

### 3.3 Métricas

Por semana y por horario: lugares, reservados, ingresaron, no vinieron (semanas pasadas) y pendientes. Incluye
los servicios especiales.

---

## 4. Procedimientos paso a paso

### 4.1 Abrir las semanas normales (cada mes o trimestre)

1. 862 → **Semana normal** → Sede → botón **3 meses**.
2. Revisa en la plantilla la **Capacidad** de cada horario y que su casilla de la izquierda esté marcada.
3. Pulsa **Aplicar plantilla**. El aviso dice cuántos servicios creó o actualizó.
4. Revisa la lista: cada fecha con sus servicios y «Puerta …» como siempre.

### 4.2 Cambiar los lugares o la puerta de un servicio de una fecha

1. 862 → **Semana normal** → rango que incluya la fecha.
2. En la lista, el servicio → **Editar**.
3. Cambia **Lugares** y/o **La puerta abre / cierra a las**. Si algo no es válido sale un mensaje en rojo y
   «Guardar» queda deshabilitado (por ejemplo, abrir después del inicio).
4. **Guardar.** Para volver a lo de siempre: **Puerta normal** → **Guardar**.

### 4.3 Crear un servicio especial (Nochebuena, Año Nuevo, un evento)

1. 862 → **Servicios especiales** → **+ Nuevo servicio especial**.
2. **¿Cuándo es?** Fecha y hora de inicio.
3. **¿Cómo se llama y cuántos lugares hay?** El nombre es opcional y **sin la hora**: se agrega sola
   («Nochebuena 20:00 h»).
4. **¿A qué hora abre y cierra la puerta?** Viene con lo normal; cámbialo si hace falta. La puerta se mueve sola
   si después cambias la hora de inicio.
5. **¿Se muestra en la página de reservas?** Desmárcalo si aún no quieres publicarlo.
6. **Ese día ya hay otros servicios. ¿Siguen ese día?** (solo si los hay): «Sí habrá» / «No habrá» para cada
   servicio **activo**. Los que tienen reservas no se pueden quitar. Los ya desactivados aparecen como
   información y no cambian.
7. Revisa **«Así quedará la puerta ese día»** (línea de tiempo) y el **Resumen**.
8. **Crear servicio especial.** Aparece en **Programados**.

### 4.4 Domingo con un solo servicio (o con otro horario)

**Hazlo antes de que abra la reserva de ese domingo** (el lunes anterior), porque un servicio con reservas no se
puede quitar.

1. Sigue §4.3 con la fecha del domingo y la hora del servicio único.
2. En el paso «¿Siguen ese día?», marca **No habrá** en los servicios normales que no habrá.
3. Crear. Esos servicios quedan desactivados ese día y **«Aplicar plantilla» no los vuelve a activar** mientras
   ese domingo tenga un servicio especial.
4. Si alguno ya tenía reservas: ocúltalo de la app (§4.6) y avisa a quienes reservaron.

### 4.5 Preparar un especial con tiempo y publicarlo después

1. Créalo (§4.3) con **«Mostrar en la app»** desmarcado.
2. El día que quieras publicarlo: **Servicios especiales → Programados → Editar** → marca «Mostrar en la app de
   reservas» → **Guardar**.

### 4.6 Dejar de recibir reservas en un servicio (sin cancelar las que ya hay)

- **Una fecha**: lista → **Editar** → desmarca «Mostrar en la app de reservas» → **Guardar**.
- **Todas las fechas de un horario** (por ejemplo, ningún sábado en las próximas semanas): **Semana normal** →
  rango (por ejemplo, 3 meses) → desmarca **Visible en la app** en la fila de ese horario. Se aplica al instante y
  sale un aviso con cuántas fechas cambió.
- Quien ya reservó **sigue entrando** con su QR.

### 4.7 Quitar un servicio o un especial

- **Desactivar** (lista o Programados). Solo si no tiene reservas ni apartados.
- Si tiene reservas: ocúltalo de la app (§4.6), avisa a quienes reservaron y, cuando ya no tenga reservas
  activas, desactívalo.
- **Nunca** borrarlo desde Administración → Horarios de Rock.

### 4.8 Abrir la puerta más temprano o cerrarla más tarde

- **Un servicio**: Editar (§4.2) o, si es especial, Programados → Editar.
- Ejemplo: servicio de 13:00 a 15:00 que debe recibir gente hasta las 15:00 → «La puerta cierra a las» **15:00**.
  La app también acepta reservas hasta las 15:00.

### 4.9 Cerrar la puerta de un servicio ahora mismo

Editar → «La puerta cierra a las» con la hora actual → Guardar. (Ocultarlo de la app **no** cierra la puerta.)

---

## 5. Ejemplo: Navidad 2026

| Fecha | Qué hacer | Hasta cuándo |
|---|---|---|
| Jueves 24-dic, Nochebuena | Servicios especiales → nuevo: 24/12, hora, «Nochebuena», lugares, puerta (por ejemplo, abre 1 h antes) | Se puede reservar desde el viernes 18-dic |
| Domingo 27-dic con un solo servicio | Nuevo especial el 27/12 y «No habrá» en los normales | Antes del lunes 21-dic |
| Domingo 3-ene normal | Nada | — |

---

## 6. Preguntas frecuentes y problemas

| Pregunta / síntoma | Respuesta |
|---|---|
| Desmarqué la casilla de la izquierda y el horario sigue saliendo | Esa casilla solo elige a qué horarios se aplica la plantilla. Usa **Visible en la app** |
| Oculté un horario y la puerta lo sigue leyendo | Es a propósito: quien ya reservó debe entrar. Para cerrarla, §4.9 |
| Oculté los sábados pero la semana siguiente siguen saliendo | «Visible en la app» de la plantilla solo cambia las fechas del **rango** elegido. Usa un rango más largo (3 o 6 meses) |
| «No puedes desactivar este horario: tiene N reservados» | Ocúltalo de la app y avisa (§4.7) |
| Alguien llega y la puerta dice «abre a las…» | Llegó antes. Espera a esa hora o, si hace falta, adelanta la apertura (§4.8) |
| Una persona no puede reservar justo después de entrar | Regla de los 30 minutos después del check-in |
| El escáner dice «Sin horario activo» | Ningún servicio tiene la puerta abierta ahora; abajo dice cuál es el próximo y en cuánto abre |
| Sale un aviso azul «falta preparar la base de datos» | TI debe correr `Dev Tools/Sql/QREVENT_SundayService_SlotSettings.sql`. Mientras tanto todo funciona con lo normal (15 min / 1 h 20 min, todo visible) |
| El nombre del especial no acepta una hora | La hora se agrega sola; escribe solo el nombre |
| «La puerta no puede abrir después de la hora de inicio» | La apertura debe ser a la hora de inicio o antes (hasta 3 h antes) |

---

## 7. Lo que no se debe hacer

- No borrar servicios especiales desde Horarios de Rock ni moverlos de la categoría «Servicios especiales
  (Reservas)».
- No llenar «Enable Check-in / Close Check-in» de esos horarios ni ligarlos a grupos (eso es del check-in de
  niños, no de las reservas).
- No editar las listas de horarios de los bloques (atributos de bloque) para un especial: ya no hace falta.
- No desplegar el DLL sin la pantalla (o al revés): van juntos (ver `DESPLIEGUE_RESERVAS_SERVICIOS_ESPECIALES.md`).
