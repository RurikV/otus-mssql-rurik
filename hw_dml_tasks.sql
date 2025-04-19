/*
Домашнее задание по курсу MS SQL Server Developer в OTUS.

Занятие "10 - Операторы изменения данных".

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

-- NOT NULL‑поля «без дефолта»
SELECT name, type_name(system_type_id) AS DataType
FROM   sys.columns
WHERE  object_id = OBJECT_ID('Sales.Customers')
  AND  is_nullable = 0
  AND  default_object_id = 0;    -- нет DEFAULT‑constraint

/*
1. Довставлять в базу пять записей используя insert в таблицу Customers или Suppliers 
*/

/*  Берём несколько «служебных» значений, чтобы не всматриваться в справочники */
DECLARE @Today date = '2025‑04‑19';              -- фиксируем дату (удобно потом удалять)
DECLARE @BillTo int   = 1;                       -- Tailspin Toys Head Office
DECLARE @Cat    int   = 1;                       -- CustomerCategoryID = 1 (Retail)
DECLARE @Person int   = 1;                       -- PersonID = 1 (по умолчанию)
DECLARE @DelMtd int   = 3;                       -- DeliveryMethodID = 3  (Road Freight)
DECLARE @City   int   = 35225;                   -- CityID, любой существующий

INSERT INTO Sales.Customers
( CustomerName, BillToCustomerID, CustomerCategoryID,
  PrimaryContactPersonID, DeliveryMethodID,
  DeliveryCityID, PostalCityID,
  AccountOpenedDate, StandardDiscountPercentage,
  IsStatementSent, IsOnCreditHold, PaymentDays,
  PhoneNumber, FaxNumber, WebsiteURL,
  DeliveryAddressLine1, DeliveryPostalCode,
  PostalAddressLine1,  PostalPostalCode,
  LastEditedBy )              -- ← оставляем, NOT NULL
VALUES
('Demo Customer A', @BillTo,@Cat,@Person,@DelMtd,@City,@City,@Today,0.0,0,0,30,
 '+1 (555) 0100','', 'https://alpha.demo',
 '100 Alpha St.','12345','PO Box 100','12345',1),

('Demo Customer B', @BillTo,@Cat,@Person,@DelMtd,@City,@City,@Today,0.0,0,0,30,
 '+1 (555) 0101','', 'https://bravo.demo',
 '101 Bravo Ave.','12345','PO Box 101','12345',1),

('Demo Customer C', @BillTo,@Cat,@Person,@DelMtd,@City,@City,@Today,0.0,0,0,30,
 '+1 (555) 0102','', 'https://charlie.demo',
 '102 Charlie Rd.','12345','PO Box 102','12345',1),

('Demo Customer D', @BillTo,@Cat,@Person,@DelMtd,@City,@City,@Today,0.0,0,0,30,
 '+1 (555) 0103','', 'https://delta.demo',
 '103 Delta Ln.','12345','PO Box 103','12345',1),

('Demo Customer E', @BillTo,@Cat,@Person,@DelMtd,@City,@City,@Today,0.0,0,0,30,
 '+1 (555) 0104','', 'https://echo.demo',
 '104 Echo Blvd.','12345','PO Box 104','12345',1);

/*
2. Удалите одну запись из Customers, которая была вами добавлена
*/

DELETE FROM Sales.Customers
WHERE  CustomerName = N'Demo Customer E';



/*
3. Изменить одну запись, из добавленных через UPDATE
*/

UPDATE Sales.Customers
SET    PhoneNumber  = N'+1 (555)‑000‑9999',
       WebsiteURL   = N'https://demo‑b‑updated.local',
       LastEditedBy = 1         
WHERE  CustomerName = N'Demo Customer B';

/*
4. Написать MERGE, который вставит вставит запись в клиенты, если ее там нет, и изменит если она уже есть
*/

DECLARE @Src TABLE
( CustomerName nvarchar(100) PRIMARY KEY,
  PhoneNumber  nvarchar(50),
  WebsiteURL   nvarchar(256) );

INSERT INTO @Src VALUES
(N'Demo Customer F', N'+1 (555)‑000‑0006', N'https://demo‑f.local'),           -- новой ещё нет
(N'Demo Customer A', N'+1 (555)‑000‑8888', N'https://demo‑a‑updated.local');  -- уже есть

MERGE Sales.Customers AS tgt
USING @Src AS src
      ON tgt.CustomerName = src.CustomerName
/* ---------- обновляем, если найдено ---------- */
WHEN MATCHED THEN
     UPDATE SET tgt.PhoneNumber  = src.PhoneNumber,
                tgt.WebsiteURL   = src.WebsiteURL,
                tgt.LastEditedBy = 1
/* ---------- вставляем, если нет ---------- */
WHEN NOT MATCHED THEN
     INSERT (CustomerName, BillToCustomerID, CustomerCategoryID,
             PrimaryContactPersonID, DeliveryMethodID,
             DeliveryCityID,  PostalCityID,
             AccountOpenedDate, StandardDiscountPercentage,
             IsStatementSent,  IsOnCreditHold,  PaymentDays,
             PhoneNumber, FaxNumber, WebsiteURL,
             DeliveryAddressLine1, DeliveryPostalCode,
             PostalAddressLine1,  PostalPostalCode,
             LastEditedBy)
     VALUES (src.CustomerName,     1, 1,
             1, 3,
             35225, 35225,
             SYSUTCDATETIME(), 0.0,
             0, 0, 14,
             src.PhoneNumber, N'', src.WebsiteURL,
             N'106 Demo St.', N'12345',
             N'PO 106',  N'12345',
             1)
OUTPUT  $action             AS MergeAction,
        Inserted.CustomerID AS AffectedCustomerID,
        Inserted.CustomerName;


/*
5. Напишите запрос, который выгрузит данные через bcp out и загрузить через bulk insert
*/

EXEC sp_configure 'show advanced options', '1'
RECONFIGURE
-- this enables xp_cmdshell
EXEC sp_configure 'xp_cmdshell', '1' 
RECONFIGURE

DECLARE @out varchar(250);
set @out = 'bcp WideWorldImporters.Sales.Customers OUT "D:\customers.txt" -T -c -S ' + @@SERVERNAME;
PRINT @out;
EXEC master..xp_cmdshell @out

DECLARE @in varchar(250);
set @in = 'bcp WideWorldImporters.Sales.Customers IN "D:\customers.txt" -T -c -S ' + @@SERVERNAME;

EXEC master..xp_cmdshell @in;


select * from Sales.Customers