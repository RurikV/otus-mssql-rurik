/*
Домашнее задание по курсу MS SQL Server Developer в OTUS.

Занятие "06 - Оконные функции".

Задания выполняются с использованием базы данных WideWorldImporters.

Бэкап БД можно скачать отсюда:
https://github.com/Microsoft/sql-server-samples/releases/tag/wide-world-importers-v1.0
Нужен WideWorldImporters-Full.bak

Описание WideWorldImporters от Microsoft:
* https://docs.microsoft.com/ru-ru/sql/samples/wide-world-importers-what-is
* https://docs.microsoft.com/ru-ru/sql/samples/wide-world-importers-oltp-database-catalog
*/

-- ---------------------------------------------------------------------------
-- Задание - написать выборки для получения указанных ниже данных.
-- ---------------------------------------------------------------------------

USE WideWorldImporters

SET STATISTICS TIME, IO ON
/*
1. Сделать расчет суммы продаж нарастающим итогом по месяцам с 2015 года 
(в рамках одного месяца он будет одинаковый, нарастать будет в течение времени выборки).
Выведите: id продажи, название клиента, дату продажи, сумму продажи, сумму нарастающим итогом

Пример:
-------------+----------------------------
Дата продажи | Нарастающий итог по месяцу
-------------+----------------------------
 2015-01-29   | 4801725.31
 2015-01-30	 | 4801725.31
 2015-01-31	 | 4801725.31
 2015-02-01	 | 9626342.98
 2015-02-02	 | 9626342.98
 2015-02-03	 | 9626342.98
Продажи можно взять из таблицы Invoices.
Нарастающий итог должен быть без оконной функции.
*/

WITH InvoiceTotals AS (
    SELECT i.InvoiceID,
           i.InvoiceDate,
           i.CustomerID,
           SUM(il.Quantity * il.UnitPrice) AS InvoiceTotal
    FROM   Sales.Invoices      i
    JOIN   Sales.InvoiceLines  il ON il.InvoiceID = i.InvoiceID
    WHERE  i.InvoiceDate >= '2015-01-01'
    GROUP  BY i.InvoiceID, i.InvoiceDate, i.CustomerID ),
MonthTotals AS (
    SELECT YEAR(InvoiceDate) AS yr,
           MONTH(InvoiceDate) AS mth,
           SUM(InvoiceTotal)  AS MonthTotal
    FROM   InvoiceTotals
    GROUP  BY YEAR(InvoiceDate), MONTH(InvoiceDate) ),
Running AS (
    SELECT mt1.yr, mt1.mth,
           (SELECT SUM(mt2.MonthTotal)
            FROM   MonthTotals mt2
            WHERE  (mt2.yr  < mt1.yr)
               OR (mt2.yr = mt1.yr AND mt2.mth <= mt1.mth)) AS RunningTotal
    FROM   MonthTotals mt1 )
SELECT it.InvoiceID,
       c.CustomerName,
       it.InvoiceDate,
       it.InvoiceTotal,
       r.RunningTotal        AS RunningTotalByMonth
FROM   InvoiceTotals it
JOIN   Running       r ON r.yr  = YEAR(it.InvoiceDate)
                      AND r.mth = MONTH(it.InvoiceDate)
JOIN   Sales.Customers c ON c.CustomerID = it.CustomerID
ORDER  BY it.InvoiceDate;

/*
(31440 rows affected)
Table 'InvoiceLines'. Scan count 21, logical reads 13413, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 313, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
Table 'InvoiceLines'. Segment reads 2, segment skipped 0.
Table 'Worktable'. Scan count 0, logical reads 0, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
Table 'Invoices'. Scan count 19, logical reads 216600, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
Table 'Worktable'. Scan count 0, logical reads 0, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
Table 'Customers'. Scan count 1, logical reads 40, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
Table 'Workfile'. Scan count 0, logical reads 0, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.

 SQL Server Execution Times:
   CPU time = 2304 ms,  elapsed time = 2314 ms.
*/

/*
2. Сделайте расчет суммы нарастающим итогом в предыдущем запросе с помощью оконной функции.
   Сравните производительность запросов 1 и 2 с помощью set statistics time, io on
*/

WITH InvoiceTotals AS (
    SELECT i.InvoiceID,
           i.InvoiceDate,
           i.CustomerID,
           SUM(il.Quantity * il.UnitPrice) AS InvoiceTotal
    FROM   Sales.Invoices i
    JOIN   Sales.InvoiceLines il ON il.InvoiceID = i.InvoiceID
    WHERE  i.InvoiceDate >= '2015-01-01'
    GROUP  BY i.InvoiceID, i.InvoiceDate, i.CustomerID )
SELECT it.InvoiceID,
       c.CustomerName,
       it.InvoiceDate,
       it.InvoiceTotal,
       SUM(it.InvoiceTotal) OVER (PARTITION BY YEAR(it.InvoiceDate), MONTH(it.InvoiceDate)
                                  ORDER BY YEAR(it.InvoiceDate), MONTH(it.InvoiceDate)
                                  ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
           AS RunningTotalByMonth
FROM   InvoiceTotals it
JOIN   Sales.Customers c ON c.CustomerID = it.CustomerID
ORDER  BY it.InvoiceDate;

/*
(31440 rows affected)
Table 'InvoiceLines'. Scan count 2, logical reads 0, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 161, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
Table 'InvoiceLines'. Segment reads 1, segment skipped 0.
Table 'Worktable'. Scan count 0, logical reads 0, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
Table 'Invoices'. Scan count 1, logical reads 11400, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
Table 'Worktable'. Scan count 0, logical reads 0, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
Table 'Customers'. Scan count 1, logical reads 40, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.

 SQL Server Execution Times:
   CPU time = 99 ms,  elapsed time = 103 ms.
*/

/*
3. Вывести список 2х самых популярных продуктов (по количеству проданных) 
в каждом месяце за 2016 год (по 2 самых популярных продукта в каждом месяце).
*/

------------------------------------------------------------
--   (без window)
------------------------------------------------------------
WITH QtyByItem AS (
    SELECT YEAR(i.InvoiceDate)  AS yr,
           MONTH(i.InvoiceDate) AS mth,
           il.StockItemID,
           SUM(il.Quantity)     AS Qty
    FROM   Sales.InvoiceLines il
    JOIN   Sales.Invoices     i ON i.InvoiceID = il.InvoiceID
    WHERE  i.InvoiceDate >= '2016-01-01' AND i.InvoiceDate < '2017-01-01'
    GROUP  BY YEAR(i.InvoiceDate), MONTH(i.InvoiceDate), il.StockItemID ),
Top2 AS (
    SELECT q1.*
    FROM   QtyByItem q1
    WHERE  2 > (SELECT COUNT(*)
                FROM QtyByItem q2
                WHERE q2.yr  = q1.yr  AND q2.mth = q1.mth
                  AND q2.Qty > q1.Qty) )
SELECT t.yr, t.mth, t.StockItemID, si.StockItemName, t.Qty
FROM   Top2 t
JOIN   Warehouse.StockItems si ON si.StockItemID = t.StockItemID
ORDER  BY t.yr, t.mth, t.Qty DESC;

/*
(10 rows affected)
Table 'InvoiceLines'. Scan count 1542023, logical reads 20072326, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 324, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
Table 'InvoiceLines'. Segment reads 1, segment skipped 0.
Table 'Invoices'. Scan count 30, logical reads 23394, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
Table 'StockItems'. Scan count 0, logical reads 20, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
Table 'Worktable'. Scan count 2815, logical reads 174486, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
Table 'Workfile'. Scan count 0, logical reads 0, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
Table 'Worktable'. Scan count 0, logical reads 0, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.

 SQL Server Execution Times:
   CPU time = 18629 ms,  elapsed time = 3815 ms.
*/


------------------------------------------------------------
--  (с оконной функцией)
------------------------------------------------------------
WITH QtyByItem AS (
    SELECT YEAR(i.InvoiceDate)  AS yr,
           MONTH(i.InvoiceDate) AS mth,
           il.StockItemID,
           SUM(il.Quantity)     AS Qty
    FROM   Sales.InvoiceLines il
    JOIN   Sales.Invoices     i ON i.InvoiceID = il.InvoiceID
    WHERE  i.InvoiceDate >= '2016-01-01' AND i.InvoiceDate < '2017-01-01'
    GROUP  BY YEAR(i.InvoiceDate), MONTH(i.InvoiceDate), il.StockItemID )
SELECT qi.yr, qi.mth, qi.StockItemID, si.StockItemName, qi.Qty
FROM  (
    SELECT qi.*, ROW_NUMBER() OVER (PARTITION BY yr, mth ORDER BY Qty DESC) AS rn
    FROM   QtyByItem qi) qi
JOIN  Warehouse.StockItems si ON si.StockItemID = qi.StockItemID
WHERE qi.rn <= 2
ORDER BY qi.yr, qi.mth, qi.Qty DESC;

/*
(10 rows affected)
Table 'StockItems'. Scan count 1, logical reads 6, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
Table 'InvoiceLines'. Scan count 56, logical reads 0, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 324, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
Table 'InvoiceLines'. Segment reads 1, segment skipped 0.
Table 'Invoices'. Scan count 29, logical reads 11994, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
Table 'Worktable'. Scan count 0, logical reads 0, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
Table 'Worktable'. Scan count 0, logical reads 0, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.

 SQL Server Execution Times:
   CPU time = 585 ms,  elapsed time = 111 ms.
*/



/*
4. Функции одним запросом
Посчитайте по таблице товаров (в вывод также должен попасть ид товара, название, брэнд и цена):
* пронумеруйте записи по названию товара, так чтобы при изменении буквы алфавита нумерация начиналась заново
* посчитайте общее количество товаров и выведете полем в этом же запросе
* посчитайте общее количество товаров в зависимости от первой буквы названия товара
* отобразите следующий id товара исходя из того, что порядок отображения товаров по имени 
* предыдущий ид товара с тем же порядком отображения (по имени)
* названия товара 2 строки назад, в случае если предыдущей строки нет нужно вывести "No items"
* сформируйте 30 групп товаров по полю вес товара на 1 шт

Для этой задачи НЕ нужно писать аналог без аналитических функций.
*/

SELECT si.StockItemID,
       si.StockItemName,
       si.Brand,
       si.UnitPrice,
       --------------------------------------------------
       -- 1) Нумерация, сбрасывающаяся при смене первой буквы
       ROW_NUMBER() OVER (PARTITION BY LEFT(si.StockItemName,1)
                          ORDER BY si.StockItemName)               AS SeqWithinLetter,
       -- 2) Общее количество товаров
       COUNT(*) OVER ()                                            AS TotalItems,
       -- 3) Кол‑во товаров на ту же первую букву
       COUNT(*) OVER (PARTITION BY LEFT(si.StockItemName,1))       AS ItemsSameLetter,
       -- 4) Следующий id товара по алфавиту
       LEAD(si.StockItemID) OVER (ORDER BY si.StockItemName)       AS NextItemID,
       -- 5) Предыдущий id товара
       LAG (si.StockItemID) OVER (ORDER BY si.StockItemName)       AS PrevItemID,
       -- 6) Название товара 2 строки назад или 'No items'
       COALESCE(LAG (si.StockItemName,2) OVER (ORDER BY si.StockItemName), 'No items') AS NameMinus2,
       -- 7) Разбивка на 30 групп по весу
       NTILE(30) OVER (ORDER BY si.TypicalWeightPerUnit)           AS WeightGroup
FROM   Warehouse.StockItems si
ORDER  BY si.StockItemName;


/*
5. По каждому сотруднику выведите последнего клиента, которому сотрудник что-то продал.
   В результатах должны быть ид и фамилия сотрудника, ид и название клиента, дата продажи, сумму сделки.
*/

------------------------------------------------------------
--   (без оконных функций, решает дубликаты по дате)
------------------------------------------------------------
SELECT p.PersonID, p.FullName,
       c.CustomerID, c.CustomerName,
       last.InvoiceDate, it.InvoiceTotal
FROM   Application.People p
CROSS  APPLY (  -- берём ровно один самый поздний инвойс сотрудника
        SELECT TOP 1 i1.CustomerID, i1.InvoiceID, i1.InvoiceDate
        FROM   Sales.Invoices i1
        WHERE  i1.SalespersonPersonID = p.PersonID
        ORDER  BY i1.InvoiceDate DESC, i1.InvoiceID DESC
      ) last
JOIN   Sales.Customers c ON c.CustomerID = last.CustomerID
JOIN  (
        SELECT InvoiceID, SUM(Quantity*UnitPrice) AS InvoiceTotal
        FROM   Sales.InvoiceLines
        GROUP  BY InvoiceID
      ) it ON it.InvoiceID = last.InvoiceID;

/*
(10 rows affected)
Table 'InvoiceLines'. Scan count 2, logical reads 0, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 161, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
Table 'InvoiceLines'. Segment reads 1, segment skipped 0.
Table 'Worktable'. Scan count 0, logical reads 0, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
Table 'Customers'. Scan count 1, logical reads 29, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
Table 'Worktable'. Scan count 1111, logical reads 145230, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
Table 'Invoices'. Scan count 1, logical reads 11400, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
Table 'People'. Scan count 1, logical reads 11, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.

 SQL Server Execution Times:
   CPU time = 167 ms,  elapsed time = 167 ms.
*/

------------------------------------------------------------
--   (с оконной функцией, тот же алгоритм)
------------------------------------------------------------
WITH Rn AS (
    SELECT i.*, ROW_NUMBER() OVER (PARTITION BY SalespersonPersonID
                                   ORDER BY InvoiceDate DESC, InvoiceID DESC) AS rn
    FROM   Sales.Invoices i )
SELECT p.PersonID, p.FullName,
       c.CustomerID, c.CustomerName,
       r.InvoiceDate,
       it.InvoiceTotal
FROM   Rn r
JOIN   Application.People p ON p.PersonID = r.SalespersonPersonID
JOIN   Sales.Customers   c ON c.CustomerID   = r.CustomerID
JOIN  (SELECT InvoiceID, SUM(Quantity*UnitPrice) AS InvoiceTotal
       FROM   Sales.InvoiceLines GROUP BY InvoiceID) it ON it.InvoiceID = r.InvoiceID
WHERE  r.rn = 1;

/*
(10 rows affected)
Table 'InvoiceLines'. Scan count 2, logical reads 0, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 161, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
Table 'InvoiceLines'. Segment reads 1, segment skipped 0.
Table 'Worktable'. Scan count 0, logical reads 0, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
Table 'Invoices'. Scan count 1, logical reads 11400, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
Table 'People'. Scan count 1, logical reads 11, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
Table 'Worktable'. Scan count 0, logical reads 0, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
Table 'Customers'. Scan count 1, logical reads 40, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.

 SQL Server Execution Times:
   CPU time = 100 ms,  elapsed time = 103 ms.
*/


/*
6. Выберите по каждому клиенту два самых дорогих товара, которые он покупал.
В результатах должно быть ид клиета, его название, ид товара, цена, дата покупки.
*/

------------------------------------------------------------
--  (без оконных функций)
------------------------------------------------------------
WITH Prices AS (
    SELECT c.CustomerID, c.CustomerName,
           il.StockItemID,
           MAX(il.UnitPrice) AS MaxPrice,
           MAX(i.InvoiceDate) AS AnyDate
    FROM   Sales.InvoiceLines il
    JOIN   Sales.Invoices i ON i.InvoiceID = il.InvoiceID
    JOIN   Sales.Customers c ON c.CustomerID = i.CustomerID
    GROUP  BY c.CustomerID, c.CustomerName, il.StockItemID ),
Top2 AS (
    SELECT p1.*
    FROM   Prices p1
    WHERE  2 > (SELECT COUNT(*)
                FROM Prices p2
                WHERE p2.CustomerID = p1.CustomerID
                  AND p2.MaxPrice  > p1.MaxPrice) )
SELECT * FROM Top2
ORDER  BY CustomerID, MaxPrice DESC;

/*
(1485 rows affected)
Table 'InvoiceLines'. Scan count 3437940, logical reads 45095374, physical reads 0, page server reads 0, read-ahead reads 186, page server read-ahead reads 0, lob logical reads 161, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
Table 'InvoiceLines'. Segment reads 1, segment skipped 0.
Table 'Worktable'. Scan count 0, logical reads 0, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
Table 'Invoices'. Scan count 31800, logical reads 84132, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
Table 'Worktable'. Scan count 0, logical reads 0, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
Table 'Customers'. Scan count 1, logical reads 63638, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.

 SQL Server Execution Times:
   CPU time = 33631 ms,  elapsed time = 33758 ms.
*/

------------------------------------------------------------
--  (с оконной функцией)
------------------------------------------------------------
WITH Prices AS (
    SELECT c.CustomerID, c.CustomerName,
           il.StockItemID,
           il.UnitPrice,
           i.InvoiceDate,
           ROW_NUMBER() OVER (PARTITION BY c.CustomerID ORDER BY il.UnitPrice DESC) AS rn
    FROM   Sales.InvoiceLines il
    JOIN   Sales.Invoices i ON i.InvoiceID = il.InvoiceID
    JOIN   Sales.Customers c ON c.CustomerID = i.CustomerID )
SELECT CustomerID, CustomerName, StockItemID, UnitPrice, InvoiceDate
FROM   Prices
WHERE  rn <= 2
ORDER  BY CustomerID, UnitPrice DESC;

/*
(1326 rows affected)
Table 'InvoiceLines'. Scan count 2, logical reads 0, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 161, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
Table 'InvoiceLines'. Segment reads 1, segment skipped 0.
Table 'Worktable'. Scan count 0, logical reads 0, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
Table 'Invoices'. Scan count 1, logical reads 11400, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
Table 'Worktable'. Scan count 0, logical reads 0, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
Table 'Customers'. Scan count 1, logical reads 40, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.

 SQL Server Execution Times:
   CPU time = 160 ms,  elapsed time = 169 ms.
*/