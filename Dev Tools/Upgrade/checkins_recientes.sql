/* checkins_recientes.sql — ¿hay check-in en este momento? Solo cuenta (sin datos de personas). Solo lectura.
   Correr desde el servidor web:  .\Invoke-SqlDesdeWeb.ps1 -Archivo .\checkins_recientes.sql */
SET NOCOUNT ON;
SELECT GETDATE() AS AhoraEnSQL,
       (SELECT COUNT(*) FROM dbo.Attendance WHERE DidAttend = 1 AND StartDateTime >= DATEADD(minute, -15, GETDATE())) AS Ultimos15min,
       (SELECT COUNT(*) FROM dbo.Attendance WHERE DidAttend = 1 AND StartDateTime >= DATEADD(minute, -60, GETDATE())) AS Ultimos60min,
       (SELECT MAX(StartDateTime) FROM dbo.Attendance WHERE DidAttend = 1) AS UltimoCheckIn;
SELECT DATEPART(hour, StartDateTime) AS HoraDeHoy, COUNT(*) AS CheckIns
FROM dbo.Attendance WHERE DidAttend = 1 AND StartDateTime >= CAST(GETDATE() AS date)
GROUP BY DATEPART(hour, StartDateTime) ORDER BY 1;
