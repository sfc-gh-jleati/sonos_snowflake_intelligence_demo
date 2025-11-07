USE ROLE SONOS_INTEL_DEMO_ROLE;
USE DATABASE SONOS_AI_DEMO;
USE SCHEMA APP;

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
	comment='Semantic view for Sonos product sales analytics - tracks product purchases, revenue, and units sold'
	with extension (CA='{"tables":[{"name":"SALES","dimensions":[{"name":"DATE","sample_values":["2024-01-01","2024-06-15","2025-07-01"]},{"name":"SALE_MONTH"},{"name":"SALE_YEAR"},{"name":"PRODUCT_KEY"}],"facts":[{"name":"AMOUNT"},{"name":"UNITS"},{"name":"SALE_RECORD"}],"metrics":[{"name":"TOTAL_REVENUE"},{"name":"TOTAL_UNITS"},{"name":"TOTAL_DEALS"},{"name":"AVERAGE_DEAL_SIZE"},{"name":"AVERAGE_UNITS_PER_SALE"}]},{"name":"PRODUCTS","dimensions":[{"name":"PRODUCT_KEY"},{"name":"PRODUCT_NAME","sample_values":["Sonos Arc","Sonos Beam (Gen 2)","Sonos Era 100","Sonos Era 300","Sonos Move 2","Sonos Roam","Sonos Sub (Gen 3)","Sonos Amp"]}]},{"name":"CATEGORIES","dimensions":[{"name":"CATEGORY_NAME","sample_values":["Soundbars","Smart Speakers","Portable Speakers","Subwoofers","Amplifiers"]},{"name":"VERTICAL","sample_values":["Home Audio","Portable Audio","Accessories"]}]},{"name":"REGIONS","dimensions":[{"name":"REGION_KEY"},{"name":"REGION_NAME","sample_values":["North America","Europe","APAC","Latin America"]}]},{"name":"CUSTOMERS","dimensions":[{"name":"CUSTOMER_NAME"},{"name":"INDUSTRY","sample_values":["Tech Professional","Audiophile","Home Owner"]}]}],"relationships":[{"name":"SALES_TO_PRODUCTS","relationship_type":"many_to_one"},{"name":"SALES_TO_REGIONS","relationship_type":"many_to_one"},{"name":"SALES_TO_CUSTOMERS","relationship_type":"many_to_one"},{"name":"PRODUCTS_TO_CATEGORIES","relationship_type":"many_to_one"}],"custom_instructions":"- SALES is the fact table containing date, amount, and units. Always start from SALES when aggregating metrics.\n- For time-based queries, filter on SALES.DATE directly before joining to dimension tables.\n- When calculating month-over-month growth, use DATE_TRUNC(''MONTH'', SALES.DATE) to group by month.\n- Join PRODUCTS only when product_name is needed in the output or filter.\n- Join REGIONS only when region filtering or region_name is needed.\n- For performance, apply date and region filters on SALES before joining dimension tables."}');

