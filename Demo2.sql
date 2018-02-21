-- DEMO 2

USE tempdb;
SET NOCOUNT ON;
GO

/* Date/time shorthand QUIZ */

-- demo 1 :

DECLARE @d date = '20170902'--GETDATE();

SELECT           'DATEPART( D )', DATEPART( D , @d )    
  --   (a)  6      (b)  1      (c)  2
UNION ALL SELECT 'DATEPART( W )', DATEPART( W , @d )   
  --   (a)  7      (b)  22     (c)  23
UNION ALL SELECT 'DATEPART( M )', DATEPART( M , @d )    
  --   (a)  9      (b)  This minute
UNION ALL SELECT 'DATEPART( Y )', DATEPART( Y , @d );
  --   (a)  17     (b)  245    (c)  2017














-- Don't use shorthand! If you mean MONTH, type MONTH
















-- demo 2 :

-- this works ok:
DECLARE @dt datetime = '20170902';
SELECT @dt + 1;
GO

-- this breaks:
DECLARE @d datetime2 = '20170902';
SELECT @d + 1;
GO

-- so does this:
DECLARE @d date = '20170902';
SELECT @d + 1;
GO

-- always use explicit DATEADD

--this works
DECLARE @d date = '20170902';
SELECT dateadd(day,1, @d);
GO

-- this works
DECLARE @d datetime2 = '20170902';
SELECT dateadd(day,1, @d);
GO

-- this works
DECLARE @d datetime = '20170902';
SELECT dateadd(day,1, @d);
GO









/* Regional formats */

SET LANGUAGE Slovenian;
-- SET LANGUAGE US_ENGLISH;

-- check this option using:
DBCC USEROPTIONS

SELECT CONVERT(datetime, '2017.09.02')
UNION ALL
SELECT CONVERT(datetime, '02/09/2017')
UNION ALL
SELECT CONVERT(datetime, '2017-09-02 12:34:56.789');

-- safe:

SELECT CONVERT(datetime, '20170902')
UNION ALL
SELECT CONVERT(datetime, '2017-09-02T12:34:56.789')
UNION ALL
SELECT CONVERT(datetime, '20170902 12:34:56.789');







/* BETWEEN / "end" of period */

CREATE TABLE dbo.SalesOrders
(
  OrderDate datetime2
);
GO

INSERT dbo.SalesOrders(OrderDate) VALUES
  ('20170201 00:00'),
  ('20170201 01:00'),
  ('20170219 00:00'),
  ('20170228 04:00'),
  ('20170228 13:27:32.534'),
  ('20170228 23:59:59.9999999'),
  ('20170301 00:00');
GO

SELECT OrderDate 
  FROM dbo.SalesOrders
  ORDER BY OrderDate;
GO

-- parameters are datetime, using old millisecond tricks:
DECLARE 
  @start datetime = '20170201',
  @end   datetime = DATEADD(MILLISECOND, -3, '20170301');

SELECT OrderDate, @start, @end 
  FROM dbo.SalesOrders
  WHERE OrderDate BETWEEN @start AND @end;
GO

-- parameters change to smalldatetime:
DECLARE 
 @start smalldatetime = '20170201',
 @end   smalldatetime = DATEADD(MILLISECOND, -3, '20170301');

SELECT OrderDate, @start, @end 
  FROM dbo.SalesOrders
  WHERE OrderDate BETWEEN @start AND @end;
GO

-- parameters change to date:
DECLARE 
  @start date = '20170201',
  @end   date = DATEADD(MILLISECOND, -3, '20170301');

SELECT OrderDate, @start, @end 
  FROM dbo.SalesOrders
  WHERE OrderDate BETWEEN @start AND @end;
GO

-- how about EOMONTH()?
DECLARE 
  @start date = '20170201';

SELECT OrderDate, @start, EOMONTH(@start) 
  FROM dbo.SalesOrders
  WHERE OrderDate BETWEEN @start AND EOMONTH(@start);
GO

-- Stop using BETWEEN. Open-ended range is safer,
-- and far easier to calculate the "end" of a period
DECLARE 
  @start date = '20170201';

SELECT OrderDate, @start, DATEADD(MONTH, 1, @start)
  FROM dbo.SalesOrders
  WHERE OrderDate >= @start 
    AND OrderDate < DATEADD(MONTH, 1, @start);
GO

DROP TABLE dbo.SalesOrders;
GO




/* FORMAT() */

DBCC DROPCLEANBUFFERS WITH NO_INFOMSGS;
DBCC FREEPROCCACHE WITH NO_INFOMSGS;
GO

DECLARE @x char(8);
SELECT @x = FORMAT(modify_date, 'yyyyMMdd') 
  FROM sys.all_objects;
GO 10
GO

DECLARE @x char(8);
SELECT @x = CONVERT(char(8), modify_date, 112) 
  FROM sys.all_objects;
GO 10

-- compare performance:
SELECT query = CASE WHEN t.[text] LIKE N'%FORMAT(%' 
   THEN 'Format' ELSE 'Convert' END, 
   qs.total_elapsed_time 
FROM sys.dm_exec_query_stats AS qs
CROSS APPLY sys.dm_exec_sql_text(qs.plan_handle) AS t
WHERE t.[text] LIKE N'%@'+N'x = %';









/* Non-sargable expressions */

SELECT DISTINCT TOP (50000) 
    id = o.[object_id], c.column_id, o.modify_date
  INTO dbo.objects
  FROM sys.all_objects AS o
  CROSS JOIN sys.all_columns AS c;
GO
CREATE UNIQUE CLUSTERED INDEX x 
  ON dbo.objects(id, column_id);
GO
CREATE INDEX y ON dbo.objects(modify_date);
GO
DBCC FREEPROCCACHE WITH NO_INFOMSGS;
DBCC DROPCLEANBUFFERS WITH NO_INFOMSGS;
GO

-- non-sarg
SELECT c = COUNT(id) INTO #x FROM dbo.objects 
  WHERE YEAR(modify_date) = YEAR(GETDATE()) 
    AND MONTH(modify_date) = MONTH(GETDATE());
GO

-- convert
SELECT c = COUNT(id) INTO #y FROM dbo.objects 
  WHERE CONVERT(char(6), modify_date, 112) 
      = CONVERT(char(6), GETDATE(),   112);
GO
-- declare @start date = DATEADD(DAY, 1-DAY(GETDATE()), CONVERT(date, GETDATE())) 
-- declare @end   date = DATEADD(MONTH, 1, @start)
-- open-ended range
GO
SELECT c = COUNT(id) INTO #z FROM dbo.objects 
  WHERE modify_date >= '20170601' 
    AND modify_date <  '20170701';
GO

-- compare performance:
SELECT query = CASE 
     WHEN t.text LIKE N'%YEAR%'    THEN 'non-sarg'
     WHEN t.text LIKE N'%CONVERT%' THEN 'convert'
     ELSE 'open-ended' END, 
   duration = qs.total_elapsed_time 
FROM sys.dm_exec_query_stats AS qs
CROSS APPLY sys.dm_exec_sql_text(qs.plan_handle) AS t
WHERE t.[text] LIKE N'%modify'+N'_date%'
ORDER BY duration DESC;

GO
DROP TABLE dbo.objects;
DROP TABLE #x, #y, #z;

