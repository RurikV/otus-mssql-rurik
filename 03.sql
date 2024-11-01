-- Query 1: Average product price and total sales amount per month
SELECT YEAR(OrderDate) AS Year, MONTH(OrderDate) AS Month, 
       AVG(ol.UnitPrice) AS AveragePrice, 
       SUM(ol.UnitPrice * ol.Quantity) AS TotalSalesAmount
FROM Sales.Orders o
JOIN Sales.OrderLines ol ON o.OrderID = ol.OrderID
GROUP BY YEAR(OrderDate), MONTH(OrderDate)
ORDER BY Year, Month;

-- Query 2: Display all months even with no sales, with total sales greater than 4,600,000
WITH Months AS (
    SELECT YEAR(OrderDate) AS Year, MONTH(OrderDate) AS Month
    FROM Sales.Orders
    GROUP BY YEAR(OrderDate), MONTH(OrderDate)
    UNION
    SELECT DISTINCT YEAR(GETDATE()) AS Year, n AS Month
    FROM (VALUES (1), (2), (3), (4), (5), (6), (7), (8), (9), (10), (11), (12)) AS t(n)
)
SELECT m.Year, m.Month, ISNULL(SUM(ol.UnitPrice * ol.Quantity), 0) AS TotalSalesAmount
FROM Months m
LEFT JOIN Sales.Orders o ON YEAR(o.OrderDate) = m.Year AND MONTH(o.OrderDate) = m.Month
LEFT JOIN Sales.OrderLines ol ON o.OrderID = ol.OrderID
GROUP BY m.Year, m.Month
HAVING ISNULL(SUM(ol.UnitPrice * ol.Quantity), 0) > 4600000
ORDER BY m.Year, m.Month;

-- Query 3: Sales amount, first sale date, and quantity sold per month, per product, where sales are less than 50 units per month
SELECT YEAR(OrderDate) AS Year, MONTH(OrderDate) AS Month, si.StockItemName, 
       SUM(ol.UnitPrice * ol.Quantity) AS TotalSalesAmount, 
       MIN(OrderDate) AS FirstSaleDate, 
       SUM(ol.Quantity) AS TotalQuantitySold
FROM Sales.Orders o
JOIN Sales.OrderLines ol ON o.OrderID = ol.OrderID
JOIN Warehouse.StockItems si ON ol.StockItemID = si.StockItemID
GROUP BY YEAR(OrderDate), MONTH(OrderDate), si.StockItemName
HAVING SUM(ol.Quantity) < 50
ORDER BY Year, Month, si.StockItemName;