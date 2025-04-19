/*
Домашнее задание по курсу MS SQL Server Developer в OTUS.

Занятие "05 - Операторы CROSS APPLY, PIVOT, UNPIVOT".

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

/*
1. Требуется написать запрос, который в результате своего выполнения 
формирует сводку по количеству покупок в разрезе клиентов и месяцев.
В строках должны быть месяцы (дата начала месяца), в столбцах - клиенты.

Клиентов взять с ID 2-6, это все подразделение Tailspin Toys.
Имя клиента нужно поменять так чтобы осталось только уточнение.
Например, исходное значение "Tailspin Toys (Gasport, NY)" - вы выводите только "Gasport, NY".
Дата должна иметь формат dd.mm.yyyy, например, 25.12.2019.

Пример, как должны выглядеть результаты:
-------------+--------------------+--------------------+-------------+--------------+------------
InvoiceMonth | Peeples Valley, AZ | Medicine Lodge, KS | Gasport, NY | Sylvanite, MT | Jessie, ND
-------------+--------------------+--------------------+-------------+--------------+------------
01.01.2013   |      3             |        1           |      4      |      2        |     2
01.02.2013   |      7             |        3           |      4      |      2        |     1
-------------+--------------------+--------------------+-------------+--------------+------------
*/

;WITH Inv AS (
    SELECT InvoiceMonth = DATEFROMPARTS(YEAR(i.InvoiceDate), MONTH(i.InvoiceDate), 1),
           c.CustomerID,
           CustomerShortName = SUBSTRING(c.CustomerName,
                                         CHARINDEX('(',c.CustomerName)+1,
                                         LEN(c.CustomerName)-CHARINDEX('(',c.CustomerName)-1)
    FROM   Sales.Invoices  i
    JOIN   Sales.Customers c ON c.CustomerID = i.CustomerID
    WHERE  c.CustomerID BETWEEN 2 AND 6 ) ,
Cnt AS (
    SELECT InvoiceMonth, CustomerShortName, Cnt = COUNT(*)
    FROM   Inv
    GROUP  BY InvoiceMonth, CustomerShortName )
SELECT FORMAT(InvoiceMonth,'dd.MM.yyyy') AS InvoiceMonth,
       [Peeples Valley, AZ],
       [Medicine Lodge, KS],
       [Gasport, NY],
       [Sylvanite, MT],
       [Jessie, ND]
FROM   Cnt
PIVOT (SUM(Cnt) FOR CustomerShortName IN (
       [Peeples Valley, AZ], [Medicine Lodge, KS], [Gasport, NY],
       [Sylvanite, MT], [Jessie, ND])) p
ORDER  BY InvoiceMonth;

/*
2. Для всех клиентов с именем, в котором есть "Tailspin Toys"
вывести все адреса, которые есть в таблице, в одной колонке.

Пример результата:
----------------------------+--------------------
CustomerName                | AddressLine
----------------------------+--------------------
Tailspin Toys (Head Office) | Shop 38
Tailspin Toys (Head Office) | 1877 Mittal Road
Tailspin Toys (Head Office) | PO Box 8975
Tailspin Toys (Head Office) | Ribeiroville
----------------------------+--------------------
*/

SELECT c.CustomerName,
       a.AddressLine
FROM   Sales.Customers c
CROSS  APPLY (VALUES (c.DeliveryAddressLine1),
                     (c.DeliveryAddressLine2),
                     (c.PostalAddressLine1),
                     (c.PostalAddressLine2)) a(AddressLine)
WHERE  c.CustomerName LIKE '%Tailspin Toys%'
  AND  a.AddressLine IS NOT NULL
ORDER  BY c.CustomerName, a.AddressLine;


/*
3. В таблице стран (Application.Countries) есть поля с цифровым кодом страны и с буквенным.
Сделайте выборку ИД страны, названия и ее кода так, 
чтобы в поле с кодом был либо цифровой либо буквенный код.

Пример результата:
--------------------------------
CountryId | CountryName | Code
----------+-------------+-------
1         | Afghanistan | AFG
1         | Afghanistan | 4
3         | Albania     | ALB
3         | Albania     | 8
----------+-------------+-------
*/

SELECT CountryID, CountryName, Code
FROM (
      SELECT CountryID, CountryName, Code = IsoAlpha3Code
      FROM   Application.Countries
      UNION ALL
      SELECT CountryID, CountryName, Code = CAST(IsoNumericCode AS varchar(3))
      FROM   Application.Countries ) x
ORDER BY CountryID, Code;

/*
4. Выберите по каждому клиенту два самых дорогих товара, которые он покупал.
В результатах должно быть ид клиета, его название, ид товара, цена, дата покупки.
*/

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
