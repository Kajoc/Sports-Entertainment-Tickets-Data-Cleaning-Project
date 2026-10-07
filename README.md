# Sports Entertainment Tickets Data Cleaning Project

A MySQL data cleaning project that transforms a raw, messy ticketing dataset into an analysis-ready table with consistent types, resolved duplicates, and standardized dates.

The dataset simulates ticket sales across sports and entertainment events — covering orders, customers, venues, pricing, payment, attendance, and post-event feedback.

---

## 📁 Repository Structure

```
.
├── data/
│   ├── sports_entertainment_tickets.csv
│   └── sports_entertainment_tickets_clean.csv
├── scripts/
│   ├── tickets_data_cleaning_script.sql
│   └── tickets_data_cleaning_script_2.sql
└── README.md
```

---

## 🎯 Project Overview

**Problem.** The raw ticket data arrived with mixed date formats, duplicate rows, inconsistent placeholder values, and string types on numeric columns — none of which are safe to analyze directly.

**Approach.** Stage the source into a working table rather than mutating it in place, deduplicate on the ticket identifier, normalize missing values, and convert free-text dates using a format-detection routine. The original source table stays intact as a reference throughout.

**Result.** A single clean table — **one row per ticket** — with typed date columns and consistent NULL handling across all text fields.

---

## 📊 Dataset

| Attribute | Value |
|---|---|
| Source table | [`sports_entertainment_tickets`](./data/sports_entertainment_tickets.csv) |
| Cleaned table | [`sports_entertainment_tickets_clean`](./data/sports_entertainment_tickets_clean.csv) |
| Raw rows | 51,714 |
| Cleaned rows | 51,000 |
| Duplicates removed | 714 |
| Unique key | `ticket_id` |
| Columns | 34 |

**Column groups:**

- **Identifiers** — `event_id`, `ticket_id`, `order_id`, `customer_id`
- **Customer** — `customer_name`, `customer_email`
- **Event** — `sport`, `event_type`, `event_name`, `venue_name`, `venue_city`, `event_date`, `event_time`
- **Seating** — `section`, `row`, `seat_number`, `ticket_type`
- **Pricing** — `face_value_eur`, `service_fee_eur`, `total_price_eur`, `discount_applied_eur`, `final_price_eur`
- **Payment** — `payment_method`, `payment_status`, `purchase_date`
- **Attendance** — `ticket_scanned`, `attendance_status`
- **Spend** — `merchandise_amount_eur`, `food_beverage_amount_eur`, `total_spend_eur`
- **Feedback** — `customer_satisfaction_score`, `nps_score`, `complaint_filed`, `notes`

---

## 🧹 Cleaning Steps

The full cleaning logic is split across two scripts, available in the `scripts/` folder:

| Script | Purpose |
|---|---|
| [**tickets_data_cleaning_script.sql**](./scripts/tickets_data_cleaning_script.sql) | Staging table, deduplication, placeholder normalization |
| [**tickets_data_cleaning_script_2.sql**](./scripts/tickets_data_cleaning_script_2.sql) | Date standardization and final rename |

---

### Step 1 — Staging table with correct datatypes

The raw data was loaded into a dedicated working table (`sports_tickets_raw`) rather than modified in place. Numeric and date fields were declared with explicit types up front to avoid implicit coercion later in the pipeline. The original source table was left untouched.

**Result:** 51,714 rows staged with declared column types.

---

### Step 2 — Duplicate detection and removal

`ticket_id` was identified as the unique identifier for the dataset. Duplicates were confirmed with a grouped count (707 duplicate groups), then collapsed using a `SELECT DISTINCT *` into a new table. Row counts were verified before the deduplicated table replaced the staging table.

**Result:** 51,714 → 51,000 rows; **714 duplicate rows removed**.

---

### Step 3 — Placeholder and missing value cleanup

Free-text placeholder values (`''` and `'-'`) were converted to `NULL` so missingness is represented consistently across the dataset. The boolean-like `complaint_filed` column was standardized to a normalized `True` / `False` / `NULL` representation.

**Columns treated:**

| Column | Rule applied |
|---|---|
| `discount_applied_eur` | Placeholder → `0` (value column; absent discount = 0) |
| `ticket_scanned` | Placeholder → `NULL` |
| `customer_satisfaction_score` | Empty string → `NULL` |
| `nps_score` | Empty string → `NULL` |
| `notes` | Placeholder → `NULL` |
| `complaint_filed` | Normalized to `True` / `False` / `NULL` |

---

### Step 4 — Backup snapshot

A snapshot of the working table was taken before date conversion so the pre-conversion state would be recoverable if any parse step misbehaved. This backup later became the base for Script 2.

**Result:** `sports_tickets_raw_backup` created with 51,000 rows.

---

### Step 5 — Date standardization

Two columns — `event_date` and `purchase_date` — arrived as free text in **six different formats**. Rather than overwriting the raw strings immediately, two new `DATE` columns were added and populated via a format-detection routine. The raw strings were only dropped after the new columns were verified.

**Supported input formats:**

| Pattern | Example |
|---|---|
| `DD Mon YYYY` | `12 Dec 2023` |
| `YYYY/MM/DD` | `2024/07/30` |
| `MM/DD/YYYY` | `04/25/2022` |
| `DD/MM/YYYY` | `25/04/2022` |
| `YYYY-MM-DD` | `2024-07-30` |
| `MM-DD-YYYY` | `04-25-2022` |
| `DD-MM-YYYY` | `25-04-2022` |

**Disambiguation rule.** For slash- and dash-separated dates, if the middle token is greater than 12 it must be the day, so the string is treated as US format. Otherwise it falls back to European (`DD/MM/YYYY`).

**Result:** Both columns converted to proper `DATE` type.

---

### Step 6 — Drop raw date columns and rename

Once the new `DATE` columns were populated and verified, the raw string columns were dropped and the clean columns were renamed to their final names.

**Result:** `event_date` and `purchase_date` exist as `DATE` in the final table, with no leftover string columns.

---

## ✅ Final Table

After cleaning, the working table was renamed to serve as the project deliverable:

```sql
RENAME TABLE sports_tickets_raw_backup 
TO sports_entertainment_tickets_clean;
```

| Attribute | Value |
|---|---|
| Table name | [`sports_entertainment_tickets_clean`](./data/sports_entertainment_tickets_clean.csv) |
| Rows | 51,000 |
| Grain | One row per `ticket_id` |
| `event_date` | `DATE` |
| `purchase_date` | `DATE` |
| `discount_applied_eur` | `DECIMAL(10,2)` |
| Missing values | `NULL` for text; `0` for absent discount |
| Source table | [`sports_entertainment_tickets`](./data/sports_entertainment_tickets.csv) (untouched) |

---

## 🛠 Tools

- **MySQL 8.0** — all cleaning logic
- **MySQL Workbench** — development and execution environment

---

## 📝 Notes & Assumptions

- **`ticket_id` is the unique identifier.** Deduplication assumes rows sharing a `ticket_id` are fully identical; this was verified against the source before applying the distinct operation.
- **Ambiguous dates resolve as European.** For inputs like `04/05/2022`, the fallback branch treats them as `DD/MM/YYYY`. This is a deliberate assumption for mixed-locale data and is the standard heuristic.
- **Month-name parsing is limited to `DD Mon YYYY`.** Inputs such as `12-Dec-2023` or `Dec 12 2023` are not covered by the current format-detection routine.
- **Source table is preserved.** `sports_entertainment_tickets` is never modified, so any downstream questions can always be traced back to the raw data.
- **All cleaning is additive until verified.** New columns were populated before old ones were dropped, and a snapshot was taken before date conversion.

---

## 📈 Summary

| Stage | Input | Output |
|---|---|---|
| Staging | [`sports_entertainment_tickets`](./data/sports_entertainment_tickets.csv) | `sports_tickets_raw` (51,714 rows) |
| Deduplication | 51,714 rows | 51,000 rows |
| Placeholder cleanup | Mixed `''` / `'-'` | Consistent `NULL` / `0` |
| Date conversion | 6 free-text formats | `DATE` type |
| **Deliverable** | — | [**`sports_entertainment_tickets_clean`**](./data/sports_entertainment_tickets_clean.csv) |

The pipeline stages rather than mutates, deduplicates on a declared key, normalizes missing values explicitly, and converts messy dates through a readable format-detection routine — all while keeping the original source intact. The result is a table that can be queried, aggregated, and joined without any further type coercion or cleanup.
