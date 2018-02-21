-- DEMO 3

USE tempdb;
SET NOCOUNT ON;
GO

/* ORDER BY myths */

CREATE TABLE dbo.Mennesker
(
  identitet int PRIMARY KEY, 
  fornavn   varchar(32)
);
GO

-- purposely out of alphabetical order
INSERT dbo.Mennesker(identitet, fornavn) 
  VALUES(1,'mike'),(2,'grant'),(3,'aaron');

-- ordered by primary key, since cheapest 
-- method is CI scan
SELECT identitet,fornavn FROM dbo.Mennesker;

-- now, someone else creates an index
CREATE INDEX IX_Mfornavn ON dbo.Mennesker(fornavn);

-- cheapest method changed; now index scan is used, 
-- ordered alpha:
SELECT identitet,fornavn FROM dbo.Mennesker;

-- TOP 100 PERCENT doesn't help:
SELECT identitet,fornavn FROM 
(
  SELECT TOP (100) PERCENT identitet,fornavn 
  FROM dbo.Mennesker ORDER BY identitet
) AS m;

-- neither does adding implicit sorting in a CTE:
;WITH cte AS 
(
  SELECT identitet,fornavn, 
    rn = ROW_NUMBER() OVER (ORDER BY identitet) 
  FROM dbo.Mennesker
)
SELECT identitet,fornavn FROM cte;

-- unless the window function is materialized (but this still isn't guaranteed):
;WITH cte AS 
(
  SELECT identitet,fornavn,
    rn = ROW_NUMBER() OVER (ORDER BY identitet) 
  FROM dbo.Mennesker
)
SELECT identitet,fornavn,rn FROM cte;
-------------------------^^

-- also, don't use this lazy shorthand
----------------------------------------------------v
SELECT identitet,fornavn FROM dbo.Mennesker ORDER BY 1;

DROP TABLE dbo.Mennesker;
GO







/* evaluation order */

CREATE TABLE dbo.Scores
(
  identitet int, 
  Score     varchar(12)
);

CREATE TABLE dbo.Related
(
  identitet int
);

INSERT dbo.Scores(identitet, Score) 
  VALUES(1,'100'),(2,'Aaron'),(5,'45');

INSERT dbo.Related(identitet) 
  VALUES(1), (5), (16), (489);
GO

SELECT s.identitet, s.Score * 5
  FROM dbo.Scores AS s
  INNER JOIN dbo.Related AS r
  ON s.identitet = r.identitet;
GO

;WITH OnlyNumbers AS
(
  SELECT identitet, Score
  FROM dbo.Scores
  WHERE ISNUMERIC(Score) = 1
  --WHERE Ergebnis NOT LIKE '%[^0-9]%' 
)
SELECT identitet, Score
  FROM OnlyNumbers
  WHERE Score > 10;
GO

-- how to solve?

SELECT s.identitet, 
    [case] = 5 * CASE WHEN ISNUMERIC(s.Score) = 1 
      THEN s.Score 
      ELSE NULL 
      END,
    [try_convert] = 5 * TRY_CONVERT(int, s.Score) 
  FROM dbo.Scores AS s
  INNER JOIN dbo.Related AS r
  ON s.identitet = r.identitet;
GO

DROP TABLE dbo.Scores, dbo.Related;