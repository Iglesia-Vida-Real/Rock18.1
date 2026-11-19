/* =====================================================================================
   19.8.1_job_reemplazo_bloques_huerfanos.sql        PROPUESTA — NO CORRER SIN APROBACIÓN
   -------------------------------------------------------------------------------------
   Problema (detectado 2026-11-19 en Rock19Test, ver docs/HANDOFF/UPGRADE_19.8.1.md §11.4):
   upstream borró en la 19 los .ascx de «System Phone Number List» y «Interactive Experience
   List» y los reemplazó por bloques Obsidian que REUSAN el BlockType.Guid del .ascx. En nuestra
   BD esos .ascx se registraron con GUIDs propios (CCF3C814…, 1BC8542B…), así que la 19 creó
   BlockTypes nuevos (72C74D98…, BD89FE49…) y las páginas siguen apuntando al .ascx que ya no
   existe:
       Página 327 «System Phone Numbers»       (Admin > Communications > System Phone Numbers)
       Página 740 «Experience Administration»  (Interactive Experiences)
   Ningún job post-actualización los arregla.

   Arreglo propuesto: crear UN job más del mismo tipo que usa upstream
   (Rock.Jobs.PostUpdateDataMigrationsReplaceWebFormsBlocksWithObsidianBlocks, estrategia Chop).
   Ese job copia cada bloque al tipo Obsidian en la misma zona y orden, copia valores de
   atributos (las llaves coinciden: SystemPhoneNumberDetailPage / DetailPage +
   OccurrenceChooserPage), permisos y preferencias, borra los bloques viejos y el BlockType viejo,
   y se borra a sí mismo si termina bien.

   - No ejecuta nada: solo crea el job. Se corre con «Run Now» en Admin > System Settings > Jobs.
   - Idempotente: si el job ya existe, solo reescribe sus atributos.
   - Sirve para Rock19Test y para prod el día real (mismos GUIDs: la BD local es copia de prod).
   - Correr: sqlcmd -S <servidor> -d <bd> -E -I -b -i "Dev Tools\Upgrade\19.8.1_job_reemplazo_bloques_huerfanos.sql"
   ===================================================================================== */
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @JobGuid uniqueidentifier = '5F2B6E31-7A1D-4C1E-9A6B-19081A000001';  -- propio, fijo
DECLARE @Class nvarchar(200) = N'Rock.Jobs.PostUpdateDataMigrationsReplaceWebFormsBlocksWithObsidianBlocks';
DECLARE @Pares nvarchar(max) =
      N'CCF3C814-5D4E-4BBE-BB69-7FFBF7D1A45D^72C74D98-D80F-4EEE-BD14-6308EA565D7A'   -- System Phone Number List
    + N'|1BC8542B-D2C8-4496-BB5C-EFF4C0E6AE9D^BD89FE49-4DD2-4313-AFF8-ABAA97B3235D'; -- Interactive Experience List

-- Prerrequisitos: los 4 BlockTypes deben existir; si no, no hay nada que hacer (o ya se hizo).
IF (SELECT COUNT(*) FROM BlockType WHERE [Guid] IN ('CCF3C814-5D4E-4BBE-BB69-7FFBF7D1A45D', '72C74D98-D80F-4EEE-BD14-6308EA565D7A',
                                                   '1BC8542B-D2C8-4496-BB5C-EFF4C0E6AE9D', 'BD89FE49-4DD2-4313-AFF8-ABAA97B3235D')) <> 4
BEGIN
    RAISERROR(N'No están los 4 BlockTypes esperados (¿ya se reemplazaron?). No se hace nada.', 16, 1);
    RETURN;
END

DECLARE @AttrPares int     = (SELECT Id FROM Attribute WHERE [Guid] = 'CDDB8075-E559-499F-B12F-B8DC8CCD73B5'); -- BlockTypeGuidReplacementPairs
DECLARE @AttrEstrategia int = (SELECT Id FROM Attribute WHERE [Guid] = 'FA99E828-2388-4CDF-B69B-DBC36332D6A4'); -- MigrationStrategy
IF @AttrPares IS NULL OR @AttrEstrategia IS NULL
BEGIN
    RAISERROR(N'Faltan los atributos del job de reemplazo (la BD no está en 19.x).', 16, 1);
    RETURN;
END

BEGIN TRAN;

IF NOT EXISTS (SELECT 1 FROM ServiceJob WHERE [Guid] = @JobGuid)
    INSERT INTO ServiceJob (IsSystem, IsActive, [Name], [Description], [Class], CronExpression, NotificationStatus, [Guid], CreatedDateTime, ModifiedDateTime)
    VALUES (0, 1,
            N'VidaReal - Replace WebForms Blocks - System Phone Numbers + Interactive Experiences',
            N'Upgrade 19.8.1: reemplaza los bloques WebForms huérfanos (su .ascx ya no existe) por sus equivalentes Obsidian. Ver docs/HANDOFF/UPGRADE_19.8.1.md §11.4.',
            @Class, N'0 0 21 1/1 * ? *', 1, @JobGuid, GETDATE(), GETDATE());

DECLARE @JobId int = (SELECT Id FROM ServiceJob WHERE [Guid] = @JobGuid);

MERGE AttributeValue AS t
USING (VALUES (@AttrPares, @Pares), (@AttrEstrategia, N'Chop')) AS s (AttributeId, [Value])
   ON t.AttributeId = s.AttributeId AND t.EntityId = @JobId
WHEN MATCHED AND t.[Value] <> s.[Value] THEN UPDATE SET [Value] = s.[Value], ModifiedDateTime = GETDATE()
WHEN NOT MATCHED THEN INSERT (IsSystem, AttributeId, EntityId, [Value], [Guid], CreatedDateTime, ModifiedDateTime)
                      VALUES (0, s.AttributeId, @JobId, s.[Value], NEWID(), GETDATE(), GETDATE());

COMMIT;

SELECT j.Id, j.[Name], j.IsActive, a.[Key], av.[Value]
FROM ServiceJob j
JOIN AttributeValue av ON av.EntityId = j.Id
JOIN Attribute a ON a.Id = av.AttributeId AND a.Id IN (@AttrPares, @AttrEstrategia)
WHERE j.Id = @JobId;
