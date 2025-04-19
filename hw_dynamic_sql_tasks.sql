/*
Домашнее задание по курсу MS SQL Server Developer в OTUS.

Занятие "07 - Динамический SQL".

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

Это задание из занятия "Операторы CROSS APPLY, PIVOT, UNPIVOT."
Нужно для него написать динамический PIVOT, отображающий результаты по всем клиентам.
Имя клиента указывать полностью из поля CustomerName.

Требуется написать запрос, который в результате своего выполнения 
формирует сводку по количеству покупок в разрезе клиентов и месяцев.
В строках должны быть месяцы (дата начала месяца), в столбцах - клиенты.

Дата должна иметь формат dd.mm.yyyy, например, 25.12.2019.

Пример, как должны выглядеть результаты:
-------------+--------------------+--------------------+----------------+----------------------
InvoiceMonth | Aakriti Byrraju    | Abel Spirlea       | Abel Tatarescu | ... (другие клиенты)
-------------+--------------------+--------------------+----------------+----------------------
01.01.2013   |      3             |        1           |      4         | ...
01.02.2013   |      7             |        3           |      4         | ...
-------------+--------------------+--------------------+----------------+----------------------
*/

DECLARE @cols        nvarchar(max),
        @colsIsNull  nvarchar(max),
        @sql         nvarchar(max);

-- list of customers
SELECT
    @cols = STRING_AGG( CAST(QUOTENAME(CustomerName) AS nvarchar(max)), ',' ), 
    @colsIsNull = STRING_AGG(
                     CAST('ISNULL('+QUOTENAME(CustomerName)+',0) AS '+QUOTENAME(CustomerName)
                          AS nvarchar(max)), ', ')
FROM  Sales.Customers;

-- dynamic PIVOT
SET @sql = N'
SELECT month_first_date, '+ @colsIsNull +'
FROM (
    SELECT
        FORMAT(DATEADD(month, DATEDIFF(month,0,i.InvoiceDate),0), ''dd.MM.yyyy'') AS month_first_date,
        c.CustomerName,
        CAST(COUNT(i.InvoiceID) AS smallint) AS cnt
    FROM  Sales.Invoices  i
    JOIN  Sales.Customers c ON c.CustomerID = i.CustomerID
    GROUP BY
        DATEADD(month, DATEDIFF(month,0,i.InvoiceDate),0),
        c.CustomerName
) src
PIVOT (
    MAX(cnt) FOR CustomerName IN ('+ @cols +')
) pvt
ORDER BY DATEFROMPARTS(
            SUBSTRING(month_first_date,7,4),
            SUBSTRING(month_first_date,4,2),
            1);';

EXEC (@sql);
