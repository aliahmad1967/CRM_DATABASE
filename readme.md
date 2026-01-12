Enterprise CRM Database Architecture (MS SQL Server)

A high-performance, scalable, and multi-tenant CRM database schema designed for Enterprise environments. This repository provides a complete T-SQL implementation featuring recursive hierarchies, automated lead-to-opportunity workflows, and built-in analytical views for business intelligence.

🚀 Features

Multi-tenant Design: Ready for SaaS applications with tenant_id isolation across all core tables to ensure data privacy and security between different organizations.

Account Hierarchies: Supports complex corporate structures allowing for Parent/Child account relationships (HQ vs. Branch offices).

Recursive Reporting: Advanced employee management with self-referencing reports_to chains for organizational charting.

Sales Pipeline: Full Lead-to-Opportunity lifecycle tracking with automated probability-based forecasting.

Polymorphic Activities: A unified activity engine for Calls, Emails, and Meetings that can be dynamically linked to Leads, Accounts, or Opportunities.

BI-Ready Views: Pre-configured SQL views optimized for rendering Sales Funnels, Revenue Forecasts, and Lead Heatmaps in tools like PowerBI, Tableau, or custom JS charts.

🏗️ Schema Overview

The database is built on modern T-SQL standards (UNIQUEIDENTIFIER, NVARCHAR(MAX), DATETIMEOFFSET) and includes the following entity groups:

Identity & Access: Tenants, Roles, Users.

Core CRM: Accounts, Contacts.

Pipeline: Lead_Sources, Leads, Opportunities.

Revenue: Products, Opportunity_Items.

Audit & Engagement: Activities.

🛠️ Installation & Setup

Prerequisites

Microsoft SQL Server 2016 or later.

SQL Server Management Studio (SSMS) or Azure Data Studio.

Deployment

Open SSMS and connect to your SQL instance.

Create a new database:

CREATE DATABASE EnterpriseCRM;
GO


Execute the script: Open the crm_enterprise.sql file and run it against your new database.

Troubleshooting "Error 15404" (Diagram Support)

If you encounter permission issues when creating Database Diagrams in SSMS (usually caused by orphaned database owners), run the following:

USE EnterpriseCRM;
GO
ALTER AUTHORIZATION ON DATABASE::EnterpriseCRM TO [sa];
GO


📊 Analytical Views

This schema includes pre-built views for common dashboard components:

View Name

Purpose

Recommended Chart

view_sales_funnel

Stage-by-stage deal volume and value.

Funnel / Pipeline Chart

view_revenue_forecast

Weighted revenue based on deal probability.

Line or Area Chart

view_lead_conversion

Efficiency of lead sources (LinkedIn, Web, etc).

Heatmap or Pie Chart

📝 License

This project is licensed under the MIT License - see the LICENSE file for details.
