-- Step 1: Append all monthly sales tables together

CREATE OR REPLACE TABLE `rfm3030.sales.sales_2025` AS
SELECT * FROM `rfm3030.sales.sales202501`
UNION ALL SELECT * FROM `rfm3030.sales.sales202502`
UNION ALL SELECT * FROM `rfm3030.sales.sales202503`
UNION ALL SELECT * FROM `rfm3030.sales.sales202504`
UNION ALL SELECT * FROM `rfm3030.sales.sales202505`
UNION ALL SELECT * FROM `rfm3030.sales.sales202506`
UNION ALL SELECT * FROM `rfm3030.sales.sales202507`
UNION ALL SELECT * FROM `rfm3030.sales.sales202508`
UNION ALL SELECT * FROM `rfm3030.sales.sales202509`
UNION ALL SELECT * FROM `rfm3030.sales.sales202510`
UNION ALL SELECT * FROM `rfm3030.sales.sales202511`
UNION ALL SELECT * FROM `rfm3030.sales.sales202512`;

-- Step 2: Calculate recency, frequency, monetary r, f, m, ranks
-- Combine views with CTEs

CREATE OR REPLACE VIEW `rfm3030.sales.rfm_metrics`
AS
WITH current_date AS (
  SELECT DATE('2026-05-04') AS analysis_date -- today's date
),
rfm AS (
  SELECT
    CustomerID,
    MAX(OrderDate) AS last_order_date,
    date_diff((SELECT analysis_date FROM current_date), MAX(OrderDate), DAY) AS recency,
    COUNT(*) AS frequency,
    SUM(OrderValue) AS monetary
  FROM `rfm3030.sales.sales_2025`
  GROUP BY CustomerID
)
SELECT
  rfm.*,
  ROW_NUMBER() OVER(ORDER BY recency ASC) AS r_rank,
  ROW_NUMBER() OVER(ORDER BY frequency DESC) AS f_rank,
  ROW_NUMBER() OVER(ORDER BY monetary DESC) AS m_rank
FROM rfm;


-- STEP 3: Assign deciles (10=best, 1=worst)
CREATE OR REPLACE VIEW `rfm3030.sales.rfm_scores`
AS
SELECT 
  *,
  NTILE(10) OVER(ORDER BY r_rank DESC) AS r_score,
  NTILE(10) OVER(ORDER BY f_rank DESC) AS f_score,
  NTILE(10) OVER(ORDER BY m_rank DESC) AS m_score
FROM `rfm3030.sales.rfm_metrics`;

-- Step 4: total_score
CREATE OR REPLACE VIEW `rfm3030.sales.rfm_total_scores`
AS
SELECT
  CustomerID,
  recency,
  frequency,
  monetary,
  r_score,
  f_score,
  m_score,
  (r_score + f_score + m_score) AS rfm_total_score
FROM `rfm3030.sales.rfm_scores`
ORDER BY rfm_total_score DESC;

--Step 5: BI ready RFM segments table
CREATE OR REPLACE TABLE `rfm3030.sales.rfm_segments_final`
AS
SELECT
  CustomerID,
  recency,
  frequency,
  monetary,
  r_score,
  f_score,
  m_score,
  rfm_total_score,
  CASE
    WHEN rfm_total_score >= 28 THEN 'Champions' -- 28-30
    WHEN rfm_total_score >= 24 THEN 'Loyal VIPs'
    WHEN rfm_total_score >= 20 THEN 'Potential Loyalists'
    WHEN rfm_total_score >= 16 THEN 'Promosing'
    WHEN rfm_total_score >= 12 THEN 'Just About Engaged'
    WHEN rfm_total_score >= 8 THEN 'Requires Attention'
    WHEN rfm_total_score >= 4 THEN 'At Risk'
    ELSE 'Lost/Inactive'
  END AS rfm_segment
FROM `rfm3030.sales.rfm_total_scores`
ORDER BY rfm_total_score DESC;