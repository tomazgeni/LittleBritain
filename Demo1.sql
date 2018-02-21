--- >>>> DEMO 1


USE tempdb;
GO

SET NOCOUNT ON;
GO

/* Properly define variable-length data types */

-- demo 1

DECLARE @x NVARCHAR = N'Jerry';

SELECT x = @x, 
       y = CONVERT(NVARCHAR, N'Jerry Seinfeld has left the building in NYC');




















-- demo 2 - it gets worse :
-- More nonsense

CREATE TABLE dbo.oops
(
   c1 NVARCHAR(MAX)
  ,c2 NVARCHAR(MAX)
  ,c3 NVARCHAR
);
GO

CREATE PROCEDURE dbo.oops_add_row
   @p1 NVARCHAR
  ,@p2 NVARCHAR(10)
  ,@p3 NVARCHAR
AS

BEGIN
  INSERT dbo.oops(c1,c2,c3)  VALUES(@p1,@p2,@p3);

END
GO

EXEC dbo.oops_add_row @p1 = N'Little Britain', 
                      @p2 = N'Little Britain, Jerry Seinfeld',
                      @p3 = N'Little Britain, Jerry Seinfeld, Fawlty Towers';

SELECT 
	 c1
	,c2
	,c3 
FROM dbo.oops;
GO

-- you've lost data BUT there is no error
-- and it is not logged anywhere

DROP PROCEDURE dbo.oops_add_row;
GO
DROP TABLE dbo.oops;
GO




-- demo 3 -- memory grants and execution times 
          -- for *SAME* data
          -- shows proper choice up front is important:

DROP TABLE IF EXISTS dbo.t1, dbo.t2, dbo.t3;
GO

-- create three tables with different column sizes
CREATE TABLE dbo.t1(
		 a NVARCHAR(32)
		,b NVARCHAR(32)
		,c NVARCHAR(32)
		,d NVARCHAR(32)
		);

CREATE TABLE dbo.t2(
		 a NVARCHAR(4000)
		,b NVARCHAR(4000) 
        ,c NVARCHAR(4000)
		,d NVARCHAR(4000)
		);

CREATE TABLE dbo.t3
		(a NVARCHAR(MAX)
		,b NVARCHAR(MAX)
		,c NVARCHAR(MAX)
		,d NVARCHAR(MAX)
		);
GO

-- populate them with a bunch of junk, 100 times
INSERT dbo.t1(a,b,c,d)
SELECT 
	TOP (250000) 
	 LEFT(c1.name,1)
	,RIGHT(c2.name,1)
	,ABS(c1.column_id/10)
	,ABS(c2.column_id%10)

FROM sys.all_columns AS c1
CROSS JOIN sys.all_columns AS c2
ORDER BY c2.[object_id];

INSERT dbo.t2(a,b,c,d) SELECT a,b,c,d FROM dbo.t1;
INSERT dbo.t3(a,b,c,d) SELECT a,b,c,d FROM dbo.t1;
GO

-- no "in-advanced" cached plans 
DBCC FREEPROCCACHE WITH NO_INFOMSGS;
DBCC DROPCLEANBUFFERS WITH NO_INFOMSGS;
GO

-- No need for actual execution plan to be turned on
-- run the same query against all three tables
SELECT DISTINCT 
	a,b,c,d
	,DENSE_RANK() OVER  (PARTITION BY b,c ORDER BY d DESC)
FROM dbo.t1 
GROUP BY a,b,c,d 
ORDER BY c,a DESC;
GO

SELECT DISTINCT 
	 a,b,c,d
	,DENSE_RANK() OVER (PARTITION BY b,c ORDER BY d DESC)
FROM dbo.t2 
GROUP BY a,b,c,d 
ORDER BY c,a DESC;
GO
SELECT DISTINCT 
	a,b,c,d
	,DENSE_RANK() OVER (PARTITION BY b,c ORDER BY d DESC)
FROM dbo.t3 
GROUP BY a,b,c,d 
ORDER BY c,a DESC;
GO

SELECT [table] = SUBSTRING(t.[text], 
  CHARINDEX(N'FROM ', t.[text])+5,6), 
  [How much memory SQL wanted] = s.max_ideal_grant_kb, 
  [How much memory SQL got]    = s.last_grant_kb, 
  [How long the query took]    = s.last_elapsed_time
FROM sys.dm_exec_query_stats AS s
CROSS APPLY sys.dm_exec_sql_text(s.[sql_handle]) AS t
WHERE t.[text] LIKE N'%dbo.'+N't[1-3]%'
ORDER BY SUBSTRING(t.[text], 
  CHARINDEX(N'FROM ', t.[text])+5,6);

DROP TABLE dbo.t1, dbo.t2, dbo.t3;














-- demo 4 : 

/*
  Deferred name resolution 
  Lower-case data types 
*/

CREATE DATABASE spodrsljaj COLLATE Slovenian_100_BIN2; 
GO
USE spodrsljaj;
GO

-- need to be careful with object/column names:
CREATE TABLE dbo.SalesOrders
(
  SalesOrderID INT
);
GO

--Check the select statement
SELECT SalesOrderID FROM dbo.SalesOrders;
GO

CREATE PROCEDURE dbo.spodrsljaj
AS
BEGIN
  SELECT salesorderid FROM dbo.salesorders;
END
GO

EXEC dbo.spodrsljaj;
GO



-- you also need to be careful with data type names.
-- I try to match what's in sys.types because:

SELECT geografi 
       = geography::STGeomFromText('LINESTRING(-10 22, -12 19)', 4326);
GO
SELECT geografi 
       = GEOGRAPHY::STGeomFromText('LINESTRING(-10 22, -12 19)', 4326);
GO

USE [tempdb];
GO

-- ALTER DATABASE spodrsljaj SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
DROP DATABASE spodrsljaj;








-- demo 5: 

/* 
  Match exact case for entities and columns
  Match white space in query text
  Important even in a case-insensitive database
*/

CREATE TABLE dbo.SalesOrders
(
  SalesOrderID INT
);
GO

DBCC FREEPROCCACHE WITH NO_INFOMSGS;
GO
SELECT TOP (1) SalesOrderID FROM dbo.SalesOrders;
GO
SELECT TOP (1) salesorderid FROM dbo.salesorders;
GO
select top (1) SalesOrderID from dbo.SalesOrders;
GO
select top (1)	SalesOrderID from dbo.SalesOrders;
GO ---- tab --^^


SELECT 
	 t.[text]
	,p.size_in_bytes
	,p.usecounts
FROM sys.dm_exec_cached_plans AS p
CROSS APPLY sys.dm_exec_sql_text(p.plan_handle) AS t
WHERE LOWER(t.[text]) LIKE N'%sales'+'orders%';
GO

DROP TABLE dbo.SalesOrders;
GO










-- demo 6 :

/* semi-colons */

GO

-- with each new version, more and more syntax requires it
CREATE OR ALTER PROCEDURE dbo.problema
  @i int
AS
BEGIN
  BEGIN TRY
    BEGIN TRANSACTION
		SELECT 1/@i
    COMMIT TRANSACTION
  END TRY
  BEGIN CATCH
    ROLLBACK TRANSACTION
    THROW
  END CATCH
END
GO

EXEC dbo.problema @i = 1;
GO
EXEC dbo.problema @i = 0;
GO

-- missing semi-colon before THROW: 
-- SQL Server tries to roll back a tx named "throw"

DROP PROCEDURE dbo.problema;
GO

-- other new syntax - service broker commands, MERGE:

CREATE TABLE #x(i int);
GO

MERGE #x AS x USING (VALUES (1),(2),(3)) AS y(i) 
ON x.i = y.i
WHEN MATCHED THEN
   UPDATE SET i = y.i
WHEN NOT MATCHED THEN
   INSERT (i) VALUES (y.i)

GO
DROP TABLE #x;

-- the "it isn't required yet" excuse doesn't cut it
-- all you're doing is justifying more technical debt
-- let me turn it around - what do you gain by 
-- NOT using semi-colons?










-- demo 7 :

/* schema prefix */

USE tempdb;
GO
CREATE SCHEMA Kjell;
GO
CREATE SCHEMA Anders;
GO
CREATE USER Kjell WITHOUT LOGIN 
  WITH DEFAULT_SCHEMA = Kjell;

CREATE USER Anders WITHOUT LOGIN 
  WITH DEFAULT_SCHEMA = Anders;
GO

CREATE TABLE dbo.DumtBord(identitet int);
GO
GRANT SELECT ON dbo.DumtBord TO Kjell, Anders;
GO

/*
-- run this batch once, then add dbo. prefix
*/
DBCC FREEPROCCACHE WITH NO_INFOMSGS;

EXECUTE AS USER = N'Kjell';
GO
SELECT identitet FROM DumtBord;
GO
REVERT;
GO

EXECUTE AS USER = N'Anders';
GO
SELECT identitet FROM DumtBord;
GO
REVERT;
GO


-- now check the plan cache; how many plans? Why?

SELECT t.[text], p.size_in_bytes, p.usecounts
FROM sys.dm_exec_cached_plans AS p
CROSS APPLY sys.dm_exec_sql_text(p.plan_handle) AS t
WHERE t.[text] LIKE N'%SELECT%identitet%'+N'%DumtBord%';

-- now clean up and run it again

-- why? dig a little deeper

SELECT t.[text], p.size_in_bytes, 
  p.usecounts, [schema_id] = pa.value, [schema] = s.name
FROM sys.dm_exec_cached_plans AS p
CROSS APPLY sys.dm_exec_sql_text(p.plan_handle) AS t
CROSS APPLY sys.dm_exec_plan_attributes(p.plan_handle) AS pa
LEFT OUTER JOIN sys.schemas AS s
  ON s.[schema_id] = CONVERT(INT, pa.[value])
WHERE t.[text] LIKE N'%SELECT%identitet%'+N'%DumtBord%'
AND pa.attribute = N'user_id';

-- attribute "user_id" actually represents default_schema_id

GO
DROP TABLE dbo.DumtBord;
DROP USER Kjell;
DROP USER Anders;

















-- demo 7.5 - semi-colons

-- copying code like CTEs without semi-colons 
-- leads to angry customers

-- e.g. I would post this answer on Stack Overflow:
WITH x(i) AS (SELECT 1) 
  SELECT i FROM x;

-- they would paste into this procedure:
GO
CREATE PROCEDURE dbo.StackQuestion
AS
BEGIN
  DECLARE @i int

  WITH x(i) AS (SELECT 1) 
  SELECT i FROM x;

END
GO

-- and then I would get blamed!


-- semi-colon to *begin* a statement is legal. So is this:

;; ;;SELECT 1;;;SELECT 2;;; ;;;SELECT 3;; ;

-- very rare that you can have too many semi-colons;
-- quite common that a missing one causes problems.
