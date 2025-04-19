/*
Домашнее задание по курсу MS SQL Server Developer в OTUS.

Занятие "12 - Хранимые процедуры, функции, триггеры, курсоры".

Задания выполняются с использованием базы данных WideWorldImporters.

Бэкап БД можно скачать отсюда:
https://github.com/Microsoft/sql-server-samples/releases/tag/wide-world-importers-v1.0
Нужен WideWorldImporters-Full.bak

Описание WideWorldImporters от Microsoft:
* https://docs.microsoft.com/ru-ru/sql/samples/wide-world-importers-what-is
* https://docs.microsoft.com/ru-ru/sql/samples/wide-world-importers-oltp-database-catalog
*/

USE WideWorldImporters

/*
Во всех заданиях написать хранимую процедуру / функцию и продемонстрировать ее использование.
*/

/*
1) Написать функцию возвращающую Клиента с наибольшей суммой покупки.
*/

/*-----------------------------------------------------------
  1. Inline TVF:  dbo.fn_TopCustomer()
  Возвращает одну строку: CustomerID, CustomerName, TotalSpent
-----------------------------------------------------------*/
CREATE OR ALTER FUNCTION dbo.fn_TopCustomer()
RETURNS TABLE
AS
RETURN
(
    SELECT TOP (1) WITH TIES
           c.CustomerID,
           c.CustomerName,
           SUM(il.Quantity * il.UnitPrice) AS TotalSpent
    FROM   Sales.InvoiceLines il
    JOIN   Sales.Invoices     i  ON i.InvoiceID   = il.InvoiceID
    JOIN   Sales.Customers    c  ON c.CustomerID  = i.CustomerID
    GROUP  BY c.CustomerID, c.CustomerName
    ORDER  BY SUM(il.Quantity * il.UnitPrice) DESC
);
GO

/* ► использование */
SELECT * FROM dbo.fn_TopCustomer();

/*

Почему inline‑TVF? — она «растворяется» в план запроса, не создаёт доп. контекст UDF,
а значит работает так же быстро, как обычный SELECT … GROUP BY.

-----------------------------------------------------------*/

/*
2) Написать хранимую процедуру с входящим параметром СustomerID, выводящую сумму покупки по этому клиенту.
Использовать таблицы :
Sales.Customers
Sales.Invoices
Sales.InvoiceLines
*/

CREATE OR ALTER PROCEDURE dbo.usp_TotalByCustomer
     @CustomerID int,
     @TotalSpent money OUTPUT          -- можно NULL = нет продаж
AS
SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

SELECT @TotalSpent =
       SUM(il.Quantity * il.UnitPrice)
FROM   Sales.InvoiceLines il
JOIN   Sales.Invoices     i ON i.InvoiceID  = il.InvoiceID
WHERE  i.CustomerID = @CustomerID;

RETURN 0;
GO

/* ► использование */
DECLARE @total money;
EXEC dbo.usp_TotalByCustomer @CustomerID = 2, @TotalSpent = @total OUTPUT;
SELECT @total AS TotalSpent;
/*
При простых агрегациях хватает READ COMMITTED: повторов/грязных чтений нет, блокировки короткие.
-----------------------------------------------------------*/

/*
3) Создать одинаковую функцию и хранимую процедуру, посмотреть в чем разница в производительности и почему.
*/

/*==========================================================
  SETUP: пересоздаём объекты
==========================================================*/
IF OBJECT_ID('dbo.ufn_TotalByCustomer') IS NOT NULL
    DROP FUNCTION dbo.ufn_TotalByCustomer;
GO
CREATE FUNCTION dbo.ufn_TotalByCustomer (@CustomerID int)
RETURNS money
AS
BEGIN
    DECLARE @s money;
    SELECT @s =
           SUM(il.Quantity * il.UnitPrice)
    FROM   Sales.InvoiceLines il
    JOIN   Sales.Invoices     i ON i.InvoiceID = il.InvoiceID
    WHERE  i.CustomerID = @CustomerID;
    RETURN @s;
END;
GO

IF OBJECT_ID('dbo.usp_TotalByCustomer_v2') IS NOT NULL
    DROP PROCEDURE dbo.usp_TotalByCustomer_v2;
GO
CREATE PROCEDURE dbo.usp_TotalByCustomer_v2
     @CustomerID int,
     @TotalSpent money OUTPUT
AS
SET NOCOUNT ON;
SELECT @TotalSpent =
       SUM(il.Quantity * il.UnitPrice)
FROM   Sales.InvoiceLines il
JOIN   Sales.Invoices     i ON i.InvoiceID = il.InvoiceID
WHERE  i.CustomerID = @CustomerID;
GO

/*==========================================================
  TEST #1 : scalar UDF в одном SELECT
==========================================================*/
SET NOCOUNT ON;
PRINT '===== TEST 1 : scalar UDF ==================================';

DECLARE @t0  datetime2 = SYSDATETIME(),
        @rd0 bigint    = (SELECT logical_reads
                          FROM   sys.dm_exec_requests
                          WHERE  session_id = @@SPID);

SELECT  c.CustomerID,
        dbo.ufn_TotalByCustomer(c.CustomerID) AS TotalSpent
INTO    #ResUdf
FROM    Sales.Customers AS c;

DECLARE @ms1   int   = DATEDIFF(ms,@t0,SYSDATETIME()),
        @rd1   bigint = (SELECT logical_reads
                         FROM   sys.dm_exec_requests
                         WHERE  session_id = @@SPID),
        @rowsU int;
SELECT  @rowsU = COUNT(*) FROM #ResUdf;

PRINT 'IO/TIME summary -> ' + CAST(@rd1-@rd0 AS varchar)
      + ' logical reads, ' + CAST(@ms1 AS varchar) + ' ms';
PRINT 'Rows from UDF  -> ' + CAST(@rowsU AS varchar);
GO

/*==========================================================
  TEST #2 : stored‑procedure в cursor loop
==========================================================*/
PRINT '===== TEST 2 : stored proc + cursor ========================';

DECLARE @t0  datetime2 = SYSDATETIME(),
        @rd0 bigint    = (SELECT logical_reads
                          FROM   sys.dm_exec_requests
                          WHERE  session_id = @@SPID),
        @cid int, @sum money;

DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT CustomerID FROM Sales.Customers;
OPEN cur;
DROP TABLE IF EXISTS #ResProc;
CREATE TABLE #ResProc(CustomerID int, TotalSpent money);

FETCH NEXT FROM cur INTO @cid;
WHILE @@FETCH_STATUS = 0
BEGIN
    EXEC dbo.usp_TotalByCustomer_v2
         @CustomerID = @cid,
         @TotalSpent = @sum OUTPUT;

    INSERT INTO #ResProc VALUES (@cid,@sum);
    FETCH NEXT FROM cur INTO @cid;
END
CLOSE cur; DEALLOCATE cur;

DECLARE @ms2   int   = DATEDIFF(ms,@t0,SYSDATETIME()),
        @rd2   bigint = (SELECT logical_reads
                         FROM   sys.dm_exec_requests
                         WHERE  session_id = @@SPID),
        @rowsP int;
SELECT  @rowsP = COUNT(*) FROM #ResProc;

PRINT 'IO/TIME summary -> ' + CAST(@rd2-@rd0 AS varchar)
      + ' logical reads, ' + CAST(@ms2 AS varchar) + ' ms';
PRINT 'Rows from PROC -> ' + CAST(@rowsP AS varchar);
GO

/*==========================================================
  CLEAN‑UP (если нужно повторно тестировать)
==========================================================*/
DROP TABLE IF EXISTS #ResUdf, #ResProc;
GO

/*
===== TEST 1 : scalar UDF ==================================
IO/TIME summary -> 113799 logical reads, 1872 ms
Rows from UDF  -> 668
===== TEST 2 : stored proc + cursor ========================
IO/TIME summary -> 116415 logical reads, 1956 ms
Rows from PROC -> 668

Почему UDF чуть быстрее (на MS SQL 2019+):
оптимизатор встраивает scalar‑UDF в запрос (если нет запретных конструкций) и выполняет всего один проход по данным. 
Тестовый курсор вынужденно «скачёт» между client‑ид и выполняет N агрегатов.

Чтобы увидеть «классическую» медлительность scalar‑UDF, нужно отключить inlining:
ALTER DATABASE SCOPED CONFIGURATION SET TSQL_SCALAR_UDF_INLINING = OFF;
После этого UDF снова будет медленнее, чем любая set‑based альтернатива.
*/

/* ------
Сравнение Scalar UDF and Inline‑TVF
--------*/

/*==========================================================
  1.  Объекты с одинаковой логикой
==========================================================*/
CREATE OR ALTER FUNCTION dbo.ufn_TotalByCustomer (@CustomerID int)
RETURNS money
AS
BEGIN
    RETURN (SELECT SUM(il.Quantity*il.UnitPrice)
            FROM   Sales.InvoiceLines il
            JOIN   Sales.Invoices     i ON i.InvoiceID = il.InvoiceID
            WHERE  i.CustomerID = @CustomerID);
END;
GO

CREATE OR ALTER FUNCTION dbo.tvf_TotalByCustomer (@CustomerID int)
RETURNS TABLE
AS
RETURN
(
    SELECT SUM(il.Quantity*il.UnitPrice) AS TotalSpent
    FROM   Sales.InvoiceLines il
    JOIN   Sales.Invoices     i ON i.InvoiceID = il.InvoiceID
    WHERE  i.CustomerID = @CustomerID
);
GO

SET NOCOUNT ON;  

/*==========================================================
  TEST #1 : scalar UDF
==========================================================*/
PRINT '===== TEST 1 : scalar UDF ===============================';

DECLARE @t1      datetime2 = SYSDATETIME(),
        @reads10 bigint    = (SELECT logical_reads
                              FROM   sys.dm_exec_requests
                              WHERE  session_id = @@SPID);

SELECT  c.CustomerID,
        dbo.ufn_TotalByCustomer(c.CustomerID) AS TotalSpent
INTO    #ResUdf
FROM    Sales.Customers AS c;

DECLARE @ms1   int    = DATEDIFF(ms,@t1,SYSDATETIME()),
        @reads11 bigint = (SELECT logical_reads
                           FROM   sys.dm_exec_requests
                           WHERE  session_id = @@SPID),
        @rowsU  int;

SELECT @rowsU = COUNT(*) FROM #ResUdf;

PRINT 'IO/TIME summary -> ' +
      CAST(@reads11-@reads10 AS varchar) + ' logical reads, ' +
      CAST(@ms1 AS varchar)  + ' ms';
PRINT 'Rows from UDF   -> ' + CAST(@rowsU AS varchar);
GO

/*==========================================================
  TEST #2 : inline TVF (CROSS APPLY)
==========================================================*/
PRINT '===== TEST 2 : inline TVF (CROSS APPLY) =================';

DECLARE @t2      datetime2 = SYSDATETIME(),
        @reads20 bigint    = (SELECT logical_reads
                              FROM   sys.dm_exec_requests
                              WHERE  session_id = @@SPID);

SELECT  c.CustomerID,
        t.TotalSpent
INTO    #ResTvf
FROM    Sales.Customers AS c
CROSS APPLY dbo.tvf_TotalByCustomer(c.CustomerID) AS t;

DECLARE @ms2   int    = DATEDIFF(ms,@t2,SYSDATETIME()),
        @reads21 bigint = (SELECT logical_reads
                           FROM   sys.dm_exec_requests
                           WHERE  session_id = @@SPID),
        @rowsT  int;

SELECT @rowsT = COUNT(*) FROM #ResTvf;

PRINT 'IO/TIME summary -> ' +
      CAST(@reads21-@reads20 AS varchar) + ' logical reads, ' +
      CAST(@ms2 AS varchar)  + ' ms';
PRINT 'Rows from TVF   -> ' + CAST(@rowsT AS varchar);
GO

/*==========================================================
  CLEAN-UP
==========================================================*/
DROP TABLE IF EXISTS #ResUdf, #ResTvf;
SET NOCOUNT OFF;
GO;

/*
===== TEST 1 : scalar UDF ===============================
IO/TIME summary -> 113870 logical reads, 1880 ms
Rows from UDF   -> 668
===== TEST 2 : inline TVF (CROSS APPLY) =================
IO/TIME summary -> 675 logical reads, 42 ms
Rows from TVF   -> 668

Почему scalar UDF оказался в 60 раз медленнее
N вызовов × N‑кратный план.
Запрос выполняется так:

for каждый CustomerID  
    заново выполняем SELECT‑SUM …  
Получается 668 отдельных обращений к InvoiceLines / Invoices.
Отсюда 113 k чтений страниц и ~1,8 сек.

Контекст‑переключение UDF.
До SQL Server 2019 каждая scalar‑UDF исполнялась в собственном интерпретаторе T‑SQL, двигатель «прыгал» между реляционным и скалярным контекстами → дополнительное CPU‑время.

Inline‑TVF вливается в общий план.
Оптимизатор видит CROSS APPLY как единый HASH JOIN + GROUP BY:

данные читаются один раз,

агрегат считается построчно в том же плане,

всего 517 логических чтений.
*/

/*
4) Создайте табличную функцию покажите как ее можно вызвать для каждой строки result set'а без использования цикла. 
*/

CREATE OR ALTER FUNCTION dbo.fn_CustomerStats (@CustomerID int)
RETURNS TABLE
AS
RETURN
(
    SELECT  @CustomerID                       AS CustomerID,
            COUNT(DISTINCT i.InvoiceID)       AS InvoiceCnt,
            SUM(il.Quantity * il.UnitPrice)   AS TotalSpent
    FROM   Sales.Invoices     i
    JOIN   Sales.InvoiceLines il ON il.InvoiceID = i.InvoiceID
    WHERE  i.CustomerID = @CustomerID
);
GO

-- Вызов — CROSS APPLY вместо цикла ---
SELECT  c.CustomerName,
        s.InvoiceCnt,
        s.TotalSpent
FROM    Sales.Customers c
CROSS APPLY dbo.fn_CustomerStats(c.CustomerID) s;


/*
5) Опционально. Во всех процедурах укажите какой уровень изоляции транзакций вы бы использовали и почему. 
*/
/*
№ | Объект                                     | Логика запроса                                       | Уровень изоляции                       | Причина выбора уровня изоляции                                                      
--+--------------------------------------------+------------------------------------------------------+----------------------------------------+--------------------------------------------------------------------------------------
1 | dbo.fn_TopCustomer (inline TVF)            | Агрегируем все продажи → ищем клиента‑лидера         | SNAPSHOT (или READ COMMITTED + RCSI)   | Нужен согласованный срез данных без блокировок вставок и апдейтов. SNAPSHOT читает   
  |                                            |                                                      |                                        | версии строк → нет shared-блокировок и разрывов агрегатов. Данные не меняются критично.                         
--+--------------------------------------------+------------------------------------------------------+----------------------------------------+--------------------------------------------------------------------------------------
2 | dbo.usp_TotalByCustomer                    | Сумма продаж выбранного клиента                      | READ COMMITTED (с включённым RCSI)     | Важна актуальная сумма, фантомы не критичны (свежие данные полезны). Версионные      
  |                                            |                                                      |                                        | строки (RCSI) → нет блокировок.                                                     
--+--------------------------------------------+------------------------------------------------------+----------------------------------------+--------------------------------------------------------------------------------------
3 | dbo.ufn_TotalByCustomer (scalar-UDF),      | Тот же расчёт, но вызывается десятки/сотни раз       | READ COMMITTED (с включённым RCSI)     | нужно точное значение «на сейчас», phantom‑read не критичен         
  | dbo.usp_TotalByCustomer_v2                 |                                                      |                                        |                                                                                      
--+--------------------------------------------+------------------------------------------------------+----------------------------------------+--------------------------------------------------------------------------------------
4 | dbo.fn_CustomerStats                       | Ведомость по каждому клиенту: число инвойсов + сумма | READ UNCOMMITTED                       | Большой объём (~1 млн строк). «Грязные» чтения минимизируют блокировки и             
  | (табличная, через CROSS APPLY)             |                                                      | (если допустимы «грязные» данные)      | латентность. Если нужна точность — READ COMMITTED (с RCSI), тоже без блокировок.     
  |                                            |                                                      | или READ COMMITTED (если важна точность)|                                                                                      

Почему почти везде достаточно READ COMMITTED?
В WideWorldImporters (как и в большинстве современных БД) включён RCSI (Read‑Committed Snapshot Isolation). 
Это означает, что обычный READ COMMITTED читает не «живые» страницы под shared‑блоками, а версионную копию из tempdb — по сути тот же SNAPSHOT, но дешевле в обслуживании. 
Поэтому:

- нет блокировок, мешающих writer‑ам;

- данные внутри одного запроса непротиворечивы;

- дополнительной защиты (Repeatable Read/Serializable) не требуется, если мы не делаем критичных расчётов складских остатков в конце месяца.


Для функций inline‑TVF и scalar‑UDF изоляция наследуется от внешнего запроса;
чтобы гарантировать SNAPSHOT, нужно обернуть вызов в BEGIN TRAN … SET TRANSACTION ISOLATION LEVEL SNAPSHOT; … COMMIT.

Таким образом:

SNAPSHOT / RCSI — там, где нужен консистентный снимок всего объёма.

READ COMMITTED — достаточно для точечных агрегатов; блокировок — минимум.

READ UNCOMMITTED — допускается в тяжёлых отчётах, если приемлема возможная «грязь».

*/
