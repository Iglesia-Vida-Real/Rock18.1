/*
    19.8.1_jobs_postupdate.sql — lista los jobs de post-actualización que creó la 19 (CHECKLIST C11). Solo lectura.
    Correr desde el servidor web:  .\Invoke-SqlDesdeWeb.ps1 -Archivo .\19.8.1_jobs_postupdate.sql
    En la copia local eran los Id 220–233; en prod deberían ser los mismos (misma BD). Al terminar bien, los de
    actualización se BORRAN solos: volver a correr esto muestra cuáles faltan.
*/
SET NOCOUNT ON;
SELECT Id, LEFT(Name, 95) AS Nombre, REPLACE(Class, 'Rock.Jobs.', '') AS Clase, IsActive AS Activo,
       ISNULL(LastStatus, '') AS UltimoEstado, LastRunDateTime AS UltimaCorrida
FROM dbo.ServiceJob
WHERE Id >= 219 OR Class LIKE 'Rock.Jobs.PostV%' OR Class LIKE 'Rock.Jobs.PostUpdate%' OR Name LIKE 'Rock Update Helper%'
ORDER BY Id;
