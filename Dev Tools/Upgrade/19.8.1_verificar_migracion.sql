/*
    19.8.1_verificar_migracion.sql — después de C9: ¿terminaron bien las migraciones de la 19? Solo lectura.
    Correr desde el servidor web:  .\Invoke-SqlDesdeWeb.ps1 -Archivo .\19.8.1_verificar_migracion.sql
    Esperado (igual que la prueba local en Rock19Test): core 202605122315282_UpdateExistingToCoreAzureBlobStorageProvider
    con 774 filas; PluginMigration «Rock» 338 / 296; el resto de plugins igual que antes.
    Excepciones: solo cuenta y agrupa las nuevas desde la línea base de C10 (MaxExc = 1721843, 2026-11-27 22:12).
*/
SET NOCOUNT ON;
PRINT N'== 1. Migraciones del core';
SELECT TOP 1 MigrationId AS UltimaMigracion, (SELECT COUNT(*) FROM dbo.__MigrationHistory) AS Total,
       CASE WHEN MigrationId = '202605122315282_UpdateExistingToCoreAzureBlobStorageProvider'
                 AND (SELECT COUNT(*) FROM dbo.__MigrationHistory) = 774
            THEN 'OK: igual que la prueba local de la 19' ELSE 'REVISAR: distinto de la prueba local' END AS Resultado
FROM dbo.__MigrationHistory ORDER BY MigrationId DESC;

PRINT N'== 2. Migraciones de plugins (Rock debe quedar en 338 / 296)';
SELECT PluginAssemblyName AS Ensamblado, MAX(MigrationNumber) AS Ultimo, COUNT(*) AS Filas,
       CASE WHEN PluginAssemblyName = 'Rock' AND (MAX(MigrationNumber) <> 338 OR COUNT(*) <> 296) THEN 'REVISAR' ELSE 'OK' END AS Resultado
FROM dbo.PluginMigration GROUP BY PluginAssemblyName ORDER BY 1;

PRINT N'== 3. Excepciones nuevas desde la línea base (agrupadas; el ruido conocido es AIAgentSessionAnchor, .ascx inexistentes, OpenID)';
SELECT COUNT(*) AS Nuevas, MIN(CreatedDateTime) AS Primera, MAX(CreatedDateTime) AS Ultima FROM dbo.ExceptionLog WHERE Id > 1721843;
SELECT TOP 25 COUNT(*) AS Veces, LEFT(ExceptionType, 60) AS Tipo, LEFT(REPLACE(REPLACE(Description, CHAR(13), ' '), CHAR(10), ' '), 160) AS Descripcion
FROM dbo.ExceptionLog WHERE Id > 1721843
GROUP BY LEFT(ExceptionType, 60), LEFT(REPLACE(REPLACE(Description, CHAR(13), ' '), CHAR(10), ' '), 160)
ORDER BY 1 DESC;
