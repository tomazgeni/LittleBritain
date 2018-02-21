-- Demo 4

USE tempdb;
SET NOCOUNT ON;
GO

/* cursor options */

DBCC DROPCLEANBUFFERS WITH NO_INFOMSGS;
GO

DECLARE @i sysname, @d datetime2 = SYSDATETIME();

DECLARE c CURSOR --LOCAL FAST_FORWARD 
  -- try with and without ^^^ these commented
  -- sometimes STATIC is better too, TEST!
FOR SELECT c1.[name] FROM sys.all_objects AS c1
 CROSS JOIN 
 (SELECT TOP (50) [name] FROM sys.all_objects) AS c2;

OPEN c; FETCH c INTO @i;

WHILE @@FETCH_STATUS <> -1
BEGIN
  SET @i += N'';
  FETCH c INTO @i;
END

CLOSE c; DEALLOCATE c;

SELECT DATEDIFF(MILLISECOND, @d, SYSDATETIME());




-- SELECT * 

-- schema stability ==> view does not reflect changed table

CREATE TABLE dbo.x(a int, b int);
GO
INSERT dbo.x(a,b) VALUES(1,2);
GO

CREATE VIEW dbo.v_x
AS
  SELECT * FROM dbo.x;
GO

-- view will not be updated to see these changes:
EXEC sys.sp_rename N'dbo.x.b', N'c', N'COLUMN';
ALTER TABLE dbo.x ADD b datetime 
    NOT NULL DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE dbo.x ADD d uniqueidentifier 
    NOT NULL DEFAULT NEWID();
GO

-- view still shows wrong data
SELECT * FROM dbo.x;
SELECT * FROM dbo.v_x;
GO

EXEC sys.sp_refreshview @viewname = N'dbo.v_x';
GO

-- now view is correct
SELECT * FROM dbo.v_x;
GO

-- trick to prevent SELECT * 
-- credit Remus Rusanu
ALTER TABLE dbo.x ADD ["Slutte å bruke SELECT *!"] AS 1/0;
GO
SELECT * FROM dbo.x;

GO
DROP VIEW dbo.v_x;
DROP TABLE dbo.x;




/* COUNT */

-- for a total table count, avoid this (even with NOLOCK):

SELECT COUNT(*) FROM dbo.tablename;

-- this is far more efficient, and no less accurate:

SELECT SUM([rows]) FROM sys.partitions 
  WHERE [object_id] = OBJECT_ID(N'dbo.tablename')
  AND index_id IN (0,1);


















/* NOLOCK */

DBCC FREEPROCCACHE WITH NO_INFOMSGS;
DBCC DROPCLEANBUFFERS WITH NO_INFOMSGS;
GO

-- We all know with NOLOCK you can:
   -- read a row that never existed (e.g. rollback)
   -- read the same row twice due to movement
   -- miss a row entirely due to movement
   -- get the "could not scan due to data movement" error

-- What about getting a single row in a state
-- that could never have logically existed?

-- Stolen from Paul White:

CREATE TABLE dbo.Test
(
    RowID int PRIMARY KEY,
    LOB varchar(max) NOT NULL,
);
 
INSERT dbo.Test
    (RowID, LOB)
VALUES
    (1, REPLICATE(CONVERT(varchar(max), 'X'), 16100));

-- run this in a different session:

SET NOCOUNT ON;
 
DECLARE 
    @ValueRead varchar(max) = '',
    @AllXs varchar(max) = REPLICATE(
           CONVERT(varchar(max), 'X'), 16100),
    @AllYs varchar(max) = REPLICATE(
           CONVERT(varchar(max), 'Y'), 16100);
 
WHILE 1 = 1
BEGIN
    SELECT @ValueRead = T.LOB
    FROM dbo.Test AS T WITH (NOLOCK)
    WHERE T.RowID = 1;
 
    IF @ValueRead NOT IN (@AllXs, @AllYs)
    BEGIN
    	PRINT LEFT(@ValueRead, 8000);
        PRINT RIGHT(@ValueRead, 8000);
        BREAK;
    END
END;

-- now in this session, run:

SET NOCOUNT ON;
 
DECLARE 
    @AllXs varchar(max) = REPLICATE(
           CONVERT(varchar(max), 'X'), 16100),
    @AllYs varchar(max) = REPLICATE(
           CONVERT(varchar(max), 'Y'), 16100);
 
WHILE 1 = 1
BEGIN
    UPDATE dbo.Test
    SET LOB = @AllYs
    WHERE RowID = 1;
 
    UPDATE dbo.Test
    SET LOB = @AllXs
    WHERE RowID = 1;
END;

GO

DROP TABLE dbo.Test;
GO