SET STATISTICS IO, TIME ON

	/*
Что делает исходный запрос 

Фильтрует инвойсы: сначала вычисляется подзапрос SalesTotals, где для каждой InvoiceID суммируется стоимость строк инвойсов; оставляют лишь те, у кого сумма > 27 000.

Собирает данные по каждому инвойсу

дата инвойса;

имя продавца (коррелированный под‑запрос к Application.People);

сумма из SalesTotals;

вторая сумма — стоимость picked‑товаров того же заказа, рассчитывается снова через вложенные запросы (внутри ещё одна выборка к Sales.Orders).

Сортирует результат по сумме инвойса.

Минусы исходной версии

Скалярные под‑запросы (SELECT … WHERE PersonID = … и “picked sum”) выполняются для каждой строки наружного запроса → множество мелких обращений, много лишних чтений, рост I/O.

Три уровня вложенности делают код трудночитаемым.

В подзапросе InvoiceLines используется несуществующее поле QuantityUnitPrice; в WideWorldImporters его роль играет Quantity * UnitPrice.
	*/

-- ORIGINAL
SELECT
    i.InvoiceID,
    i.InvoiceDate,
    (
        SELECT
            FullName
        FROM
            Application.People p
        WHERE
            p.PersonID = i.SalespersonPersonID
    ) AS SalesPersonName,
    st.TotalSumm AS TotalSummByInvoice,
    (
        SELECT
            SUM(ol.PickedQuantity * ol.UnitPrice)
        FROM
            Sales.OrderLines ol
        WHERE
            ol.OrderID = (
                SELECT
                    o.OrderID
                FROM
                    Sales.Orders o
                WHERE
                    o.PickingCompletedWhen IS NOT NULL
                    AND o.OrderID = i.OrderID
            )
    ) AS TotalSummForPickedItems
FROM
    Sales.Invoices i
    JOIN (
        SELECT
            InvoiceID,
            SUM(Quantity * UnitPrice) AS TotalSumm
        FROM
            Sales.InvoiceLines
        GROUP BY
            InvoiceID
        HAVING
            SUM(Quantity * UnitPrice) > 27000
    ) st ON st.InvoiceID = i.InvoiceID
ORDER BY
    st.TotalSumm DESC;

	/*

(8 rows affected)
Table 'OrderLines'. Scan count 56, logical reads 0, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 508, lob physical reads 3, lob page server reads 0, lob read-ahead reads 790, lob page server read-ahead reads 0.
Table 'OrderLines'. Segment reads 1, segment skipped 0.
Table 'InvoiceLines'. Scan count 56, logical reads 0, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 332, lob physical reads 2, lob page server reads 0, lob read-ahead reads 6, lob page server read-ahead reads 0.
Table 'InvoiceLines'. Segment reads 1, segment skipped 0.
Table 'Orders'. Scan count 29, logical reads 725, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
Table 'Invoices'. Scan count 29, logical reads 11994, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
Table 'People'. Scan count 8, logical reads 28, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
Table 'Worktable'. Scan count 0, logical reads 0, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.

 SQL Server Execution Times:
   CPU time = 425 ms,  elapsed time = 153 ms.

	*/



-- OPTIMISED VERSION (CTEs + set‑based joins)
;

WITH
    SalesTotals AS (
        SELECT
            il.InvoiceID,
            SUM(il.Quantity * il.UnitPrice) AS TotalSumm
        FROM
            Sales.InvoiceLines il
        GROUP BY
            il.InvoiceID
        HAVING
            SUM(il.Quantity * il.UnitPrice) > 27000
    ),
    PickedTotals AS (
        SELECT
            o.OrderID,
            SUM(ol.PickedQuantity * ol.UnitPrice) AS PickedTotal
        FROM
            Sales.Orders o
            JOIN Sales.OrderLines ol ON ol.OrderID = o.OrderID
        WHERE
            o.PickingCompletedWhen IS NOT NULL
        GROUP BY
            o.OrderID
    )
SELECT
    i.InvoiceID,
    i.InvoiceDate,
    sp.FullName AS SalesPersonName,
    st.TotalSumm AS TotalSummByInvoice,
    ISNULL (pt.PickedTotal, 0) AS TotalSummForPickedItems
FROM
    Sales.Invoices i
    JOIN SalesTotals st ON st.InvoiceID = i.InvoiceID
    LEFT JOIN PickedTotals pt ON pt.OrderID = i.OrderID
    JOIN Application.People sp ON sp.PersonID = i.SalespersonPersonID
ORDER BY
    st.TotalSumm DESC;

	/*
(8 rows affected)
Table 'OrderLines'. Scan count 56, logical reads 0, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 326, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
Table 'OrderLines'. Segment reads 1, segment skipped 0.
Table 'InvoiceLines'. Scan count 56, logical reads 0, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 322, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
Table 'InvoiceLines'. Segment reads 1, segment skipped 0.
Table 'Orders'. Scan count 29, logical reads 725, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
Table 'Invoices'. Scan count 29, logical reads 11994, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
Table 'People'. Scan count 15, logical reads 28, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
Table 'Worktable'. Scan count 0, logical reads 0, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.

 SQL Server Execution Times:
   CPU time = 296 ms,  elapsed time = 117 ms.
	*/

	/*
Почему быстрее / чище

Проблема оригинала                                            | Исправление
-----------------------------------------------------------------------------------------------------------------------
Коррелированные под‑запросы → N × (скан People / OrderLines). | Все суммы вынесены в CTE‑агрегации, выполняются один раз.
Не‑SARGable фильтр в под‑запросе                               | Используется обычный JOIN, индексируется.
Многоуровневая вложенность                                     | Логика читается сверху‑вниз в две CTE.

         Logical reads	CPU (ms)
Original	500	        425
Optimised	326	        296
	*/

-- Комбинированные covering‑индексы уменьшают кол‑во чтений и позволяют Optimizer выбрать hash/merge join
CREATE INDEX IX_InvoiceLines_Invoice
    ON Sales.InvoiceLines(InvoiceID)
    INCLUDE (Quantity, UnitPrice);

CREATE INDEX IX_OrderLines_Order
    ON Sales.OrderLines(OrderID)
    INCLUDE (PickedQuantity, UnitPrice);

CREATE INDEX IX_Orders_PickedStatus
    ON Sales.Orders(OrderID, PickingCompletedWhen);
