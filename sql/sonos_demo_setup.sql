
-- ========================================================================
-- Sonos Product Analytics Demo - Complete Setup Script
-- Snowflake Intelligence Demo for Sonos Product Team
-- Focus: Product usage, customer engagement, and sales analytics
-- Repository: https://github.com/sfc-gh-jleati/sonos_snowflake_intelligence_demo.git
-- ========================================================================

/*
=============================================================================
ABOUT THIS DEMO
=============================================================================

This demo is customized for Sonos Product Team to showcase how Snowflake 
Intelligence can provide actionable insights about:

1. PRODUCT USAGE ANALYTICS
   - Track which products customers buy (Arc, Beam, Era, Move, Roam, etc.)
   - Monitor product adoption rates and sales trends
   - Identify best-selling products by region and channel
   - Analyze product mix and ecosystem expansion
   
2. SALES ANALYTICS
   - Track revenue by product, region, and time period
   - Monitor seasonal trends and promotional impact
   - Analyze average order value and product attach rates
   - Forecast future sales trends
   
3. MARKETING CAMPAIGN PERFORMANCE
   - Track campaign effectiveness across channels
   - Analyze customer acquisition costs and ROI
   - Monitor channel performance (Paid Search, YouTube, Social, etc.)
   - Calculate marketing attribution to sales
   
4. CUSTOMER INSIGHTS
   - Understand customer purchase behavior
   - Analyze customer lifetime value
   - Track product ecosystem expansion per customer
   - Monitor customer satisfaction and NPS

SAMPLE QUESTIONS YOU CAN ASK:
- "Over the last 90 days in North America, which Sonos product led in units and revenue?"
- "What drove the Arc sales spike? Break down by marketing channel and campaign."
- "Forecast the next 4 weeks of units for Sonos Arc and flag any anomalies."
- "Summarize sentiment from recent Sonos product reviews."

=============================================================================
*/


-- Switch to accountadmin role to create warehouse
USE ROLE accountadmin;

-- Enable Snowflake Intelligence by granting access to the agents schema
GRANT USAGE ON DATABASE snowflake_intelligence TO ROLE PUBLIC;
GRANT USAGE ON SCHEMA snowflake_intelligence.agents TO ROLE PUBLIC;


CREATE OR REPLACE ROLE SONOS_INTEL_DEMO_ROLE;


SET current_user_name = CURRENT_USER();
    
-- Grant the role to current user
GRANT ROLE SONOS_INTEL_DEMO_ROLE TO USER IDENTIFIER($current_user_name);
GRANT CREATE DATABASE ON ACCOUNT TO ROLE SONOS_INTEL_DEMO_ROLE;
    
-- Create a dedicated warehouse for the Sonos demo with auto-suspend/resume
CREATE OR REPLACE WAREHOUSE SONOS_INTEL_WH 
    WITH WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 300
    AUTO_RESUME = TRUE;


-- Grant usage on warehouse to Sonos demo role
GRANT USAGE ON WAREHOUSE SONOS_INTEL_WH TO ROLE SONOS_INTEL_DEMO_ROLE;


-- Alter current user's default role and warehouse
ALTER USER IDENTIFIER($current_user_name) SET DEFAULT_ROLE = SONOS_INTEL_DEMO_ROLE;
ALTER USER IDENTIFIER($current_user_name) SET DEFAULT_WAREHOUSE = SONOS_INTEL_WH;
    

-- Switch to SONOS_INTEL_DEMO_ROLE role to create demo objects
USE ROLE SONOS_INTEL_DEMO_ROLE;
   
-- Create database and schema for Sonos demo
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


USE ROLE accountadmin;
-- Create API Integration for GitHub (public repository access)
CREATE OR REPLACE API INTEGRATION git_api_integration
    API_PROVIDER = git_https_api
    API_ALLOWED_PREFIXES = ('https://github.com/sfc-gh-jleati/')
    ENABLED = TRUE;


GRANT USAGE ON INTEGRATION GIT_API_INTEGRATION TO ROLE SONOS_INTEL_DEMO_ROLE;


USE ROLE SONOS_INTEL_DEMO_ROLE;
-- Create Git repository integration for the public demo repository
CREATE OR REPLACE GIT REPOSITORY SONOS_AI_DEMO_REPO
    API_INTEGRATION = git_api_integration
    ORIGIN = 'https://github.com/sfc-gh-jleati/sonos_snowflake_intelligence_demo.git';

-- Create internal stage for copied data files
CREATE OR REPLACE STAGE INTERNAL_DATA_STAGE
    FILE_FORMAT = CSV_FORMAT
    COMMENT = 'Internal stage for copied demo data files'
    DIRECTORY = ( ENABLE = TRUE)
    ENCRYPTION = (   TYPE = 'SNOWFLAKE_SSE');

ALTER GIT REPOSITORY SONOS_AI_DEMO_REPO FETCH;

-- ========================================================================
-- COPY DATA FROM GIT TO INTERNAL STAGE
-- ========================================================================

-- Copy all CSV files from Git repository demo_data folder to internal stage
COPY FILES
INTO @INTERNAL_DATA_STAGE/demo_data/
FROM @SONOS_AI_DEMO_REPO/branches/main/demo_data/;


COPY FILES
INTO @INTERNAL_DATA_STAGE/unstructured_docs/
FROM @SONOS_AI_DEMO_REPO/branches/main/unstructured_docs/;

-- Verify files were copied
LS @INTERNAL_DATA_STAGE;

ALTER STAGE INTERNAL_DATA_STAGE refresh;

  

-- ========================================================================
-- DIMENSION TABLES
-- ========================================================================

-- Product Category Dimension
CREATE OR REPLACE TABLE product_category_dim (
    category_key INT PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL,
    vertical VARCHAR(50) NOT NULL
);

-- Product Dimension
CREATE OR REPLACE TABLE product_dim (
    product_key INT PRIMARY KEY,
    product_name VARCHAR(200) NOT NULL,
    category_key INT NOT NULL,
    category_name VARCHAR(100),
    vertical VARCHAR(50)
);

-- Vendor/Partner Dimension (service providers, payment processors)
CREATE OR REPLACE TABLE vendor_dim (
    vendor_key INT PRIMARY KEY,
    vendor_name VARCHAR(200) NOT NULL,
    vertical VARCHAR(50) NOT NULL,
    address VARCHAR(200),
    city VARCHAR(100),
    state VARCHAR(10),
    zip VARCHAR(20)
) COMMENT = 'Service partners and payment processors (Stripe, AWS, Shopify, etc.)';

-- Customer Dimension
CREATE OR REPLACE TABLE customer_dim (
    customer_key INT PRIMARY KEY,
    customer_name VARCHAR(200) NOT NULL,
    industry VARCHAR(100),
    vertical VARCHAR(50),
    address VARCHAR(200),
    city VARCHAR(100),
    state VARCHAR(10),
    zip VARCHAR(20)
) COMMENT = 'Sonos customers who purchase products';

-- Account Dimension (Finance)
CREATE OR REPLACE TABLE account_dim (
    account_key INT PRIMARY KEY,
    account_name VARCHAR(100) NOT NULL,
    account_type VARCHAR(50)
);

-- Department Dimension
CREATE OR REPLACE TABLE department_dim (
    department_key INT PRIMARY KEY,
    department_name VARCHAR(100) NOT NULL
);

-- Region Dimension
CREATE OR REPLACE TABLE region_dim (
    region_key INT PRIMARY KEY,
    region_name VARCHAR(100) NOT NULL
);

-- Sales Rep Dimension  
CREATE OR REPLACE TABLE sales_rep_dim (
    sales_rep_key INT PRIMARY KEY,
    sales_rep_name VARCHAR(200) NOT NULL
);

-- Campaign Dimension (Marketing)
CREATE OR REPLACE TABLE campaign_dim (
    campaign_key INT PRIMARY KEY,
    campaign_name VARCHAR(300) NOT NULL,
    objective VARCHAR(100)
);

-- Channel Dimension (Marketing)
CREATE OR REPLACE TABLE channel_dim (
    channel_key INT PRIMARY KEY,
    channel_name VARCHAR(100) NOT NULL
);

-- Employee Dimension (HR)
CREATE OR REPLACE TABLE employee_dim (
    employee_key INT PRIMARY KEY,
    employee_name VARCHAR(200) NOT NULL,
    gender VARCHAR(1),
    hire_date DATE
);

-- Job Dimension (HR)
CREATE OR REPLACE TABLE job_dim (
    job_key INT PRIMARY KEY,
    job_title VARCHAR(100) NOT NULL,
    job_level INT
);

-- Location Dimension (HR)
CREATE OR REPLACE TABLE location_dim (
    location_key INT PRIMARY KEY,
    location_name VARCHAR(200) NOT NULL
);

-- ========================================================================
-- FACT TABLES
-- ========================================================================

-- Sales Fact Table (Product purchases)
CREATE OR REPLACE TABLE sales_fact (
    sale_id INT PRIMARY KEY,
    date DATE NOT NULL,
    customer_key INT NOT NULL,
    product_key INT NOT NULL,
    region_key INT NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    units INT NOT NULL
);

-- Finance Transactions Fact Table
CREATE OR REPLACE TABLE finance_transactions (
    transaction_id INT PRIMARY KEY,
    date DATE NOT NULL,
    account_key INT NOT NULL,
    department_key INT NOT NULL,
    vendor_key INT NOT NULL,
    product_key INT NOT NULL,
    customer_key INT NOT NULL,
    amount DECIMAL(12,2) NOT NULL
);

-- Marketing Campaign Fact Table
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
);

-- HR Employee Fact Table
CREATE OR REPLACE TABLE hr_employee_fact (
    hr_fact_id INT PRIMARY KEY,
    date DATE NOT NULL,
    employee_key INT NOT NULL,
    department_key INT NOT NULL,
    job_key INT NOT NULL,
    location_key INT NOT NULL,
    salary DECIMAL(10,2) NOT NULL,
    attrition_flag INT NOT NULL
);

-- ========================================================================
-- CUSTOMER JOURNEY TABLES (CRM-like)
-- ========================================================================

-- Customer Accounts Table
CREATE OR REPLACE TABLE sf_accounts (
    account_id VARCHAR(20) PRIMARY KEY,
    account_name VARCHAR(200) NOT NULL,
    customer_key INT NOT NULL,
    industry VARCHAR(100),
    vertical VARCHAR(50),
    billing_street VARCHAR(200),
    billing_city VARCHAR(100),
    billing_state VARCHAR(10),
    billing_postal_code VARCHAR(20),
    account_type VARCHAR(50),
    annual_revenue DECIMAL(15,2),
    employees INT,
    created_date DATE
) COMMENT = 'Customer account records - tracks customer profiles and lifetime value';

-- Opportunities Table (conversions)
CREATE OR REPLACE TABLE sf_opportunities (
    opportunity_id VARCHAR(20) PRIMARY KEY,
    sale_id INT,
    account_id VARCHAR(20) NOT NULL,
    opportunity_name VARCHAR(200) NOT NULL,
    stage_name VARCHAR(100) NOT NULL,
    amount DECIMAL(15,2) NOT NULL,
    probability DECIMAL(5,2),
    close_date DATE,
    created_date DATE,
    lead_source VARCHAR(100),
    type VARCHAR(100),
    campaign_id INT
) COMMENT = 'Sales opportunities - tracks customer journey from lead to purchase';

-- Contacts Table (leads)
CREATE OR REPLACE TABLE sf_contacts (
    contact_id VARCHAR(20) PRIMARY KEY,
    opportunity_id VARCHAR(20) NOT NULL,
    account_id VARCHAR(20) NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    email VARCHAR(200),
    phone VARCHAR(50),
    title VARCHAR(100),
    department VARCHAR(100),
    lead_source VARCHAR(100),
    campaign_no INT,
    created_date DATE
) COMMENT = 'Contact/lead records - tracks customer signups and leads';

-- ========================================================================
-- LOAD DIMENSION DATA FROM INTERNAL STAGE
-- ========================================================================

-- Load Product Category Dimension
COPY INTO product_category_dim
FROM @INTERNAL_DATA_STAGE/demo_data/product_category_dim.csv
FILE_FORMAT = CSV_FORMAT
ON_ERROR = 'CONTINUE';

-- Load Product Dimension
COPY INTO product_dim
FROM @INTERNAL_DATA_STAGE/demo_data/product_dim.csv
FILE_FORMAT = CSV_FORMAT
ON_ERROR = 'CONTINUE';

-- Load Vendor Dimension
COPY INTO vendor_dim
FROM @INTERNAL_DATA_STAGE/demo_data/vendor_dim.csv
FILE_FORMAT = CSV_FORMAT
ON_ERROR = 'CONTINUE';

-- Load Customer Dimension
COPY INTO customer_dim
FROM @INTERNAL_DATA_STAGE/demo_data/customer_dim.csv
FILE_FORMAT = CSV_FORMAT
ON_ERROR = 'CONTINUE';

-- Load Account Dimension
COPY INTO account_dim
FROM @INTERNAL_DATA_STAGE/demo_data/account_dim.csv
FILE_FORMAT = CSV_FORMAT
ON_ERROR = 'CONTINUE';

-- Load Department Dimension
COPY INTO department_dim
FROM @INTERNAL_DATA_STAGE/demo_data/department_dim.csv
FILE_FORMAT = CSV_FORMAT
ON_ERROR = 'CONTINUE';

-- Load Region Dimension
COPY INTO region_dim
FROM @INTERNAL_DATA_STAGE/demo_data/region_dim.csv
FILE_FORMAT = CSV_FORMAT
ON_ERROR = 'CONTINUE';

-- Load Sales Rep Dimension
COPY INTO sales_rep_dim
FROM @INTERNAL_DATA_STAGE/demo_data/sales_rep_dim.csv
FILE_FORMAT = CSV_FORMAT
ON_ERROR = 'CONTINUE';

-- Load Campaign Dimension
COPY INTO campaign_dim
FROM @INTERNAL_DATA_STAGE/demo_data/campaign_dim.csv
FILE_FORMAT = CSV_FORMAT
ON_ERROR = 'CONTINUE';

-- Load Channel Dimension
COPY INTO channel_dim
FROM @INTERNAL_DATA_STAGE/demo_data/channel_dim.csv
FILE_FORMAT = CSV_FORMAT
ON_ERROR = 'CONTINUE';

-- Load Employee Dimension
COPY INTO employee_dim
FROM @INTERNAL_DATA_STAGE/demo_data/employee_dim.csv
FILE_FORMAT = CSV_FORMAT
ON_ERROR = 'CONTINUE';

-- Load Job Dimension
COPY INTO job_dim
FROM @INTERNAL_DATA_STAGE/demo_data/job_dim.csv
FILE_FORMAT = CSV_FORMAT
ON_ERROR = 'CONTINUE';

-- Load Location Dimension
COPY INTO location_dim
FROM @INTERNAL_DATA_STAGE/demo_data/location_dim.csv
FILE_FORMAT = CSV_FORMAT
ON_ERROR = 'CONTINUE';

-- ========================================================================
-- LOAD FACT DATA FROM INTERNAL STAGE
-- ========================================================================

-- Load Sales Fact
COPY INTO sales_fact
FROM @INTERNAL_DATA_STAGE/demo_data/sales_fact.csv
FILE_FORMAT = CSV_FORMAT
ON_ERROR = 'CONTINUE';

-- Load Finance Transactions
COPY INTO finance_transactions
FROM @INTERNAL_DATA_STAGE/demo_data/finance_transactions.csv
FILE_FORMAT = CSV_FORMAT
ON_ERROR = 'CONTINUE';

-- Load Marketing Campaign Fact
COPY INTO marketing_campaign_fact
FROM @INTERNAL_DATA_STAGE/demo_data/marketing_campaign_fact.csv
FILE_FORMAT = CSV_FORMAT
ON_ERROR = 'CONTINUE';

-- Load HR Employee Fact
COPY INTO hr_employee_fact
FROM @INTERNAL_DATA_STAGE/demo_data/hr_employee_fact.csv
FILE_FORMAT = CSV_FORMAT
ON_ERROR = 'CONTINUE';

-- ========================================================================
-- LOAD CUSTOMER JOURNEY DATA FROM INTERNAL STAGE
-- ========================================================================

-- Load Customer Accounts
COPY INTO sf_accounts
FROM @INTERNAL_DATA_STAGE/demo_data/sf_accounts.csv
FILE_FORMAT = CSV_FORMAT
ON_ERROR = 'CONTINUE';

-- Load Opportunities
COPY INTO sf_opportunities
FROM @INTERNAL_DATA_STAGE/demo_data/sf_opportunities.csv
FILE_FORMAT = CSV_FORMAT
ON_ERROR = 'CONTINUE';

-- Load Contacts
COPY INTO sf_contacts
FROM @INTERNAL_DATA_STAGE/demo_data/sf_contacts.csv
FILE_FORMAT = CSV_FORMAT
ON_ERROR = 'CONTINUE';

-- ========================================================================
-- VERIFICATION
-- ========================================================================

-- Verify Git integration and file copy
SHOW GIT REPOSITORIES;

-- Verify data loads
SELECT 'DIMENSION TABLES' as category, '' as table_name, NULL as row_count
UNION ALL
SELECT '', 'product_category_dim', COUNT(*) FROM product_category_dim
UNION ALL
SELECT '', 'product_dim', COUNT(*) FROM product_dim
UNION ALL
SELECT '', 'vendor_dim', COUNT(*) FROM vendor_dim
UNION ALL
SELECT '', 'customer_dim', COUNT(*) FROM customer_dim
UNION ALL
SELECT '', 'account_dim', COUNT(*) FROM account_dim
UNION ALL
SELECT '', 'department_dim', COUNT(*) FROM department_dim
UNION ALL
SELECT '', 'region_dim', COUNT(*) FROM region_dim
UNION ALL
SELECT '', 'sales_rep_dim', COUNT(*) FROM sales_rep_dim
UNION ALL
SELECT '', 'campaign_dim', COUNT(*) FROM campaign_dim
UNION ALL
SELECT '', 'channel_dim', COUNT(*) FROM channel_dim
UNION ALL
SELECT '', 'employee_dim', COUNT(*) FROM employee_dim
UNION ALL
SELECT '', 'job_dim', COUNT(*) FROM job_dim
UNION ALL
SELECT '', 'location_dim', COUNT(*) FROM location_dim
UNION ALL
SELECT '', '', NULL
UNION ALL
SELECT 'FACT TABLES', '', NULL
UNION ALL
SELECT '', 'sales_fact', COUNT(*) FROM sales_fact
UNION ALL
SELECT '', 'finance_transactions', COUNT(*) FROM finance_transactions
UNION ALL
SELECT '', 'marketing_campaign_fact', COUNT(*) FROM marketing_campaign_fact
UNION ALL
SELECT '', 'hr_employee_fact', COUNT(*) FROM hr_employee_fact
UNION ALL
SELECT '', '', NULL
UNION ALL
SELECT 'CUSTOMER JOURNEY TABLES', '', NULL
UNION ALL
SELECT '', 'sf_accounts', COUNT(*) FROM sf_accounts
UNION ALL
SELECT '', 'sf_opportunities', COUNT(*) FROM sf_opportunities
UNION ALL
SELECT '', 'sf_contacts', COUNT(*) FROM sf_contacts;

-- Show all tables
SHOW TABLES IN SCHEMA APP;




-- ========================================================================
-- SEMANTIC VIEWS FOR CORTEX ANALYST
-- ========================================================================
USE ROLE SONOS_INTEL_DEMO_ROLE;
USE DATABASE SONOS_AI_DEMO;
USE SCHEMA APP;

-- ========================================================================
-- SALES/PRODUCT ANALYTICS SEMANTIC VIEW
-- Tracks product sales, revenue, and customer purchases
-- ========================================================================

CREATE OR REPLACE SEMANTIC VIEW SONOS_AI_DEMO.APP.SALES_SEMANTIC_VIEW
	tables (
		SALES as SALES_FACT primary key (SALE_ID) with synonyms=('sales','purchases','transactions','orders') comment='Product sales transactions - fact table with date, product, region, amount, and units',
		PRODUCTS as PRODUCT_DIM primary key (PRODUCT_KEY) with synonyms=('products','devices','speakers','soundbars','items') comment='Sonos products: Arc, Beam, Era, Move, Roam, Sub, Amp',
		CATEGORIES as PRODUCT_CATEGORY_DIM primary key (CATEGORY_KEY) with synonyms=('product categories','categories') comment='Product categories: Soundbars, Smart Speakers, Portable Speakers',
		REGIONS as REGION_DIM primary key (REGION_KEY) with synonyms=('regions','markets','territories') comment='Geographic regions: North America, Europe, APAC, Latin America',
		CUSTOMERS as CUSTOMER_DIM primary key (CUSTOMER_KEY) with synonyms=('customers','buyers','purchasers') comment='Sonos customers who purchase products'
	)
	relationships (
		SALES_TO_PRODUCTS as SALES(PRODUCT_KEY) references PRODUCTS(PRODUCT_KEY),
		SALES_TO_REGIONS as SALES(REGION_KEY) references REGIONS(REGION_KEY),
		SALES_TO_CUSTOMERS as SALES(CUSTOMER_KEY) references CUSTOMERS(CUSTOMER_KEY),
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
		PRODUCTS.PRODUCT_NAME as product_name with synonyms=('product','device','speaker','model') comment='Sonos product name (Arc, Beam, Era 100, Era 300, Move 2, Roam, Sub, Amp)',
		PRODUCTS.PRODUCT_KEY as PRODUCT_KEY,
		CATEGORIES.CATEGORY_NAME as CATEGORY_NAME with synonyms=('category','product category','product line') comment='Product category: Soundbars, Smart Speakers, Portable Speakers, Subwoofers, Amplifiers',
		CATEGORIES.VERTICAL as VERTICAL with synonyms=('vertical','product vertical') comment='Product vertical: Home Audio, Portable Audio, Accessories',
		REGIONS.REGION_NAME as region_name with synonyms=('region','market','territory') comment='Geographic region',
		REGIONS.REGION_KEY as REGION_KEY,
		CUSTOMERS.INDUSTRY as INDUSTRY with synonyms=('customer segment','customer type') comment='Customer demographic segment',
		CUSTOMERS.CUSTOMER_NAME as customer_name with synonyms=('customer','buyer') comment='Customer identifier'
	)
	metrics (
		SALES.TOTAL_REVENUE as SUM(sales.amount) comment='Total revenue from product sales',
		SALES.TOTAL_UNITS as SUM(sales.units) comment='Total units sold',
		SALES.TOTAL_DEALS as COUNT(sales.sale_record) comment='Total number of sales transactions',
		SALES.AVERAGE_DEAL_SIZE as AVG(sales.amount) comment='Average sale amount per transaction',
		SALES.AVERAGE_UNITS_PER_SALE as AVG(sales.units) comment='Average units per sale'
	)
	comment='Semantic view for Sonos product sales analytics - tracks product purchases, revenue, and units sold';


-- ========================================================================
-- MARKETING CAMPAIGN SEMANTIC VIEW (SIMPLIFIED)
-- Tracks marketing campaign performance, spend, and ROI
-- ========================================================================

CREATE OR REPLACE SEMANTIC VIEW SONOS_AI_DEMO.APP.MARKETING_SEMANTIC_VIEW
	tables (
		CAMPAIGNS as MARKETING_CAMPAIGN_FACT primary key (CAMPAIGN_FACT_ID) with synonyms=('campaigns','marketing activities','marketing data') comment='Marketing campaign performance - daily spend, impressions, and leads by campaign/channel/product',
		CAMPAIGN_DETAILS as CAMPAIGN_DIM primary key (CAMPAIGN_KEY) with synonyms=('campaign info','campaign names') comment='Campaign names and objectives',
		CHANNELS as CHANNEL_DIM primary key (CHANNEL_KEY) with synonyms=('channels','marketing channels') comment='Marketing channels: Paid Search, YouTube, Retail eCom, Email, Social Media',
		PRODUCTS as PRODUCT_DIM primary key (PRODUCT_KEY) with synonyms=('products','items') comment='Sonos products featured in campaigns',
		REGIONS as REGION_DIM primary key (REGION_KEY) with synonyms=('regions','markets') comment='Geographic regions targeted by campaigns'
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
		CAMPAIGNS.CAMPAIGN_KEY as CAMPAIGN_KEY,
		CAMPAIGNS.CHANNEL_KEY as CHANNEL_KEY,
		CAMPAIGNS.PRODUCT_KEY as PRODUCT_KEY,
		CAMPAIGNS.REGION_KEY as REGION_KEY,
		CAMPAIGN_DETAILS.CAMPAIGN_NAME as campaign_name with synonyms=('campaign','campaign title') comment='Campaign name (e.g., Arc Upgrade Promo Q3 2025)',
		CAMPAIGN_DETAILS.CAMPAIGN_OBJECTIVE as objective with synonyms=('objective','goal','campaign type') comment='Campaign objective (Product Launch, Seasonal Promotion, Lead Generation)',
		CHANNELS.CHANNEL_NAME as channel_name with synonyms=('channel','marketing channel') comment='Marketing channel (Paid Search, YouTube, Retail eCom, Social Media, Email)',
		PRODUCTS.PRODUCT_NAME as product_name with synonyms=('product','device') comment='Sonos product name (Arc, Beam, Era 100, Move 2, Roam, etc.)',
		REGIONS.REGION_NAME as region_name with synonyms=('region','market') comment='Geographic region'
	)
	metrics (
		CAMPAIGNS.TOTAL_SPEND as SUM(campaigns.spend) comment='Total marketing spend',
		CAMPAIGNS.TOTAL_IMPRESSIONS as SUM(campaigns.impressions) comment='Total ad impressions',
		CAMPAIGNS.TOTAL_LEADS as SUM(campaigns.leads_generated) comment='Total leads generated',
		CAMPAIGNS.TOTAL_ACTIVITIES as COUNT(campaigns.campaign_record) comment='Total campaign activity days',
		CAMPAIGNS.AVERAGE_SPEND as AVG(campaigns.spend) comment='Average daily spend',
		CAMPAIGNS.COST_PER_LEAD as SUM(campaigns.spend) / NULLIF(SUM(campaigns.leads_generated), 0) comment='Cost per lead (CAC)',
		CAMPAIGNS.COST_PER_IMPRESSION as SUM(campaigns.spend) / NULLIF(SUM(campaigns.impressions), 0) * 1000 comment='CPM (cost per thousand impressions)'
	)
	comment='Semantic view for Sonos marketing campaign analytics - tracks spend, impressions, leads, and ROI by campaign/channel/product';


-- ========================================================================
-- FINANCE TRANSACTIONS SEMANTIC VIEW
-- ========================================================================

CREATE OR REPLACE SEMANTIC VIEW SONOS_AI_DEMO.APP.FINANCE_SEMANTIC_VIEW
    tables (
        TRANSACTIONS as FINANCE_TRANSACTIONS primary key (TRANSACTION_ID) with synonyms=('transactions','financial transactions') comment='Financial transactions',
        ACCOUNTS as ACCOUNT_DIM primary key (ACCOUNT_KEY) with synonyms=('accounts') comment='Account types',
        DEPARTMENTS as DEPARTMENT_DIM primary key (DEPARTMENT_KEY) with synonyms=('departments') comment='Departments',
        VENDORS as VENDOR_DIM primary key (VENDOR_KEY) with synonyms=('vendors','partners') comment='Vendors and partners',
        PRODUCTS as PRODUCT_DIM primary key (PRODUCT_KEY) with synonyms=('products') comment='Products',
        CUSTOMERS as CUSTOMER_DIM primary key (CUSTOMER_KEY) with synonyms=('customers') comment='Customers'
    )
    relationships (
        TRANSACTIONS_TO_ACCOUNTS as TRANSACTIONS(ACCOUNT_KEY) references ACCOUNTS(ACCOUNT_KEY),
        TRANSACTIONS_TO_DEPARTMENTS as TRANSACTIONS(DEPARTMENT_KEY) references DEPARTMENTS(DEPARTMENT_KEY),
        TRANSACTIONS_TO_VENDORS as TRANSACTIONS(VENDOR_KEY) references VENDORS(VENDOR_KEY),
        TRANSACTIONS_TO_PRODUCTS as TRANSACTIONS(PRODUCT_KEY) references PRODUCTS(PRODUCT_KEY),
        TRANSACTIONS_TO_CUSTOMERS as TRANSACTIONS(CUSTOMER_KEY) references CUSTOMERS(CUSTOMER_KEY)
    )
    facts (
        TRANSACTIONS.AMOUNT as amount comment='Transaction amount',
        TRANSACTIONS.TRANSACTION_RECORD as 1 comment='Transaction count'
    )
    dimensions (
        TRANSACTIONS.DATE as date with synonyms=('date','transaction date') comment='Transaction date',
        TRANSACTIONS.TRANSACTION_MONTH as MONTH(date),
        TRANSACTIONS.TRANSACTION_YEAR as YEAR(date),
        ACCOUNTS.ACCOUNT_NAME as account_name,
        ACCOUNTS.ACCOUNT_TYPE as account_type,
        DEPARTMENTS.DEPARTMENT_NAME as department_name,
        VENDORS.VENDOR_NAME as vendor_name,
        PRODUCTS.PRODUCT_NAME as product_name,
        CUSTOMERS.CUSTOMER_NAME as customer_name
    )
    metrics (
        TRANSACTIONS.AVERAGE_AMOUNT as AVG(transactions.amount),
        TRANSACTIONS.TOTAL_AMOUNT as SUM(transactions.amount),
        TRANSACTIONS.TOTAL_TRANSACTIONS as COUNT(transactions.transaction_record)
    )
    comment='Semantic view for Sonos finance analytics';


-- ========================================================================
-- HR/TEAM PERFORMANCE SEMANTIC VIEW
-- ========================================================================

CREATE OR REPLACE SEMANTIC VIEW SONOS_AI_DEMO.APP.HR_SEMANTIC_VIEW
	tables (
		DEPARTMENTS as DEPARTMENT_DIM primary key (DEPARTMENT_KEY) with synonyms=('departments','teams') comment='Sonos departments and teams',
		EMPLOYEES as EMPLOYEE_DIM primary key (EMPLOYEE_KEY) with synonyms=('employees','team members','staff') comment='Sonos team members',
		HR_RECORDS as HR_EMPLOYEE_FACT primary key (HR_FACT_ID) with synonyms=('employee records','team data') comment='Employee records',
		JOBS as JOB_DIM primary key (JOB_KEY) with synonyms=('roles','positions','job titles') comment='Job roles',
		LOCATIONS as LOCATION_DIM primary key (LOCATION_KEY) with synonyms=('locations','offices') comment='Work locations'
	)
	relationships (
		HR_TO_DEPARTMENTS as HR_RECORDS(DEPARTMENT_KEY) references DEPARTMENTS(DEPARTMENT_KEY),
		HR_TO_EMPLOYEES as HR_RECORDS(EMPLOYEE_KEY) references EMPLOYEES(EMPLOYEE_KEY),
		HR_TO_JOBS as HR_RECORDS(JOB_KEY) references JOBS(JOB_KEY),
		HR_TO_LOCATIONS as HR_RECORDS(LOCATION_KEY) references LOCATIONS(LOCATION_KEY)
	)
	facts (
		HR_RECORDS.ATTRITION_FLAG as attrition_flag with synonyms=('turnover','departure flag') comment='Attrition flag (0=active, 1=departed)',
		HR_RECORDS.EMPLOYEE_RECORD as 1 comment='Employee record count',
		HR_RECORDS.EMPLOYEE_SALARY as salary comment='Employee salary'
	)
	dimensions (
		DEPARTMENTS.DEPARTMENT_KEY as DEPARTMENT_KEY,
		DEPARTMENTS.DEPARTMENT_NAME as department_name with synonyms=('department','team') comment='Department name',
		EMPLOYEES.EMPLOYEE_KEY as EMPLOYEE_KEY,
		EMPLOYEES.EMPLOYEE_NAME as employee_name with synonyms=('employee','team member') comment='Employee name',
		EMPLOYEES.GENDER as gender,
		EMPLOYEES.HIRE_DATE as hire_date,
		HR_RECORDS.DEPARTMENT_KEY as DEPARTMENT_KEY,
		HR_RECORDS.EMPLOYEE_KEY as EMPLOYEE_KEY,
		HR_RECORDS.HR_FACT_ID as HR_FACT_ID,
		HR_RECORDS.JOB_KEY as JOB_KEY,
		HR_RECORDS.LOCATION_KEY as LOCATION_KEY,
		HR_RECORDS.RECORD_DATE as date with synonyms=('date','record date') comment='Record date',
		HR_RECORDS.RECORD_MONTH as MONTH(date),
		HR_RECORDS.RECORD_YEAR as YEAR(date),
		JOBS.JOB_KEY as JOB_KEY,
		JOBS.JOB_LEVEL as job_level,
		JOBS.JOB_TITLE as job_title with synonyms=('job title','position','role') comment='Job title',
		LOCATIONS.LOCATION_KEY as LOCATION_KEY,
		LOCATIONS.LOCATION_NAME as location_name with synonyms=('location','office') comment='Location'
	)
	metrics (
		HR_RECORDS.ATTRITION_COUNT as SUM(hr_records.attrition_flag),
		HR_RECORDS.AVG_SALARY as AVG(hr_records.employee_salary),
		HR_RECORDS.TOTAL_EMPLOYEES as COUNT(hr_records.employee_record),
		HR_RECORDS.TOTAL_SALARY_COST as SUM(hr_records.EMPLOYEE_SALARY)
	)
	comment='Semantic view for Sonos team/HR analytics';

-- ========================================================================
-- VERIFICATION
-- ========================================================================

-- Show all semantic views
SHOW SEMANTIC VIEWS;

-- Show dimensions for each semantic view
SHOW SEMANTIC DIMENSIONS;

-- Show metrics for each semantic view
SHOW SEMANTIC METRICS;




-- ========================================================================
-- UNSTRUCTURED DATA - Parse PDFs and create Cortex Search Services
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


-- Switch to SONOS demo role for remaining operations
USE ROLE SONOS_INTEL_DEMO_ROLE;

-- Create search service for finance documents
CREATE OR REPLACE CORTEX SEARCH SERVICE Search_finance_docs
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
        WHERE relative_path ilike '%/finance/%'
    );
    
-- Create search service for HR documents
CREATE OR REPLACE CORTEX SEARCH SERVICE Search_hr_docs
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
        WHERE relative_path ilike '%/hr/%'
    );

-- Create search service for marketing documents
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

-- Create search service for sales/product documents
CREATE OR REPLACE CORTEX SEARCH SERVICE Search_sales_docs
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


USE ROLE SONOS_INTEL_DEMO_ROLE;


-- ========================================================================
-- EXTERNAL ACCESS FOR WEB SCRAPING
-- ========================================================================

-- Network rule for web access
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

CREATE NOTIFICATION INTEGRATION SONOS_AI_EMAIL_INT
  TYPE=EMAIL
  ENABLED=TRUE;

GRANT USAGE ON DATABASE snowflake_intelligence TO ROLE SONOS_INTEL_DEMO_ROLE;
GRANT USAGE ON SCHEMA snowflake_intelligence.agents TO ROLE SONOS_INTEL_DEMO_ROLE;
GRANT CREATE AGENT ON SCHEMA snowflake_intelligence.agents TO ROLE SONOS_INTEL_DEMO_ROLE;

GRANT USAGE ON INTEGRATION SONOS_INTEL_EAI TO ROLE SONOS_INTEL_DEMO_ROLE;

GRANT USAGE ON INTEGRATION SONOS_AI_EMAIL_INT TO ROLE SONOS_INTEL_DEMO_ROLE;


USE ROLE SONOS_INTEL_DEMO_ROLE;

-- ========================================================================
-- CUSTOM TOOLS - Web Scraper, Email, File Access
-- ========================================================================

-- Create stored procedure to generate presigned URLs for files
CREATE OR REPLACE PROCEDURE Get_File_Presigned_URL_SP(
    RELATIVE_FILE_PATH STRING, 
    EXPIRATION_MINS INTEGER DEFAULT 60
)
RETURNS STRING
LANGUAGE SQL
COMMENT = 'Generates a presigned URL for a file in @INTERNAL_DATA_STAGE'
EXECUTE AS CALLER
AS
$$
DECLARE
    presigned_url STRING;
    sql_stmt STRING;
    expiration_seconds INTEGER;
    stage_name STRING DEFAULT '@SONOS_AI_DEMO.APP.INTERNAL_DATA_STAGE';
BEGIN
    expiration_seconds := EXPIRATION_MINS * 60;

    sql_stmt := 'SELECT GET_PRESIGNED_URL(' || stage_name || ', ' || '''' || RELATIVE_FILE_PATH || '''' || ', ' || expiration_seconds || ') AS url';
    
    EXECUTE IMMEDIATE :sql_stmt;
    
    SELECT "URL"
    INTO :presigned_url
    FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));
    
    RETURN :presigned_url;
END;
$$;

-- Create stored procedure to send emails
CREATE OR REPLACE PROCEDURE send_mail(recipient TEXT, subject TEXT, text TEXT)
RETURNS TEXT
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'send_mail'
AS
$$
def send_mail(session, recipient, subject, text):
    session.call(
        'SYSTEM$SEND_EMAIL',
        'SONOS_AI_EMAIL_INT',
        recipient,
        subject,
        text,
        'text/html'
    )
    return f'Email was sent to {recipient} with subject: "{subject}".'
$$;

-- Create web scraper function
CREATE OR REPLACE FUNCTION Web_scrape(weburl STRING)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = 3.11
HANDLER = 'get_page'
EXTERNAL_ACCESS_INTEGRATIONS = (SONOS_INTEL_EAI)
PACKAGES = ('requests', 'beautifulsoup4')
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
    COMMENT=$$ This is a product analytics agent for Sonos that can answer questions about product sales, marketing campaigns, customer behavior, and provide forecasts and sentiment analysis. $$
FROM SPECIFICATION $$
{
  "models": {
    "orchestration": ""
  },
  "instructions": {
    "response": "You are a product analytics specialist for Sonos, the premium audio technology company. You have access to product sales data, marketing campaign performance, customer information, and team analytics. If user does not specify a date range, default to year 2025 or last 90 days for trends. Provide visualizations when possible - use line charts for trends over time, bar charts for categorical comparisons. Focus on actionable insights for the product team. When analyzing Sonos products, remember: Arc/Beam/Ray are soundbars, Era 100/300 and One are smart speakers, Move 2 and Roam are portable speakers, Sub/Sub Mini are subwoofers, and Amp/Port are amplifiers.",
    "orchestration": "Use cortex search for document retrieval and pass results to cortex analyst for detailed analysis.\n\nKey Context for Sonos:\n- Sales data represents product purchases (Arc, Beam, Era, Move, Roam, etc.)\n- Marketing campaigns track user acquisition across channels (Paid Search, YouTube, Social, etc.)\n- Customers are consumers who purchase Sonos products\n- Products include soundbars, smart speakers, portable speakers, subwoofers, and amplifiers\n- Finance data includes revenue, costs, and vendor relationships\n\nWhen analyzing product metrics:\n- Focus on product mix, attach rates, and ecosystem growth\n- Consider seasonal patterns (holidays, product launches)\n- Look for marketing campaign impact on sales\n- Analyze regional performance differences\n- Use ML functions for forecasting and anomaly detection when appropriate\n\n",
    "sample_questions": [
      {
        "question": "Over the last 90 days in North America, which Sonos product led in units and revenue? Show top 5, with units, revenue, and MoM growth."
      },
      {
        "question": "For the top product, what drove the spike? Break it down by marketing channel and campaign over the last 8 weeks, and correlate with spend and impressions."
      },
      {
        "question": "Forecast the next 4 weeks of units for Sonos Arc and flag any anomalies over the past 12 weeks."
      },
      {
        "question": "Summarize sentiment and top recurring themes from recent Sonos Arc and Move 2 product reviews from tech websites."
      }
    ]
  },
  "tools": [
    {
      "tool_spec": {
        "type": "cortex_analyst_text_to_sql",
        "name": "Query Product Sales Analytics",
        "description": "Analyze Sonos product sales including units sold, revenue, trends by product (Arc, Beam, Era, Move, Roam, etc.), region, and time period. Track which products are selling best and identify growth opportunities."
      }
    },
    {
      "tool_spec": {
        "type": "cortex_analyst_text_to_sql",
        "name": "Query Marketing Campaign Performance",
        "description": "Analyze marketing campaign effectiveness, spend, leads, and attribution to sales. Track channel performance (Paid Search, YouTube, Social Media, Email, etc.) and campaign ROI. Understand which marketing drives product sales."
      }
    },
    {
      "tool_spec": {
        "type": "cortex_analyst_text_to_sql",
        "name": "Query Finance Analytics",
        "description": "Query financial transactions, revenue, costs, and vendor relationships. Analyze financial performance by product, department, and time period."
      }
    },
    {
      "tool_spec": {
        "type": "cortex_analyst_text_to_sql",
        "name": "Query Team Performance",
        "description": "Query team and employee data including staffing levels, departments, and organizational metrics."
      }
    },
    {
      "tool_spec": {
        "type": "cortex_search",
        "name": "Search Financial Policies & Reports",
        "description": "Search Sonos financial policies, reports, vendor contracts, and expense policies."
      }
    },
    {
      "tool_spec": {
        "type": "cortex_search",
        "name": "Search Team & Operations Docs",
        "description": "Search internal documents related to team operations, employee handbooks, performance guidelines, and organizational structure."
      }
    },
    {
      "tool_spec": {
        "type": "cortex_search",
        "name": "Search Marketing Campaign Materials",
        "description": "Search marketing campaign strategies, channel performance reports, campaign plans, and marketing materials."
      }
    },
    {
      "tool_spec": {
        "type": "cortex_search",
        "name": "Search Product Documentation",
        "description": "Search product playbooks, customer success stories, product performance data, and sales materials for Sonos products."
      }
    },
    {
      "tool_spec": {
        "type": "generic",
        "name": "Web_scraper",
        "description": "This tool scrapes and analyzes content from public web pages. Use it to gather sentiment and insights from product reviews, tech blogs, and news articles about Sonos products. Input a web URL (http:// or https://) and receive the text content for analysis.",
        "input_schema": {
          "type": "object",
          "properties": {
            "weburl": {
              "description": "Web URL to scrape (must include http:// or https://). The tool will extract text content from the page.",
              "type": "string"
            }
          },
          "required": [
            "weburl"
          ]
        }
      }
    },
    {
      "tool_spec": {
        "type": "generic",
        "name": "Send_Emails",
        "description": "Send emails to verified recipients with analytics reports and insights. Use HTML formatting for email content.",
        "input_schema": {
          "type": "object",
          "properties": {
            "recipient": {
              "description": "Email recipient address",
              "type": "string"
            },
            "subject": {
              "description": "Email subject line",
              "type": "string"
            },
            "text": {
              "description": "Email content (HTML formatted)",
              "type": "string"
            }
          },
          "required": [
            "text",
            "recipient",
            "subject"
          ]
        }
      }
    },
    {
      "tool_spec": {
        "type": "generic",
        "name": "Dynamic_Doc_URL_Tool",
        "description": "Generates temporary presigned URLs for accessing internal document files. Use this to share documents with stakeholders. Returns a clickable URL that expires after specified time.",
        "input_schema": {
          "type": "object",
          "properties": {
            "expiration_mins": {
              "description": "URL expiration time in minutes (default 5)",
              "type": "number"
            },
            "relative_file_path": {
              "description": "Relative file path from cortex search results",
              "type": "string"
            }
          },
          "required": [
            "expiration_mins",
            "relative_file_path"
          ]
        }
      }
    }
  ],
  "tool_resources": {
    "Dynamic_Doc_URL_Tool": {
      "execution_environment": {
        "query_timeout": 0,
        "type": "warehouse",
        "warehouse": "SONOS_INTEL_WH"
      },
      "identifier": "SONOS_AI_DEMO.APP.GET_FILE_PRESIGNED_URL_SP",
      "name": "GET_FILE_PRESIGNED_URL_SP(VARCHAR, DEFAULT NUMBER)",
      "type": "procedure"
    },
    "Query Product Sales Analytics": {
      "semantic_view": "SONOS_AI_DEMO.APP.SALES_SEMANTIC_VIEW"
    },
    "Query Marketing Campaign Performance": {
      "semantic_view": "SONOS_AI_DEMO.APP.MARKETING_SEMANTIC_VIEW"
    },
    "Query Finance Analytics": {
      "semantic_view": "SONOS_AI_DEMO.APP.FINANCE_SEMANTIC_VIEW"
    },
    "Query Team Performance": {
      "semantic_view": "SONOS_AI_DEMO.APP.HR_SEMANTIC_VIEW"
    },
    "Search Financial Policies & Reports": {
      "id_column": "FILE_URL",
      "max_results": 5,
      "name": "SONOS_AI_DEMO.APP.SEARCH_FINANCE_DOCS",
      "title_column": "TITLE"
    },
    "Search Team & Operations Docs": {
      "id_column": "FILE_URL",
      "max_results": 5,
      "name": "SONOS_AI_DEMO.APP.SEARCH_HR_DOCS",
      "title_column": "TITLE"
    },
    "Search Marketing Campaign Materials": {
      "id_column": "RELATIVE_PATH",
      "max_results": 5,
      "name": "SONOS_AI_DEMO.APP.SEARCH_MARKETING_DOCS",
      "title_column": "TITLE"
    },
    "Search Product Documentation": {
      "id_column": "FILE_URL",
      "max_results": 5,
      "name": "SONOS_AI_DEMO.APP.SEARCH_SALES_DOCS",
      "title_column": "TITLE"
    },
    "Send_Emails": {
      "execution_environment": {
        "query_timeout": 0,
        "type": "warehouse",
        "warehouse": "SONOS_INTEL_WH"
      },
      "identifier": "SONOS_AI_DEMO.APP.SEND_MAIL",
      "name": "SEND_MAIL(VARCHAR, VARCHAR, VARCHAR)",
      "type": "procedure"
    },
    "Web_scraper": {
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
-- DEMO COMPLETE - Final Verification
-- ========================================================================

SHOW TABLES IN SCHEMA APP;
SHOW SEMANTIC VIEWS IN SCHEMA APP;
SHOW CORTEX SEARCH SERVICES IN SCHEMA APP;
SHOW FUNCTIONS LIKE 'WEB_SCRAPE' IN SCHEMA APP;
SHOW FUNCTIONS LIKE 'GET_FILE_PRESIGNED_URL_SP' IN SCHEMA APP;
SHOW AGENTS IN SCHEMA snowflake_intelligence.agents;

-- ========================================================================
-- QUICKSTART GUIDE
-- ========================================================================

SELECT '
========================================================================
SONOS PRODUCT ANALYTICS DEMO - SETUP COMPLETE
========================================================================

AGENT CREATED: SNOWFLAKE_INTELLIGENCE.AGENTS.SONOS_PRODUCT_INTELLIGENCE

TO USE THE AGENT:
1. Navigate to Snowflake UI > AI & ML > Agents
2. Select "Sonos Product Intelligence"
3. Start asking questions!

SAMPLE QUESTIONS:

Q1 - Product Analytics (Simple):
"Over the last 90 days in North America, which Sonos product led in 
units and revenue? Show top 5, with units, revenue, and MoM growth."

Q2 - Marketing Attribution (Why):
"For the top product from the previous question, what drove the spike? 
Break it down by marketing channel and campaign over the last 8 weeks, 
and correlate with spend and impressions."

Q3 - Forecasting & Anomaly Detection:
"Forecast the next 4 weeks of units for Sonos Arc and flag any anomalies 
over the past 12 weeks."

Q4 - Sentiment Analysis (Web Scraping):
"Summarize sentiment and top recurring themes from recent Sonos Arc and 
Move 2 product reviews. Use web scraper on tech review sites."

EXAMPLE URLS FOR Q4 (web scraping):
- https://www.theverge.com/reviews (search for Sonos)
- https://www.cnet.com/reviews/ (search for Sonos)  
- https://www.soundguys.com/reviews/ (search for Sonos)

DATABASE: SONOS_AI_DEMO
SCHEMA: APP
WAREHOUSE: SONOS_INTEL_WH
ROLE: SONOS_INTEL_DEMO_ROLE

DATA LOADED:
- 13 Dimension Tables
- 4 Fact Tables (~45K+ rows total)
- 3 Customer Journey Tables (16K+ rows)
- 12 PDF Documents (Finance, HR, Marketing, Sales)
- 4 Cortex Search Services
- 4 Semantic Views
- 1 Intelligence Agent

========================================================================
' as SETUP_GUIDE;

