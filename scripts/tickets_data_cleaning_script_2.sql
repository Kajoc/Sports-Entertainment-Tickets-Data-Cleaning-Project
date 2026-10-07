-- Date data cleaning, date column has multiple formarts so i have to standardize them to one format.
-- Add new columns with the correct data types. It's safer to populate new columns rather than overwriting existing raw data immediately.
-- Just figured out i don't have to call the schema name in my queries if i have the schema selected on my left pane navigator.
ALTER TABLE sports_tickets_raw_backup
ADD COLUMN event_date_clean DATE,
ADD COLUMN purchase_date_clean DATE;

-- Standardize event date column as it had numerous wromg formats
UPDATE sports_tickets_raw_backup
SET event_date_clean = CASE
    -- 1. Contains Letters (e.g., '12 Dec 2023')
    WHEN event_date REGEXP '[A-Za-z]' THEN 
        STR_TO_DATE(event_date, '%d %b %Y')
        
    -- 2. Contains Slashes
    WHEN event_date LIKE '%/%' THEN 
        CASE 
            -- Year first: '2024/07/30'
            WHEN LENGTH(SUBSTRING_INDEX(event_date, '/', 1)) = 4 THEN STR_TO_DATE(event_date, '%Y/%m/%d')
            
            -- US Format: '04/25/2022' (Middle number is > 12, so it must be the day)
            WHEN CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(event_date, '/', -2), '/', 1) AS UNSIGNED) > 12 THEN STR_TO_DATE(event_date, '%m/%d/%Y')
            
            -- European Format: '25/04/2022' (Fallback)
            ELSE STR_TO_DATE(event_date, '%d/%m/%Y') 
        END
        
    -- 3. Contains Dashes
    WHEN event_date LIKE '%-%' THEN
        CASE 
            -- Year first: '2024-07-30'
            WHEN LENGTH(SUBSTRING_INDEX(event_date, '-', 1)) = 4 THEN STR_TO_DATE(event_date, '%Y-%m-%d')
            
            -- US Format: '04-25-2022'
            WHEN CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(event_date, '-', -2), '-', 1) AS UNSIGNED) > 12 THEN STR_TO_DATE(event_date, '%m-%d-%Y')
            
            -- European Format: '25-04-2022' (Fallback)
            ELSE STR_TO_DATE(event_date, '%d-%m-%Y')
        END
        
    ELSE NULL
END;

-- apply same logic to purchase date colums
UPDATE sports_tickets_raw_backup
SET purchase_date_clean = CASE
    WHEN purchase_date REGEXP '[A-Za-z]' THEN STR_TO_DATE(purchase_date, '%d %b %Y')
    WHEN purchase_date LIKE '%/%' THEN 
        CASE 
            WHEN LENGTH(SUBSTRING_INDEX(purchase_date, '/', 1)) = 4 THEN STR_TO_DATE(purchase_date, '%Y/%m/%d')
            WHEN CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(purchase_date, '/', -2), '/', 1) AS UNSIGNED) > 12 THEN STR_TO_DATE(purchase_date, '%m/%d/%Y')
            ELSE STR_TO_DATE(purchase_date, '%d/%m/%Y') 
        END
    WHEN purchase_date LIKE '%-%' THEN
        CASE 
            WHEN LENGTH(SUBSTRING_INDEX(purchase_date, '-', 1)) = 4 THEN STR_TO_DATE(purchase_date, '%Y-%m-%d')
            WHEN CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(purchase_date, '-', -2), '-', 1) AS UNSIGNED) > 12 THEN STR_TO_DATE(purchase_date, '%m-%d-%Y')
            ELSE STR_TO_DATE(purchase_date, '%d-%m-%Y')
        END
    ELSE NULL
END;

-- Drop old and redundant date columns.
ALTER TABLE sports_tickets_raw_backup
DROP COLUMN event_date,
DROP COLUMN purchase_date;

-- Rename final clean columns
ALTER TABLE sports_tickets_raw_backup
CHANGE COLUMN event_date_clean event_date DATE,
CHANGE COLUMN purchase_date_clean purchase_date DATE;

RENAME TABLE sports_tickets_raw_backup TO sports_Entertainment_tickets_clean;