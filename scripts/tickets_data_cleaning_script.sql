-- Create new table to hold variables with correct datatype that will allow me analyze properly
CREATE TABLE tickets_project.sports_tickets_raw (
    event_id VARCHAR(20),
    ticket_id VARCHAR(20),
    order_id VARCHAR(20),
    customer_id VARCHAR(20),
    customer_name VARCHAR(100),
    customer_email VARCHAR(100),
    sport VARCHAR(50),
    event_type VARCHAR(50),
    event_name VARCHAR(100),
    venue_name VARCHAR(100),
    venue_city VARCHAR(50),
    event_date VARCHAR(20),
    event_time VARCHAR(10),
    section VARCHAR(50),
    `row` VARCHAR(10),
    seat_number INT,
    ticket_type VARCHAR(50),
    face_value_eur DECIMAL(10,2),
    service_fee_eur DECIMAL(10,2),
    total_price_eur DECIMAL(10,2),
    discount_applied_eur VARCHAR(10),
    final_price_eur DECIMAL(10,2),
    payment_method VARCHAR(50),
    payment_status VARCHAR(50),
    purchase_date VARCHAR(20),
    ticket_scanned VARCHAR(10),
    attendance_status VARCHAR(50),
    merchandise_amount_eur DECIMAL(10,2),
    food_beverage_amount_eur DECIMAL(10,2),
    total_spend_eur DECIMAL(10,2),
    customer_satisfaction_score VARCHAR(10),
    nps_score VARCHAR(10),
    complaint_filed VARCHAR(10),
    notes VARCHAR(255)
    );
    
    -- Populate new sports_ticket_raw table from the already-loaded source table
INSERT INTO tickets_project.sports_tickets_raw (
    event_id, ticket_id, order_id, customer_id, customer_name, customer_email,
    sport, event_type, event_name, venue_name, venue_city,
    event_date, event_time, section, `row`, seat_number, ticket_type,
    face_value_eur, service_fee_eur, total_price_eur, discount_applied_eur,
    final_price_eur, payment_method, payment_status, purchase_date,
    ticket_scanned, attendance_status,
    merchandise_amount_eur, food_beverage_amount_eur, total_spend_eur,
    customer_satisfaction_score, nps_score, complaint_filed, notes
)
SELECT 
    event_id, ticket_id, order_id, customer_id, customer_name, customer_email,
    sport, event_type, event_name, venue_name, venue_city,
    event_date, event_time, section, `row`, seat_number, ticket_type,
    face_value_eur, service_fee_eur, total_price_eur, discount_applied_eur,
    final_price_eur, payment_method, payment_status, purchase_date,
    ticket_scanned, attendance_status,
    merchandise_amount_eur, food_beverage_amount_eur, total_spend_eur,
    customer_satisfaction_score, nps_score, complaint_filed, notes
FROM tickets_project.sports_entertainment_tickets; 


-- Identify duplicates, ticket_id is theunique identifier in this dataset
SELECT ticket_id, COUNT(*) 
FROM tickets_project.sports_tickets_raw 
GROUP BY ticket_id 
HAVING COUNT(*) > 1;
-- 707 duplicate rows returned


-- Create a table to collapse all duplicate rows into one because they are all identical with other variables. 
CREATE TABLE
tickets_project.sports_tickets_deduped
AS SELECT DISTINCT *
FROM tickets_project.sports_tickets_raw;

-- Check row counts to make sure duplicates have been collapsed(removed)
SELECT count(*) FROM tickets_project.sports_tickets_raw;
-- 51,714 rows returned

SELECT count(*) FROM tickets_project.sports_tickets_deduped;
-- 51,000 rows returned

-- Swap the tables
DROP TABLE tickets_project.sports_tickets_raw;
RENAME TABLE tickets_project.sports_tickets_deduped 
TO tickets_project.sports_tickets_raw;

 -- Clean missing and place holder values
 UPDATE tickets_project.sports_tickets_raw
SET discount_applied_eur = '0'
WHERE discount_applied_eur IN ('-', '');

 UPDATE tickets_project.sports_tickets_raw
SET ticket_scanned = NULL
WHERE ticket_scanned IN ('-', '');

UPDATE tickets_project.sports_tickets_raw
SET customer_satisfaction_score = NULL
WHERE customer_satisfaction_score = '';

UPDATE tickets_project.sports_tickets_raw
SET nps_score = NULL
WHERE nps_score = '';

UPDATE tickets_project.sports_tickets_raw
SET notes = NULL
WHERE notes = '' OR notes = '-';


UPDATE tickets_project.sports_tickets_raw
SET complaint_filed = 
    CASE 
        WHEN UPPER(TRIM(CAST(complaint_filed AS CHAR))) IN ('TRUE', '1')  THEN 'True'
        WHEN UPPER(TRIM(CAST(complaint_filed AS CHAR))) IN ('FALSE', '0') THEN 'False'
        ELSE NULL
    END;
    
-- Create new backup table before complex date and time data cleaning incase of of corrupted data.
CREATE TABLE tickets_project.sports_tickets_raw_backup AS SELECT * FROM tickets_project.sports_tickets_raw;

-- Create Clean Columns
-- Add new columns with the correct data types. It's safer to populate new columns rather than overwriting existing raw data immediately.
ALTER TABLE tickets_project.sports_tickets_raw
ADD COLUMN event_date_clean DATE,
ADD COLUMN purchase_date_clean DATE;

-- Standardize event date column as it had numerous wromg formats
UPDATE tickets_project.sports_tickets_raw
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
UPDATE tickets_project.sports_tickets_raw
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
ALTER TABLE tickets_project.sports_tickets_raw
DROP COLUMN event_date,
DROP COLUMN event_time,
DROP COLUMN purchase_date;

-- Rename final clean columns
ALTER TABLE tickets_project.sports_tickets_raw
CHANGE COLUMN event_date_clean event_date DATE,
CHANGE COLUMN purchase_date_clean purchase_date DATE;

select * from tickets_project.sports_tickets_raw;





