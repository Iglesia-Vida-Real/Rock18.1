/*
    Aislar_BD_Dev.sql  —  SOLO PARA LA BD DE DESARROLLO (copia de prod restaurada en localhost)

    Una copia de prod manda correos, SMS, WhatsApp y push REALES a miembros reales y puede cobrar
    con las pasarelas si no se aísla ANTES del primer arranque del sitio. Este script:
      1. Lista y desactiva todos los jobs (ServiceJob).
      2. Desactiva las pasarelas de pago (FinancialGateway).
      3. Agrega '.test' a los correos de Person (no los de sistema).
      4. Desactiva los transportes SendGrid, Twilio, WhatsApp y OneSignal (atributo 'Active').

    Correr DESPUÉS de Enable_LocalhostDevTesting.sql y ANTES de arrancar el sitio:
        sqlcmd -S localhost -d Rock18 -E -I -f 65001 -b -i "Dev Tools\Sql\Aislar_BD_Dev.sql"

    Candado: se niega a correr si el servidor SQL no está en la misma máquina que el cliente
    (es decir, si estás conectado a un servidor remoto, como prod). Es idempotente: se puede
    correr más de una vez. Todo va en una transacción: si algo falla, no queda nada a medias.

    Verificado el 2026-10-26 sobre una copia de Rock18.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF CAST(SERVERPROPERTY('MachineName') AS nvarchar(128)) <> HOST_NAME()
BEGIN
    RAISERROR('BLOQUEADO: el servidor SQL no es local (MachineName <> HOST_NAME). Este script es solo para la BD de desarrollo.', 16, 1);
    RETURN;
END

BEGIN TRAN;

PRINT '1. Jobs que estaban activos (guardar esta lista si luego hay que reactivar alguno):';
SELECT [Id], [Name] FROM [ServiceJob] WHERE [IsActive] = 1 ORDER BY [Id];
UPDATE [ServiceJob] SET [IsActive] = 0 WHERE [IsActive] = 1;
PRINT CONCAT('   Jobs desactivados: ', @@ROWCOUNT);

UPDATE [FinancialGateway] SET [IsActive] = 0 WHERE [IsActive] = 1;
PRINT CONCAT('2. Pasarelas desactivadas: ', @@ROWCOUNT);

UPDATE [Person]
SET [Email] = CONCAT([Email], '.test')
WHERE [Email] <> '' AND [Email] NOT LIKE '%.test' AND [IsSystem] <> 1;
PRINT CONCAT('3. Correos invalidados con .test: ', @@ROWCOUNT);

UPDATE av
SET av.[Value] = 'False', av.[ModifiedDateTime] = GETDATE()
FROM [AttributeValue] av
JOIN [Attribute] a ON a.[Id] = av.[AttributeId] AND a.[Key] = 'Active'
JOIN [EntityType] et ON et.[Id] = a.[EntityTypeId]
WHERE et.[Name] IN (
    'Rock.Communication.Transport.SendGridHttp',
    'Rock.Communication.Transport.Twilio',
    'Rock.WhatsApp.Communication.Transport.WhatsAppTransport',
    'Rock.Communication.Transport.OneSignal'
)
AND av.[Value] <> 'False';
PRINT CONCAT('4. Transportes desactivados: ', @@ROWCOUNT);

COMMIT;

PRINT 'Estado final (todo debe ser 0 / False):';
SELECT
    (SELECT COUNT(*) FROM [ServiceJob] WHERE [IsActive] = 1) AS JobsActivos,
    (SELECT COUNT(*) FROM [FinancialGateway] WHERE [IsActive] = 1) AS PasarelasActivas,
    (SELECT COUNT(*) FROM [Person] WHERE [Email] <> '' AND [Email] NOT LIKE '%.test' AND [IsSystem] <> 1) AS CorreosSinTest;
SELECT et.[Name] AS Transporte, av.[Value] AS Active
FROM [EntityType] et
JOIN [Attribute] a ON a.[EntityTypeId] = et.[Id] AND a.[Key] = 'Active'
JOIN [AttributeValue] av ON av.[AttributeId] = a.[Id]
WHERE et.[Name] LIKE '%Communication.Transport%'
ORDER BY et.[Name];
