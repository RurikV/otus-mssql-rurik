/*
Домашнее задание по курсу MS SQL Server Developer в OTUS.

Занятие "08 - Выборки из XML и JSON полей".

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
Примечания к заданиям 1, 2:
* Если с выгрузкой в файл будут проблемы, то можно сделать просто SELECT c результатом в виде XML. 
* Если у вас в проекте предусмотрен экспорт/импорт в XML, то можете взять свой XML и свои таблицы.
* Если с этим XML вам будет скучно, то можете взять любые открытые данные и импортировать их в таблицы (например, с https://data.gov.ru).
* Пример экспорта/импорта в файл https://docs.microsoft.com/en-us/sql/relational-databases/import-export/examples-of-bulk-import-and-export-of-xml-documents-sql-server
*/


/*
1. В личном кабинете есть файл StockItems.xml.
Это данные из таблицы Warehouse.StockItems.
Преобразовать эти данные в плоскую таблицу с полями, аналогичными Warehouse.StockItems.
Поля: StockItemName, SupplierID, UnitPackageID, OuterPackageID, QuantityPerOuter, TypicalWeightPerUnit, LeadTimeDays, IsChillerStock, TaxRate, UnitPrice 

Загрузить эти данные в таблицу Warehouse.StockItems: 
существующие записи в таблице обновить, отсутствующие добавить (сопоставлять записи по полю StockItemName). 

Сделать два варианта: с помощью OPENXML и через XQuery.
*/

--- 1‑A. Вариант OPENXML ---

/* ─ 1‑A‑1  читаем XML в переменную ─ */
DECLARE @xml xml;
SELECT @xml = BulkColumn
FROM   OPENROWSET(BULK N'/mnt/data/StockItems.xml', SINGLE_BLOB) AS x;

/* ─ 1‑A‑2  временное хранилище ─ */
DROP TABLE IF EXISTS #Stg;
CREATE TABLE #Stg
( StockItemName          nvarchar(100) COLLATE Latin1_General_100_CI_AS PRIMARY KEY,
  SupplierID             int,
  UnitPackageID          int,
  OuterPackageID         int,
  QuantityPerOuter       int,
  TypicalWeightPerUnit   decimal(18,3),
  LeadTimeDays           int,
  IsChillerStock         bit,
  TaxRate                decimal(18,3),
  UnitPrice              decimal(18,6) );

/* ─ 1‑A‑3  распарсим через OPENXML ─ */
DECLARE @h int;
EXEC sp_xml_preparedocument @h OUTPUT, @xml;

INSERT INTO #Stg
SELECT *
FROM   OPENXML(@h, '/StockItems/Item', 2)
       WITH ( StockItemName          nvarchar(100) '@Name',
              SupplierID             int            'SupplierID',
              UnitPackageID          int            'Package/UnitPackageID',
              OuterPackageID         int            'Package/OuterPackageID',
              QuantityPerOuter       int            'Package/QuantityPerOuter',
              TypicalWeightPerUnit   decimal(18,3)  'Package/TypicalWeightPerUnit',
              LeadTimeDays           int            'LeadTimeDays',
              IsChillerStock         bit            'IsChillerStock',
              TaxRate                decimal(18,3)  'TaxRate',
              UnitPrice              decimal(18,6)  'UnitPrice' );

EXEC sp_xml_removedocument @h;

/* ─ 1‑A‑4  MERGE в Warehouse.StockItems ─ */
MERGE Warehouse.StockItems AS tgt
USING #Stg AS src
      ON tgt.StockItemName = src.StockItemName
	   COLLATE Latin1_General_100_CI_AS
WHEN MATCHED THEN
     UPDATE SET SupplierID           = src.SupplierID,
                UnitPackageID        = src.UnitPackageID,
                OuterPackageID       = src.OuterPackageID,
                QuantityPerOuter     = src.QuantityPerOuter,
                TypicalWeightPerUnit = src.TypicalWeightPerUnit,
                LeadTimeDays         = src.LeadTimeDays,
                IsChillerStock       = src.IsChillerStock,
                TaxRate              = src.TaxRate,
                UnitPrice            = src.UnitPrice,
                LastEditedBy         = 1
WHEN NOT MATCHED THEN
     INSERT (StockItemName,SupplierID,UnitPackageID,OuterPackageID,
             QuantityPerOuter,TypicalWeightPerUnit,LeadTimeDays,
             IsChillerStock,TaxRate,UnitPrice,LastEditedBy)
     VALUES (src.StockItemName,src.SupplierID,src.UnitPackageID,src.OuterPackageID,
             src.QuantityPerOuter,src.TypicalWeightPerUnit,src.LeadTimeDays,
             src.IsChillerStock,src.TaxRate,src.UnitPrice,1);

--- 1‑B. Вариант XQuery (nodes() + value()) ---

DECLARE @xml xml;
SELECT @xml = BulkColumn
FROM   OPENROWSET(BULK N'/mnt/data/StockItems.xml', SINGLE_BLOB) AS x;

;WITH x AS (
    SELECT  i.value('@Name','nvarchar(100)')                        AS StockItemName,
            i.value('(SupplierID/text())[1]','int')                 AS SupplierID,
            i.value('(Package/UnitPackageID/text())[1]','int')      AS UnitPackageID,
            i.value('(Package/OuterPackageID/text())[1]','int')     AS OuterPackageID,
            i.value('(Package/QuantityPerOuter/text())[1]','int')   AS QuantityPerOuter,
            i.value('(Package/TypicalWeightPerUnit/text())[1]','decimal(18,3)') AS TypicalWeightPerUnit,
            i.value('(LeadTimeDays/text())[1]','int')               AS LeadTimeDays,
            i.value('(IsChillerStock/text())[1]','bit')             AS IsChillerStock,
            i.value('(TaxRate/text())[1]','decimal(18,3)')          AS TaxRate,
            i.value('(UnitPrice/text())[1]','decimal(18,6)')        AS UnitPrice
    FROM   @xml.nodes('/StockItems/Item') AS t(i)
)
MERGE Warehouse.StockItems AS tgt
USING x AS src
      ON  tgt.StockItemName = src.StockItemName
WHEN MATCHED THEN
     UPDATE SET SupplierID           = src.SupplierID,
                UnitPackageID        = src.UnitPackageID,
                OuterPackageID       = src.OuterPackageID,
                QuantityPerOuter     = src.QuantityPerOuter,
                TypicalWeightPerUnit = src.TypicalWeightPerUnit,
                LeadTimeDays         = src.LeadTimeDays,
                IsChillerStock       = src.IsChillerStock,
                TaxRate              = src.TaxRate,
                UnitPrice            = src.UnitPrice,
                LastEditedBy         = 1
WHEN NOT MATCHED THEN
     INSERT (StockItemName,SupplierID,UnitPackageID,OuterPackageID,
             QuantityPerOuter,TypicalWeightPerUnit,LeadTimeDays,
             IsChillerStock,TaxRate,UnitPrice,LastEditedBy)
     VALUES (src.StockItemName,src.SupplierID,src.UnitPackageID,src.OuterPackageID,
             src.QuantityPerOuter,src.TypicalWeightPerUnit,src.LeadTimeDays,
             src.IsChillerStock,src.TaxRate,src.UnitPrice,1);


/*
2. Выгрузить данные из таблицы StockItems в такой же xml-файл, как StockItems.xml
*/

DECLARE @out xml =
(
    SELECT  'StockItems' as [root] FOR XML PATH('')  -- «обёртка»
);

SELECT @out =
(
    SELECT  'StockItems'   = ''  -- placeholder, заменим ниже
    FOR XML PATH('')
);

SELECT @out =
(
    SELECT  (
        SELECT  si.StockItemName               AS [@Name],
                si.SupplierID,
                ( SELECT  si.UnitPackageID     AS UnitPackageID,
                          si.OuterPackageID    AS OuterPackageID,
                          si.QuantityPerOuter  AS QuantityPerOuter,
                          si.TypicalWeightPerUnit AS TypicalWeightPerUnit
                  FOR XML PATH('Package'), TYPE ),
                si.LeadTimeDays,
                si.IsChillerStock,
                si.TaxRate,
                si.UnitPrice
        FROM   Warehouse.StockItems si
        FOR XML PATH('Item'), TYPE
    )
    FOR XML PATH('StockItems'), TYPE
);

-- записываем в файл (SQLCMD/ADS: :OUT ...)
EXEC sp_writefile '/mnt/data/StockItems_out.xml', @out;

/*
--- просто SELECT c результатом в виде XML ---
 */
SELECT
       si.StockItemName               AS [@Name],          -- атрибут Name
       si.SupplierID,
       ( SELECT si.UnitPackageID      AS UnitPackageID,    -- вложенный <Package>
                si.OuterPackageID     AS OuterPackageID,
                si.QuantityPerOuter   AS QuantityPerOuter,
                si.TypicalWeightPerUnit AS TypicalWeightPerUnit
         FOR XML PATH('Package'), TYPE ),
       si.LeadTimeDays,
       si.IsChillerStock,
       si.TaxRate,
       si.UnitPrice
FROM   Warehouse.StockItems AS si
FOR    XML PATH('Item'), ROOT('StockItems'), TYPE;


/*
3. В таблице Warehouse.StockItems в колонке CustomFields есть данные в JSON.
Написать SELECT для вывода:
- StockItemID
- StockItemName
- CountryOfManufacture (из CustomFields)
- FirstTag (из поля CustomFields, первое значение из массива Tags)
*/

SELECT  StockItemID,
        StockItemName,
        JSON_VALUE(CustomFields,'$.CountryOfManufacture') AS CountryOfManufacture,
        JSON_VALUE(CustomFields,'$.Tags[0]')              AS FirstTag
FROM Warehouse.StockItems;


/*
4. Найти в StockItems строки, где есть тэг "Vintage".
Вывести: 
- StockItemID
- StockItemName
- (опционально) все теги (из CustomFields) через запятую в одном поле

Тэги искать в поле CustomFields, а не в Tags.
Запрос написать через функции работы с JSON.
Для поиска использовать равенство, использовать LIKE запрещено.

Должно быть в таком виде:
... where ... = 'Vintage'

Так принято не будет:
... where ... Tags like '%Vintage%'
... where ... CustomFields like '%Vintage%' 
*/

SELECT  StockItemID,
        StockItemName,
        STRING_AGG(value,',') AS AllTags          -- опционально
FROM Warehouse.StockItems
CROSS APPLY OPENJSON(CustomFields,'$.Tags')          -- каждую строку раскатали в теги
WHERE value = N'Vintage'                            -- строгая проверка, без LIKE
GROUP BY StockItemID, StockItemName;
