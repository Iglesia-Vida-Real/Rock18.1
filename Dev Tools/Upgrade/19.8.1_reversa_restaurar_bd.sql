/*
    19.8.1_reversa_restaurar_bd.sql — REVERSA: restaura Rock18 desde el respaldo de C3 (CHECKLIST E2).

    ¡SOBRESCRIBE LA BD DE PRODUCCIÓN! Solo en la fase E, con el sitio detenido (E1) y por decisión de Fredy Ramirez.

    Se corre DESDE EL SERVIDOR WEB con Invoke-SqlDesdeWeb.ps1 y -BaseMaster (la conexión del sitio, pero en master):
        powershell -NoProfile -ExecutionPolicy Bypass -File .\Invoke-SqlDesdeWeb.ps1 -Archivo .\19.8.1_reversa_restaurar_bd.sql -BaseMaster

    La cuenta del sitio es dueña (dbo) de Rock18: eso alcanza para RESTORE sobre la BD existente (preflight bloque 14).
    Probado en local con una cuenta con los mismos permisos (dueña de la BD, sin sysadmin ni dbcreator).
*/
SET NOCOUNT ON;
DECLARE @conectada sysname = DB_NAME();
IF @conectada <> N'master'
BEGIN
    RAISERROR(N'Correr con -BaseMaster (la conexión está en %s). No se hizo nada.', 16, 1, @conectada);
    RETURN;
END;

DECLARE @bd sysname = N'Rock18';
DECLARE @dir nvarchar(260) = CAST(SERVERPROPERTY('InstanceDefaultBackupPath') AS nvarchar(260));
DECLARE @archivo nvarchar(400) = @dir + N'\' + @bd + N'_antes_19.8.1.bak';
DECLARE @ok bit = 0;

-- El respaldo a restaurar debe ser el de C3 (COPY_ONLY, con checksum) y debe existir en msdb.
SELECT TOP 1 bs.backup_finish_date AS RespaldoDe, CAST(bs.backup_size / 1048576 AS bigint) AS MB, bmf.physical_device_name AS Archivo
FROM msdb.dbo.backupset bs JOIN msdb.dbo.backupmediafamily bmf ON bmf.media_set_id = bs.media_set_id
WHERE bs.database_name = @bd AND bs.is_copy_only = 1 AND bmf.physical_device_name = @archivo
ORDER BY bs.backup_finish_date DESC;

PRINT N'== Restaurando ' + @bd + N' desde ' + @archivo + N' (' + CONVERT(nvarchar(19), GETDATE(), 120) + N')';
BEGIN TRY
    ALTER DATABASE [Rock18] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    RESTORE DATABASE [Rock18] FROM DISK = @archivo WITH REPLACE, CHECKSUM, STATS = 10;
    SET @ok = 1;
END TRY
BEGIN CATCH
    PRINT N'FALLÓ LA RESTAURACIÓN: ' + ERROR_MESSAGE();
END CATCH;

-- Siempre dejar la BD abierta a todos, haya salido bien o no.
BEGIN TRY ALTER DATABASE [Rock18] SET MULTI_USER; END TRY BEGIN CATCH PRINT N'MULTI_USER: ' + ERROR_MESSAGE(); END CATCH;

SELECT d.name AS BD, d.state_desc AS Estado, d.user_access_desc AS Acceso,
       (SELECT TOP 1 MigrationId FROM [Rock18].dbo.__MigrationHistory ORDER BY MigrationId DESC) AS UltimaMigracion,
       CASE WHEN @ok = 1 AND d.state_desc = 'ONLINE' AND d.user_access_desc = 'MULTI_USER'
                 AND (SELECT TOP 1 MigrationId FROM [Rock18].dbo.__MigrationHistory ORDER BY MigrationId DESC) = '202511121736124_CodeGenerated_20251112'
            THEN 'OK: Rock18 restaurada al estado de 18.1'
            ELSE 'REVISAR: la restauración no quedó bien (ver mensajes)' END AS Resultado
FROM sys.databases d WHERE d.name = @bd;
