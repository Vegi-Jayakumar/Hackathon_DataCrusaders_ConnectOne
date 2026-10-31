Hackathon: Codegnan · Problem ID: DA-05 · Team: Data Crusaders · Industry: Telecom

Team members: Jayakumar Vegi, Shankar, Satyaveni, Aruna

Repository: https://github.com/Vegi-Jayakumar/Hackathon_DataCrusaders_ConnectOne

1. Problem Statement
ConnectOne is a regional telecom operator with 8 lakh prepaid and postpaid subscribers in Andhra Pradesh and Telangana. Every month thousands of subscribers move to other networks, and the company is not sure which plans or areas are losing the most customers.

Network complaints are rising in some towns, and many subscribers are on plans that are not profitable. Leadership wants to understand churn, usage and plan performance before revising plans and network investments.

2. Objectives
Measure churn by plan, area and subscriber type
Find the usage and complaint patterns seen before subscribers leave
Identify profitable and loss-making plans
Find areas with poor network experience
Turn the findings into a dashboard and retention recommendations
3. Approach
The team's responsibilities follow five stages: Collect Data → Validate → Analyze → Report → Recommend.

Stage	Tools
Data cleaning & EDA	Python (pandas, NumPy, Matplotlib, Seaborn)
SQL analysis	MySQL
Dashboard	Dashboard with filters and KPIs (executive summary view)
Report & presentation	PDF / slides
4. Data
Five source files were collected, cleaned and combined into one analysis table:

File	Key fields
Subscriber.csv	subscriber_id, activation_date, plan_type (Prepaid/Postpaid), plan_name, city, age_group, age
Network.csv	call_drops, avg_data_speed_mbps, tower_area
Status.csv	status (Active/Churned), churn_date, ported_to
Usage.csv	month, data_used_gb, voice_minutes, sms_count, recharge_amount
Complaints.csv	complaint_id, complaint_date, complaint_type, resolution_days
Master table: master_subscribers_clean.csv – one row per subscriber (40,000 rows) combining subscriber, network, status and usage fields, plus derived columns is_churned and tenure_days.

5. Data Cleaning (Python notebook)
Notebook: ConnectOne(cleaning).ipynb

Inspected all five datasets (shape, types, missing values, duplicates)
Removed rows with a missing subscriber_id and exact/duplicate records
Kept structurally blank values for active users (churn_date empty, ported_to = "Not Applicable")
Standardized data types (dates to datetime; plan, city, age group and month as categories; counts as integers)
Ran integrity checks (unique IDs, churn date not before activation date, no negative usage)
Exported cleaned CSVs and a cleaning audit log
6. SQL Operations
The cleaned master table is loaded into a MySQL database named connectone:

subscribers table (primary key subscriber_id) with CHECK constraints on plan_type (Prepaid/Postpaid) and status (Active/Churned)
Indexes on plan/city, status and tower area
complaints table and a vw_subscriber_summary view
The script is re-runnable (drops and recreates objects)
Queries cover monthly churn rate by plan and city, usage drop analysis, ARPU by plan, and areas ranked by call drops and complaints per 1,000 subscribers.

7. Dashboard – "Churn Intelligence"
Executive-summary dashboard with filters and these headline KPIs:

KPI	Value
Overall churn rate	19.9%
High-risk cities	9
Complaints	2,224 (avg. resolution 7.5 days)
Top port-out destination	Airtel (2,062 subscribers)
Visuals: Churn by plan (plan tier × Postpaid/Prepaid, with average line), drivers of churn (correlation with churn outcome), city risk monitor (churn rate by service area – e.g. Vijayawada 22.2%, Siddipet 21.3%) and port-out destinations.

8. Key Insights & Recommendations
Tenure matters most. Longer-tenured subscribers are significantly less likely to churn (correlation about -0.44). → Prioritize retention within the first 90 days.
Network quality shows little direct correlation with churn (call drops, data speed and recharge amount are all close to zero). → Avoid broad infrastructure action based on churn alone.
Complaints. Most churn is attributed to VAS-related complaints. → Focus on improving customer support on that front.
9. Notes & Limitations
Complaints.csv has no subscriber ID or city, so complaints cannot be linked to individual subscribers; complaint figures are overall, not per area or per churned customer.
Usage.csv has no subscriber ID and was linked to subscribers by row position (assumption); it holds one month per subscriber, so month-over-month usage trends are not available.
tenure_days is measured to the churn date for churned subscribers and to the latest date in the data for active ones, which partly explains its negative correlation with churn.
Churn is close to uniform across plan tiers (about 19.6–20.2%) and plan types (19.9% each).
10. How to Run
Clone the repo and place the five raw CSVs in the data folder.
Open the notebook (Google Colab or Jupyter), set DATA_DIR, and run all cells to generate the cleaned data.
In MySQL, run the .sql script, then load master_subscribers_clean.csv into subscribers and complaints_clean.csv into complaints.
Open the dashboard and point it to the cleaned data.
11. Deliverables
SQL file (.sql) with queries and outputs
Python notebook (.ipynb) with cleaning and EDA, plus the cleaned dataset
Dashboard with screenshots / exported PDF
Short report with findings and business recommendations
Presentation (ConnectOne.pdf)
Thank you – Team Data Crusaders
