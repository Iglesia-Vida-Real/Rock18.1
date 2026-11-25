/*
    19.8.1_linea_base.sql — líneas base de la ventana (CHECKLIST C10; guía de pagos, consulta 6.0). Solo lectura.
    Correr desde el servidor web:  .\Invoke-SqlDesdeWeb.ps1 -Archivo .\19.8.1_linea_base.sql
    Anotar los tres números: todo lo que aparezca con Id mayor es de después del upgrade.
*/
SET NOCOUNT ON;
PRINT N'== Líneas base (anotar en la checklist, C10)';
SELECT (SELECT MAX(Id) FROM dbo.FinancialTransaction) AS MaxTx,
       (SELECT MAX(Id) FROM dbo.ExceptionLog) AS MaxExc,
       (SELECT MAX(Id) FROM dbo._com_vidareal_Events_Order) AS MaxOrden,
       (SELECT TOP 1 MigrationId FROM dbo.__MigrationHistory ORDER BY MigrationId DESC) AS UltimaMigracion,
       GETDATE() AS Ahora;
