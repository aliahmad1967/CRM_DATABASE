-- ==========================================================
-- ENTERPRISE CRM DATABASE ARCHITECTURE (T-SQL / MS SQL Server)
-- ==========================================================
-- Objective: Designing a High-Performance, Scalable CRM Schema
-- Features: 
-- 1. Multi-tenant Account Hierarchies (Parent/Child Accounts)
-- 2. Advanced Lead-to-Opportunity Workflow
-- 3. RBAC (Role Based Access Control)
-- 4. Audit compliance using Standard Data Types
-- ==========================================================

/* ERD MAP (Conceptual)
[TENANT] 1 --- N [ACCOUNTS]
[ACCOUNTS] 1 --- N [CONTACTS]
[ACCOUNTS] 1 (Parent) --- N (Children) [ACCOUNTS]
[USERS] 1 --- N [OPPORTUNITIES]
[OPPORTUNITIES] N --- N [PRODUCTS] (via OPPORTUNITY_ITEMS)
[ACTIVITIES] (Polymorphic) --- [LEADS/CONTACTS/OPPS]
*/

-- 1. ACCESS CONTROL & TENANCY
CREATE TABLE Tenants (
    tenant_id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    company_name NVARCHAR(255) NOT NULL,
    subscription_plan NVARCHAR(50) DEFAULT 'Standard',
    is_active BIT DEFAULT 1,
    created_at DATETIMEOFFSET DEFAULT SYSDATETIMEOFFSET()
);

CREATE TABLE Roles (
    role_id INT IDENTITY(1,1) PRIMARY KEY,
    role_name NVARCHAR(50) UNIQUE NOT NULL, -- e.g., 'Sales_VP', 'Account_Manager'
    permissions NVARCHAR(MAX) -- SQL Server uses NVARCHAR(MAX) for JSON strings
);

CREATE TABLE Users (
    user_id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    tenant_id UNIQUEIDENTIFIER REFERENCES Tenants(tenant_id),
    role_id INT REFERENCES Roles(role_id),
    first_name NVARCHAR(100),
    last_name NVARCHAR(100),
    email NVARCHAR(255) UNIQUE NOT NULL,
    reports_to UNIQUEIDENTIFIER REFERENCES Users(user_id), -- Recursive Relationship
    is_active BIT DEFAULT 1,
    last_login DATETIMEOFFSET
);

-- 2. CORE CRM ENTITIES
CREATE TABLE Accounts (
    account_id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    tenant_id UNIQUEIDENTIFIER REFERENCES Tenants(tenant_id),
    parent_account_id UNIQUEIDENTIFIER REFERENCES Accounts(account_id), -- Hierarchy support
    account_name NVARCHAR(255) NOT NULL,
    industry NVARCHAR(100),
    annual_revenue DECIMAL(18, 2),
    website_url NVARCHAR(255),
    billing_address NVARCHAR(MAX), -- JSON string
    owner_id UNIQUEIDENTIFIER REFERENCES Users(user_id),
    created_at DATETIMEOFFSET DEFAULT SYSDATETIMEOFFSET()
);

CREATE TABLE Contacts (
    contact_id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    account_id UNIQUEIDENTIFIER REFERENCES Accounts(account_id) ON DELETE CASCADE,
    first_name NVARCHAR(100),
    last_name NVARCHAR(100),
    email NVARCHAR(255),
    phone NVARCHAR(50),
    job_title NVARCHAR(100),
    is_primary_contact BIT DEFAULT 0,
    opt_in_marketing BIT DEFAULT 1
);

-- 3. SALES PIPELINE
CREATE TABLE Lead_Sources (
    source_id INT IDENTITY(1,1) PRIMARY KEY,
    source_name NVARCHAR(100) -- 'Web', 'Referral', 'Trade Show'
);

CREATE TABLE Leads (
    lead_id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    tenant_id UNIQUEIDENTIFIER REFERENCES Tenants(tenant_id),
    source_id INT REFERENCES Lead_Sources(source_id),
    first_name NVARCHAR(100),
    last_name NVARCHAR(100),
    company NVARCHAR(255),
    status NVARCHAR(50) DEFAULT 'New', -- 'New', 'Qualified', 'Converted', 'Lost'
    assigned_to UNIQUEIDENTIFIER REFERENCES Users(user_id),
    lead_score INT DEFAULT 0,
    converted_at DATETIME2,
    converted_contact_id UNIQUEIDENTIFIER REFERENCES Contacts(contact_id)
);

CREATE TABLE Opportunities (
    opportunity_id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    account_id UNIQUEIDENTIFIER REFERENCES Accounts(account_id),
    contact_id UNIQUEIDENTIFIER REFERENCES Contacts(contact_id), -- Decision maker
    owner_id UNIQUEIDENTIFIER REFERENCES Users(user_id),
    opportunity_name NVARCHAR(255),
    stage NVARCHAR(50), -- 'Discovery', 'Proposal', 'Negotiation', 'Closed Won'
    amount DECIMAL(18, 2),
    probability INT CHECK (probability BETWEEN 0 AND 100),
    forecast_category NVARCHAR(50),
    expected_close_date DATE,
    created_at DATETIMEOFFSET DEFAULT SYSDATETIMEOFFSET()
);

-- 4. PRODUCTS & REVENUE
CREATE TABLE Products (
    product_id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    sku NVARCHAR(100) UNIQUE,
    product_name NVARCHAR(255),
    unit_price DECIMAL(18, 2),
    is_subscription BIT DEFAULT 0
);

CREATE TABLE Opportunity_Items (
    item_id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    opportunity_id UNIQUEIDENTIFIER REFERENCES Opportunities(opportunity_id),
    product_id UNIQUEIDENTIFIER REFERENCES Products(product_id),
    quantity INT DEFAULT 1,
    discount_percentage DECIMAL(5, 2) DEFAULT 0.00,
    total_price DECIMAL(18, 2) -- Calculated in Application logic or via Trigger
);

-- 5. ACTIVITY TRACKING & AUDIT
CREATE TABLE Activities (
    activity_id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    owner_id UNIQUEIDENTIFIER REFERENCES Users(user_id),
    activity_type NVARCHAR(50), -- 'Call', 'Email', 'Meeting', 'Task'
    subject NVARCHAR(255),
    description NVARCHAR(MAX),
    due_date DATETIME2,
    status NVARCHAR(20), -- 'Pending', 'Completed'
    -- Polymorphic Associations (Manual Implementation)
    related_to_type NVARCHAR(50), -- 'Lead', 'Account', 'Opportunity'
    related_to_id UNIQUEIDENTIFIER,
    created_at DATETIME2 DEFAULT GETDATE()
);

-- 6. PERFORMANCE INDEXING (SQL Server Syntax)
CREATE INDEX idx_tenant_accounts ON Accounts(tenant_id);
CREATE INDEX idx_lead_status ON Leads(status);
CREATE INDEX idx_opp_stage_amount ON Opportunities(stage, amount);
-- Note: SQL Server uses Full-Text Search Catalog for GIN-like functionality. 
-- For basic performance:
CREATE INDEX idx_contact_email ON Contacts(email);

GO

-- 7. ANALYTICAL VIEWS FOR CHARTS
-- 7a. Sales Funnel View
CREATE OR ALTER VIEW view_sales_funnel AS
SELECT 
    stage,
    COUNT(*) as deal_count,
    SUM(amount) as total_value,
    ROUND(AVG(CAST(probability AS FLOAT)), 2) as avg_probability
FROM Opportunities
GROUP BY stage;
GO

-- 7b. Weighted Revenue Forecast
CREATE OR ALTER VIEW view_revenue_forecast AS
SELECT 
    DATEFROMPARTS(YEAR(expected_close_date), MONTH(expected_close_date), 1) as forecast_month,
    SUM(amount * (probability / 100.0)) as weighted_forecast,
    SUM(amount) as raw_pipeline_value
FROM Opportunities
WHERE stage NOT LIKE 'Closed%'
GROUP BY YEAR(expected_close_date), MONTH(expected_close_date);
GO

-- 7c. Lead Conversion Heatmap (By Source)
CREATE OR ALTER VIEW view_lead_conversion_by_source AS
SELECT 
    ls.source_name,
    COUNT(l.lead_id) as total_leads,
    COUNT(CASE WHEN l.status = 'Converted' THEN 1 END) as converted_count,
    ROUND(CAST(COUNT(CASE WHEN l.status = 'Converted' THEN 1 END) AS FLOAT) / NULLIF(COUNT(l.lead_id), 0) * 100, 2) as conversion_rate
FROM Leads l
JOIN Lead_Sources ls ON l.source_id = ls.source_id
GROUP BY ls.source_name;
GO

-- 8. SAMPLE DATA INSERTION (T-SQL Procedural)
BEGIN
    DECLARE @v_tenant_id UNIQUEIDENTIFIER = NEWID();
    DECLARE @v_vp_id UNIQUEIDENTIFIER = NEWID();
    DECLARE @v_mgr_id UNIQUEIDENTIFIER = NEWID();
    DECLARE @v_parent_acc_id UNIQUEIDENTIFIER = NEWID();
    DECLARE @v_child_acc_id UNIQUEIDENTIFIER = NEWID();
    DECLARE @v_contact_id UNIQUEIDENTIFIER = NEWID();
    DECLARE @v_prod_id UNIQUEIDENTIFIER = NEWID();
    DECLARE @v_opp_id UNIQUEIDENTIFIER = NEWID();

    -- Insert Tenant
    INSERT INTO Tenants (tenant_id, company_name, subscription_plan) 
    VALUES (@v_tenant_id, 'Global Tech Solutions', 'Enterprise');

    -- Insert Roles
    INSERT INTO Roles (role_name, permissions) VALUES 
    ('Sales_VP', '{"view_all": true, "delete": true}'),
    ('Account_Executive', '{"view_assigned": true, "edit": true}');

    -- Insert Users
    INSERT INTO Users (user_id, tenant_id, role_id, first_name, last_name, email)
    VALUES (@v_vp_id, @v_tenant_id, 1, 'Sarah', 'Connor', 's.connor@globaltech.com');

    INSERT INTO Users (user_id, tenant_id, role_id, first_name, last_name, email, reports_to)
    VALUES (@v_mgr_id, @v_tenant_id, 2, 'John', 'Doe', 'j.doe@globaltech.com', @v_vp_id);

    -- Insert Accounts
    INSERT INTO Accounts (account_id, tenant_id, account_name, industry, annual_revenue, owner_id)
    VALUES (@v_parent_acc_id, @v_tenant_id, 'Acme Corp HQ', 'Manufacturing', 500000000, @v_mgr_id);

    INSERT INTO Accounts (account_id, tenant_id, parent_account_id, account_name, industry, annual_revenue, owner_id)
    VALUES (@v_child_acc_id, @v_tenant_id, @v_parent_acc_id, 'Acme East Division', 'Logistics', 45000000, @v_mgr_id);

    -- Insert Contact
    INSERT INTO Contacts (contact_id, account_id, first_name, last_name, email, job_title, is_primary_contact)
    VALUES (@v_contact_id, @v_child_acc_id, 'Alice', 'Smith', 'alice@acme-east.com', 'CTO', 1);

    -- Insert Products
    INSERT INTO Products (product_id, sku, product_name, unit_price, is_subscription)
    VALUES (@v_prod_id, 'SaaS-ENT-001', 'Cloud CRM Suite', 1200.00, 1);

    -- Insert Lead Source
    INSERT INTO Lead_Sources (source_name) VALUES ('LinkedIn Outreach'), ('Webinar'), ('Direct Email');

    -- Insert Sample Leads
    INSERT INTO Leads (tenant_id, source_id, first_name, last_name, company, status, assigned_to, lead_score)
    VALUES 
    (@v_tenant_id, 1, 'Robert', 'Vance', 'Vance Refrigeration', 'Qualified', @v_mgr_id, 85),
    (@v_tenant_id, 2, 'Michael', 'Scott', 'Dunder Mifflin', 'Converted', @v_mgr_id, 95);

    -- Insert Opportunities
    INSERT INTO Opportunities (opportunity_id, account_id, contact_id, owner_id, opportunity_name, stage, amount, probability, expected_close_date)
    VALUES 
    (@v_opp_id, @v_child_acc_id, @v_contact_id, @v_mgr_id, 'Q1 Acme Expansion', 'Proposal', 150000, 60, '2024-06-30');

END
GO
