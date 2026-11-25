/*
    19.8.1_respaldo_bd.sql — respaldo COPY_ONLY de la BD de Rock antes del upgrade (CHECKLIST C3).

    Se corre DESDE EL SERVIDOR WEB con Invoke-SqlDesdeWeb.ps1 (conexión del sitio, conectada a Rock18):
        powershell -NoProfile -ExecutionPolicy Bypass -File .\Invoke-SqlDesdeWeb.ps1 -Archivo .\19.8.1_respaldo_bd.sql

    - Escribe en la carpeta de respaldos por defecto del servidor SQL: <InstanceDefaultBackupPath>\Rock18_antes_19.8.1.bak
      (WITH INIT, FORMAT: si ya existe ese archivo, por ejemplo de un ensayo, se REEMPLAZA; así no se acumulan).
    - COPY_ONLY: no altera la cadena de respaldos automáticos que ya existe (los diarios de las 12:39).
    - CHECKSUM: SQL valida cada página al escribir. Luego intenta RESTORE VERIFYONLY (puede negarse por permisos: la
      cuenta del sitio no tiene CREATE DATABASE; en ese caso la prueba es el CHECKSUM + el registro en msdb).
    - Al final dice OK solo si msdb registra un respaldo de esta corrida (no uno viejo del mismo archivo).
    No modifica la BD.

    Responsable del upgrade: Fredy Ramirez.
*/
SET NOCOUNT ON;
DECLARE @bd sysname = DB_NAME();
IF @bd <> N'Rock18'
BEGIN
    RAISERROR(N'Este script respalda Rock18 y la conexión está en %s. No se hizo nada.', 16, 1, @bd);
    RETURN;
END;

DECLARE @dir nvarchar(260) = CAST(SERVERPROPERTY('InstanceDefaultBackupPath') AS nvarchar(260));
DECLARE @archivo nvarchar(400) = @dir + N'\' + @bd + N'_antes_19.8.1.bak';
DECLARE @inicio datetime = GETDATE();
DECLARE @ok bit = 0;
PRINT N'== Respaldo de ' + @bd + N' en ' + @archivo + N' (inicio ' + CONVERT(nvarchar(19), @inicio, 120) + N')';

BEGIN TRY
    BACKUP DATABASE @bd TO DISK = @archivo WITH COPY_ONLY, INIT, FORMAT, CHECKSUM, COMPRESSION, STATS = 10;
    SET @ok = 1;
END TRY
BEGIN CATCH
    PRINT N'FALLÓ EL RESPALDO: ' + ERROR_MESSAGE();
END CATCH;

IF @ok = 1
BEGIN
    PRINT N'== Verificación del archivo (RESTORE VERIFYONLY)';
    BEGIN TRY
        RESTORE VERIFYONLY FROM DISK = @archivo WITH CHECKSUM;
        PRINT N'VERIFYONLY: el archivo es válido.';
    END TRY
    BEGIN CATCH
        PRINT N'VERIFYONLY no se pudo correr (' + ERROR_MESSAGE() + N'). Se toma como prueba el CHECKSUM del respaldo y msdb.';
    END CATCH;
END;

PRINT N'== Resultado';
SELECT TOP 1 bs.backup_start_date AS Inicio, bs.backup_finish_date AS Termino,
       DATEDIFF(second, bs.backup_start_date, bs.backup_finish_date) AS Segundos,
       CAST(bs.backup_size / 1048576 AS bigint) AS MB, CAST(bs.compressed_backup_size / 1048576 AS bigint) AS MB_comprimido,
       bs.has_backup_checksums AS ConChecksum, bs.is_damaged AS Danado, bmf.physical_device_name AS Archivo,
       CASE WHEN @ok = 1 AND bs.backup_start_date >= DATEADD(second, -5, @inicio) AND bs.has_backup_checksums = 1 AND bs.is_damaged = 0
            THEN 'OK: respaldo de esta corrida, con checksum'
            ELSE 'REVISAR: no hay un respaldo válido de esta corrida. NO seguir con la ventana.' END AS Resultado
FROM msdb.dbo.backupset bs JOIN msdb.dbo.backupmediafamily bmf ON bmf.media_set_id = bs.media_set_id
WHERE bs.database_name = @bd AND bs.is_copy_only = 1 AND bmf.physical_device_name = @archivo
ORDER BY bs.backup_finish_date DESC;
IF @ok = 0 SELECT 'REVISAR: el respaldo falló (ver el mensaje de arriba). NO seguir con la ventana.' AS Resultado;
