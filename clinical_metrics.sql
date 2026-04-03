-- =============================================================================
-- Oncology Patient Flow & Care Quality — Core SQL Queries
-- Author: Portfolio Project | Data: Synthea synthetic EMR
-- Purpose: Mirrors queries a clinical analyst would run against Epic Clarity
-- =============================================================================

-- NOTE: These queries are written for DuckDB / SQLite, which you can run
-- locally against the exported CSVs. They mirror Epic Clarity SQL patterns.
-- In a real Epic environment, column names like PAT_ID, HSP_ACCOUNT_ID, etc.
-- would replace the Synthea equivalents used here.

-- =============================================================================
-- QUERY 1: Monthly encounter volume by encounter type
-- Business question: Are encounter volumes trending up or down by care setting?
-- =============================================================================
SELECT
    strftime('%Y-%m', start) AS encounter_month,
    encounterclass,
    COUNT(*)                 AS encounter_count,
    COUNT(DISTINCT patient)  AS unique_patients
FROM encounters
WHERE start >= '2018-01-01'
GROUP BY 1, 2
ORDER BY 1, 2;


-- =============================================================================
-- QUERY 2: Average length of stay by encounter type and year
-- Business question: Is LOS improving over time? Which care settings drive LOS?
-- =============================================================================
SELECT
    strftime('%Y', e.start)            AS enc_year,
    e.encounterclass,
    COUNT(*)                            AS inpatient_encounters,
    ROUND(AVG(
        (julianday(e.stop) - julianday(e.start)) * 24
    ), 1)                               AS avg_los_hours,
    ROUND(AVG(
        julianday(e.stop) - julianday(e.start)
    ), 2)                               AS avg_los_days,
    ROUND(MEDIAN(
        julianday(e.stop) - julianday(e.start)
    ), 2)                               AS median_los_days
FROM encounters e
WHERE
    e.stop > e.start                    -- valid date range
    AND (julianday(e.stop) - julianday(e.start)) >= 1  -- inpatient only
GROUP BY 1, 2
ORDER BY 1, 2;


-- =============================================================================
-- QUERY 3: 30-day readmission rate
-- Business question: What % of inpatients return within 30 days?
--                    This is a CMS quality measure.
-- =============================================================================
WITH inpatient_stays AS (
    SELECT
        patient,
        id                                     AS encounter_id,
        start                                  AS admit_dt,
        stop                                   AS discharge_dt,
        LAG(stop) OVER (
            PARTITION BY patient ORDER BY start
        )                                      AS prev_discharge_dt
    FROM encounters
    WHERE (julianday(stop) - julianday(start)) >= 1
),
flagged AS (
    SELECT
        *,
        CASE
            WHEN prev_discharge_dt IS NOT NULL
             AND julianday(admit_dt) - julianday(prev_discharge_dt) BETWEEN 1 AND 30
            THEN 1 ELSE 0
        END AS is_readmit_30d
    FROM inpatient_stays
)
SELECT
    strftime('%Y', admit_dt)        AS year,
    COUNT(*)                        AS total_discharges,
    SUM(is_readmit_30d)             AS readmissions_30d,
    ROUND(
        100.0 * SUM(is_readmit_30d) / COUNT(*), 1
    )                               AS readmit_rate_pct
FROM flagged
GROUP BY 1
ORDER BY 1;


-- =============================================================================
-- QUERY 4: Top diagnoses in oncology patients
-- Business question: What are the most common oncology diagnoses by patient count?
-- =============================================================================
WITH oncology_patients AS (
    SELECT DISTINCT patient
    FROM conditions
    WHERE LOWER(description) LIKE '%malignant%'
       OR LOWER(description) LIKE '%carcinoma%'
       OR LOWER(description) LIKE '%lymphoma%'
       OR LOWER(description) LIKE '%leukemia%'
       OR LOWER(description) LIKE '%cancer%'
       OR LOWER(description) LIKE '%neoplasm%'
)
SELECT
    c.description                   AS diagnosis,
    c.code                          AS snomed_code,
    COUNT(DISTINCT c.patient)       AS patient_count,
    COUNT(*)                        AS diagnosis_instances,
    ROUND(
        100.0 * COUNT(DISTINCT c.patient) /
        (SELECT COUNT(*) FROM oncology_patients), 1
    )                               AS pct_of_onc_patients
FROM conditions c
INNER JOIN oncology_patients op ON c.patient = op.patient
WHERE LOWER(c.description) LIKE '%malignant%'
   OR LOWER(c.description) LIKE '%carcinoma%'
   OR LOWER(c.description) LIKE '%lymphoma%'
   OR LOWER(c.description) LIKE '%leukemia%'
   OR LOWER(c.description) LIKE '%cancer%'
   OR LOWER(c.description) LIKE '%neoplasm%'
GROUP BY 1, 2
ORDER BY 3 DESC
LIMIT 20;


-- =============================================================================
-- QUERY 5: HbA1c quality metric — diabetes control in oncology patients
-- Business question: What % of oncology patients with diabetes have controlled HbA1c?
-- =============================================================================
WITH oncology_patients AS (
    SELECT DISTINCT patient
    FROM conditions
    WHERE LOWER(description) LIKE '%malignant%'
       OR LOWER(description) LIKE '%carcinoma%'
       OR LOWER(description) LIKE '%cancer%'
),
latest_hba1c AS (
    SELECT
        patient,
        MAX(date)                           AS last_test_date,
        CAST(value AS FLOAT)                AS hba1c_value
    FROM observations
    WHERE code = '4548-4'
       OR LOWER(description) LIKE '%hemoglobin a1c%'
    GROUP BY patient, value
    QUALIFY ROW_NUMBER() OVER (PARTITION BY patient ORDER BY date DESC) = 1
)
SELECT
    CASE
        WHEN h.hba1c_value < 7   THEN 'Controlled (<7%)'
        WHEN h.hba1c_value < 9   THEN 'At risk (7–9%)'
        WHEN h.hba1c_value >= 9  THEN 'Poor control (≥9%)'
        ELSE 'Unknown'
    END                                     AS control_status,
    COUNT(*)                                AS patient_count,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1
    )                                       AS pct_of_tested
FROM latest_hba1c h
INNER JOIN oncology_patients op ON h.patient = op.patient
GROUP BY 1
ORDER BY 2 DESC;


-- =============================================================================
-- QUERY 6: Patient demographics summary for oncology cohort
-- Business question: What is the demographic profile of our oncology patients?
-- =============================================================================
WITH oncology_patients AS (
    SELECT DISTINCT patient
    FROM conditions
    WHERE LOWER(description) LIKE '%malignant%'
       OR LOWER(description) LIKE '%carcinoma%'
       OR LOWER(description) LIKE '%cancer%'
)
SELECT
    p.gender,
    p.race,
    p.ethnicity,
    COUNT(*)                            AS patient_count,
    ROUND(AVG(
        (julianday('now') - julianday(p.birthdate)) / 365.25
    ), 1)                               AS avg_age,
    ROUND(MEDIAN(
        (julianday('now') - julianday(p.birthdate)) / 365.25
    ), 1)                               AS median_age,
    ROUND(
        100.0 * SUM(CASE WHEN p.deathdate IS NOT NULL THEN 1 ELSE 0 END)
        / COUNT(*), 1
    )                                   AS pct_deceased
FROM patients p
INNER JOIN oncology_patients op ON p.id = op.patient
GROUP BY 1, 2, 3
ORDER BY 4 DESC;
