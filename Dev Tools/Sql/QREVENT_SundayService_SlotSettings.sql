/*
================================================================================
  QREVENT · Sunday Service — ajustes por cupo (2026-11-20 / 2026-11-23)
================================================================================

  Agrega a dbo.SundayServiceSlot tres columnas que se configuran desde
  Configuración Domingos (página 862), por cupo y al crear un servicio especial:

    · CheckInOpensMinutesBefore  — minutos ANTES de la hora de inicio en que el
      escáner de la puerta (página 863) empieza a aceptar los QR del cupo.
      NULL = 15 (valor de siempre).
    · CheckInClosesMinutesAfter  — minutos DESPUÉS de la hora de inicio en que la
      puerta deja de aceptar QR y la app (página 860) deja de aceptar reservas
      para ese cupo (cierran juntas a propósito). NULL = 80 (valor de siempre).
      No hay check-out en este módulo.
    · ShowInApp                  — 0 = el cupo NO aparece en la app de reservas y
      no se puede reservar; quien ya reservó sigue entrando por la puerta con su
      QR. NULL o 1 = visible (valor de siempre).

  NULL en las tres = exactamente el comportamiento de antes del cambio: ninguna
  fila existente cambia.

  IDEMPOTENTE: se puede correr varias veces; la segunda no cambia nada.
  Toma segundos: agregar columnas NULL es solo metadato (no reescribe la
  tabla). Aun así, correrlo fuera de horario de reservas.

  ORDEN DE DESPLIEGUE
    El DLL nuevo funciona CON y SIN estas columnas (las detecta solo y, sin
    ellas, usa los valores de siempre y la pantalla avisa que falta el script).
    Lo recomendado igual es: 1) este SQL, 2) DLL + bundle.

  Correr con:
    sqlcmd -S <servidor> -E -d <BD> -I -f 65001 -i QREVENT_SundayService_SlotSettings.sql
  (-I = QUOTED_IDENTIFIER ON; la tabla hermana tiene índice filtrado.)

  REVERTIR (solo si hiciera falta). Después de revertir, REINICIAR el sitio:
  el DLL recuerda que las columnas existían y seguiría usándolas.
    ALTER TABLE dbo.SundayServiceSlot DROP CONSTRAINT CK_SundayServiceSlot_CheckInOpensMinutesBefore;
    ALTER TABLE dbo.SundayServiceSlot DROP CONSTRAINT CK_SundayServiceSlot_CheckInClosesMinutesAfter;
    ALTER TABLE dbo.SundayServiceSlot DROP COLUMN CheckInOpensMinutesBefore, CheckInClosesMinutesAfter, ShowInApp;
================================================================================
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;

IF OBJECT_ID( N'dbo.SundayServiceSlot', N'U' ) IS NULL
BEGIN
    RAISERROR( N'ABORTADO: no existe dbo.SundayServiceSlot en esta BD.', 16, 1 );
    SET NOEXEC ON;
END;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRANSACTION;

IF COL_LENGTH( N'dbo.SundayServiceSlot', N'CheckInOpensMinutesBefore' ) IS NULL
BEGIN
    ALTER TABLE dbo.SundayServiceSlot ADD CheckInOpensMinutesBefore INT NULL;
    PRINT N'Columna CheckInOpensMinutesBefore agregada.';
END
ELSE
    PRINT N'Columna CheckInOpensMinutesBefore ya existía.';

IF COL_LENGTH( N'dbo.SundayServiceSlot', N'CheckInClosesMinutesAfter' ) IS NULL
BEGIN
    ALTER TABLE dbo.SundayServiceSlot ADD CheckInClosesMinutesAfter INT NULL;
    PRINT N'Columna CheckInClosesMinutesAfter agregada.';
END
ELSE
    PRINT N'Columna CheckInClosesMinutesAfter ya existía.';

IF COL_LENGTH( N'dbo.SundayServiceSlot', N'ShowInApp' ) IS NULL
BEGIN
    ALTER TABLE dbo.SundayServiceSlot ADD ShowInApp BIT NULL;
    PRINT N'Columna ShowInApp agregada.';
END
ELSE
    PRINT N'Columna ShowInApp ya existía.';

COMMIT TRANSACTION;
GO

SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;

-- Las restricciones van en un lote aparte: en el mismo lote del ALTER ADD las
-- columnas todavía no existen para el compilador.
IF NOT EXISTS ( SELECT 1 FROM sys.check_constraints WHERE name = N'CK_SundayServiceSlot_CheckInOpensMinutesBefore' )
BEGIN
    ALTER TABLE dbo.SundayServiceSlot WITH CHECK
        ADD CONSTRAINT CK_SundayServiceSlot_CheckInOpensMinutesBefore
        CHECK ( CheckInOpensMinutesBefore IS NULL OR CheckInOpensMinutesBefore BETWEEN 0 AND 240 );
    PRINT N'Restricción CK_SundayServiceSlot_CheckInOpensMinutesBefore agregada (0 a 240 min).';
END
ELSE
    PRINT N'Restricción CK_SundayServiceSlot_CheckInOpensMinutesBefore ya existía.';

IF NOT EXISTS ( SELECT 1 FROM sys.check_constraints WHERE name = N'CK_SundayServiceSlot_CheckInClosesMinutesAfter' )
BEGIN
    ALTER TABLE dbo.SundayServiceSlot WITH CHECK
        ADD CONSTRAINT CK_SundayServiceSlot_CheckInClosesMinutesAfter
        CHECK ( CheckInClosesMinutesAfter IS NULL OR CheckInClosesMinutesAfter BETWEEN 0 AND 720 );
    PRINT N'Restricción CK_SundayServiceSlot_CheckInClosesMinutesAfter agregada (0 a 720 min).';
END
ELSE
    PRINT N'Restricción CK_SundayServiceSlot_CheckInClosesMinutesAfter ya existía.';
GO

-- Verificación
SELECT
    ColumnaApertura = CASE WHEN COL_LENGTH( N'dbo.SundayServiceSlot', N'CheckInOpensMinutesBefore' ) IS NULL THEN 0 ELSE 1 END,
    ColumnaCierre   = CASE WHEN COL_LENGTH( N'dbo.SundayServiceSlot', N'CheckInClosesMinutesAfter' ) IS NULL THEN 0 ELSE 1 END,
    ColumnaVisible  = CASE WHEN COL_LENGTH( N'dbo.SundayServiceSlot', N'ShowInApp' ) IS NULL THEN 0 ELSE 1 END,
    Restricciones   = ( SELECT COUNT(*) FROM sys.check_constraints
                        WHERE name IN ( N'CK_SundayServiceSlot_CheckInOpensMinutesBefore', N'CK_SundayServiceSlot_CheckInClosesMinutesAfter' ) );
GO

SET NOEXEC OFF;
GO
