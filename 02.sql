-- Query 1: All products with "urgent" in their name or starting with "Animal"
SELECT *
FROM Warehouse.StockItems
WHERE StockItemName LIKE '%urgent%'
   OR StockItemName LIKE 'Animal%';

-- Query 2: Suppliers who have not had any orders (PurchaseOrders)
SELECT s.*
FROM Purchasing.Suppliers s
LEFT JOIN Purchasing.PurchaseOrders po ON s.SupplierID = po.SupplierID
WHERE po.SupplierID IS NULL;

-- Query 3: Orders with UnitPrice > $100 or Quantity > 20 and PickingCompletedWhen is not NULL
SELECT o.*
FROM Sales.Orders o
JOIN Sales.OrderLines ol ON o.OrderID = ol.OrderID
WHERE (ol.UnitPrice > 100 OR ol.Quantity > 20)
  AND o.PickingCompletedWhen IS NOT NULL;

-- Query 4: Supplier orders expected in January 2013 with "Air Freight" or "Refrigerated Air Freight" and finalized
SELECT po.*
FROM Purchasing.PurchaseOrders po
JOIN Application.DeliveryMethods dm ON po.DeliveryMethodID = dm.DeliveryMethodID
WHERE po.ExpectedDeliveryDate >= '2013-01-01'
  AND po.ExpectedDeliveryDate < '2013-02-01'
  AND dm.DeliveryMethodName IN ('Air Freight', 'Refrigerated Air Freight')
  AND po.IsOrderFinalized = 1;

-- Query 5: Last ten sales with customer name and salesperson name
SELECT TOP 10 o.OrderID, c.CustomerName, p.FullName AS Salesperson
FROM Sales.Orders o
JOIN Sales.Customers c ON o.CustomerID = c.CustomerID
JOIN Application.People p ON o.SalespersonPersonID = p.PersonID
ORDER BY o.OrderDate DESC;

-- Query 6: All customer IDs, names, and phone numbers for customers who bought "Chocolate frogs 250g"
SELECT DISTINCT c.CustomerID, c.CustomerName, c.PhoneNumber
FROM Sales.Customers c
JOIN Sales.Orders o ON c.CustomerID = o.CustomerID
JOIN Sales.OrderLines ol ON o.OrderID = ol.OrderID
JOIN Warehouse.StockItems si ON ol.StockItemID = si.StockItemID
WHERE si.StockItemName = 'Chocolate frogs 250g';
