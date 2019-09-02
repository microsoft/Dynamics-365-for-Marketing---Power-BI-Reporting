# Overview
[Portal with all the details on the resources in this repository and on Marketing Analytics with Power BI](http://powerbi.dynamicsmarketing.org)

[Documentation on the setup in Dynamics 365 Marketing](https://docs.microsoft.com/en-us/dynamics365/customer-engagement/marketing/custom-analytics#set-up--and-connect-it-to-marketing)

[Interactions avaliable building reports](https://docs.microsoft.com/en-us/dynamics365/customer-engagement/marketing/developer/retrieve-interactions-contact#action-parameters)

Instructions for this release
=============================
After opening a template (*.pbit file) in Power BI desktop and filling the parameters please use the drop down option on the "Load" button and press Edit. Then navigate to File / Option and Settings/Options. Under Current File/Privacy select the option "Ignore Privacy Levels". Without that setting the Report will not be able to load data from the different stores.

What's new in this release
==========================
Removed parameter for max amount of interaction files to load, instead new parameter that specifies for how many days back from today the report should load interaction data. Leave that field empty to load interaction from the start of the org (best start with a smaller number and use the Interaction Data Flow report page to identify a good range).
Central interaction loading query, with customizable selection from available Interaction.
Corrected OOTB relations
Improved interaction data flow views to help selecting date range and relevant interactions for custom report, * * Added report view for email leaderboard and updated other views

Description
===========
Download these Power BI templates to start building custom analytics and reports based on your Dynamics 365 for Marketing data. These templates will help you to connect to your Dynamics 365 instance and access its data. The download includes the following templates:
Power BI template for Dynamics 365 for Marketing: Includes the code required to connect to your Dynamics 365 for Marketing data, and also includes functions that you can call to load entity and interaction data with just one line of code. This template provides a basic starting point for building your own custom reports.

About the sample for an email marketing analytics report
========================================================
This sample provides a comprehensive report of your email marketing results, including detailed analytics, charts, and views spread across multiple report pages. You can use this template as-is, or as inspiration for designing your own reports.

# Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.microsoft.com.

When you submit a pull request, a CLA-bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., label, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.
