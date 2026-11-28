/*
    19.8.1_transacciones_nuevas.sql — transacciones creadas después de la línea base de C10 (MaxTx = 3564). Solo lectura.
    Sin nombres ni datos de tarjeta: fecha, estado, pasarela, monto y origen. (guía de pagos, consulta 6.1)
*/
SET NOCOUNT ON;
SELECT t.Id, t.CreatedDateTime AS Creada, t.TransactionDateTime AS Fecha, t.Status AS Estado,
       LEFT(ISNULL(t.StatusMessage, ''), 80) AS Mensaje, g.Name AS Pasarela, d.Amount AS Monto,
       ISNULL(dv.Value, '') AS Origen, ISNULL(tt.Value, '') AS Tipo, t.BatchId AS Lote,
       LEFT(ISNULL(t.ForeignKey, ''), 40) AS ForeignKey, t.ScheduledTransactionId AS Programada
FROM dbo.FinancialTransaction t
LEFT JOIN dbo.FinancialGateway g ON g.Id = t.FinancialGatewayId
LEFT JOIN dbo.FinancialTransactionDetail d ON d.TransactionId = t.Id
LEFT JOIN dbo.DefinedValue dv ON dv.Id = t.SourceTypeValueId
LEFT JOIN dbo.DefinedValue tt ON tt.Id = t.TransactionTypeValueId
WHERE t.Id > 3564 ORDER BY t.Id;
