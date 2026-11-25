/*
    19.8.1_preflight_bd_prod.sql — revisión de la BD de producción ANTES del upgrade a Rock 19.8.1.

    SOLO LECTURA: no cambia nada (solo SELECT sobre la BD, sys.* y msdb). Se puede correr con el sitio arriba.
    Uso (en el servidor de SQL de prod, con una cuenta que pueda leer la BD y msdb):
        sqlcmd -S <servidor> -E -d Rock18 -I -f 65001 -W -s "|" -i 19.8.1_preflight_bd_prod.sql -o preflight_resultado.txt
    No incluye datos de personas: solo versiones, tamaños, conteos y nombres de migraciones.

    Cada bloque dice qué valor se espera. Si algo marca «REVISAR», no seguir con el upgrade hasta entenderlo.
    Valores de referencia tomados de la copia de prod del 18/19-nov (BD local Rock18Base) el 2026-11-23.
*/
SET NOCOUNT ON;

PRINT '== 1. Servidor SQL (la 19 exige SQL Server 2016 o más nuevo; VersionValidationHelper)';
SELECT CAST(SERVERPROPERTY('ProductVersion') AS varchar(20)) AS VersionProducto,
       CAST(SERVERPROPERTY('ProductLevel') AS varchar(20)) AS Nivel,
       CAST(SERVERPROPERTY('Edition') AS varchar(60)) AS Edicion,
       CASE WHEN CAST(PARSENAME(CAST(SERVERPROPERTY('ProductVersion') AS varchar(20)), 4) AS int) >= 13
            THEN 'OK' ELSE 'REVISAR: menor que SQL Server 2016' END AS Resultado;

PRINT '== 2. Base de datos (nivel de compatibilidad >= 130; la 19 se niega a instalar con menos)';
SELECT d.name AS BD, d.compatibility_level AS NivelCompat, d.recovery_model_desc AS Recuperacion,
       d.state_desc AS Estado, d.collation_name AS Intercalacion, d.is_read_only AS SoloLectura,
       CASE WHEN d.compatibility_level >= 130 THEN 'OK' ELSE 'REVISAR: subir el nivel de compatibilidad antes' END AS Resultado
FROM sys.databases d WHERE d.name = DB_NAME();

PRINT '== 3. Tamaño de la BD (referencia: ~7.3 GB en total, ~7.1 GB de datos)';
SELECT type_desc AS Tipo, name AS ArchivoLogico, physical_name AS Ruta,
       CAST(size * 8 / 1024 AS int) AS MB, CAST(FILEPROPERTY(name, 'SpaceUsed') * 8 / 1024 AS int) AS MB_usados
FROM sys.database_files;

PRINT '== 4. Espacio libre en los discos de la BD (el .bak COPY_ONLY ocupa casi lo mismo que los datos)';
SELECT DISTINCT vs.volume_mount_point AS Disco,
       CAST(vs.total_bytes / 1048576 AS bigint) AS MB_total,
       CAST(vs.available_bytes / 1048576 AS bigint) AS MB_libres,
       CASE WHEN vs.available_bytes / 1048576 > 3 * (SELECT SUM(size) * 8 / 1024 FROM sys.database_files)
            THEN 'OK' ELSE 'REVISAR: poco espacio para .bak + crecimiento del log en las migraciones' END AS Resultado
FROM sys.database_files f CROSS APPLY sys.dm_os_volume_stats(DB_ID(), f.file_id) vs;

PRINT '== 5. Últimos respaldos registrados en msdb';
SELECT TOP 5 bs.type AS Tipo /* D=completo, I=diferencial, L=log */, bs.is_copy_only AS CopyOnly,
       bs.backup_finish_date AS Termino, CAST(bs.backup_size / 1048576 AS bigint) AS MB,
       bmf.physical_device_name AS Archivo
FROM msdb.dbo.backupset bs JOIN msdb.dbo.backupmediafamily bmf ON bmf.media_set_id = bs.media_set_id
WHERE bs.database_name = DB_NAME() ORDER BY bs.backup_finish_date DESC;

PRINT '== 6. Migraciones del core (esperado en 18.1: última 202511121736124_CodeGenerated_20251112, 707 filas)';
SELECT (SELECT TOP 1 MigrationId FROM dbo.__MigrationHistory ORDER BY MigrationId DESC) AS UltimaMigracion,
       (SELECT COUNT(*) FROM dbo.__MigrationHistory) AS Total,
       CASE WHEN (SELECT TOP 1 MigrationId FROM dbo.__MigrationHistory ORDER BY MigrationId DESC) = '202511121736124_CodeGenerated_20251112'
            THEN 'OK (igual que la copia probada)' ELSE 'REVISAR: prod no está donde la copia probada' END AS Resultado;

PRINT '== 7. Migraciones de plugins (esperado = columna Esperado; el upgrade solo agrega hotfixes de «Rock»)';
WITH Esperado AS (
    SELECT * FROM (VALUES
        ('apollosproject.ApollosPlugin', 2, 2), ('com.bemaservices.MailChimp', 4, 4),
        ('com.bemaservices.WorkflowExtensions', 3, 3), ('com.blueboxmoon.AcmeCertificate', 6, 6),
        ('com.blueboxmoon.DataToolkit', 8, 8), ('com.minecartstudio.MinePass.Client', 3, 3),
        ('com.vidareal.DupDetect', 5, 5), ('com.vidareal.Events', 25, 9), ('com.vidareal.Qr', 7, 7),
        ('com.vidareal.Translator', 4, 4), ('com.vidareal.Wallet', 16, 16), ('Rock', 270, 251),
        ('Rock.Checkr', 11, 11), ('Rock.StatementGenerator', 3, 3),
        ('rocks.pillars.ServiceReservation', 6, 6), ('tech.triumph.MinistryPass.Client', 3, 3)
    ) v (Ensamblado, UltimoNumero, Filas)
)
SELECT COALESCE(e.Ensamblado, m.PluginAssemblyName) AS Ensamblado,
       e.UltimoNumero AS EsperadoUltimo, m.UltimoNumero AS ProdUltimo, e.Filas AS EsperadoFilas, m.Filas AS ProdFilas,
       CASE WHEN e.UltimoNumero = m.UltimoNumero AND e.Filas = m.Filas THEN 'OK'
            WHEN e.Ensamblado IS NULL THEN 'REVISAR: plugin que no estaba en la copia probada'
            WHEN m.PluginAssemblyName IS NULL THEN 'REVISAR: falta en prod'
            ELSE 'REVISAR: distinto de la copia probada' END AS Resultado
FROM Esperado e
FULL JOIN (SELECT PluginAssemblyName, MAX(MigrationNumber) AS UltimoNumero, COUNT(*) AS Filas
           FROM dbo.PluginMigration GROUP BY PluginAssemblyName) m ON m.PluginAssemblyName = e.Ensamblado
ORDER BY 1;

PRINT '== 8. Reservas dominicales: script QREVENT_SundayService_SlotSettings.sql (NULL = no se ha corrido; runbook §7.3 paso 5b)';
SELECT COL_LENGTH('dbo.SundayServiceSlot', 'CheckInOpensMinutesBefore') AS ColumnaApertura,
       COL_LENGTH('dbo.SundayServiceSlot', 'CheckInClosesMinutesAfter') AS ColumnaCierre,
       COL_LENGTH('dbo.SundayServiceSlot', 'ShowInApp') AS ColumnaVisible;

PRINT '== 9. Bloques que apuntan a un .ascx (los que la 19 quitó se revisan contra quitar_del_servidor.txt)';
SELECT COUNT(*) AS BloquesWebForms FROM dbo.Block b JOIN dbo.BlockType bt ON bt.Id = b.BlockTypeId
WHERE bt.Path LIKE '~/%.ascx';
SELECT bt.Path, COUNT(*) AS Bloques FROM dbo.Block b JOIN dbo.BlockType bt ON bt.Id = b.BlockTypeId
WHERE bt.Path IN ('~/Blocks/Cms/FileManager.ascx', '~/Blocks/Reporting/ServiceMetricsEntry.ascx',
                  '~/Blocks/Communication/SystemPhoneNumberList.ascx', '~/Blocks/Event/InteractiveExperiences/InteractiveExperienceList.ascx')
GROUP BY bt.Path;   -- esperado: las páginas 433, 451, 327, 740 (las arreglan los jobs / el job de UPGRADE §11.4)

PRINT '== 10. Actividad en este momento (el día del cambio debe estar en 0 o casi)';
SELECT COUNT(*) AS SesionesALaBD FROM sys.dm_exec_sessions WHERE database_id = DB_ID() AND session_id <> @@SPID;
SELECT COUNT(*) AS CheckInsAbiertosHoy FROM dbo.Attendance
WHERE StartDateTime >= CAST(GETDATE() AS date) AND EndDateTime IS NULL AND DidAttend = 1;

PRINT '== 11. Tablas grandes (referencia de la copia probada: History ~3.8 M, AttributeValue ~565 mil)';
SELECT TOP 8 t.name AS Tabla, SUM(p.rows) AS Filas
FROM sys.tables t JOIN sys.partitions p ON p.object_id = t.object_id AND p.index_id IN (0, 1)
GROUP BY t.name ORDER BY 2 DESC;

PRINT '== 12. Valores cifrados que la 19 confundiría con su formato nuevo «V2» (esperado: 0; en la copia del 19-nov: 0 de 83)';
-- La 19 (Encryption.cs, DecryptString) trata como V2 todo valor cuyos 2 últimos bytes sean 0x56 0x32 y entonces NO
-- intenta el descifrado de siempre: ese secreto (p. ej. de ePay o Dar) quedaría vacío. Probabilidad 1/65536 por valor.
-- Solo cuenta; no muestra ningún valor.
SELECT COUNT(*) AS ValoresCifrados,
       SUM(CASE WHEN SUBSTRING(b.Bytes, DATALENGTH(b.Bytes) - 1, 2) = 0x5632 THEN 1 ELSE 0 END) AS ConPieV2,
       CASE WHEN SUM(CASE WHEN SUBSTRING(b.Bytes, DATALENGTH(b.Bytes) - 1, 2) = 0x5632 THEN 1 ELSE 0 END) = 0 THEN 'OK'
            ELSE 'REVISAR: re-guardar ese secreto en la 19 desde la UI (ver GUIA_FALLAS_PAGOS_19.8.1.md)' END AS Resultado
FROM dbo.AttributeValue av
CROSS APPLY (SELECT CAST(N'' AS xml).value('xs:base64Binary(sql:column("av.Value"))', 'varbinary(max)') AS Bytes) b
WHERE LEFT(av.Value, 5) = 'EAAAA';

PRINT '== 13. Bloques que usan un .ascx que la 19 retira (quitar_del_servidor.txt). En la copia probada del 19-nov: 88 tipos, 204 bloques; tras migraciones y jobs en la 19 local quedaron 0)';
SELECT COUNT(DISTINCT bt.Path) AS Tipos, COUNT(b.Id) AS Bloques,
       CASE WHEN COUNT(DISTINCT bt.Path) <= 88 AND COUNT(b.Id) <= 204 THEN 'OK (igual o menos que la copia probada)'
            ELSE 'REVISAR: hay bloques nuevos sobre .ascx retirados desde el 19-nov (ver la lista de abajo)' END AS Resultado
FROM dbo.BlockType bt JOIN dbo.Block b ON b.BlockTypeId = bt.Id
WHERE bt.Path IN (
    '~/Blocks/Administration/ExternalApplicationList.ascx', '~/Blocks/Administration/NotificationList.ascx', '~/Blocks/BulkImport/CsvImport.ascx',
    '~/Blocks/Bus/BusStatus.ascx', '~/Blocks/CheckIn/Manager/Roster.ascx', '~/Blocks/Cms/ContentChannelDetail.ascx',
    '~/Blocks/Cms/ContentChannelItemList.ascx', '~/Blocks/Cms/ContentChannelList.ascx', '~/Blocks/Cms/ContentCollectionList.ascx',
    '~/Blocks/Cms/FileEditor.ascx', '~/Blocks/Cms/FileManager.ascx', '~/Blocks/Cms/MediaAccountDetail.ascx',
    '~/Blocks/Cms/MediaAccountList.ascx', '~/Blocks/Cms/MediaElementList.ascx', '~/Blocks/Cms/MediaFolderDetail.ascx',
    '~/Blocks/Cms/MediaFolderList.ascx', '~/Blocks/Cms/PageMap.ascx', '~/Blocks/Cms/PageMenu.ascx',
    '~/Blocks/Cms/PersonalizationSegmentDetail.ascx', '~/Blocks/Cms/PersonalizationSegmentResults.ascx', '~/Blocks/Cms/Redirect.ascx',
    '~/Blocks/Cms/RequestFilterDetails.ascx', '~/Blocks/Cms/RequestFilterList.ascx', '~/Blocks/Communication/CommunicationListSubscribe.ascx',
    '~/Blocks/Communication/SnippetList.ascx', '~/Blocks/Communication/SnippetTypeList.ascx', '~/Blocks/Communication/SystemCommunicationDetail.ascx',
    '~/Blocks/Communication/SystemCommunicationList.ascx', '~/Blocks/Communication/SystemEmailDetail.ascx', '~/Blocks/Communication/SystemEmailList.ascx',
    '~/Blocks/Communication/SystemPhoneNumberList.ascx', '~/Blocks/Communication/TemplateList.ascx', '~/Blocks/Connection/CampaignConfiguration.ascx',
    '~/Blocks/Connection/CampaignList.ascx', '~/Blocks/Connection/ConnectionOpportunityDetail.ascx', '~/Blocks/Connection/ConnectionOpportunityList.ascx',
    '~/Blocks/Connection/ConnectionOpportunitySelect.ascx', '~/Blocks/Connection/ConnectionTypeDetail.ascx', '~/Blocks/Connection/ConnectionTypeList.ascx',
    '~/Blocks/Core/AttributeCategories.ascx', '~/Blocks/Core/Attributes.ascx', '~/Blocks/Core/CampusContextSetter.ascx',
    '~/Blocks/Core/CategoryDetail.ascx', '~/Blocks/Core/Components.ascx', '~/Blocks/Core/ExceptionDetail.ascx',
    '~/Blocks/Core/ExceptionOccurrences.ascx', '~/Blocks/Core/PluginManager.ascx', '~/Blocks/Core/SmartSearch.ascx',
    '~/Blocks/Crm/PersonDetail/GivingConfiguration.ascx', '~/Blocks/Crm/PersonDuplicateDetail.ascx', '~/Blocks/Crm/PersonDuplicateList.ascx',
    '~/Blocks/Crm/PersonMergeRequestList.ascx', '~/Blocks/Crm/PersonalDeviceInteractions.ascx', '~/Blocks/Crm/PersonalDevices.ascx',
    '~/Blocks/Event/CalendarDetail.ascx', '~/Blocks/Event/EventItemDetail.ascx', '~/Blocks/Event/EventItemList.ascx',
    '~/Blocks/Event/EventItemOccurrenceList.ascx', '~/Blocks/Event/InteractiveExperiences/InteractiveExperienceList.ascx', '~/Blocks/Event/RegistrationEntry.ascx',
    '~/Blocks/Event/RegistrationInstanceLinkageDetail.ascx', '~/Blocks/Examples/DevelopEnvironmentInfo.ascx', '~/Blocks/Examples/ModelMap.ascx',
    '~/Blocks/Examples/SampleData.ascx', '~/Blocks/Finance/BenevolenceRequestDetail.ascx', '~/Blocks/Finance/BusinessContactList.ascx',
    '~/Blocks/Finance/BusinessDetail.ascx', '~/Blocks/Finance/BusinessList.ascx', '~/Blocks/Finance/ConvertBusiness.ascx',
    '~/Blocks/Finance/PledgeAnalytics.ascx', '~/Blocks/Groups/GroupTypeDetail.ascx', '~/Blocks/Groups/GroupTypeList.ascx',
    '~/Blocks/Mobile/MobileDeepLinkDetail.ascx', '~/Blocks/Prayer/PrayerRequestList.ascx', '~/Blocks/Reporting/DynamicHeatMap.ascx',
    '~/Blocks/Reporting/Insights.ascx', '~/Blocks/Reporting/InteractionChannelDetail.ascx', '~/Blocks/Reporting/InteractionComponentDetail.ascx',
    '~/Blocks/Reporting/PersistedDataViewList.ascx', '~/Blocks/Reporting/ReportList.ascx', '~/Blocks/Reporting/ReportSearch.ascx',
    '~/Blocks/Reporting/ServiceMetricsEntry.ascx', '~/Blocks/Security/BackgroundCheck/CheckrRequestList.ascx', '~/Blocks/Security/BackgroundCheck/CheckrSettings.ascx',
    '~/Blocks/Security/BackgroundCheck/RequestList.ascx', '~/Blocks/Security/ChangePassword.ascx', '~/Blocks/Security/Logout.ascx',
    '~/Blocks/Security/Oidc/AuthClaims.ascx', '~/Blocks/Security/Oidc/AuthScopeDetail.ascx', '~/Blocks/Security/Oidc/AuthScopeList.ascx',
    '~/Blocks/Security/PersonViewedDetail.ascx', '~/Blocks/Security/PersonViewedSummary.ascx', '~/Blocks/Store/PackageDetail.ascx',
    '~/Blocks/Utility/CacheReader.ascx', '~/Blocks/WorkFlow/FormBuilder/FormList.ascx'
);
SELECT bt.Path, COUNT(b.Id) AS Bloques FROM dbo.BlockType bt JOIN dbo.Block b ON b.BlockTypeId = bt.Id
WHERE bt.Path IN (
    '~/Blocks/Administration/ExternalApplicationList.ascx', '~/Blocks/Administration/NotificationList.ascx', '~/Blocks/BulkImport/CsvImport.ascx',
    '~/Blocks/Bus/BusStatus.ascx', '~/Blocks/CheckIn/Manager/Roster.ascx', '~/Blocks/Cms/ContentChannelDetail.ascx',
    '~/Blocks/Cms/ContentChannelItemList.ascx', '~/Blocks/Cms/ContentChannelList.ascx', '~/Blocks/Cms/ContentCollectionList.ascx',
    '~/Blocks/Cms/FileEditor.ascx', '~/Blocks/Cms/FileManager.ascx', '~/Blocks/Cms/MediaAccountDetail.ascx',
    '~/Blocks/Cms/MediaAccountList.ascx', '~/Blocks/Cms/MediaElementList.ascx', '~/Blocks/Cms/MediaFolderDetail.ascx',
    '~/Blocks/Cms/MediaFolderList.ascx', '~/Blocks/Cms/PageMap.ascx', '~/Blocks/Cms/PageMenu.ascx',
    '~/Blocks/Cms/PersonalizationSegmentDetail.ascx', '~/Blocks/Cms/PersonalizationSegmentResults.ascx', '~/Blocks/Cms/Redirect.ascx',
    '~/Blocks/Cms/RequestFilterDetails.ascx', '~/Blocks/Cms/RequestFilterList.ascx', '~/Blocks/Communication/CommunicationListSubscribe.ascx',
    '~/Blocks/Communication/SnippetList.ascx', '~/Blocks/Communication/SnippetTypeList.ascx', '~/Blocks/Communication/SystemCommunicationDetail.ascx',
    '~/Blocks/Communication/SystemCommunicationList.ascx', '~/Blocks/Communication/SystemEmailDetail.ascx', '~/Blocks/Communication/SystemEmailList.ascx',
    '~/Blocks/Communication/SystemPhoneNumberList.ascx', '~/Blocks/Communication/TemplateList.ascx', '~/Blocks/Connection/CampaignConfiguration.ascx',
    '~/Blocks/Connection/CampaignList.ascx', '~/Blocks/Connection/ConnectionOpportunityDetail.ascx', '~/Blocks/Connection/ConnectionOpportunityList.ascx',
    '~/Blocks/Connection/ConnectionOpportunitySelect.ascx', '~/Blocks/Connection/ConnectionTypeDetail.ascx', '~/Blocks/Connection/ConnectionTypeList.ascx',
    '~/Blocks/Core/AttributeCategories.ascx', '~/Blocks/Core/Attributes.ascx', '~/Blocks/Core/CampusContextSetter.ascx',
    '~/Blocks/Core/CategoryDetail.ascx', '~/Blocks/Core/Components.ascx', '~/Blocks/Core/ExceptionDetail.ascx',
    '~/Blocks/Core/ExceptionOccurrences.ascx', '~/Blocks/Core/PluginManager.ascx', '~/Blocks/Core/SmartSearch.ascx',
    '~/Blocks/Crm/PersonDetail/GivingConfiguration.ascx', '~/Blocks/Crm/PersonDuplicateDetail.ascx', '~/Blocks/Crm/PersonDuplicateList.ascx',
    '~/Blocks/Crm/PersonMergeRequestList.ascx', '~/Blocks/Crm/PersonalDeviceInteractions.ascx', '~/Blocks/Crm/PersonalDevices.ascx',
    '~/Blocks/Event/CalendarDetail.ascx', '~/Blocks/Event/EventItemDetail.ascx', '~/Blocks/Event/EventItemList.ascx',
    '~/Blocks/Event/EventItemOccurrenceList.ascx', '~/Blocks/Event/InteractiveExperiences/InteractiveExperienceList.ascx', '~/Blocks/Event/RegistrationEntry.ascx',
    '~/Blocks/Event/RegistrationInstanceLinkageDetail.ascx', '~/Blocks/Examples/DevelopEnvironmentInfo.ascx', '~/Blocks/Examples/ModelMap.ascx',
    '~/Blocks/Examples/SampleData.ascx', '~/Blocks/Finance/BenevolenceRequestDetail.ascx', '~/Blocks/Finance/BusinessContactList.ascx',
    '~/Blocks/Finance/BusinessDetail.ascx', '~/Blocks/Finance/BusinessList.ascx', '~/Blocks/Finance/ConvertBusiness.ascx',
    '~/Blocks/Finance/PledgeAnalytics.ascx', '~/Blocks/Groups/GroupTypeDetail.ascx', '~/Blocks/Groups/GroupTypeList.ascx',
    '~/Blocks/Mobile/MobileDeepLinkDetail.ascx', '~/Blocks/Prayer/PrayerRequestList.ascx', '~/Blocks/Reporting/DynamicHeatMap.ascx',
    '~/Blocks/Reporting/Insights.ascx', '~/Blocks/Reporting/InteractionChannelDetail.ascx', '~/Blocks/Reporting/InteractionComponentDetail.ascx',
    '~/Blocks/Reporting/PersistedDataViewList.ascx', '~/Blocks/Reporting/ReportList.ascx', '~/Blocks/Reporting/ReportSearch.ascx',
    '~/Blocks/Reporting/ServiceMetricsEntry.ascx', '~/Blocks/Security/BackgroundCheck/CheckrRequestList.ascx', '~/Blocks/Security/BackgroundCheck/CheckrSettings.ascx',
    '~/Blocks/Security/BackgroundCheck/RequestList.ascx', '~/Blocks/Security/ChangePassword.ascx', '~/Blocks/Security/Logout.ascx',
    '~/Blocks/Security/Oidc/AuthClaims.ascx', '~/Blocks/Security/Oidc/AuthScopeDetail.ascx', '~/Blocks/Security/Oidc/AuthScopeList.ascx',
    '~/Blocks/Security/PersonViewedDetail.ascx', '~/Blocks/Security/PersonViewedSummary.ascx', '~/Blocks/Store/PackageDetail.ascx',
    '~/Blocks/Utility/CacheReader.ascx', '~/Blocks/WorkFlow/FormBuilder/FormList.ascx'
) GROUP BY bt.Path HAVING COUNT(b.Id) > 0 ORDER BY bt.Path;

PRINT '== Fin. Nada se modificó.';
