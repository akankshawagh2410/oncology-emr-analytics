# Oncology Patient Flow & Care Quality Analytics

**Tools:** Python · SQL · Pandas · Matplotlib/Seaborn · Tableau     
**Data:** [Synthea](https://synthetichealth.github.io/synthea/) synthetic EMR (de-identified, HIPAA-safe)                                                                 
**Dashboard Link:** [Oncology Patient Flow Analytics](https://public.tableau.com/shared/JN97PNCY9?:display_count=n&:origin=viz_share_link)                   
**Blog:** 


---

## Project overview

This project transforms raw EMR data into actionable insights for clinical leadership. It covers the full analytics lifecycle: data discovery, cleaning, SQL-based metric development, Python EDA, and Tableau dashboard delivery.

**Key clinical questions answered:**
- How is oncology encounter volume trending over time, by care setting?
- What is the average and median inpatient length of stay (LOS)?
- What is our 30-day readmission rate, and which patient cohorts drive it?
- What are the most prevalent oncology diagnoses in our patient population?
- What percentage of oncology patients with diabetes have controlled HbA1c?

---

## Repository structure

```
oncology-emr-analytics/
├── data/
│   ├── raw/               # Synthea CSVs (gitignored — generate locally)
│   └── processed/         # Clean exports for Tableau
├── notebooks/
│   └── eda_synthea.ipynb   # Main EDA notebook
├── SQL/
│   └── clinical_metrics.sql   # Standalone SQL queries (DuckDB / SQLite)
├── scripts/
│   └── setup_data.py          # Downloads Synthea and generates data
├── figures/                   # Exported charts (auto-generated)
├── requirements.txt
├── Tableau Dashboard/
│   └── Oncology Patient Flow & Care Quality.twbx
│   └── Dashboard.png  
└── README.md
```
---

## Key metrics produced

| Metric | Description | Clinical relevance |
|---|---|---|
| Encounter volume | Monthly count by encounter type | Capacity planning, staffing |
| Length of stay (LOS) | Mean and median days, inpatient | Throughput, cost drivers |
| 30-day readmission rate | % returning within 30 days | CMS quality measure |
| Top diagnoses | Patient count by diagnosis | Program focus, resource allocation |
| HbA1c control rate | % controlled / at-risk / poor | Diabetes quality measure (comorbidity) |

---

## EMR data schema (Synthea → Epic Clarity mapping)

| Synthea table | Epic Clarity equivalent | Key fields used |
|---|---|---|
| `patients.csv` | `PATIENT` / `IDENTITY_ID` | demographics, DOB |
| `encounters.csv` | `PAT_ENC` / `HSP_ACCOUNT` | admit/discharge, encounter type |
| `conditions.csv` | `PROBLEM_LIST` / `DIAGNOSES` | SNOMED codes, descriptions |
| `observations.csv` | `ORDER_RESULTS` | LOINC codes, values |
| `medications.csv` | `ORDER_MED` | medication orders |

---

## SQL environment

Queries in `sql/clinical_metrics.sql` run against the raw CSVs using [DuckDB](https://duckdb.org/):

```bash
pip install duckdb
python -c "
import duckdb
con = duckdb.connect()
con.execute(\"CREATE VIEW encounters AS SELECT * FROM read_csv_auto('data/raw/encounters.csv')\")
con.execute(\"CREATE VIEW conditions AS SELECT * FROM read_csv_auto('data/raw/conditions.csv')\")
# Then paste any query from sql/clinical_metrics.sql
"
```

---
## Live dashboard
View on Tableau Public → [Oncology Patient Flow Analytics](https://public.tableau.com/shared/JN97PNCY9?:display_count=n&:origin=viz_share_link)

## Key findings
1. Encounter volume peaked ~2018–2020 then declined — 
   signals end-of-life attrition or referral pipeline change
2. Hospice median LOS ~25 days vs inpatient ~5.3 days — 
   care setting drives resource utilization
3. 31% 30-day readmission rate exceeds 10–15% benchmark — 
   quality improvement opportunity
4. Lung and breast cancer most prevalent (6 patients each)
5. 95% of oncology patients aged 55+ — consistent with 
   real-world cancer epidemiology

## Tech Stack

Built as a portfolio project demonstrating clinical data analytics skills for oncology program.  
Tools: Python 3.10 · Pandas · Seaborn · DuckDB · Tableau · Git
