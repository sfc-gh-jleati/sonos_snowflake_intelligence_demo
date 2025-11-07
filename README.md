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
- Time-series forecasting using statistical methods or Snowflake ML
- Anomaly detection with z-score analysis
- Forward-looking predictive analytics
- Identification of promotional spikes and unusual patterns

**Helper Views Available:**

The demo includes pre-built helper views for Arc analysis:
- `arc_daily_sales` - Arc sales by date and region
- `arc_weekly_na_sales` - Arc weekly aggregates for North America

**Alternative Approach - Run the Forecast Example:**

Since Cortex Analyst focuses on historical data, you can run the forecasting SQL directly:

```sql
-- See sql/arc_forecast_example.sql for complete forecasting examples
-- Quick anomaly check:
SELECT 
    date,
    units_sold,
    CASE 
        WHEN (units_sold - AVG(units_sold) OVER (ORDER BY ts ROWS BETWEEN 13 PRECEDING AND 1 PRECEDING)) / 
             NULLIF(STDDEV(units_sold) OVER (ORDER BY ts ROWS BETWEEN 13 PRECEDING AND 1 PRECEDING), 0) > 2 
        THEN '🔴 ANOMALY HIGH'
        ELSE '✅ NORMAL'
    END as flag
FROM arc_daily_sales
WHERE region_name = 'North America'
  AND date >= DATEADD(week, -12, CURRENT_DATE())
ORDER BY date DESC;
```

**Expected output:**
- **Anomalies flagged** on Sept 10, Sept 26, Oct 11, Oct 20 (Arc Upgrade Promo spikes: 40-53 units vs normal 20-30)
- **Forecast baseline**: ~5-7 units/day for next 4 weeks (based on Nov-Dec stable pattern)
- **Story**: Arc Upgrade Promo Q3 2025 drove significant spikes in Sept/Oct, now stabilizing in Nov-Dec
- See `sql/arc_forecast_example.sql` for complete forecasting SQL

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

## 📊 Streamlined Data Model

**Focused on answering the 4 demo questions with relevant Sonos consumer electronics data only.**

### Dimension Tables (5)

| Table | Description | Row Count |
|-------|-------------|-----------|
| `product_category_dim` | Product categories: Soundbars, Smart Speakers, Portable Speakers, Subwoofers, Amplifiers | 6 |
| `product_dim` | Sonos products: Arc, Beam, Ray, Era 100/300, One, Move 2, Roam, Sub, Amp | 15 |
| `region_dim` | Geographic regions: North America, Europe, APAC, Latin America | 4 |
| `campaign_dim` | Marketing campaigns: Arc Upgrade Promo Q3 2025, Beam Back-to-School, Move 2 Launch, etc. | 15 |
| `channel_dim` | Marketing channels: Paid Search, YouTube, Social Media, Retail eCom, Email, Affiliates | 10 |

### Fact Tables (2)

| Table | Description | Row Count | Date Range |
|-------|-------------|-----------|------------|
| `sales_fact` | Sonos product sales by date/product/region | 22,858 | 2024-01-01 → 2025-12-15 |
| `marketing_campaign_fact` | Campaign performance: spend, impressions, leads | 2,662 | 2024-03-01 → 2025-10-31 |

### Helper Views (2)

| View | Description | Purpose |
|------|-------------|---------|
| `arc_daily_sales` | Arc daily sales by region | Q3 - Forecasting & anomaly detection |
| `arc_weekly_na_sales` | Arc weekly North America aggregates | Q3 - Trend analysis |

### Unstructured Documents (6)

**Marketing** (3 PDFs):
- Campaign Strategy 2024 - Annual campaign planning and objectives
- Channel Performance Report - ROI analysis by marketing channel
- Marketing Plan 2025 - Future campaign roadmap

**Product/Sales** (3 PDFs):
- Product Playbook 2024 - Sonos product positioning and features
- Customer Success Stories - Real customer testimonials and use cases
- Product Performance Data - Sales performance by product

## 🛠️ Technical Components

### Semantic Views (2)

1. **SALES_SEMANTIC_VIEW**: Product sales analytics - revenue, units, trends by product/region/time (for Q1 & Q3)
2. **MARKETING_SEMANTIC_VIEW**: Campaign performance - spend, impressions, leads, ROI by campaign/channel (for Q2)

### Cortex Search Services (2)

- **SEARCH_MARKETING_DOCS**: Search campaign strategies, channel performance reports, marketing plans
- **SEARCH_PRODUCT_DOCS**: Search product playbooks, customer success stories, product performance data

### Custom Tools (1)

- **Web_Scraper**: Python UDF to scrape and analyze web content from review sites (for Q4)

### Agent Capabilities

The **Sonos Product Intelligence Agent** can:

- ✅ **Analyze product sales** (Q1) - Top products, revenue, units, growth rates by region and time
- ✅ **Attribute sales to marketing** (Q2) - Track which campaigns and channels drive product sales
- ✅ **Forecast and detect anomalies** (Q3) - Predict future sales, flag unusual patterns using statistical methods
- ✅ **Analyze sentiment** (Q4) - Scrape product reviews from web, extract sentiment and themes
- ✅ **Search product documentation** - Find insights in marketing plans and product playbooks
- ✅ **Create visualizations** - Generate line charts (trends) and bar charts (comparisons)
- ✅ **Multi-tool orchestration** - Combine structured data, documents, and web content

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
├── demo_data/ (7 CSV files - 25,520 total rows)
│   ├── product_category_dim.csv (6 rows)
│   ├── product_dim.csv (15 rows)
│   ├── region_dim.csv (4 rows)
│   ├── campaign_dim.csv (15 rows)
│   ├── channel_dim.csv (10 rows)
│   ├── sales_fact.csv (22,858 rows) ⭐
│   └── marketing_campaign_fact.csv (2,662 rows) ⭐
├── unstructured_docs/
│   ├── marketing/
│   │   ├── Campaign_Strategy_2024.pdf
│   │   ├── Channel_Performance_Report.pdf
│   │   └── Marketing_Plan_2025.pdf
│   └── sales/
│       ├── Product_Playbook_2024.pdf
│       ├── Customer_Success_Stories.pdf
│       └── Product_Performance_Data.pdf
└── sql/
    ├── sonos_demo_setup.sql (streamlined setup script)
    └── arc_forecast_example.sql (forecasting SQL examples)
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

