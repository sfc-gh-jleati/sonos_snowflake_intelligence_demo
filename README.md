# Sonos Snowflake Intelligence Demo

A comprehensive demonstration of Snowflake Intelligence capabilities tailored for **Sonos** product analytics. This demo showcases how Snowflake's AI-powered analytics can provide actionable insights into product sales, marketing campaigns, customer behavior, and business performance.

## 🎯 Purpose

This demo is designed for the Sonos Product Team to explore how Snowflake Intelligence can answer critical business questions about:

- **Product Performance**: Which Sonos products (Arc, Beam, Era, Move, Roam, etc.) are selling best?
- **Sales Trends**: How are sales trending over time, by region, and by channel?
- **Marketing Attribution**: Which marketing campaigns and channels drive the most product sales?
- **Customer Insights**: What are customer purchase patterns and ecosystem expansion behaviors?
- **Predictive Analytics**: Forecast future sales and detect anomalies
- **Sentiment Analysis**: Understand customer sentiment from product reviews

## 🏗️ Architecture

The demo includes:

- **Data Layer**: 20 CSV files with realistic Sonos product data (soundbars, smart speakers, portable speakers, subwoofers, amplifiers)
- **Semantic Layer**: 4 semantic views for natural language queries (Sales, Marketing, Finance, HR)
- **Knowledge Base**: 12 PDF documents with product playbooks, marketing plans, and operational policies
- **Search Services**: 4 Cortex Search services for unstructured document retrieval
- **Intelligence Agent**: Multi-tool AI agent that orchestrates across structured and unstructured data
- **Custom Tools**: Web scraping for sentiment analysis, email capabilities, and file sharing

## 🚀 Quickstart

### Prerequisites

- Snowflake account with **Snowflake Intelligence** enabled
- `ACCOUNTADMIN` role access to run the setup script
- Basic familiarity with Snowflake SQL worksheets

### Installation

**Option 1: Run the single setup script (Recommended)**

1. Open a new SQL worksheet in Snowsight
2. Copy and paste the entire contents of `sql/sonos_demo_setup.sql`
3. Run the script (it will take 2-5 minutes to complete)
4. The script will:
   - Create role `SONOS_INTEL_DEMO_ROLE` and warehouse `SONOS_INTEL_WH`
   - Set up Git integration to pull data from this repository
   - Create database `SONOS_AI_DEMO` with schema `APP`
   - Load all dimension and fact tables
   - Create 4 semantic views for Cortex Analyst
   - Parse PDF documents and create 4 Cortex Search services
   - Set up web scraper function with external access integration
   - Create the **Sonos Product Intelligence Agent**

**Option 2: Clone repository and integrate via Git**

```sql
-- After creating the Git integration, Snowflake will automatically pull files
CREATE GIT REPOSITORY SONOS_AI_DEMO_REPO
    API_INTEGRATION = git_api_integration
    ORIGIN = 'https://github.com/sfc-gh-jleati/sonos_snowflake_intelligence_demo.git';
```

### Verification

After setup completes, verify the installation:

```sql
USE ROLE SONOS_INTEL_DEMO_ROLE;
USE DATABASE SONOS_AI_DEMO;
USE SCHEMA APP;

-- Check tables loaded
SHOW TABLES;

-- Check semantic views created
SHOW SEMANTIC VIEWS;

-- Check search services created
SHOW CORTEX SEARCH SERVICES;

-- Check agent created
SHOW AGENTS IN SCHEMA snowflake_intelligence.agents;
```

## 💡 Using the Agent

### Access the Agent

1. Navigate to **Snowflake UI** → **AI & ML** → **Agents**
2. Select **"Sonos Product Intelligence"**
3. Start asking questions!

### Four Demo Questions

#### Q1: Simple Product Analytics (The "What")

**Question:**
```
Over the last 90 days in North America, which Sonos product led in units and revenue? 
Show top 5, with units, revenue, and MoM growth.
```

**What it demonstrates:**
- Natural language to SQL conversion via Cortex Analyst
- Querying the Sales Semantic View
- Time-based filtering (last 90 days)
- Regional filtering (North America)
- Aggregations and rankings
- Month-over-month growth calculations

**Expected output:**
- Table showing top 5 Sonos products by units and revenue
- MoM growth percentages
- Likely leaders: Arc, Era 100, Beam (based on demo data patterns)

---

#### Q2: Marketing Attribution (The "Why Behind the What")

**Question:**
```
For the top product from Q1, what drove the spike? Break it down by marketing channel 
and campaign over the last 8 weeks, and correlate with spend and impressions.
```

**What it demonstrates:**
- Cross-semantic view analysis (Sales + Marketing)
- Campaign attribution to product sales
- Channel performance breakdown
- Correlation analysis between spend/impressions and sales
- Time-series trend identification

**Expected output:**
- Breakdown of marketing channels contributing to top product sales
- Campaign names and their impact
- Spend vs. impressions vs. leads vs. conversions
- Identification of highest-ROI channels (e.g., Paid Search, YouTube)
- Notable campaigns like "Arc Upgrade Promo Q3 2025"

---

#### Q3: Forecasting & Anomaly Detection

**Question:**
```
Forecast the next 4 weeks of units for Sonos Arc and flag any anomalies over the past 12 weeks.
```

**What it demonstrates:**
- Time-series forecasting using Snowflake ML functions
- Anomaly detection capabilities
- Forward-looking predictive analytics
- Identification of unexpected sales spikes or drops

**Implementation notes:**

The agent should use **SNOWFLAKE.ML.FORECAST** or **SNOWFLAKE.CORTEX.FORECAST** if available. If ML functions are unavailable in your account, the agent can fall back to statistical methods:

```sql
-- Example: Manual anomaly detection using z-score
WITH sales_stats AS (
  SELECT 
    DATE_TRUNC('week', date) as week,
    SUM(units) as weekly_units,
    AVG(SUM(units)) OVER (ORDER BY DATE_TRUNC('week', date) 
                          ROWS BETWEEN 11 PRECEDING AND CURRENT ROW) as avg_units,
    STDDEV(SUM(units)) OVER (ORDER BY DATE_TRUNC('week', date) 
                             ROWS BETWEEN 11 PRECEDING AND CURRENT ROW) as stddev_units
  FROM sales_fact s
  JOIN product_dim p ON s.product_key = p.product_key
  WHERE p.product_name = 'Sonos Arc'
    AND date >= DATEADD(week, -12, CURRENT_DATE())
  GROUP BY DATE_TRUNC('week', date)
)
SELECT 
  week,
  weekly_units,
  avg_units,
  CASE 
    WHEN ABS(weekly_units - avg_units) > 2 * stddev_units THEN 'ANOMALY'
    ELSE 'NORMAL'
  END as anomaly_flag
FROM sales_stats
ORDER BY week;
```

**Expected output:**
- Forecast for next 4 weeks of Sonos Arc units
- Flagged anomalies in past 12 weeks (e.g., product launch spikes, promotional periods)
- Confidence intervals if using ML forecasting

---

#### Q4: Sentiment Analysis from Web Reviews

**Question:**
```
Summarize sentiment and top recurring themes from recent Sonos Arc and Move 2 product reviews. 
Use the web scraper tool on tech review sites.
```

**What it demonstrates:**
- Web scraping capability via External Access Integration
- Real-time external data integration
- Sentiment analysis using Cortex LLM functions
- Theme/topic extraction from unstructured text
- Competitive intelligence gathering

**Example URLs to scrape:**

Include 3-4 of these in your prompt:

- **Tech reviews**: `https://www.theverge.com/reviews` (search for Sonos Arc or Move 2)
- **Editorial reviews**: `https://www.cnet.com/reviews/` (search for Sonos)
- **Audio-focused**: `https://www.soundguys.com/reviews/` (search for Sonos Arc)
- **Consumer reviews**: `https://www.consumerreports.org/` (if accessible)

**Implementation flow:**

1. Agent calls `Web_scrape(url)` for each review URL
2. Agent aggregates scraped text content
3. Agent uses Cortex LLM to analyze sentiment (positive/neutral/negative)
4. Agent extracts top themes (sound quality, ease of setup, value, battery life, etc.)
5. Agent provides representative quotes

**Expected output:**
- Overall sentiment score (e.g., "Positive - 85% favorable")
- Top 5-7 recurring themes:
  - Sound Quality (mentioned X times, 95% positive)
  - Setup/Ease of Use (mentioned Y times, 90% positive)
  - Value/Price (mentioned Z times, 70% mixed)
  - Design/Aesthetics (mentioned W times, 92% positive)
- Sample quotes for each theme
- Comparison between Arc (premium soundbar) and Move 2 (portable speaker) sentiment

---

## 📊 Data Model

### Dimension Tables (13)

| Table | Description | Row Count |
|-------|-------------|-----------|
| `product_category_dim` | Product categories (Soundbars, Smart Speakers, etc.) | 6 |
| `product_dim` | Sonos products (Arc, Beam, Era, Move, Roam, Sub, Amp) | 15 |
| `vendor_dim` | Service partners (Stripe, AWS, Shopify, etc.) | 10 |
| `customer_dim` | Customers who purchase Sonos products | 1,000 |
| `account_dim` | Financial account types | 8 |
| `department_dim` | Sonos departments | 10 |
| `region_dim` | Geographic regions (NA, Europe, APAC, LATAM) | 4 |
| `sales_rep_dim` | Sales representatives | 10 |
| `campaign_dim` | Marketing campaigns | 15 |
| `channel_dim` | Marketing channels (Paid Search, YouTube, etc.) | 10 |
| `employee_dim` | Sonos employees | 20 |
| `job_dim` | Job titles and levels | 20 |
| `location_dim` | Office locations | 10 |

### Fact Tables (4)

| Table | Description | Row Count |
|-------|-------------|-----------|
| `sales_fact` | Product sales transactions (2024-2025) | ~20,000 |
| `marketing_campaign_fact` | Campaign performance data | ~2,500 |
| `finance_transactions` | Financial transactions | ~6,800 |
| `hr_employee_fact` | Employee records (quarterly snapshots) | ~160 |

### Customer Journey Tables (3)

| Table | Description | Row Count |
|-------|-------------|-----------|
| `sf_accounts` | Customer accounts and profiles | 1,000 |
| `sf_opportunities` | Sales opportunities and conversions | 5,000 |
| `sf_contacts` | Customer contacts and leads | 10,000 |

### Unstructured Documents (12)

**Finance** (3 PDFs):
- Expense Policy 2024
- Vendor Management Policy
- Financial Report Q3 2024

**HR** (3 PDFs):
- Employee Handbook 2024
- Performance Guidelines
- Department Overview

**Marketing** (3 PDFs):
- Campaign Strategy 2024
- Channel Performance Report
- Marketing Plan 2025

**Sales/Product** (3 PDFs):
- Product Playbook 2024
- Customer Success Stories
- Product Performance Data

## 🛠️ Technical Components

### Semantic Views (4)

1. **SALES_SEMANTIC_VIEW**: Product sales, revenue, units by product/region/time
2. **MARKETING_SEMANTIC_VIEW**: Campaign performance, spend, attribution to sales
3. **FINANCE_SEMANTIC_VIEW**: Financial transactions, revenue, costs
4. **HR_SEMANTIC_VIEW**: Team composition, staffing, organizational metrics

### Cortex Search Services (4)

- **SEARCH_FINANCE_DOCS**: Search financial policies and reports
- **SEARCH_HR_DOCS**: Search employee handbook and HR policies
- **SEARCH_MARKETING_DOCS**: Search campaign strategies and plans
- **SEARCH_SALES_DOCS**: Search product playbooks and success stories

### Custom Tools (3)

- **Web_scraper**: Python UDF to scrape and analyze web content
- **Send_Emails**: Send analytics reports via email
- **Dynamic_Doc_URL_Tool**: Generate presigned URLs for document sharing

### Agent Capabilities

The **Sonos Product Intelligence Agent** can:

- ✅ Query structured data across Sales, Marketing, Finance, and HR
- ✅ Search unstructured documents for policies and insights
- ✅ Scrape and analyze external web content (reviews, news)
- ✅ Generate forecasts and detect anomalies using ML functions
- ✅ Create visualizations (line charts, bar charts)
- ✅ Provide multi-tool orchestration for complex queries
- ✅ Share documents via presigned URLs
- ✅ Send email reports

## 🔧 Troubleshooting

### Issue: "No agents available" or "Agent not found"

**Solution:**
- Verify you're using the correct role: `USE ROLE SONOS_INTEL_DEMO_ROLE;`
- Check if agent was created: `SHOW AGENTS IN SCHEMA snowflake_intelligence.agents;`
- Ensure you have proper grants:
  ```sql
  GRANT USAGE ON DATABASE snowflake_intelligence TO ROLE SONOS_INTEL_DEMO_ROLE;
  GRANT USAGE ON SCHEMA snowflake_intelligence.agents TO ROLE SONOS_INTEL_DEMO_ROLE;
  ```

### Issue: ML function names differ (SNOWFLAKE.ML.* vs SNOWFLAKE.CORTEX.*)

**Solution:**

Snowflake's ML function naming has evolved. The demo is designed to be flexible:

- **Preferred**: `SNOWFLAKE.ML.FORECAST` and `SNOWFLAKE.ML.ANOMALY_DETECTION`
- **Alternative**: `SNOWFLAKE.CORTEX.FORECAST` (if available in your account)
- **Fallback**: The agent can use statistical methods (z-score for anomalies, moving averages for trends) if ML functions are unavailable

To check what's available in your account:

```sql
SHOW FUNCTIONS LIKE '%FORECAST%';
SHOW FUNCTIONS LIKE '%ANOMALY%';
```

### Issue: Web scraper returns errors or timeouts

**Solution:**
- Verify External Access Integration is enabled: `SHOW INTEGRATIONS LIKE 'SONOS_INTEL_EAI';`
- Check network rule allows web access: `SHOW NETWORK RULES;`
- Some websites block scrapers - use editorial/review sites with accessible HTML
- Try URLs without JavaScript-heavy single-page apps
- Respect robots.txt and website terms of service

### Issue: Data loads but row counts are zero

**Solution:**
- Verify Git repository fetch completed: `ALTER GIT REPOSITORY SONOS_AI_DEMO_REPO FETCH;`
- Check files copied to internal stage: `LS @INTERNAL_DATA_STAGE;`
- Refresh stage directory: `ALTER STAGE INTERNAL_DATA_STAGE REFRESH;`
- Re-run COPY INTO commands with `ON_ERROR = 'CONTINUE'`

### Issue: Cortex Search services not returning results

**Solution:**
- Verify PDFs were parsed: `SELECT COUNT(*) FROM parsed_content;`
- Check search service status: `SHOW CORTEX SEARCH SERVICES;`
- Refresh search services if needed (they auto-refresh based on `TARGET_LAG = '30 day'`)
- Ensure `EMBEDDING_MODEL = 'snowflake-arctic-embed-l-v2.0'` is available in your region

## 📁 Repository Structure

```
sonos_snowflake_intelligence_demo/
├── README.md (this file)
├── LICENSE
├── demo_data/
│   ├── product_category_dim.csv
│   ├── product_dim.csv
│   ├── vendor_dim.csv
│   ├── customer_dim.csv
│   ├── account_dim.csv
│   ├── department_dim.csv
│   ├── region_dim.csv
│   ├── sales_rep_dim.csv
│   ├── campaign_dim.csv
│   ├── channel_dim.csv
│   ├── employee_dim.csv
│   ├── job_dim.csv
│   ├── location_dim.csv
│   ├── sales_fact.csv (~20K rows)
│   ├── finance_transactions.csv
│   ├── marketing_campaign_fact.csv
│   ├── hr_employee_fact.csv
│   ├── sf_accounts.csv
│   ├── sf_opportunities.csv
│   └── sf_contacts.csv
├── unstructured_docs/
│   ├── finance/
│   │   ├── Expense_Policy_2024.pdf
│   │   ├── Vendor_Management_Policy.pdf
│   │   └── Financial_Report_Q3_2024.pdf
│   ├── hr/
│   │   ├── Employee_Handbook_2024.pdf
│   │   ├── Performance_Guidelines.pdf
│   │   └── Department_Overview.pdf
│   ├── marketing/
│   │   ├── Campaign_Strategy_2024.pdf
│   │   ├── Channel_Performance_Report.pdf
│   │   └── Marketing_Plan_2025.pdf
│   └── sales/
│       ├── Product_Playbook_2024.pdf
│       ├── Customer_Success_Stories.pdf
│       └── Product_Performance_Data.pdf
└── sql/
    └── sonos_demo_setup.sql (complete setup script)
```

## 🎓 Learning Resources

- [Snowflake Cortex Documentation](https://docs.snowflake.com/en/user-guide/snowflake-cortex)
- [Snowflake Intelligence Agents](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-analyst)
- [Semantic Views Guide](https://docs.snowflake.com/en/user-guide/semantic-models)
- [Cortex Search Documentation](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-search)
- [Snowflake ML Functions](https://docs.snowflake.com/en/user-guide/ml-functions)

## 📝 Data Dictionary

### Key Product Names (Sonos Products)

- **Sonos Arc**: Premium soundbar with Dolby Atmos ($899)
- **Sonos Beam (Gen 2)**: Compact soundbar ($499)
- **Sonos Ray**: Entry-level soundbar ($279)
- **Sonos Era 100**: Smart speaker ($249)
- **Sonos Era 300**: Spatial audio speaker ($449)
- **Sonos One (Gen 2)**: Compact smart speaker ($219)
- **Sonos Move 2**: Portable smart speaker ($449)
- **Sonos Roam**: Ultra-portable speaker ($179)
- **Sonos Sub (Gen 3)**: Premium subwoofer ($799)
- **Sonos Sub Mini**: Compact subwoofer ($429)
- **Sonos Amp**: Streaming amplifier ($699)
- **Sonos Port**: Streaming component ($449)

### Key Marketing Campaigns

- **Arc Upgrade Promo Q3 2025**: Premium soundbar promotion
- **Beam Back-to-School**: Targeting students and young professionals
- **Move 2 Summer Launch**: Portable speaker product launch
- **Roam Holiday Bundle**: Holiday gift promotion
- **Era 300 Spatial Showcase**: Spatial audio feature demonstration
- **Black Friday Soundbar Sale**: Seasonal promotion
- **Prime Day Exclusive**: Amazon partnership event

### Key Marketing Channels

- **Paid Search**: Google Search, Shopping campaigns
- **YouTube**: Video advertising, influencer partnerships
- **Retail eCom**: Amazon, Best Buy, Apple online
- **Email**: Customer lifecycle marketing
- **Social Media**: Instagram, Facebook, TikTok
- **Affiliates**: Review sites, cashback programs
- **Display Ads**: Banner advertising
- **Podcast Ads**: Audio advertising
- **Content Marketing**: SEO, blog content
- **Referral Program**: Customer referral incentives

### Geographic Regions

- **North America**: US, Canada, Mexico
- **Europe**: UK, Germany, France, Netherlands, etc.
- **APAC**: Australia, Japan, Singapore, etc.
- **Latin America**: Brazil, Argentina, Chile, etc.

## 🤝 Contributing

This is a demo repository. For issues or suggestions:

1. Open an issue on GitHub
2. Contact the Snowflake team
3. Fork and submit a pull request

## 📄 License

MIT License - see LICENSE file for details

## 🙏 Acknowledgments

Based on the original [Snowflake_AI_DEMO](https://github.com/NickAkincilar/Snowflake_AI_DEMO) by Nick Akincilar, customized for Sonos product analytics use cases.

---

**Ready to explore Sonos product analytics with Snowflake Intelligence?** 

Run `sql/sonos_demo_setup.sql` and start asking questions! 🎵

