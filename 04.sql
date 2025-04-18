-- ===============================
-- SUBQUERIES & CTEs HOMEWORK
-- ===============================

/*
Task A
Employees (Application.People) who are salespeople (IsSalesperson = 1) and made **no** sales on 4 July 2015 (Sales.Invoices).
Return: PersonID, FullName
*/
-- A‑1  📄  Sub‑query version
SELECT PersonID, FullName
FROM   Application.People
WHERE  IsSalesperson = 1
  AND  PersonID NOT IN (  -- no invoice on the date
        SELECT SalespersonPersonID
        FROM   Sales.Invoices
        WHERE  InvoiceDate = '2015‑07‑04');

-- A‑2  📄  CTE version
WITH SalesOnDate AS (
    SELECT DISTINCT SalespersonPersonID
    FROM   Sales.Invoices
    WHERE  InvoiceDate = '2015‑07‑04'
)
SELECT p.PersonID, p.FullName
FROM   Application.People p
LEFT  JOIN SalesOnDate s  ON s.SalespersonPersonID = p.PersonID
WHERE  p.IsSalesperson = 1
  AND  s.SalespersonPersonID IS NULL;

/*
Task B
Products having the **minimum** price (Warehouse.StockItems.UnitPrice).
Return: StockItemID, StockItemName, UnitPrice
*/
-- B‑1  📄  Scalar sub‑query
SELECT StockItemID, StockItemName, UnitPrice
FROM   Warehouse.StockItems
WHERE  UnitPrice = (SELECT MIN(UnitPrice) FROM Warehouse.StockItems);

-- B‑2  📄  Correlated sub‑query (NOT EXISTS)
SELECT si.StockItemID, si.StockItemName, si.UnitPrice
FROM   Warehouse.StockItems si
WHERE  NOT EXISTS (SELECT 1
                   FROM   Warehouse.StockItems x
                   WHERE  x.UnitPrice < si.UnitPrice);

-- B‑3  📜  CTE version (for completeness)
WITH MinPrice AS (
    SELECT MIN(UnitPrice) AS MinUnitPrice
    FROM   Warehouse.StockItems )
SELECT StockItemID, StockItemName, UnitPrice
FROM   Warehouse.StockItems, MinPrice
WHERE  UnitPrice = MinPrice.MinUnitPrice;

/*
Task C
Information on customers who made the company’s **five biggest payments** (Sales.CustomerTransactions).
Assume positive AmountExcludingTax values are payments to the company.
Return: CustomerID, CustomerName, TransactionID, AmountExcludingTax, TransactionDate
*/
-- C‑1  📄  Inline sub‑query with TOP 5 WITH TIES
SELECT ct.CustomerID, c.CustomerName,
       ct.CustomerTransactionID, ct.AmountExcludingTax, ct.TransactionDate
FROM   Sales.CustomerTransactions ct
JOIN   Sales.Customers           c  ON c.CustomerID = ct.CustomerID
WHERE  ct.CustomerTransactionID IN (
        SELECT TOP 5 WITH TIES CustomerTransactionID
        FROM   Sales.CustomerTransactions
        ORDER  BY AmountExcludingTax DESC )
ORDER  BY ct.AmountExcludingTax DESC;

-- C‑2  📄  Derived‑table variant 
-- Return: CustomerID, CustomerName, AmountExcludingTax
SELECT c.CustomerID, c.CustomerName, dt.AmountExcludingTax
FROM   Sales.Customers c
JOIN  (
        SELECT TOP 5 WITH TIES CustomerID, AmountExcludingTax
        FROM   Sales.CustomerTransactions
        ORDER  BY AmountExcludingTax DESC
      ) dt ON dt.CustomerID = c.CustomerID
ORDER BY dt.AmountExcludingTax DESC;

-- C‑3  📜  CTE + window‐function version
WITH RankedPayments AS (
    SELECT ct.*, ROW_NUMBER() OVER (ORDER BY AmountExcludingTax DESC)  AS rn
    FROM   Sales.CustomerTransactions ct)
SELECT rp.CustomerID, c.CustomerName,
       rp.CustomerTransactionID, rp.AmountExcludingTax, rp.TransactionDate
FROM   RankedPayments rp
JOIN   Sales.Customers   c ON c.CustomerID = rp.CustomerID
WHERE  rp.rn <= 5
ORDER  BY rp.AmountExcludingTax DESC;

-- C‑4  📜  Simple CTE 
-- Return: CustomerID, CustomerName, AmountExcludingTax
;WITH tr AS (
    SELECT TOP 5 CustomerID, AmountExcludingTax
    FROM   Sales.CustomerTransactions
    ORDER  BY AmountExcludingTax DESC
)
SELECT c.CustomerID, c.CustomerName, tr.AmountExcludingTax
FROM   Sales.Customers c
JOIN   tr ON tr.CustomerID = c.CustomerID
ORDER  BY tr.AmountExcludingTax DESC;

/*
Task D
Cities (ID & Name) to which items belonging to the **top‑3 most expensive products** were delivered,
plus the employee who packed those orders (PackedByPersonID).
*/
-- D‑1  📄  Sub‑query version
SELECT DISTINCT ci.CityID, ci.CityName, pe.FullName AS PickedBy
FROM   Sales.Orders      o
JOIN   Sales.OrderLines  ol ON ol.OrderID = o.OrderID
JOIN   Sales.Customers   cu ON cu.CustomerID = o.CustomerID
JOIN   Application.Cities ci ON ci.CityID  = cu.DeliveryCityID
JOIN   Application.People pe ON pe.PersonID = o.PickedByPersonID
WHERE  ol.StockItemID IN (SELECT TOP 3 WITH TIES StockItemID
                          FROM Warehouse.StockItems
                          ORDER BY UnitPrice DESC);

-- D‑2  📜  CTE version
WITH TopItems AS (
    SELECT TOP 3 WITH TIES StockItemID
    FROM   Warehouse.StockItems
    ORDER  BY UnitPrice DESC)
SELECT DISTINCT ci.CityID, ci.CityName, pe.FullName AS PickedBy
FROM   Sales.Orders      o
JOIN   Sales.OrderLines  ol ON ol.OrderID = o.OrderID
JOIN   TopItems          ti ON ti.StockItemID = ol.StockItemID
JOIN   Sales.Customers   cu ON cu.CustomerID = o.CustomerID
JOIN   Application.Cities ci ON ci.CityID  = cu.DeliveryCityID
JOIN   Application.People pe ON pe.PersonID = o.PickedByPersonID;

