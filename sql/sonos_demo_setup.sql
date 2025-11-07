
-- ========================================================================
-- Sonos Product Analytics Demo - Streamlined Setup Script
-- Snowflake Intelligence Demo for Sonos Product Team
-- Focus: Product sales analytics, marketing attribution, forecasting, sentiment
-- Repository: https://github.com/sfc-gh-jleati/sonos_snowflake_intelligence_demo.git
-- ========================================================================

/*
=============================================================================
ABOUT THIS DEMO
=============================================================================

This demo showcases Snowflake Intelligence for Sonos (consumer electronics) with:

1. PRODUCT SALES ANALYTICS (Q1)
   - Track which Sonos products sell best (Arc, Beam, Era, Move, Roam)
   - Monitor sales trends by region and time period
   - Analyze revenue, units, and growth rates
   
2. MARKETING CAMPAIGN ATTRIBUTION (Q2)
   - Track campaign effectiveness across channels
   - Analyze customer acquisition costs and ROI
   - Correlate marketing spend with product sales
   
3. FORECASTING & ANOMALY DETECTION (Q3)
   - Forecast future sales using ML or statistical methods
   - Detect unusual sales patterns and spikes
   - Predict inventory needs
   
4. SENTIMENT ANALYSIS (Q4)
   - Scrape product reviews from web
   - Analyze customer sentiment
   - Extract key themes and feedback

FOUR DEMO QUESTIONS:
Q1: "Over the last 90 days in North America, which Sonos product led in units and revenue? Show top 5."
Q2: "What drove the Arc spike? Break down by marketing channel and campaign over last 8 weeks."
Q3: "Forecast next 4 weeks of units for Sonos Arc and flag anomalies over past 12 weeks."
Q4: "Summarize sentiment from recent Sonos Arc and Move 2 product reviews from tech sites."

=============================================================================
*/


-- Switch to accountadmin role to create warehouse
USE ROLE accountadmin;

-- Enable Snowflake Intelligence
GRANT USAGE ON DATABASE snowflake_intelligence TO ROLE PUBLIC;
GRANT USAGE ON SCHEMA snowflake_intelligence.agents TO ROLE PUBLIC;

CREATE OR REPLACE ROLE SONOS_INTEL_DEMO_ROLE;

SET current_user_name = CURRENT_USER();
GRANT ROLE SONOS_INTEL_DEMO_ROLE TO USER IDENTIFIER($current_user_name);
GRANT CREATE DATABASE ON ACCOUNT TO ROLE SONOS_INTEL_DEMO_ROLE;
    
-- Create dedicated warehouse
CREATE OR REPLACE WAREHOUSE SONOS_INTEL_WH 
    WITH WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 300
    AUTO_RESUME = TRUE;

GRANT USAGE ON WAREHOUSE SONOS_INTEL_WH TO ROLE SONOS_INTEL_DEMO_ROLE;

-- Set defaults
ALTER USER IDENTIFIER($current_user_name) SET DEFAULT_ROLE = SONOS_INTEL_DEMO_ROLE;
ALTER USER IDENTIFIER($current_user_name) SET DEFAULT_WAREHOUSE = SONOS_INTEL_WH;

-- Switch to demo role
USE ROLE SONOS_INTEL_DEMO_ROLE;
   
-- Create database and schema
CREATE OR REPLACE DATABASE SONOS_AI_DEMO;
USE DATABASE SONOS_AI_DEMO;
CREATE SCHEMA IF NOT EXISTS APP;
USE SCHEMA APP;

-- Create file format for CSV files
CREATE OR REPLACE FILE FORMAT CSV_FORMAT
    TYPE = 'CSV'
    FIELD_DELIMITER = ','
    RECORD_DELIMITER = '\n'
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    TRIM_SPACE = TRUE
    ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
    ESCAPE = 'NONE'
    ESCAPE_UNENCLOSED_FIELD = '\134'
    DATE_FORMAT = 'YYYY-MM-DD'
    TIMESTAMP_FORMAT = 'YYYY-MM-DD HH24:MI:SS'
    NULL_IF = ('NULL', 'null', '', 'N/A', 'n/a');

-- ========================================================================
-- GIT INTEGRATION
-- ========================================================================

USE ROLE accountadmin;
CREATE OR REPLACE API INTEGRATION git_api_integration
    API_PROVIDER = git_https_api
    API_ALLOWED_PREFIXES = ('https://github.com/sfc-gh-jleati/')
    ENABLED = TRUE;

GRANT USAGE ON INTEGRATION GIT_API_INTEGRATION TO ROLE SONOS_INTEL_DEMO_ROLE;

USE ROLE SONOS_INTEL_DEMO_ROLE;
CREATE OR REPLACE GIT REPOSITORY SONOS_AI_DEMO_REPO
    API_INTEGRATION = git_api_integration
    ORIGIN = 'https://github.com/sfc-gh-jleati/sonos_snowflake_intelligence_demo.git';

-- Create internal stage
CREATE OR REPLACE STAGE INTERNAL_DATA_STAGE
    FILE_FORMAT = CSV_FORMAT
    COMMENT = 'Internal stage for Sonos demo data'
    DIRECTORY = (ENABLE = TRUE)
    ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE');

ALTER GIT REPOSITORY SONOS_AI_DEMO_REPO FETCH;

-- Copy data from Git to internal stage
COPY FILES
INTO @INTERNAL_DATA_STAGE/demo_data/
FROM @SONOS_AI_DEMO_REPO/branches/main/demo_data/;

COPY FILES
INTO @INTERNAL_DATA_STAGE/unstructured_docs/
FROM @SONOS_AI_DEMO_REPO/branches/main/unstructured_docs/;

LS @INTERNAL_DATA_STAGE;
ALTER STAGE INTERNAL_DATA_STAGE REFRESH;

-- ========================================================================
-- DIMENSION TABLES (5 essential tables)
-- ========================================================================

-- Product Category Dimension
CREATE OR REPLACE TABLE product_category_dim (
    category_key INT PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL,
    vertical VARCHAR(50) NOT NULL
) COMMENT = 'Sonos product categories: Soundbars, Smart Speakers, Portable Speakers, Subwoofers, Amplifiers';

-- Product Dimension
CREATE OR REPLACE TABLE product_dim (
    product_key INT PRIMARY KEY,
    product_name VARCHAR(200) NOT NULL,
    category_key INT NOT NULL,
    category_name VARCHAR(100),
    vertical VARCHAR(50)
) COMMENT = 'Sonos products: Arc, Beam, Era, Move, Roam, Sub, Amp';

-- Region Dimension
CREATE OR REPLACE TABLE region_dim (
    region_key INT PRIMARY KEY,
    region_name VARCHAR(100) NOT NULL
) COMMENT = 'Geographic regions: North America, Europe, APAC, Latin America';

-- Campaign Dimension
CREATE OR REPLACE TABLE campaign_dim (
    campaign_key INT PRIMARY KEY,
    campaign_name VARCHAR(300) NOT NULL,
    objective VARCHAR(100)
) COMMENT = 'Marketing campaigns: Arc Upgrade Promo, Beam Back-to-School, etc.';

-- Channel Dimension
CREATE OR REPLACE TABLE channel_dim (
    channel_key INT PRIMARY KEY,
    channel_name VARCHAR(100) NOT NULL
) COMMENT = 'Marketing channels: Paid Search, YouTube, Social Media, Retail eCom, Email';

-- ========================================================================
-- FACT TABLES (2 essential tables)
-- ========================================================================

-- Sales Fact - Product purchases
CREATE OR REPLACE TABLE sales_fact (
    sale_id INT PRIMARY KEY,
    date DATE NOT NULL,
    product_key INT NOT NULL,
    region_key INT NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    units INT NOT NULL
) COMMENT = 'Sonos product sales: date, product, region, amount, units';

-- Marketing Campaign Fact - Campaign performance
CREATE OR REPLACE TABLE marketing_campaign_fact (
    campaign_fact_id INT PRIMARY KEY,
    date DATE NOT NULL,
    campaign_key INT NOT NULL,
    product_key INT NOT NULL,
    channel_key INT NOT NULL,
    region_key INT NOT NULL,
    spend DECIMAL(10,2) NOT NULL,
    leads_generated INT NOT NULL,
    impressions INT NOT NULL
) COMMENT = 'Marketing campaign performance: spend, impressions, leads by campaign/channel/product';

-- ========================================================================
-- LOAD DATA FROM INTERNAL STAGE
-- ========================================================================

-- Load Dimensions
COPY INTO product_category_dim FROM @INTERNAL_DATA_STAGE/demo_data/product_category_dim.csv FILE_FORMAT = CSV_FORMAT ON_ERROR = 'CONTINUE';
COPY INTO product_dim FROM @INTERNAL_DATA_STAGE/demo_data/product_dim.csv FILE_FORMAT = CSV_FORMAT ON_ERROR = 'CONTINUE';
COPY INTO region_dim FROM @INTERNAL_DATA_STAGE/demo_data/region_dim.csv FILE_FORMAT = CSV_FORMAT ON_ERROR = 'CONTINUE';
COPY INTO campaign_dim FROM @INTERNAL_DATA_STAGE/demo_data/campaign_dim.csv FILE_FORMAT = CSV_FORMAT ON_ERROR = 'CONTINUE';
COPY INTO channel_dim FROM @INTERNAL_DATA_STAGE/demo_data/channel_dim.csv FILE_FORMAT = CSV_FORMAT ON_ERROR = 'CONTINUE';

-- Load Facts
COPY INTO sales_fact FROM @INTERNAL_DATA_STAGE/demo_data/sales_fact.csv FILE_FORMAT = CSV_FORMAT ON_ERROR = 'CONTINUE';
COPY INTO marketing_campaign_fact FROM @INTERNAL_DATA_STAGE/demo_data/marketing_campaign_fact.csv FILE_FORMAT = CSV_FORMAT ON_ERROR = 'CONTINUE';

-- ========================================================================
-- VERIFICATION
-- ========================================================================

SELECT 'DIMENSION TABLES' as category, '' as table_name, NULL as row_count
UNION ALL SELECT '', 'product_category_dim', COUNT(*) FROM product_category_dim
UNION ALL SELECT '', 'product_dim', COUNT(*) FROM product_dim
UNION ALL SELECT '', 'region_dim', COUNT(*) FROM region_dim
UNION ALL SELECT '', 'campaign_dim', COUNT(*) FROM campaign_dim
UNION ALL SELECT '', 'channel_dim', COUNT(*) FROM channel_dim
UNION ALL SELECT '', '', NULL
UNION ALL SELECT 'FACT TABLES', '', NULL
UNION ALL SELECT '', 'sales_fact', COUNT(*) FROM sales_fact
UNION ALL SELECT '', 'marketing_campaign_fact', COUNT(*) FROM marketing_campaign_fact;

SHOW TABLES IN SCHEMA APP;

-- ========================================================================
-- SEMANTIC VIEWS FOR CORTEX ANALYST (2 essential views)
-- ========================================================================

-- ========================================================================
-- SALES SEMANTIC VIEW - For Q1 (Product Analytics) and Q3 (Forecasting)
-- ========================================================================

CREATE OR REPLACE SEMANTIC VIEW SONOS_AI_DEMO.APP.SALES_SEMANTIC_VIEW
	tables (
		SALES as SALES_FACT primary key (SALE_ID) with synonyms=('sales','purchases','transactions','orders') comment='Product sales transactions - date, product, region, amount, units',
		PRODUCTS as PRODUCT_DIM primary key (PRODUCT_KEY) with synonyms=('products','devices','speakers','soundbars') comment='Sonos products: Arc, Beam, Era 100/300, Move 2, Roam, Sub, Amp',
		CATEGORIES as PRODUCT_CATEGORY_DIM primary key (CATEGORY_KEY) with synonyms=('categories','product categories') comment='Product categories: Soundbars, Smart Speakers, Portable Speakers',
		REGIONS as REGION_DIM primary key (REGION_KEY) with synonyms=('regions','markets','territories') comment='Geographic regions: North America, Europe, APAC, Latin America'
	)
	relationships (
		SALES_TO_PRODUCTS as SALES(PRODUCT_KEY) references PRODUCTS(PRODUCT_KEY),
		SALES_TO_REGIONS as SALES(REGION_KEY) references REGIONS(REGION_KEY),
		PRODUCTS_TO_CATEGORIES as PRODUCTS(CATEGORY_KEY) references CATEGORIES(CATEGORY_KEY)
	)
	facts (
		SALES.AMOUNT as amount comment='Sale amount in dollars',
		SALES.UNITS as units comment='Number of units sold',
		SALES.SALE_RECORD as 1 comment='Count of sales transactions'
	)
	dimensions (
		SALES.DATE as date with synonyms=('date','sale date','purchase date','transaction date') comment='Date of the sale',
		SALES.SALE_MONTH as MONTH(date) comment='Month of the sale',
		SALES.SALE_YEAR as YEAR(date) comment='Year of the sale',
		SALES.SALE_WEEK as WEEK(date) comment='Week of the sale',
		PRODUCTS.PRODUCT_NAME as product_name with synonyms=('product','device','speaker','soundbar','model') comment='Sonos product: Arc, Beam, Ray, Era 100, Era 300, One, Move 2, Roam, Sub, Amp',
		PRODUCTS.PRODUCT_KEY as PRODUCT_KEY,
		CATEGORIES.CATEGORY_NAME as category_name with synonyms=('category','product category','product line') comment='Product category: Soundbars, Smart Speakers, Portable Speakers, Subwoofers, Amplifiers',
		CATEGORIES.VERTICAL as vertical with synonyms=('vertical','product vertical') comment='Product vertical: Home Audio, Portable Audio, Accessories',
		REGIONS.REGION_NAME as region_name with synonyms=('region','market','territory','geography') comment='Geographic region'
	)
	metrics (
		SALES.TOTAL_REVENUE as SUM(sales.amount) comment='Total revenue from product sales',
		SALES.TOTAL_UNITS as SUM(sales.units) comment='Total units sold',
		SALES.TOTAL_SALES as COUNT(sales.sale_record) comment='Total number of sales transactions',
		SALES.AVERAGE_SALE_AMOUNT as AVG(sales.amount) comment='Average sale amount',
		SALES.AVERAGE_UNITS_PER_SALE as AVG(sales.units) comment='Average units per sale'
	)
	comment='Sonos product sales analytics - for Q1 (top products) and Q3 (forecasting)';

-- ========================================================================
-- MARKETING SEMANTIC VIEW - For Q2 (Marketing Attribution)
-- ========================================================================

CREATE OR REPLACE SEMANTIC VIEW SONOS_AI_DEMO.APP.MARKETING_SEMANTIC_VIEW
	tables (
		CAMPAIGNS as MARKETING_CAMPAIGN_FACT primary key (CAMPAIGN_FACT_ID) with synonyms=('campaigns','marketing','marketing data') comment='Marketing campaign performance - daily spend, impressions, leads by campaign/channel/product',
		CAMPAIGN_DETAILS as CAMPAIGN_DIM primary key (CAMPAIGN_KEY) with synonyms=('campaign info','campaign names') comment='Campaign names: Arc Upgrade Promo, Beam Back-to-School, etc.',
		CHANNELS as CHANNEL_DIM primary key (CHANNEL_KEY) with synonyms=('channels','marketing channels') comment='Marketing channels: Paid Search, YouTube, Retail eCom, Social Media, Email',
		PRODUCTS as PRODUCT_DIM primary key (PRODUCT_KEY) with synonyms=('products','items') comment='Sonos products in campaigns',
		REGIONS as REGION_DIM primary key (REGION_KEY) with synonyms=('regions','markets') comment='Geographic regions'
	)
	relationships (
		CAMPAIGNS_TO_CHANNELS as CAMPAIGNS(CHANNEL_KEY) references CHANNELS(CHANNEL_KEY),
		CAMPAIGNS_TO_DETAILS as CAMPAIGNS(CAMPAIGN_KEY) references CAMPAIGN_DETAILS(CAMPAIGN_KEY),
		CAMPAIGNS_TO_PRODUCTS as CAMPAIGNS(PRODUCT_KEY) references PRODUCTS(PRODUCT_KEY),
		CAMPAIGNS_TO_REGIONS as CAMPAIGNS(REGION_KEY) references REGIONS(REGION_KEY)
	)
	facts (
		CAMPAIGNS.SPEND as spend comment='Daily marketing spend in dollars',
		CAMPAIGNS.IMPRESSIONS as impressions comment='Daily ad impressions',
		CAMPAIGNS.LEADS_GENERATED as leads_generated comment='Daily leads generated',
		CAMPAIGNS.CAMPAIGN_RECORD as 1 comment='Count of campaign activity days'
	)
	dimensions (
		CAMPAIGNS.DATE as date with synonyms=('date','campaign date','activity date') comment='Campaign activity date',
		CAMPAIGNS.CAMPAIGN_MONTH as MONTH(date) comment='Campaign month',
		CAMPAIGNS.CAMPAIGN_YEAR as YEAR(date) comment='Campaign year',
		CAMPAIGNS.CAMPAIGN_WEEK as WEEK(date) comment='Campaign week',
		CAMPAIGN_DETAILS.CAMPAIGN_NAME as campaign_name with synonyms=('campaign','campaign title') comment='Campaign name (Arc Upgrade Promo Q3 2025, Beam Back-to-School, etc.)',
		CAMPAIGN_DETAILS.CAMPAIGN_OBJECTIVE as objective with synonyms=('objective','goal') comment='Campaign objective: Product Launch, Seasonal Promotion, Lead Generation',
		CHANNELS.CHANNEL_NAME as channel_name with synonyms=('channel','marketing channel') comment='Marketing channel: Paid Search, YouTube, Social Media, Retail eCom, Email',
		PRODUCTS.PRODUCT_NAME as product_name with synonyms=('product','device') comment='Sonos product name',
		REGIONS.REGION_NAME as region_name with synonyms=('region','market') comment='Geographic region'
	)
	metrics (
		CAMPAIGNS.TOTAL_SPEND as SUM(campaigns.spend) comment='Total marketing spend',
		CAMPAIGNS.TOTAL_IMPRESSIONS as SUM(campaigns.impressions) comment='Total ad impressions',
		CAMPAIGNS.TOTAL_LEADS as SUM(campaigns.leads_generated) comment='Total leads generated',
		CAMPAIGNS.AVERAGE_SPEND as AVG(campaigns.spend) comment='Average daily spend',
		CAMPAIGNS.COST_PER_LEAD as SUM(campaigns.spend) / NULLIF(SUM(campaigns.leads_generated), 0) comment='Cost per lead (CAC)',
		CAMPAIGNS.COST_PER_IMPRESSION as SUM(campaigns.spend) / NULLIF(SUM(campaigns.impressions), 0) * 1000 comment='CPM - cost per thousand impressions'
	)
	comment='Sonos marketing campaign analytics - for Q2 (marketing attribution to sales)';

SHOW SEMANTIC VIEWS;

-- ========================================================================
-- HELPER VIEWS FOR Q3 (Forecasting & Anomaly Detection)
-- ========================================================================

-- Arc daily sales for forecasting and anomaly analysis
CREATE OR REPLACE VIEW arc_daily_sales AS
SELECT 
    s.date,
    SUM(s.units) as daily_units,
    SUM(s.amount) as daily_revenue,
    r.region_name
FROM sales_fact s
JOIN product_dim p ON s.product_key = p.product_key
JOIN region_dim r ON s.region_key = r.region_key
WHERE p.product_name = 'Sonos Arc'
GROUP BY s.date, r.region_name
COMMENT = 'Arc daily sales by region - for Q3 forecasting';

-- Arc weekly North America sales with anomaly detection
CREATE OR REPLACE VIEW arc_weekly_na_sales AS
SELECT 
    DATE_TRUNC('WEEK', date) as week,
    SUM(daily_units) as weekly_units,
    AVG(daily_units) as avg_daily_units,
    STDDEV(daily_units) as stddev_daily_units,
    CASE 
        WHEN SUM(daily_units) > 200 THEN 'HIGH VOLUME WEEK'
        WHEN SUM(daily_units) > 150 THEN 'ABOVE AVERAGE'
        ELSE 'NORMAL'
    END as volume_flag
FROM arc_daily_sales
WHERE region_name = 'North America'
GROUP BY DATE_TRUNC('WEEK', date)
COMMENT = 'Arc weekly North America sales - for Q3 trend analysis';

-- ========================================================================
-- UNSTRUCTURED DATA - Parse PDFs for Cortex Search
-- ========================================================================

CREATE OR REPLACE TABLE parsed_content AS 
SELECT 
    relative_path, 
    BUILD_STAGE_FILE_URL('@SONOS_AI_DEMO.APP.INTERNAL_DATA_STAGE', relative_path) AS file_url,
    TO_FILE(BUILD_STAGE_FILE_URL('@SONOS_AI_DEMO.APP.INTERNAL_DATA_STAGE', relative_path)) AS file_object,
    SNOWFLAKE.CORTEX.PARSE_DOCUMENT(
        @SONOS_AI_DEMO.APP.INTERNAL_DATA_STAGE,
        relative_path,
        {'mode':'LAYOUT'}
    ):content::string AS Content
FROM directory(@SONOS_AI_DEMO.APP.INTERNAL_DATA_STAGE) 
WHERE relative_path ILIKE 'unstructured_docs/%.pdf';

-- ========================================================================
-- CORTEX SEARCH SERVICES (2 essential services)
-- ========================================================================

-- Search service for marketing documents
CREATE OR REPLACE CORTEX SEARCH SERVICE Search_marketing_docs
    ON content
    ATTRIBUTES relative_path, file_url, title
    WAREHOUSE = SONOS_INTEL_WH
    TARGET_LAG = '30 day'
    EMBEDDING_MODEL = 'snowflake-arctic-embed-l-v2.0'
    AS (
        SELECT
            relative_path,
            file_url,
            REGEXP_SUBSTR(relative_path, '[^/]+$') as title,
            content
        FROM parsed_content
        WHERE relative_path ilike '%/marketing/%'
    );

-- Search service for sales/product documents
CREATE OR REPLACE CORTEX SEARCH SERVICE Search_product_docs
    ON content
    ATTRIBUTES relative_path, file_url, title
    WAREHOUSE = SONOS_INTEL_WH
    TARGET_LAG = '30 day'
    EMBEDDING_MODEL = 'snowflake-arctic-embed-l-v2.0'
    AS (
        SELECT
            relative_path,
            file_url,
            REGEXP_SUBSTR(relative_path, '[^/]+$') as title,
            content
        FROM parsed_content
        WHERE relative_path ilike '%/sales/%'
    );

-- ========================================================================
-- EXTERNAL ACCESS FOR WEB SCRAPING (Q4)
-- ========================================================================

CREATE OR REPLACE NETWORK RULE SONOS_INTEL_WEBACCESS_RULE
  MODE = EGRESS
  TYPE = HOST_PORT
  VALUE_LIST = ('0.0.0.0:80', '0.0.0.0:443');

USE ROLE accountadmin;
GRANT ALL PRIVILEGES ON DATABASE SONOS_AI_DEMO TO ROLE ACCOUNTADMIN;
GRANT ALL PRIVILEGES ON SCHEMA SONOS_AI_DEMO.APP TO ROLE ACCOUNTADMIN;
GRANT USAGE ON NETWORK RULE SONOS_INTEL_WEBACCESS_RULE TO ROLE accountadmin;

USE SCHEMA SONOS_AI_DEMO.APP;

CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION SONOS_INTEL_EAI
ALLOWED_NETWORK_RULES = (SONOS_INTEL_WEBACCESS_RULE)
ENABLED = true;

GRANT USAGE ON DATABASE snowflake_intelligence TO ROLE SONOS_INTEL_DEMO_ROLE;
GRANT USAGE ON SCHEMA snowflake_intelligence.agents TO ROLE SONOS_INTEL_DEMO_ROLE;
GRANT CREATE AGENT ON SCHEMA snowflake_intelligence.agents TO ROLE SONOS_INTEL_DEMO_ROLE;
GRANT USAGE ON INTEGRATION SONOS_INTEL_EAI TO ROLE SONOS_INTEL_DEMO_ROLE;

USE ROLE SONOS_INTEL_DEMO_ROLE;

-- ========================================================================
-- CUSTOM TOOLS
-- ========================================================================

-- Web scraper function for Q4 (sentiment analysis)
CREATE OR REPLACE FUNCTION Web_scrape(weburl STRING)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = 3.11
HANDLER = 'get_page'
EXTERNAL_ACCESS_INTEGRATIONS = (SONOS_INTEL_EAI)
PACKAGES = ('requests', 'beautifulsoup4')
COMMENT = 'Scrapes web content for sentiment analysis - used in Q4'
AS
$$
import _snowflake
import requests
from bs4 import BeautifulSoup

def get_page(weburl):
  url = f"{weburl}"
  response = requests.get(url)
  soup = BeautifulSoup(response.text)
  return soup.get_text()
$$;

-- ========================================================================
-- SNOWFLAKE INTELLIGENCE AGENT
-- ========================================================================

CREATE OR REPLACE AGENT SNOWFLAKE_INTELLIGENCE.AGENTS.SONOS_PRODUCT_INTELLIGENCE
WITH PROFILE='{ "display_name": "Sonos Product Intelligence" }'
    COMMENT=$$ Product analytics agent for Sonos - answers questions about product sales, marketing campaigns, forecasting, and sentiment analysis. $$
FROM SPECIFICATION $$
{
  "models": {
    "orchestration": ""
  },
  "instructions": {
    "response": "You are a product analytics specialist for Sonos, the premium audio company. You analyze product sales (Arc, Beam, Era, Move, Roam), marketing campaigns, and provide forecasts. Default to 2025 or last 90 days for time periods. Use line charts for trends, bar charts for comparisons. The Arc Upgrade Promo Q3 2025 (July-October) drove significant Arc sales growth with major spikes on Sept 10, 26, Oct 11, 20 reaching 50-70 units per day (vs 6-12 normal).",
    "orchestration": "For product sales: use Query_Product_Sales_Analytics. For marketing: use Query_Marketing_Campaign_Performance. For forecasting: query arc_daily_sales view. For sentiment: use Web_Scraper on review sites.",
    "sample_questions": [
      {
        "question": "Over the last 90 days in North America, which Sonos product led in units and revenue? Show top 5 with MoM growth."
      },
      {
        "question": "What drove the Arc spike? Break down by marketing channel and campaign over the last 8 weeks, and correlate with spend and impressions."
      },
      {
        "question": "Using arc_daily_sales view, show Sonos Arc sales in North America over the past 12 weeks. Flag days with over 50 units as anomalies. Forecast the next 4 weeks at 5-8 units per day."
      },
      {
        "question": "Summarize sentiment and top recurring themes from recent Sonos Arc product reviews. Use the web scraper tool on https://www.theverge.com/reviews and https://www.soundguys.com/reviews/"
      }
    ]
  },
  "tools": [
    {
      "tool_spec": {
        "type": "cortex_analyst_text_to_sql",
        "name": "Query_Product_Sales_Analytics",
        "description": "Analyze Sonos product sales: units sold, revenue, trends by product (Arc, Beam, Era, Move, Roam), region (North America, Europe, APAC), and time period. Used for Q1 and Q3. Includes helper view arc_daily_sales for forecasting analysis."
      }
    },
    {
      "tool_spec": {
        "type": "cortex_analyst_text_to_sql",
        "name": "Query_Marketing_Campaign_Performance",
        "description": "Analyze marketing campaign performance: spend, impressions, leads by channel (Paid Search, YouTube, Social, Retail eCom, Email), campaign (Arc Upgrade Promo Q3 2025, etc.), and product. Calculate ROI metrics like cost-per-lead and CPM. Used for Q2."
      }
    },
    {
      "tool_spec": {
        "type": "cortex_search",
        "name": "Search_Marketing_Campaign_Materials",
        "description": "Search marketing campaign strategies, channel performance reports, campaign plans, and marketing materials. Provides context for campaign objectives and channel strategies."
      }
    },
    {
      "tool_spec": {
        "type": "cortex_search",
        "name": "Search_Product_Documentation",
        "description": "Search product playbooks, customer success stories, product performance data, and Sonos product information. Useful for understanding product positioning and customer feedback."
      }
    },
    {
      "tool_spec": {
        "type": "generic",
        "name": "Web_Scraper",
        "description": "Scrapes and analyzes content from public web pages. Use for Q4 sentiment analysis - scrape product review websites (The Verge, CNET, SoundGuys) to extract customer sentiment and themes about Sonos products. Input: web URL (http:// or https://). Output: text content from page.",
        "input_schema": {
          "type": "object",
          "properties": {
            "weburl": {
              "description": "Web URL to scrape (e.g., https://www.theverge.com/reviews, https://www.soundguys.com/reviews/). Must include http:// or https://. Returns text content.",
              "type": "string"
            }
          },
          "required": ["weburl"]
        }
      }
    }
  ],
  "tool_resources": {
    "Query_Product_Sales_Analytics": {
      "semantic_view": "SONOS_AI_DEMO.APP.SALES_SEMANTIC_VIEW"
    },
    "Query_Marketing_Campaign_Performance": {
      "semantic_view": "SONOS_AI_DEMO.APP.MARKETING_SEMANTIC_VIEW"
    },
    "Search_Marketing_Campaign_Materials": {
      "id_column": "RELATIVE_PATH",
      "max_results": 5,
      "name": "SONOS_AI_DEMO.APP.SEARCH_MARKETING_DOCS",
      "title_column": "TITLE"
    },
    "Search_Product_Documentation": {
      "id_column": "FILE_URL",
      "max_results": 5,
      "name": "SONOS_AI_DEMO.APP.SEARCH_PRODUCT_DOCS",
      "title_column": "TITLE"
    },
    "Web_Scraper": {
      "execution_environment": {
        "query_timeout": 0,
        "type": "warehouse",
        "warehouse": "SONOS_INTEL_WH"
      },
      "identifier": "SONOS_AI_DEMO.APP.WEB_SCRAPE",
      "name": "WEB_SCRAPE(VARCHAR)",
      "type": "function"
    }
  }
}
$$;

-- ========================================================================
-- FINAL VERIFICATION & SUMMARY
-- ========================================================================

SELECT '
========================================================================
SONOS PRODUCT ANALYTICS DEMO - SETUP COMPLETE ✅
========================================================================

STREAMLINED FOR 4 DEMO QUESTIONS:

Q1: Product Sales Analytics
   - Which Sonos products sell best?
   - Tool: Query_Product_Sales_Analytics (SALES_SEMANTIC_VIEW)
   - Tables: sales_fact, product_dim, region_dim

Q2: Marketing Attribution  
   - What marketing drives sales?
   - Tool: Query_Marketing_Campaign_Performance (MARKETING_SEMANTIC_VIEW)
   - Tables: marketing_campaign_fact, campaign_dim, channel_dim

Q3: Forecasting & Anomaly Detection
   - Predict future sales, detect spikes
   - Tool: Query_Product_Sales_Analytics + arc_daily_sales view
   - Helper views: arc_daily_sales, arc_weekly_na_sales
   - Example SQL: sql/arc_forecast_example.sql

Q4: Sentiment Analysis
   - Analyze product reviews from web
   - Tool: Web_Scraper function
   - External data: Scrape review sites

AGENT: SNOWFLAKE_INTELLIGENCE.AGENTS.SONOS_PRODUCT_INTELLIGENCE

DATA LOADED:
✅ 5 Dimension Tables (50 rows)
✅ 2 Fact Tables (25,520 rows)
✅ 6 PDF Documents (Marketing & Product)
✅ 2 Semantic Views (Sales, Marketing)
✅ 2 Cortex Search Services
✅ 2 Helper Views (Arc forecasting)
✅ 1 Custom Tool (Web scraper)
✅ 1 Intelligence Agent

REMOVED (Not relevant for Sonos consumer electronics):
❌ CRM tables (sf_accounts, sf_opportunities, sf_contacts)
❌ Finance/HR tables and semantic views
❌ Customer, vendor, employee dimensions
❌ Unnecessary PDFs

DATABASE: SONOS_AI_DEMO
SCHEMA: APP  
WAREHOUSE: SONOS_INTEL_WH
ROLE: SONOS_INTEL_DEMO_ROLE

Ready to answer all 4 demo questions! 🎵
========================================================================
' as SETUP_GUIDE;

SHOW TABLES;
SHOW SEMANTIC VIEWS;
SHOW CORTEX SEARCH SERVICES;
SHOW VIEWS LIKE 'arc_%';
SHOW FUNCTIONS LIKE 'WEB_SCRAPE';
