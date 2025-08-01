namespace Microsoft.PowerBIReports;

using Microsoft.Projects.RoleCenters;

pageextension 36963 "Project Manager Role Center" extends "Project Manager Role Center"
{
    actions
    {
        addfirst(Sections)
        {
            group("PBI Reports")
            {
                Caption = 'Power BI Reports';
                Image = AnalysisView;
                ToolTip = 'Power BI reports for projects';
                action("Projects Report (Power BI)")
                {
                    ApplicationArea = Basic, Suite;
                    Caption = 'Projects Report (Power BI)';
                    Image = "PowerBI";
                    RunObject = page "Projects Report";
                    Tooltip = 'Open a Power BI Report that offers a consolidated view of all project report pages, conveniently embedded into a single page for easy access.';
                }
                action("Projects Overview (Power BI)")
                {
                    ApplicationArea = Basic, Suite;
                    Caption = 'Projects Overview (Power BI)';
                    Image = "PowerBI";
                    RunObject = page "Projects Overview";
                    Tooltip = 'Open a Power BI Report that provides key insights into project performance with metrics like Percent Complete, Percent Invoiced, Realization Percent, Actual Profit, and Actual Profit Margin. It features visuals comparing Actual vs. Budgeted Costs, highlighting Profit per Project, and organizing projects by Project Manager for streamlined project management.';
                }
                action("Project Tasks (Power BI)")
                {
                    ApplicationArea = Basic, Suite;
                    Caption = 'Project Tasks (Power BI)';
                    Image = "PowerBI";
                    RunObject = page "Project Tasks";
                    Tooltip = 'Open a Power BI Report that details tasks related to each project, with metrics for each task clearly outlined. It presents tasks in a table matrix in a hierarchical view, making it easy to navigate and analyze project task information.';
                }
                action("Project Profitability (Power BI)")
                {
                    ApplicationArea = Basic, Suite;
                    Caption = 'Project Profitability (Power BI)';
                    Image = "PowerBI";
                    RunObject = page "Project Profitability";
                    Tooltip = 'Open a Power BI Report that displays key metrics such as Actuals and Budgeted KPIs, compares actual profit to the initial profit target, and includes a table view of project ledger entries by type.';
                }
                action("Project Realization (Power BI)")
                {
                    ApplicationArea = Basic, Suite;
                    Caption = 'Project Realization (Power BI)';
                    Image = "PowerBI";
                    RunObject = page "Project Realization";
                    Tooltip = 'Open a Power BI Report that features key metrics like Billable Invoice Price and Actual Total Price to support Realization percent per project. Enabling organizations to measure actual performance and achievements against planned or budgeted expectations.';
                }
                action("Project Performance to Budget (Power BI)")
                {
                    ApplicationArea = Basic, Suite;
                    Caption = 'Project Performance to Budget (Power BI)';
                    Image = "PowerBI";
                    RunObject = page "Project Performance to Budget";
                    Tooltip = 'Open a Power BI Report that highlights key metrics, including Budget Total Cost, Actual Total Cost, and the variance and percentage variance from the budget. It features a table that details these metrics by project, offering a clear view of cost performance and deviations from budgeted targets.';
                }
                action("Project Invoiced Sales by Type (Power BI)")
                {
                    ApplicationArea = Basic, Suite;
                    Caption = 'Project Invoiced Sales by Type (Power BI)';
                    Image = "PowerBI";
                    RunObject = page "Project Invoiced Sales by Type";
                    Tooltip = 'Open a Power BI Report that details invoiced sales for a project categorized by line type. It includes key KPIs such as % Invoiced, Billable Invoiced Price, and Billable Total Price, providing a clear overview of project invoicing performance and statistics.';
                }
                action("Project Invd. Sales by Cust. (Power BI)")
                {
                    ApplicationArea = Basic, Suite;
                    Caption = 'Project Invd. Sales by Cust. (Power BI)';
                    Image = "PowerBI";
                    RunObject = page "Project Invd. Sales by Cust.";
                    Tooltip = 'Open a Power BI Report that details invoiced sales for a project, broken down by customer. It includes key KPIs such as % Invoiced, Billable Invoiced Price, and Billable Total Price, offering a clear view of project invoicing by customer. ';
                }
            }
        }
    }
}

