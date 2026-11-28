/*
    19.8.1_verificacion_d.sql — fase D: errores nuevos desde la línea base y eventos publicados. Solo lectura.
    Correr desde el servidor web:  .\Invoke-SqlDesdeWeb.ps1 -Archivo .\19.8.1_verificacion_d.sql
    Línea base de C10 (2026-11-27 22:12): MaxExc = 1721843, MaxTx = 3564, MaxOrden = 112.
*/
SET NOCOUNT ON;
PRINT N'== 1. Excepciones nuevas desde la línea base, agrupadas (ruido conocido: AIAgentSessionAnchor, .ascx inexistentes, OpenID, SendGrid webhook)';
SELECT COUNT(*) AS Nuevas, MAX(CreatedDateTime) AS Ultima FROM dbo.ExceptionLog WHERE Id > 1721843;
SELECT TOP 30 COUNT(*) AS Veces, MAX(CreatedDateTime) AS Ultima, LEFT(ExceptionType, 50) AS Tipo,
       LEFT(REPLACE(REPLACE(Description, CHAR(13), ' '), CHAR(10), ' '), 150) AS Descripcion
FROM dbo.ExceptionLog WHERE Id > 1721843
GROUP BY LEFT(ExceptionType, 50), LEFT(REPLACE(REPLACE(Description, CHAR(13), ' '), CHAR(10), ' '), 150)
ORDER BY 1 DESC;

PRINT N'== 2. Origen del error «Nullable object must have a value» (si apareció después de la línea base)';
SELECT TOP 3 Id, CreatedDateTime, LEFT(ISNULL(PageUrl, ''), 80) AS Pagina,
       LEFT(REPLACE(REPLACE(StackTrace, CHAR(13), ' '), CHAR(10), ' '), 300) AS Pila
FROM dbo.ExceptionLog WHERE Id > 1721843 AND Description LIKE 'Nullable object must have a value%' ORDER BY Id DESC;

PRINT N'== 3. Eventos (boletería) por estado y si son futuros: el calendario público mostró «No hay eventos próximos»';
SELECT Status, Visibility, COUNT(*) AS Eventos, SUM(CASE WHEN EndDateTime >= GETDATE() OR StartDateTime >= GETDATE() THEN 1 ELSE 0 END) AS Futuros
FROM dbo._com_vidareal_Events_Event GROUP BY Status, Visibility ORDER BY Status, Visibility;

PRINT N'== 4. Transacciones y órdenes nuevas desde la línea base (antes de la donación de prueba deberían ser 0)';
SELECT (SELECT COUNT(*) FROM dbo.FinancialTransaction WHERE Id > 3564) AS TxNuevas,
       (SELECT COUNT(*) FROM dbo._com_vidareal_Events_Order WHERE Id > 112) AS OrdenesNuevas;
