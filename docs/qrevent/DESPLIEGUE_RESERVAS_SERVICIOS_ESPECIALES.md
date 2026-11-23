# Despliegue a producción — reservas: servicios especiales, puerta y visibilidad por servicio

Paquete para TI (Rodolfo). Sigue el runbook general `docs/HANDOFF/DEPLOY_PRODUCCION.md` §1–§3 y §5; aquí
solo lo específico de este cambio. **Nada de esto está en producción** (al 2026-11-23).

## Qué trae

Configuración Domingos (página 862) con pestañas «Semana normal» / «Servicios especiales» / «Métricas»:

- **Servicios especiales** de una sola fecha (Nochebuena, Año Nuevo, un domingo con otro horario), con
  formulario guiado, línea de tiempo y resumen; «Programados» con Editar y Desactivar.
- **Horario de la puerta por servicio** (abre / cierra, en horas de reloj). Por omisión, lo de siempre:
  15 min antes y 1 h 20 min después del inicio. La app deja de reservar cuando cierra la puerta.
- **«Visible en la app»** por servicio, por horario de la plantilla (al instante) y al crear un especial.
- **Escáner (863):** cada QR se valida con la ventana de su propio servicio; avisa «la puerta abre a las…»
  / «cerró a las…».

Detalle técnico: `Rock.Blocks/QREVENT/CHANGES.md` (últimas secciones). Guía para quien configura:
`docs/qrevent/GUIA_RESERVAS_DOMINGOS.md`.

## Dónde está el código

| | Rama | Commits |
|---|---|---|
| 18.1 (lo que va a prod) | `reservas-servicios-especiales` (sale de `hotfix-18.1` `81ed172522`) | `8d1c644263`, `4075d88b3e`, `3965e6aec7`, `ffa1e4786a`, `ad7b0f6776` (+ este documento) |
| 19 (upgrade) | `Test_Update_18.1_a_19.8.1` (antes `Test_Update_18.1_a_18.8`; renombrada el 2026-11-23) | `055bb6cbdb`, `563f523093`, `8ec5442d7a`, `bdb062dcc2`, `4f1f310323` (cherry-pick limpio) |

**Las dos ramas están solo en la máquina de desarrollo (sin push).** Antes del despliegue hay que subirlas
al remoto y unir `reservas-servicios-especiales` a `hotfix-18.1` (con aprobación).

Archivos: `Rock.Blocks/QREVENT/{SundayServiceCapacityAdmin,ReservationScanner,SundayServiceRegistration}.cs`,
`Rock.JavaScript.Obsidian.Blocks/src/QREVENT/SundayServiceCapacityAdmin.obs`,
`Dev Tools/Sql/QREVENT_SundayService_SlotSettings.sql`, docs. **Sin** cambios en SPs, esquema existente,
`.obs` de la app de reservas ni del escáner, `App_Code` ni plugins.

## Probado

- 18.1 local (`localhost:6231`, BD `Rock18Reservas` = bacpac de prod del 19-nov aislado): crear especiales,
  reservar, cambiar horario, escanear, llegar temprano, ventanas cruzadas, cierre tardío, ocultar/mostrar
  (por servicio y desde la plantilla), editar lugares y puerta, «Puerta normal». Regresión encontrada y
  corregida (el formulario reactivaba servicios desactivados).
- 19 local (`localhost:6229`, `Rock19Test`): compila 0 errores contra 19.8.1; crear especial, reservar,
  escanear y ocultar funcionan igual.
- Ambas BDs de prueba se dejaron idénticas al original de prod en sábados y domingos.

## Fecha límite

Las reservas de **Nochebuena (jueves 24-dic)** abren el **viernes 18-dic** (la app muestra 7 días). Lo ideal es
desplegar **antes del viernes 11-dic** para que el ministerio configure con calma. Si el domingo 27-dic tendrá un
solo servicio, hay que desactivar los normales **antes del lunes 21-dic** (cuando abre su reserva).

## Pasos

**Ventana:** entre semana, fuera de horario de reservas (nunca sábado en la noche ni domingo).

### 0. Máquina de build

1. `hotfix-18.1` con la rama unida; `git status` limpio; anotar el hash.
2. `.\"Dev Tools\Build\build-all.ps1" -FullObsidian` (Release).
3. Kit con rutas:
   - `Bin\Rock.dll`, `Bin\Rock.Blocks.dll`, `Bin\Rock.ViewModels.dll`, `Bin\Rock.Rest.dll` — **los cuatro del
     mismo build** (regla 2 del runbook; el cambio está en `Rock.Blocks.dll`, los otros van para no mezclar builds).
   - `Obsidian\Blocks\QREVENT\SundayServiceCapacityAdmin.obs.js` (+ `.map`).
   - `Dev Tools\Sql\QREVENT_SundayService_SlotSettings.sql`.
   - `Get-FileHash` de cada uno.

### 1. Prod: respaldo

- BD (o confirmar el respaldo del día) — como mínimo `dbo.SundayServiceSlot`.
- Copia con fecha de `RockWeb\Bin\{Rock,Rock.Blocks,Rock.ViewModels,Rock.Rest}.dll` y de
  `RockWeb\Obsidian\Blocks\QREVENT\SundayServiceCapacityAdmin.obs.js*`.

### 2. SQL (antes que la DLL)

```powershell
sqlcmd -S <servidor> -E -d Rock18 -I -f 65001 -i "QREVENT_SundayService_SlotSettings.sql"
```

Debe terminar con `ColumnaApertura 1 · ColumnaCierre 1 · ColumnaVisible 1 · Restricciones 2`. Es idempotente
(una segunda corrida dice «ya existía»). Toma segundos y **no cambia el comportamiento**: las columnas nuevas
quedan en NULL = lo de siempre.

### 3. Copiar el kit sobre `RockWeb\` (DLLs + bundle en la misma pasada)

Recicla el sitio; primera carga 2+ min. Reiniciar el app pool para que Obsidian recalcule el fingerprint.

### 4. Verificación

- [ ] 862 abre con las pestañas «Semana normal / Servicios especiales / Métricas» y **sin** el aviso azul de
      «falta preparar la base de datos».
- [ ] En «Semana normal», los domingos muestran «Puerta 6:45 a 8:20», «8:45 a 10:20», etc. (lo de siempre) y
      ninguno «Oculto en la app».
- [ ] 860 muestra los mismos horarios que antes del despliegue.
- [ ] Crear un especial de prueba **oculto** para mañana: aparece en «Programados» y **no** en la 860.
      Desactivarlo.
- [ ] 863 abre (fuera de horario: «Sin horario activo» y el «Próximo» correcto).
- [ ] `RockExceptions.csv` / Excepciones: nada nuevo de `QREVENT` / `SundayService`.
- [ ] Registrar fecha, hash, hashes de archivos y resultado en `Rock.Blocks/QREVENT/CHANGES.md` y
      `DEPLOY_PRODUCCION.md` §8.

### 5. Si algo sale mal (revertir)

1. Restaurar los 4 DLLs y el bundle del respaldo del paso 1 → el sitio vuelve a lo anterior. **Las columnas
   nuevas pueden quedarse**: el DLL viejo no las usa.
2. Solo si hiciera falta quitar las columnas: las instrucciones están al inicio del script (y luego reiniciar el
   sitio).
3. Los servicios especiales que se hubieran creado quedan como horarios en la categoría «Servicios especiales
   (Reservas)»; con el DLL viejo el escáner no los reconoce (no están en su lista de horarios).

## Para la 19 (upgrade)

Los commits ya están en `Test_Update_18.1_a_19.8.1`. Si el script se corre en prod **antes** del upgrade, las
columnas viajan solas con la BD. Agregar al runbook del upgrade (`docs/HANDOFF/UPGRADE_19.8.1.md`) el paso
«correr `QREVENT_SundayService_SlotSettings.sql` si no se corrió antes» (idempotente).
