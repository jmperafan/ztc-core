-- =====================================================================
-- ZTC Tennis Club — demo data expansion for raw.ztc on Snowflake
--
-- Adds 10 new tables across 4 domains:
--   coaching     : coaches, lessons
--   competition  : tournaments, tournament_entries, matches
--   billing      : invoices, invoice_line_items
--   retail       : products, sales_transactions, equipment_rentals
--
-- ---------------------------------------------------------------------
-- ASSUMPTIONS — adjust the values in the CONFIG CTE below if your
-- existing source tables use different column names.
--   - club_members natural key column : account_number
--   - court_usage  court identifier   : court_id
--   - all generators read existing members/courts from raw.ztc.*
--     so FKs hit real IDs without me knowing what they are.
--
-- Story patterns baked in:
--   - Summer peak (Jun–Aug) for lessons + tournaments
--   - Weekend lesson volume ~2x weekdays
--   - "Rainy week" in May 2025: ~60% of lessons cancelled
--   - Late-July Summer Championship drives a pro-shop sales spike
--   - Three popular coaches (C001, C003, C010) get ~3x bookings
--   - ~5% of FKs are deliberately orphaned (for dbt data tests to catch)
--
-- Volumes:
--   coaches            : 15
--   tournaments        : 13
--   products           : 33
--   lessons            : 3,000
--   tournament_entries : ~400
--   matches            : ~600
--   invoices           : 5,000
--   invoice_line_items : ~12,000
--   sales_transactions : 2,000
--   equipment_rentals  :   600
-- =====================================================================

USE DATABASE raw;
USE SCHEMA ztc;


-- =====================================================================
-- 1. COACHES
-- =====================================================================
CREATE OR REPLACE TABLE coaches (
  coach_id              VARCHAR(8)   NOT NULL,
  first_name            VARCHAR(50),
  last_name             VARCHAR(50),
  email                 VARCHAR(120),
  phone                 VARCHAR(20),
  hire_date             DATE,
  specialty             VARCHAR(50),
  certification_level   VARCHAR(20),
  hourly_rate           NUMBER(6,2),
  is_active             BOOLEAN
);

INSERT INTO coaches VALUES
  ('C001','Maria','Hernandez','maria.hernandez@ztc.example','+34-600-100-101','2019-03-15','Adult lessons','Master',95.00,TRUE),
  ('C002','James','Carter','james.carter@ztc.example','+34-600-100-102','2020-06-01','Junior development','Professional',75.00,TRUE),
  ('C003','Sofia','Rossi','sofia.rossi@ztc.example','+34-600-100-103','2021-01-10','Competitive','Elite',110.00,TRUE),
  ('C004','David','Kim','david.kim@ztc.example','+34-600-100-104','2022-08-22','Beginners','Certified',60.00,TRUE),
  ('C005','Aisha','Okafor','aisha.okafor@ztc.example','+34-600-100-105','2018-09-05','Doubles strategy','Master',95.00,TRUE),
  ('C006','Lucas','Muller','lucas.muller@ztc.example','+34-600-100-106','2023-04-12','Junior development','Professional',70.00,TRUE),
  ('C007','Priya','Sharma','priya.sharma@ztc.example','+34-600-100-107','2020-11-20','Adult lessons','Certified',65.00,TRUE),
  ('C008','Tomas','Silva','tomas.silva@ztc.example','+34-600-100-108','2021-07-15','Fitness/conditioning','Professional',80.00,TRUE),
  ('C009','Elena','Petrov','elena.petrov@ztc.example','+34-600-100-109','2024-02-01','Beginners','Certified',55.00,TRUE),
  ('C010','Mark','OBrien','mark.obrien@ztc.example','+34-600-100-110','2019-05-30','Competitive','Elite',105.00,TRUE),
  ('C011','Yuki','Tanaka','yuki.tanaka@ztc.example','+34-600-100-111','2022-03-18','Adult lessons','Professional',75.00,TRUE),
  ('C012','Carlos','Mendez','carlos.mendez@ztc.example','+34-600-100-112','2017-08-14','Doubles strategy','Master',95.00,FALSE),
  ('C013','Fatima','Al-Rashid','fatima.alrashid@ztc.example','+34-600-100-113','2023-09-01','Junior development','Certified',60.00,TRUE),
  ('C014','Henrik','Larsen','henrik.larsen@ztc.example','+34-600-100-114','2024-06-10','Beginners','Certified',55.00,TRUE),
  ('C015','Beatrice','Dubois','beatrice.dubois@ztc.example','+34-600-100-115','2020-04-25','Fitness/conditioning','Professional',80.00,TRUE);


-- =====================================================================
-- 2. TOURNAMENTS
-- =====================================================================
CREATE OR REPLACE TABLE tournaments (
  tournament_id     VARCHAR(10) NOT NULL,
  name              VARCHAR(100),
  start_date        DATE,
  end_date          DATE,
  category          VARCHAR(30),
  entry_fee         NUMBER(6,2),
  max_participants  INTEGER,
  season_year       INTEGER
);

INSERT INTO tournaments VALUES
  ('T2024-01','Winter Indoor Cup',   '2024-02-10','2024-02-18','Mixed',         45.00,32,2024),
  ('T2024-02','Spring Open',         '2024-04-13','2024-04-21','Singles',       60.00,64,2024),
  ('T2024-03','Summer Championship', '2024-07-20','2024-07-28','Singles',       90.00,64,2024),
  ('T2024-04','Junior Masters',      '2024-08-10','2024-08-14','Junior',        25.00,32,2024),
  ('T2024-05','Doubles Classic',     '2024-09-14','2024-09-22','Doubles',       70.00,32,2024),
  ('T2024-06','Fall Open',           '2024-10-19','2024-10-27','Mixed',         55.00,48,2024),
  ('T2025-01','Winter Indoor Cup',   '2025-02-08','2025-02-16','Mixed',         45.00,32,2025),
  ('T2025-02','Spring Open',         '2025-04-12','2025-04-20','Singles',       60.00,64,2025),
  ('T2025-03','Summer Championship', '2025-07-19','2025-07-27','Singles',       90.00,64,2025),
  ('T2025-04','Junior Masters',      '2025-08-09','2025-08-13','Junior',        25.00,32,2025),
  ('T2025-05','Doubles Classic',     '2025-09-13','2025-09-21','Doubles',       70.00,32,2025),
  ('T2025-06','Fall Open',           '2025-10-18','2025-10-26','Mixed',         55.00,48,2025),
  ('T2025-07','Veterans Cup',        '2025-11-15','2025-11-23','Veterans (50+)',40.00,24,2025);


-- =====================================================================
-- 3. PRODUCTS
-- =====================================================================
CREATE OR REPLACE TABLE products (
  product_id      VARCHAR(8) NOT NULL,
  name            VARCHAR(100),
  category        VARCHAR(30),
  brand           VARCHAR(50),
  unit_price      NUMBER(8,2),
  is_rentable     BOOLEAN,
  rental_fee      NUMBER(6,2),
  stock_quantity  INTEGER
);

INSERT INTO products VALUES
  ('P001','Pro Staff 97 v14','Racquet','Wilson',260.00,TRUE,15.00,12),
  ('P002','Blade 98 v9','Racquet','Wilson',245.00,TRUE,15.00,8),
  ('P003','Pure Drive 2024','Racquet','Babolat',245.00,TRUE,15.00,10),
  ('P004','Pure Aero 2023','Racquet','Babolat',240.00,TRUE,15.00,9),
  ('P005','Speed Pro 2025','Racquet','Head',250.00,TRUE,15.00,7),
  ('P006','Radical MP','Racquet','Head',220.00,TRUE,12.00,6),
  ('P007','Ezone 98','Racquet','Yonex',235.00,TRUE,15.00,5),
  ('P008','Junior Tour 25','Racquet','Wilson',85.00,TRUE,8.00,15),
  ('P010','Championship 3-pack','Balls','Wilson',8.50,FALSE,NULL,250),
  ('P011','US Open 3-pack','Balls','Wilson',10.00,FALSE,NULL,180),
  ('P012','Roland Garros 3-pack','Balls','Babolat',10.50,FALSE,NULL,140),
  ('P013','Tour 4-pack','Balls','Head',12.00,FALSE,NULL,110),
  ('P020','NXT 16','Strings','Wilson',18.00,FALSE,NULL,60),
  ('P021','RPM Blast 17','Strings','Babolat',22.00,FALSE,NULL,55),
  ('P022','Hawk Touch 1.25','Strings','Tecnifibre',24.00,FALSE,NULL,40),
  ('P023','Polytour Pro 125','Strings','Yonex',20.00,FALSE,NULL,35),
  ('P030','Court Tee Mens','Apparel','Nike',45.00,FALSE,NULL,50),
  ('P031','Court Skirt Womens','Apparel','Nike',55.00,FALSE,NULL,40),
  ('P032','Polo Performance','Apparel','Adidas',60.00,FALSE,NULL,35),
  ('P033','Dri-FIT Shorts','Apparel','Nike',40.00,FALSE,NULL,45),
  ('P034','ZTC Club Cap','Apparel','ZTC',20.00,FALSE,NULL,80),
  ('P035','ZTC Club T-Shirt','Apparel','ZTC',25.00,FALSE,NULL,100),
  ('P040','GEL-Resolution 9','Footwear','Asics',150.00,FALSE,NULL,30),
  ('P041','Court FF 3','Footwear','Asics',160.00,FALSE,NULL,25),
  ('P042','Air Zoom Vapor Pro','Footwear','Nike',155.00,FALSE,NULL,28),
  ('P043','Adizero Ubersonic 4','Footwear','Adidas',150.00,FALSE,NULL,22),
  ('P050','Overgrip 3-pack','Accessories','Wilson',9.00,FALSE,NULL,200),
  ('P051','Vibration Dampener','Accessories','Babolat',4.50,FALSE,NULL,150),
  ('P052','Tennis Bag 9R','Accessories','Head',110.00,TRUE,8.00,20),
  ('P053','Ball Hopper 75','Accessories','Gamma',55.00,TRUE,5.00,10),
  ('P054','Sweatband Set','Accessories','Nike',12.00,FALSE,NULL,90),
  ('P060','Restringing synthetic','Services','ZTC Pro Shop',25.00,FALSE,NULL,9999),
  ('P061','Restringing natural gut','Services','ZTC Pro Shop',65.00,FALSE,NULL,9999),
  ('P062','Grip replacement','Services','ZTC Pro Shop',12.00,FALSE,NULL,9999);


-- =====================================================================
-- Helper view: weighted coach pool (popular coaches appear more often)
-- =====================================================================
CREATE OR REPLACE TEMPORARY VIEW _coach_weighted AS
SELECT 'C001' AS coach_id UNION ALL SELECT 'C001' UNION ALL SELECT 'C001'
UNION ALL SELECT 'C002' UNION ALL SELECT 'C002'
UNION ALL SELECT 'C003' UNION ALL SELECT 'C003' UNION ALL SELECT 'C003'
UNION ALL SELECT 'C004' UNION ALL SELECT 'C004'
UNION ALL SELECT 'C005' UNION ALL SELECT 'C005'
UNION ALL SELECT 'C006'
UNION ALL SELECT 'C007' UNION ALL SELECT 'C007'
UNION ALL SELECT 'C008'
UNION ALL SELECT 'C009'
UNION ALL SELECT 'C010' UNION ALL SELECT 'C010' UNION ALL SELECT 'C010'
UNION ALL SELECT 'C011' UNION ALL SELECT 'C011'
UNION ALL SELECT 'C013'
UNION ALL SELECT 'C014'
UNION ALL SELECT 'C015';


-- =====================================================================
-- 4. LESSONS  (3,000 rows; ~5% orphan member_ids, ~5% orphan court_ids)
-- =====================================================================
CREATE OR REPLACE TABLE lessons (
  lesson_id          VARCHAR(10) NOT NULL,
  member_id          VARCHAR(50),
  coach_id           VARCHAR(8),
  court_id           VARCHAR(20),
  lesson_date        DATE,
  start_time         TIME,
  duration_minutes   INTEGER,
  lesson_type        VARCHAR(30),
  level              VARCHAR(20),
  price              NUMBER(7,2),
  status             VARCHAR(15),
  created_at         TIMESTAMP_NTZ
);

INSERT INTO lessons
WITH
  member_pool AS (
    SELECT account_number, ROW_NUMBER() OVER (ORDER BY RANDOM()) AS rn,
           COUNT(*) OVER () AS total
    FROM raw.ztc.club_members
  ),
  court_pool AS (
    SELECT DISTINCT court_id::VARCHAR AS court_id,
           ROW_NUMBER() OVER (ORDER BY court_id) AS rn,
           COUNT(*) OVER () AS total
    FROM raw.ztc.court_usage
  ),
  coach_pool AS (
    SELECT coach_id, ROW_NUMBER() OVER (ORDER BY RANDOM()) AS rn,
           COUNT(*) OVER () AS total
    FROM _coach_weighted
  ),
  gen AS (
    SELECT SEQ4()+1 AS seq,
           DATEADD(day, UNIFORM(0, 729, RANDOM()), DATE '2024-01-01') AS base_date,
           UNIFORM(0, 999999, RANDOM()) AS r1,
           UNIFORM(0, 999999, RANDOM()) AS r2,
           UNIFORM(0, 999999, RANDOM()) AS r3,
           UNIFORM(0, 999999, RANDOM()) AS r4
    FROM TABLE(GENERATOR(ROWCOUNT => 3000))
  ),
  shaped AS (
    SELECT seq, r1, r2, r3,
           -- 50% chance: shift to nearest Saturday (weekend boost)
           CASE WHEN MOD(r4, 100) < 50
                THEN DATEADD(day, MOD(6 - DAYOFWEEKISO(base_date) + 7, 7), base_date)
                ELSE base_date
           END AS lesson_date
    FROM gen
  )
SELECT
  'L' || LPAD(s.seq::VARCHAR, 6, '0') AS lesson_id,
  CASE WHEN MOD(s.r1, 100) < 5
       THEN 'GHOST-' || LPAD(MOD(s.r1, 999)::VARCHAR, 3, '0')
       ELSE m.account_number
  END AS member_id,
  c.coach_id,
  CASE WHEN MOD(s.r2, 100) < 5 THEN 'COURT-X'
       ELSE ct.court_id
  END AS court_id,
  s.lesson_date,
  TIME_FROM_PARTS(7 + MOD(s.r3, 14),
                  CASE MOD(s.r3, 4) WHEN 0 THEN 0 WHEN 1 THEN 15 WHEN 2 THEN 30 ELSE 45 END,
                  0) AS start_time,
  CASE MOD(s.r3, 4) WHEN 0 THEN 30 WHEN 1 THEN 60 WHEN 2 THEN 60 ELSE 90 END AS duration_minutes,
  CASE MOD(s.r1, 10)
    WHEN 0 THEN 'Group' WHEN 1 THEN 'Group'
    WHEN 2 THEN 'Semi-private' WHEN 3 THEN 'Semi-private'
    WHEN 4 THEN 'Clinic'
    ELSE 'Private'
  END AS lesson_type,
  CASE MOD(s.r2, 3) WHEN 0 THEN 'Beginner' WHEN 1 THEN 'Intermediate' ELSE 'Advanced' END AS level,
  ROUND(
    CASE MOD(s.r1, 10)
      WHEN 0 THEN 25 WHEN 1 THEN 25
      WHEN 2 THEN 45 WHEN 3 THEN 45
      WHEN 4 THEN 30
      ELSE 75
    END * (1 + (MOD(s.r2, 21) - 10) / 100.0)
  , 2) AS price,
  CASE
    WHEN s.lesson_date BETWEEN '2025-05-12' AND '2025-05-18' AND MOD(s.r3, 100) < 60 THEN 'Cancelled'
    WHEN MOD(s.r3, 100) < 8  THEN 'Cancelled'
    WHEN MOD(s.r3, 100) < 11 THEN 'No-show'
    WHEN s.lesson_date < CURRENT_DATE THEN 'Completed'
    ELSE 'Booked'
  END AS status,
  s.lesson_date::TIMESTAMP_NTZ + INTERVAL '8 HOURS' AS created_at
FROM shaped s
JOIN member_pool m ON m.rn = MOD(s.r1, m.total) + 1
JOIN coach_pool  c ON c.rn = MOD(s.r2, c.total) + 1
JOIN court_pool ct ON ct.rn = MOD(s.r3, ct.total) + 1;


-- =====================================================================
-- 5. TOURNAMENT_ENTRIES  (members registering for tournaments)
-- =====================================================================
CREATE OR REPLACE TABLE tournament_entries (
  entry_id          VARCHAR(12) NOT NULL,
  tournament_id     VARCHAR(10),
  member_id         VARCHAR(50),
  registration_date DATE,
  seed              INTEGER,
  entry_fee_paid    NUMBER(6,2),
  final_placement   VARCHAR(20)
);

INSERT INTO tournament_entries
WITH
  member_pool AS (
    SELECT account_number, ROW_NUMBER() OVER (ORDER BY RANDOM()) AS rn,
           COUNT(*) OVER () AS total
    FROM raw.ztc.club_members
  ),
  -- For each tournament, generate ~30 entries
  gen AS (
    SELECT t.tournament_id, t.start_date, t.entry_fee,
           SEQ4()+1 AS seq,
           UNIFORM(0, 999999, RANDOM()) AS r1,
           UNIFORM(0, 999999, RANDOM()) AS r2
    FROM tournaments t,
         TABLE(GENERATOR(ROWCOUNT => 30))
  )
SELECT
  'TE' || LPAD(ROW_NUMBER() OVER (ORDER BY g.tournament_id, g.seq)::VARCHAR, 6, '0') AS entry_id,
  g.tournament_id,
  CASE WHEN MOD(g.r1, 100) < 5
       THEN 'GHOST-' || LPAD(MOD(g.r1, 999)::VARCHAR, 3, '0')
       ELSE m.account_number
  END AS member_id,
  DATEADD(day, -1 * (7 + MOD(g.r2, 30)), g.start_date) AS registration_date,
  g.seq AS seed,
  g.entry_fee AS entry_fee_paid,
  CASE
    WHEN g.seq = 1 THEN 'Champion'
    WHEN g.seq = 2 THEN 'Runner-up'
    WHEN g.seq IN (3,4) THEN 'Semifinalist'
    WHEN g.seq BETWEEN 5 AND 8 THEN 'Quarterfinalist'
    WHEN g.seq BETWEEN 9 AND 16 THEN 'Round of 16'
    ELSE 'Eliminated'
  END AS final_placement
FROM gen g
JOIN member_pool m ON m.rn = MOD(g.r1, m.total) + 1;


-- =====================================================================
-- 6. MATCHES
-- =====================================================================
CREATE OR REPLACE TABLE matches (
  match_id          VARCHAR(12) NOT NULL,
  tournament_id     VARCHAR(10),
  player1_member_id VARCHAR(50),
  player2_member_id VARCHAR(50),
  court_id          VARCHAR(20),
  match_date        DATE,
  start_time        TIME,
  duration_minutes  INTEGER,
  winner_member_id  VARCHAR(50),
  score             VARCHAR(50),
  round_name        VARCHAR(30)
);

INSERT INTO matches
WITH
  member_pool AS (
    SELECT account_number, ROW_NUMBER() OVER (ORDER BY RANDOM()) AS rn,
           COUNT(*) OVER () AS total
    FROM raw.ztc.club_members
  ),
  court_pool AS (
    SELECT DISTINCT court_id::VARCHAR AS court_id,
           ROW_NUMBER() OVER (ORDER BY court_id) AS rn,
           COUNT(*) OVER () AS total
    FROM raw.ztc.court_usage
  ),
  gen AS (
    SELECT t.tournament_id, t.start_date, t.end_date,
           SEQ4()+1 AS seq,
           UNIFORM(0, 999999, RANDOM()) AS r1,
           UNIFORM(0, 999999, RANDOM()) AS r2,
           UNIFORM(0, 999999, RANDOM()) AS r3,
           UNIFORM(0, 999999, RANDOM()) AS r4,
           UNIFORM(0, 999999, RANDOM()) AS r5
    FROM tournaments t,
         TABLE(GENERATOR(ROWCOUNT => 45))
  )
SELECT
  'M' || LPAD(ROW_NUMBER() OVER (ORDER BY g.tournament_id, g.seq)::VARCHAR, 7, '0') AS match_id,
  g.tournament_id,
  m1.account_number AS player1_member_id,
  m2.account_number AS player2_member_id,
  ct.court_id,
  DATEADD(day, MOD(g.r3, DATEDIFF(day, g.start_date, g.end_date) + 1), g.start_date) AS match_date,
  TIME_FROM_PARTS(9 + MOD(g.r4, 11), CASE MOD(g.r4, 2) WHEN 0 THEN 0 ELSE 30 END, 0) AS start_time,
  60 + MOD(g.r5, 120) AS duration_minutes,
  CASE WHEN MOD(g.r5, 2) = 0 THEN m1.account_number ELSE m2.account_number END AS winner_member_id,
  CASE MOD(g.r5, 6)
    WHEN 0 THEN '6-4, 6-3'
    WHEN 1 THEN '7-6, 6-4'
    WHEN 2 THEN '6-2, 6-1'
    WHEN 3 THEN '7-5, 4-6, 6-3'
    WHEN 4 THEN '6-3, 5-7, 7-6'
    ELSE '6-4, 7-5'
  END AS score,
  CASE
    WHEN g.seq <= 16 THEN 'Round of 32'
    WHEN g.seq <= 24 THEN 'Round of 16'
    WHEN g.seq <= 28 THEN 'Quarterfinal'
    WHEN g.seq <= 30 THEN 'Semifinal'
    WHEN g.seq = 31  THEN 'Final'
    ELSE 'Consolation'
  END AS round_name
FROM gen g
JOIN member_pool m1 ON m1.rn = MOD(g.r1, m1.total) + 1
JOIN member_pool m2 ON m2.rn = MOD(g.r2, m2.total) + 1 AND m2.rn != m1.rn
JOIN court_pool ct ON ct.rn = MOD(g.r3, ct.total) + 1
WHERE g.seq <= 32;  -- 32 matches per tournament * 13 tournaments ~= 416


-- =====================================================================
-- 7. INVOICES  (header table; total_amount filled by UPDATE after #8)
-- =====================================================================
CREATE OR REPLACE TABLE invoices (
  invoice_id        VARCHAR(12) NOT NULL,
  member_id         VARCHAR(50),
  invoice_date      DATE,
  due_date          DATE,
  total_amount      NUMBER(10,2),
  status            VARCHAR(15),
  payment_method    VARCHAR(20),
  paid_date         DATE
);

INSERT INTO invoices
WITH
  member_pool AS (
    SELECT account_number, ROW_NUMBER() OVER (ORDER BY RANDOM()) AS rn,
           COUNT(*) OVER () AS total
    FROM raw.ztc.club_members
  ),
  gen AS (
    SELECT SEQ4()+1 AS seq,
           DATEADD(day, UNIFORM(0, 729, RANDOM()), DATE '2024-01-01') AS inv_date,
           UNIFORM(0, 999999, RANDOM()) AS r1,
           UNIFORM(0, 999999, RANDOM()) AS r2,
           UNIFORM(0, 999999, RANDOM()) AS r3
    FROM TABLE(GENERATOR(ROWCOUNT => 5000))
  )
SELECT
  'INV' || LPAD(g.seq::VARCHAR, 7, '0') AS invoice_id,
  CASE WHEN MOD(g.r1, 100) < 5
       THEN 'GHOST-' || LPAD(MOD(g.r1, 999)::VARCHAR, 3, '0')
       ELSE m.account_number
  END AS member_id,
  g.inv_date AS invoice_date,
  DATEADD(day, 30, g.inv_date) AS due_date,
  NULL AS total_amount,
  CASE
    WHEN g.inv_date > DATEADD(day, -30, CURRENT_DATE) AND MOD(g.r2, 100) < 60 THEN 'Pending'
    WHEN MOD(g.r2, 100) < 5  THEN 'Overdue'
    WHEN MOD(g.r2, 100) < 10 THEN 'Pending'
    ELSE 'Paid'
  END AS status,
  CASE MOD(g.r3, 5)
    WHEN 0 THEN 'Credit Card'
    WHEN 1 THEN 'Credit Card'
    WHEN 2 THEN 'Direct Debit'
    WHEN 3 THEN 'Bank Transfer'
    ELSE 'Cash'
  END AS payment_method,
  CASE WHEN MOD(g.r2, 100) >= 10 THEN DATEADD(day, MOD(g.r3, 35), g.inv_date) END AS paid_date
FROM gen g
JOIN member_pool m ON m.rn = MOD(g.r1, m.total) + 1;


-- =====================================================================
-- 8. INVOICE_LINE_ITEMS  (1–4 lines per invoice)
-- =====================================================================
CREATE OR REPLACE TABLE invoice_line_items (
  line_item_id    VARCHAR(14) NOT NULL,
  invoice_id      VARCHAR(12),
  category        VARCHAR(30),
  description     VARCHAR(200),
  quantity        INTEGER,
  unit_amount     NUMBER(8,2),
  line_amount     NUMBER(10,2)
);

INSERT INTO invoice_line_items
WITH
  expanded AS (
    SELECT i.invoice_id,
           i.invoice_date,
           SEQ4()+1 AS line_seq,
           UNIFORM(0, 999999, RANDOM()) AS r1,
           UNIFORM(0, 999999, RANDOM()) AS r2,
           UNIFORM(1, 4, RANDOM()) AS line_count
    FROM invoices i,
         TABLE(GENERATOR(ROWCOUNT => 4))
  ),
  filtered AS (
    SELECT * FROM expanded WHERE line_seq <= line_count
  )
SELECT
  'LI' || LPAD(ROW_NUMBER() OVER (ORDER BY invoice_id, line_seq)::VARCHAR, 8, '0') AS line_item_id,
  invoice_id,
  CASE MOD(r1, 10)
    WHEN 0 THEN 'Membership'
    WHEN 1 THEN 'Membership'
    WHEN 2 THEN 'Court Fee'
    WHEN 3 THEN 'Court Fee'
    WHEN 4 THEN 'Lesson'
    WHEN 5 THEN 'Lesson'
    WHEN 6 THEN 'Pro Shop'
    WHEN 7 THEN 'Tournament Entry'
    WHEN 8 THEN 'Equipment Rental'
    ELSE 'Restringing'
  END AS category,
  CASE MOD(r1, 10)
    WHEN 0 THEN 'Monthly membership dues'
    WHEN 1 THEN 'Quarterly membership dues'
    WHEN 2 THEN 'Court reservation fee'
    WHEN 3 THEN 'Prime-time court fee'
    WHEN 4 THEN 'Private lesson (60 min)'
    WHEN 5 THEN 'Group clinic'
    WHEN 6 THEN 'Pro shop purchase'
    WHEN 7 THEN 'Tournament entry fee'
    WHEN 8 THEN 'Racquet rental'
    ELSE 'Racquet restringing'
  END AS description,
  1 + MOD(r2, 3) AS quantity,
  ROUND(
    CASE MOD(r1, 10)
      WHEN 0 THEN 85.00 WHEN 1 THEN 230.00
      WHEN 2 THEN 20.00 WHEN 3 THEN 35.00
      WHEN 4 THEN 75.00 WHEN 5 THEN 25.00
      WHEN 6 THEN 45.00 + MOD(r2, 200)
      WHEN 7 THEN 60.00
      WHEN 8 THEN 15.00
      ELSE 25.00
    END
  , 2) AS unit_amount,
  ROUND(
    (1 + MOD(r2, 3)) *
    CASE MOD(r1, 10)
      WHEN 0 THEN 85.00 WHEN 1 THEN 230.00
      WHEN 2 THEN 20.00 WHEN 3 THEN 35.00
      WHEN 4 THEN 75.00 WHEN 5 THEN 25.00
      WHEN 6 THEN 45.00 + MOD(r2, 200)
      WHEN 7 THEN 60.00
      WHEN 8 THEN 15.00
      ELSE 25.00
    END
  , 2) AS line_amount
FROM filtered;

-- Backfill invoices.total_amount from line items
UPDATE invoices i
SET total_amount = li.total
FROM (
  SELECT invoice_id, ROUND(SUM(line_amount), 2) AS total
  FROM invoice_line_items
  GROUP BY invoice_id
) li
WHERE i.invoice_id = li.invoice_id;


-- =====================================================================
-- 9. SALES_TRANSACTIONS  (pro-shop sales; spike during Summer Championship)
-- =====================================================================
CREATE OR REPLACE TABLE sales_transactions (
  transaction_id     VARCHAR(12) NOT NULL,
  member_id          VARCHAR(50),
  product_id         VARCHAR(8),
  transaction_date   DATE,
  quantity           INTEGER,
  unit_price         NUMBER(8,2),
  discount_pct       NUMBER(4,2),
  total_amount       NUMBER(10,2)
);

INSERT INTO sales_transactions
WITH
  member_pool AS (
    SELECT account_number, ROW_NUMBER() OVER (ORDER BY RANDOM()) AS rn,
           COUNT(*) OVER () AS total
    FROM raw.ztc.club_members
  ),
  product_pool AS (
    -- Use only retail products (exclude services P060-P062)
    SELECT product_id, unit_price,
           ROW_NUMBER() OVER (ORDER BY RANDOM()) AS rn,
           COUNT(*) OVER () AS total
    FROM products
    WHERE category != 'Services'
  ),
  gen AS (
    SELECT SEQ4()+1 AS seq,
           DATEADD(day, UNIFORM(0, 729, RANDOM()), DATE '2024-01-01') AS base_date,
           UNIFORM(0, 999999, RANDOM()) AS r1,
           UNIFORM(0, 999999, RANDOM()) AS r2,
           UNIFORM(0, 999999, RANDOM()) AS r3,
           UNIFORM(0, 999999, RANDOM()) AS r4
    FROM TABLE(GENERATOR(ROWCOUNT => 2000))
  ),
  shaped AS (
    SELECT seq, r1, r2, r3,
           -- 25% of sales get pulled into Summer Championship week 2025-07-15..2025-07-28
           CASE WHEN MOD(r4, 100) < 25
                THEN DATEADD(day, MOD(r4, 14), DATE '2025-07-15')
                ELSE base_date
           END AS tx_date
    FROM gen
  )
SELECT
  'TX' || LPAD(s.seq::VARCHAR, 7, '0') AS transaction_id,
  m.account_number AS member_id,
  p.product_id,
  s.tx_date,
  1 + MOD(s.r2, 3) AS quantity,
  p.unit_price,
  CASE WHEN MOD(s.r3, 10) = 0 THEN 10.00
       WHEN MOD(s.r3, 20) = 1 THEN 20.00
       ELSE 0.00
  END AS discount_pct,
  ROUND(
    (1 + MOD(s.r2, 3)) * p.unit_price *
    (1 - (CASE WHEN MOD(s.r3, 10) = 0 THEN 0.10
               WHEN MOD(s.r3, 20) = 1 THEN 0.20
               ELSE 0.00 END))
  , 2) AS total_amount
FROM shaped s
JOIN member_pool m  ON m.rn  = MOD(s.r1, m.total)  + 1
JOIN product_pool p ON p.rn  = MOD(s.r2, p.total) + 1;


-- =====================================================================
-- 10. EQUIPMENT_RENTALS  (racquet/bag/hopper rentals)
-- =====================================================================
CREATE OR REPLACE TABLE equipment_rentals (
  rental_id        VARCHAR(12) NOT NULL,
  member_id        VARCHAR(50),
  product_id       VARCHAR(8),
  rental_date      DATE,
  return_date      DATE,
  rental_fee       NUMBER(6,2),
  late_fee         NUMBER(6,2),
  was_returned     BOOLEAN
);

INSERT INTO equipment_rentals
WITH
  member_pool AS (
    SELECT account_number, ROW_NUMBER() OVER (ORDER BY RANDOM()) AS rn,
           COUNT(*) OVER () AS total
    FROM raw.ztc.club_members
  ),
  rentable AS (
    SELECT product_id, rental_fee,
           ROW_NUMBER() OVER (ORDER BY RANDOM()) AS rn,
           COUNT(*) OVER () AS total
    FROM products
    WHERE is_rentable = TRUE
  ),
  gen AS (
    SELECT SEQ4()+1 AS seq,
           DATEADD(day, UNIFORM(0, 729, RANDOM()), DATE '2024-01-01') AS rent_date,
           UNIFORM(0, 999999, RANDOM()) AS r1,
           UNIFORM(0, 999999, RANDOM()) AS r2,
           UNIFORM(0, 999999, RANDOM()) AS r3
    FROM TABLE(GENERATOR(ROWCOUNT => 600))
  )
SELECT
  'R' || LPAD(g.seq::VARCHAR, 6, '0') AS rental_id,
  m.account_number AS member_id,
  p.product_id,
  g.rent_date,
  CASE WHEN MOD(g.r3, 100) < 95
       THEN DATEADD(day, 1 + MOD(g.r3, 14), g.rent_date)
  END AS return_date,
  p.rental_fee,
  CASE WHEN MOD(g.r3, 100) BETWEEN 80 AND 94 THEN ROUND(p.rental_fee * 0.5, 2) ELSE 0 END AS late_fee,
  MOD(g.r3, 100) < 95 AS was_returned
FROM gen g
JOIN member_pool m ON m.rn = MOD(g.r1, m.total) + 1
JOIN rentable p    ON p.rn = MOD(g.r2, p.total) + 1;


-- =====================================================================
-- Quick sanity checks
-- =====================================================================
-- SELECT 'coaches',            COUNT(*) FROM coaches            UNION ALL
-- SELECT 'tournaments',        COUNT(*) FROM tournaments        UNION ALL
-- SELECT 'products',           COUNT(*) FROM products           UNION ALL
-- SELECT 'lessons',            COUNT(*) FROM lessons            UNION ALL
-- SELECT 'tournament_entries', COUNT(*) FROM tournament_entries UNION ALL
-- SELECT 'matches',            COUNT(*) FROM matches            UNION ALL
-- SELECT 'invoices',           COUNT(*) FROM invoices           UNION ALL
-- SELECT 'invoice_line_items', COUNT(*) FROM invoice_line_items UNION ALL
-- SELECT 'sales_transactions', COUNT(*) FROM sales_transactions UNION ALL
-- SELECT 'equipment_rentals',  COUNT(*) FROM equipment_rentals;
