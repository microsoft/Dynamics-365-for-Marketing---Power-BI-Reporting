section Section1;

shared GetCleanedCRMOrgUrl = ()=> let
    Source = #"@CRMOrgUrl",
    #"Trimmed Text" = Text.TrimEnd(Text.Trim(Source), "/")
in
    #"Trimmed Text";

shared GetCDSTHubSource = ()=>
let
    Source = Cds.Contents(GetCleanedCRMOrgUrl(), [ReorderColumns=null, UseFormattedValue=null])
in
    Source;

shared #"#CDST_CDMProfiles" = let
    Source = GetCDSTHubSource(),
    
    CustomProfiles = Source{[Group="cdm"]}[Data],
    CoreTable = Table.SelectColumns(CustomProfiles,{"EntitySetName", "SchemaName"}),
    Result = Table.Buffer(CoreTable)
in
    Result;

shared #"#CDST_CustomProfiles" = let
    Source = GetCDSTHubSource(),
    
    CustomProfiles = Source{[Group="custom"]}[Data],
    #"Sorted Rows" = Table.Sort(CustomProfiles,{{"EntitySetName", Order.Ascending}}),
    CoreTable = Table.SelectColumns(#"Sorted Rows",{"EntitySetName", "SchemaName"}),
    Result = Table.Buffer(CoreTable)
in
    Result;

shared #"#CDST_SystemProfiles" = let
    Source = GetCDSTHubSource(),
    
    CustomProfiles = Source{[Group="system"]}[Data],
    CoreTable = Table.SelectColumns(CustomProfiles,{"Name"}),
    Result = Table.Buffer(CoreTable)
in
    Result;

[ Description = "Loads the table of profile instances for a specific CDM Profile" ]
shared GetCDST_CDMProfileTable = (#"schema name" as text) =>
        let
            Source = GetCDSTHubSource(),
            Entities = Source{[Group="cdm"]}[Data],
            DataTable = Entities{[SchemaName=#"schema name"]}[Data]
        in
            DataTable;

shared fnDateTable = let
    Source = (StartDate) =>
let
    EndDate = Date.From(Date.AddMonths(Date.EndOfYear(DateTime.LocalNow()),1)),
    //Create lists of month and day names for use later on
    MonthList = {"January", "February", "March", "April", "May", "June"
                 , "July", "August", "September", "October", "November", "December"},
    DayList = {"Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"},
 
    //Find the number of days between the end date and the start date
    NumberOfDates = Duration.Days(EndDate-StartDate)+1,
    //Generate a continuous list of dates from the start date to the end date
    DateList = List.Dates(StartDate, NumberOfDates, #duration(1, 0, 0, 0)),

    //Turn this list into a table
    TableFromList = Table.FromList(DateList, Splitter.SplitByNothing(), {"Date"}
                     , null, ExtraValues.Error),
    //Caste the single column in the table to type date
    ChangedType = Table.TransformColumnTypes(TableFromList,{{"Date", type date}}),

    //Add custom columns for day of month, month number, year
    DayOfMonth = Table.AddColumn(ChangedType, "DayOfMonth", each Date.Day([Date])),
    MonthNumber = Table.AddColumn(DayOfMonth, "MonthNumberOfYear", each Date.Month([Date])),
    Year = Table.AddColumn(MonthNumber, "Year", each Date.Year([Date])),
    DayOfWeekNumber = Table.AddColumn(Year, "DayOfWeekNumber", each Date.DayOfWeek([Date])+1),

    //Since Power Query doesn't have functions to return day or month names, 
    //use the lists created earlier for this
    MonthName = Table.AddColumn(DayOfWeekNumber, "MonthName", each MonthList{[MonthNumberOfYear]-1}),
    DayName = Table.AddColumn(MonthName, "DayName", each DayList{[DayOfWeekNumber]-1}),
    //use the System Date to determine Today
    IsToday = Table.AddColumn(DayName, "IsToday", each Date.IsInCurrentDay([Date])),
    WeekEnding = Table.AddColumn(IsToday, "Week Ending", each Date.EndOfWeek([Date])),
    //Group Dates into bands of Last7Days, Last30Days, Last90Days, Last180Days, Last360Days
    TodayFunction = DateTime.FixedLocalNow,
    Today = Table.AddColumn(WeekEnding, "Today", each TodayFunction()),

    #"Changed Type" = Table.TransformColumnTypes(Today,{{"Today", type date}}),
    #"Added Custom" = Table.AddColumn(#"Changed Type", "DaysFromToday", each [Date]-[Today]),
    #"Changed DaysFromToday" = Table.TransformColumnTypes(#"Added Custom",{{"DaysFromToday", Int64.Type}, {"MonthNumberOfYear", Int64.Type}, {"Year", Int64.Type}, {"DayOfWeekNumber", Int64.Type}}),

    #"Duplicated Column1" = Table.DuplicateColumn(#"Changed DaysFromToday", "Date", "DateValue"),
    #"Changed Type2" = Table.TransformColumnTypes(#"Duplicated Column1",{{"DateValue", Int64.Type}, {"Today", Int64.Type}}),
    #"Removed Columns" = Table.RemoveColumns(#"Changed Type2",{"Today", "DateValue"})
in
    #"Removed Columns"
in
    Source;

shared ActivityContactBlocked = let
    Source = GetInteractionTableData("ActivityContactBlocked")
in
    Source;

shared #"&DateTable" = let
    Source = fnDateTable(Date.FromText("1/8/2018")),
    #"Changed Type" = Table.TransformColumnTypes(Source,{{"Week Ending", type date}}),
    #"Added Month-Year" = Table.AddColumn(#"Changed Type", "Month-Year", each Text.Start([MonthName],3)&"-"&Text.From([Year])),
    #"Added MonthYearSortBy" = Table.AddColumn(#"Added Month-Year", "MonthYearSortBy", each [Year]*100+[MonthNumberOfYear]),
    #"Changed Type1" = Table.TransformColumnTypes(#"Added MonthYearSortBy",{{"Week Ending", type date}, {"MonthYearSortBy", Int64.Type}, {"IsToday", type logical}, {"DayOfMonth", Int64.Type}}),
    CoreTable = Table.RenameColumns(#"Changed Type1",{{"Date", "Datestamp"}}),
    Result = Table.Buffer(CoreTable)
in
    Result;

[ Description = "Loads the table of profile instances for a specific custom Profile" ]
shared GetCDST_CustomProfileTable = (#"schema name" as text) =>
        let
            Source = GetCDSTHubSource(),
            Entities = Source{[Group="custom"]}[Data],
            DataTable = Entities{[SchemaName=#"schema name"]}[Data]
        in
            DataTable;

shared Accounts = let
    Accounts = GetCDST_CDMProfileTable("Account"),
    #"Removed Other Columns" = Table.SelectColumns(Accounts,{"accountid", "accountnumber", "createdby", "createdon", "customertypecode", "customertypecode_display", "emailaddress1", "modifiedby", "modifiedon", "name", "statecode", "statecode_display", "statuscode", "statuscode_display", "telephone1", "websiteurl"})
in
    #"Removed Other Columns";

shared Leads = let
    Leads = GetCDST_CDMProfileTable("Lead"),
    #"Removed Other Columns" = Table.SelectColumns(Leads,{"accountid", "address1_city", "address1_country", "address1_line1", "address1_name", "address1_postalcode", "emailaddress1", "fullname", "msdyncrm_contactid", "msdyncrm_customerjourneyid", "msdyncrm_emailid", "msdyncrm_latestsubmissiondate", "msdyncrm_leadid", "msdyncrm_leadsourcetype", "msdyncrm_leadsourcetype_display", "msdyncrm_linkedincampaign", "msdyncrm_linkedinsubmissioncount", "msdyncrm_marketingformid", "msdyncrm_marketingpageid", "msdyncrm_salesaccepted", "msdyncrm_salesready", "statecode", "statuscode", "subject", "telephone1", "websiteurl"})
in
    #"Removed Other Columns";

shared CustomerJourneys = let
    source = GetCDST_CustomProfileTable("msdyncrm_customerjourney"),
    #"Changed Type" = Table.TransformColumnTypes(source,{{"createdon", type date}, {"msdyncrm_startdatetime", type date}, {"msdyncrm_enddatetime", type date}}),
    #"Renamed Columns" = Table.RenameColumns(#"Changed Type",{{"msdyncrm_name", "Journey Name"}, {"msdyncrm_type_display", "Journey Type"}, {"msdyncrm_enddatetime", "Jorney End"}, {"msdyncrm_description", "Description"}, {"msdyncrm_entitytarget_display", "Target audience"}, {"msdyncrm_startdatetime", "Journey Start"}, {"msdyncrm_customerjourneyid", "CustomerJourneyId"}, {"statuscode_display", "Journey Status"}})
in
    #"Renamed Columns";

shared CustomerJourneysEmails = let
    source = GetCDST_CustomProfileTable("msdyncrm_customerjourney_msdyncrm_marketingemail"),
    #"Removed Columns" = Table.RemoveColumns(source,{"versionnumber"}),
    #"Renamed Columns" = Table.RenameColumns(#"Removed Columns",{{"msdyncrm_customerjourneyid", "CustomerJourneyId"}, {"msdyncrm_marketingemailid", "MessageId"}, {"msdyncrm_customerjourney_msdyncrm_marketingemailid", "Id"}}),
    #"Merged Journeys" = Table.NestedJoin(#"Renamed Columns",{"CustomerJourneyId"},CustomerJourneys,{"CustomerJourneyId"},"CustomerJourneys",JoinKind.LeftOuter),
    #"Merged MarketingEmails" = Table.NestedJoin(#"Merged Journeys",{"MessageId"},MarketingEmails,{"MessageId"},"MarketingEmails",JoinKind.LeftOuter),
    #"Expanded CustomerJourneys" = Table.ExpandTableColumn(#"Merged MarketingEmails", "CustomerJourneys", {"Jorney End", "Journey Name", "Journey Start", "Journey Status"}, {"Jorney End", "Journey Name", "Journey Start", "Journey Status"}),
    #"Expanded MarketingEmails" = Table.ExpandTableColumn(#"Expanded CustomerJourneys", "MarketingEmails", {"Message Name"}, {"Message Name"})
in
    #"Expanded MarketingEmails";

shared MarketingEmails = let
    source = GetCDST_CustomProfileTable("msdyncrm_marketingemail"),
    #"Removed Other Columns" = Table.SelectColumns(source,{"createdby", "createdon", "modifiedby", "modifiedon", "msdyncrm_clickmap", "msdyncrm_description", "msdyncrm_email_contenttype", "msdyncrm_email_contenttype_display", "msdyncrm_fromemail", "msdyncrm_fromname", "msdyncrm_fromuser", "msdyncrm_insights_placeholder", "msdyncrm_istemplategalleryneeded", "msdyncrm_marketingemailid", "msdyncrm_messagedesignation", "msdyncrm_messagedesignation_display", "msdyncrm_name", "msdyncrm_replytoemail", "msdyncrm_subject", "msdyncrm_templateid", "msdyncrm_to", "msdyncrm_uicentityid", "overriddencreatedon", "ownerid", "owningbusinessunit", "owningteam", "owninguser", "statecode", "statecode_display", "statuscode", "statuscode_display", "timezoneruleversionnumber", "utcconversiontimezonecode", "versionnumber"}),
    #"Changed Type" = Table.TransformColumnTypes(#"Removed Other Columns",{{"createdon", type date}, {"modifiedon", type date}}),
    #"Renamed Columns" = Table.RenameColumns(#"Changed Type",{{"msdyncrm_name", "Message Name"}, {"msdyncrm_subject", "Subject"}, {"msdyncrm_fromname", "From Name"}, {"msdyncrm_description", "Description"}, {"msdyncrm_messagedesignation_display", "Designation"}, {"msdyncrm_email_contenttype_display", "Content Type"}, {"msdyncrm_marketingemailid", "MessageId"}, {"msdyncrm_fromemail", "From Email Address"}, {"msdyncrm_fromuser", "From User Id"}, {"msdyncrm_templateid", "TemplateId"}, {"statuscode_display", "Status"}})
in
    #"Renamed Columns";

shared MarketingEmailDynamicContentMetaData = let
    source = GetCDST_CustomProfileTable("msdyncrm_marketingemaildynamiccontentmetadata")
in
    source;

shared MarketingEmailTemplates = let
    source = GetCDST_CustomProfileTable("msdyncrm_marketingemailtemplate"),
    #"Removed Columns" = Table.RemoveColumns(source,{"msdyncrm_designerhtml", "msdyncrm_emailbody", "msdyncrm_email_template_purpose_optionset", "msdyncrm_email_template_optimizedfor_optionset", "msdyncrm_email_template_market_type_optionset", "msdyncrm_email_contenttype"}),
    #"Added Custom" = Table.AddColumn(#"Removed Columns", "Template Image", each GetCleanedCRMOrgUrl()&[entityimage_url]),
    #"Changed Type" = Table.TransformColumnTypes(#"Added Custom",{{"createdon", type date}, {"entityimage_timestamp", Int64.Type}, {"modifiedon", type date}}),
    #"Renamed Columns" = Table.RenameColumns(#"Changed Type",{{"msdyncrm_email_contenttype_display", "Content Type"}, {"msdyncrm_name", "Template Name"}, {"msdyncrm_messagedesignation_display", "Designation"}, {"msdyncrm_email_template_visual_style_optionset_display", "Visual Style"}, {"msdyncrm_email_template_purpose_optionset_display", "Purpose"}, {"msdyncrm_email_template_optimizedfor_optionset_display", "Optimized For"}, {"msdyncrm_marketingemailtemplateid", "TemplateId"}, {"msdyncrm_language_display", "Language"}}),
    #"Changed Type1" = Table.TransformColumnTypes(#"Renamed Columns",{{"Template Image", type text}}),
    #"Removed Columns1" = Table.RemoveColumns(#"Changed Type1",{"entityimage_url"}),
    #"Renamed Columns1" = Table.RenameColumns(#"Removed Columns1",{{"Template Image", "Template Image Url"}})
in
    #"Renamed Columns1";

shared MarketingEmailTestSends = let
    source = GetCDST_CustomProfileTable("msdyncrm_marketingemailtestsend"),
    #"Removed Columns" = Table.RemoveColumns(source,{"msdyncrm_textpart"}),
    #"Changed Type" = Table.TransformColumnTypes(#"Removed Columns",{{"createdon", type date}}),
    #"Renamed Columns" = Table.RenameColumns(#"Changed Type",{{"msdyncrm_marketingemailtestsendid", "TestSendId"}, {"msdyncrm_emailid", "MessageId"}, {"msdyncrm_marketinglistid", "MarketingListId"}, {"msdyncrm_testcontactid", "TestContactId"}, {"msdyncrm_testsendemailaddress", "TestSendEmailAddress"}})
in
    #"Renamed Columns";

shared MarketingPages = let
    source = GetCDST_CustomProfileTable("msdyncrm_marketingpage"),
    #"Removed Columns" = Table.RemoveColumns(source,{"msdyncrm_content"}),
    #"Renamed Columns" = Table.RenameColumns(#"Removed Columns",{{"msdyncrm_name", "Page Name"}, {"msdyncrm_marketingpageid", "MarketingPageId"}, {"statuscode_display", "Status"}, {"msdyncrm_visualstyle_display", "Visual Style"}, {"msdyncrm_type_display", "Page Type"}, {"msdyncrm_remote_websiteid", "WebsiteId"}, {"msdyncrm_purpose_display", "Purpose"}, {"msdyncrm_partialurl", "Partial Url"}, {"msdyncrm_optimizedfor_display", "Optimized for"}, {"msdyncrm_markettype_display", "Market type"}, {"msdyncrm_full_page_url", "Page Url"}, {"msdyncrm_marketingpagetemplate", "MarketingPageTemplateId"}})
in
    #"Renamed Columns";

shared MarketingDynamicContentMetaData = let
    source = GetCDST_CustomProfileTable("msdyncrm_marketingdynamiccontentmetadata")
in
    source;

shared MarketingPagesEmails = let
    source = GetCDST_CustomProfileTable("msdyncrm_marketingpage_marketingemail"),
    #"Removed Columns" = Table.RemoveColumns(source,{"versionnumber"}),
    #"Renamed Columns" = Table.RenameColumns(#"Removed Columns",{{"msdyncrm_marketingemailid", "MessageId"}, {"msdyncrm_marketingpage_marketingemailid", "Id"}, {"msdyncrm_marketingpageid", "MarketingPageId"}})
in
    #"Renamed Columns";

shared #"#StorageContainers" = let
    Source = AzureStorage.Blobs(#"@AzureStorageAccountName")
in
    Source;

shared GetStorageContainerContent = ()=>
let
    Source = #"#StorageContainers",
    #"ContainerContent" = Source{[Name=#"@AzureStorageBlobContainerName"]}[Data],
    #"Removed Other Columns" = Table.SelectColumns(ContainerContent,{"Content", "Name", "Date modified", "Attributes"}),
    #"Filtered Rows" = Table.SelectRows(#"Removed Other Columns", each [Name] <> "model.json"),
    #"Sorted Rows" = Table.Sort(#"Filtered Rows",{{"Date modified", Order.Descending}}),
    #"Expanded Attributes" = Table.ExpandRecordColumn(#"Sorted Rows", "Attributes", {"Size"}, {"Size"}),
    #"File Name column" = Table.DuplicateColumn(#"Expanded Attributes", "Name", "File Name"),
    #"Remove csv" = Table.ReplaceValue(#"File Name column","csv/","",Replacer.ReplaceText,{"File Name"}),
    #"Split Column by Delimiter" = Table.SplitColumn(#"Remove csv", "File Name", Splitter.SplitTextByEachDelimiter({"/"}, QuoteStyle.Csv, true), {"Interaction Name", "File Name"}),
    #"Transform" = Table.TransformColumnTypes(#"Split Column by Delimiter",{{"Interaction Name", type text}, {"File Name", type text}, {"Size", Int64.Type}}),    
    #"Add Datestamp" = Table.DuplicateColumn(#"Transform", "Date modified", "Datestamp"),
    #"DateStampFormat" = Table.TransformColumnTypes(#"Add Datestamp",{{"Datestamp", type date}}),
    
    TodayFunction = DateTime.FixedLocalNow,    
    #"Add Today" = Table.AddColumn(#"DateStampFormat", "Today", each TodayFunction()),
    #"Changed TodayType" = Table.TransformColumnTypes(#"Add Today",{{"Today", type date}}),
    #"Add DaysFromToday" = Table.AddColumn(#"Changed TodayType", "DaysFromToday", each [Datestamp]-[Today]),
    #"Changed DaysFromToday" = Table.TransformColumnTypes(#"Add DaysFromToday",{{"DaysFromToday", Int64.Type}}),
    Result = Table.RemoveColumns(#"Changed DaysFromToday", "Today")
in
    Result;

shared #"#StorageContainerContentIndex" = let
    Source = GetStorageContainerContent(),
    #"Removed Content" = Table.RemoveColumns(Source,{"Content","Name","Date modified"}),
    Result = Table.Buffer(#"Removed Content")
in
    Result;

shared LoadFileContent = (#"File Name" as text) =>

let
    Source = #"#StorageContainers",
    #"Container" = Source{[Name=#"@AzureStorageBlobContainerName"]}[Data],
    #"Removed Other Columns" = Table.SelectColumns(Container,{"Content", "Name"}),
    Content = #"Removed Other Columns"{[Name=#"File Name"]}[Content]
in
    Content;

shared LoadInteractionFileContent = (#"Interaction Name" as text, #"File Name" as text) =>

let
    #"TheFileName" = "csv/" & #"Interaction Name" & "/" & #"File Name",
   Content = LoadFileContent (#"TheFileName")
in
    Content;

shared #"%InteractionModel" = let
    ModelFile = LoadFileContent("model.json"), 
    #"Imported JSON" = Json.Document(ModelFile,1252),
    entities = #"Imported JSON"[entities],
    #"Converted to Table" = Table.FromList(entities, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    CoreTable = Table.ExpandRecordColumn(#"Converted to Table", "Column1", {"name", "attributes"}, {"Interaction Type", "attributes"}),
    Result = Table.Buffer(CoreTable)
in
    Result;

shared #"%InteractionTypeIndex" = let
    Source = #"%InteractionModel",
    CoreTable = Table.RemoveColumns(Source,{"attributes"}),
    Result = Table.Buffer(CoreTable)
in
    Result;

shared #"%InteractionModelExpanded" = let
    Source = #"%InteractionModel",
    #"Expanded attributes" = Table.ExpandListColumn(Source, "attributes"),
    CoreTable = Table.ExpandRecordColumn(#"Expanded attributes", "attributes", {"name", "dataType"}, {"Attribute Name", "Attribute Type"}),
    Result = Table.Buffer(CoreTable)
in
    Result;

shared GetDefaultInteractionTable = (InteractionType as text) =>
let
    Source = #"%InteractionModelExpanded",
    #"Filtered Rows" = Table.SelectRows(Source, each ([Interaction Type] = InteractionType)),
    #"Removed Other Columns" = Table.SelectColumns(#"Filtered Rows",{"Attribute Name"}),
    #"Transposed Table" = Table.Transpose(#"Removed Other Columns"),
    #"Promoted Headers" = Table.PromoteHeaders(#"Transposed Table", [PromoteAllScalars=true]),
    Result = Table.TransformColumnTypes(#"Promoted Headers",{{"Timestamp", type datetimezone}})
in
    Result;

shared ParseInteractionFileContent = (content as binary) =>
  let
    #"Imported CSV" = Csv.Document(content,[Delimiter=",", Encoding=1252, QuoteStyle=QuoteStyle.None]),
    #"Promoted Headers" = Table.PromoteHeaders(#"Imported CSV", [PromoteAllScalars=true])
  in
    #"Promoted Headers";

shared FilterStorageContainerContent = (#"Interaction Name") =>
let
    Source = GetStorageContainerContent(),
    #"FilteredByInteraction" = if (#"Interaction Name" is null) then Source 
    else
    Table.SelectRows(#"Source", each [Interaction Name] = #"Interaction Name"),
    
    // Filter by the number of daysback
    Result = if (not (#"@LoadInteractionsForNumberOfDaysBack" is null))
      then Table.SelectRows(#"FilteredByInteraction", each [DaysFromToday] >= -#"@LoadInteractionsForNumberOfDaysBack")
      else #"FilteredByInteraction"
in
    Result;

shared #"#FilteredStorageContainerContent" = let
    Source = FilterStorageContainerContent(null),
    #"Remove Columns" = Table.RemoveColumns(Source,{"Name", "Date modified"}),
    Result = Table.Buffer(#"Remove Columns")

in
    Result;

shared GetInteractionTableData = (#"Interaction Name" as text) =>
       let
           //Source = FilterStorageContainerContent(#"Interaction Name"),
           Source = #"#FilteredStorageContainerContent",
           #"FilteredByInteraction" = Table.SelectRows(#"Source", each [Interaction Name] = #"Interaction Name"),
           #"AddFileContents" = Table.AddColumn(#"FilteredByInteraction", "FileContent", each ParseInteractionFileContent([Content])),
           #"ContentTable" = Table.SelectColumns(AddFileContents,{"FileContent"}),
           #"NoDataFiles" = Table.IsEmpty(#"ContentTable"),
           
           InteractionTable = if (#"NoDataFiles") then 
             GetDefaultInteractionTable(#"Interaction Name")
           else
             Table.ExpandTableColumn(#"ContentTable", "FileContent", Table.ColumnNames(ContentTable{0}[FileContent])),
           #"Transformed" = Table.TransformColumnTypes(InteractionTable,{{"Timestamp", type datetimezone}}),
           #"Duplicated Column" = Table.DuplicateColumn(#"Transformed", "Timestamp", "Datestamp"),
           #"Datestamp" = Table.TransformColumns(#"Duplicated Column",{{"Datestamp", DateTime.Date, type date}}),
           #"RenameId" = Table.RenameColumns(#"Datestamp",{{"InternalMarketingInteractionId", "Id"}})          
       in
           #"RenameId";

shared EmailBlockBounced = let
    Source = GetInteractionTableData("EmailBlockBounced")
in
    Source;

shared EmailBlocked = let
    Source = GetInteractionTableData("EmailBlocked")
in
    Source;

shared EmailClicked = let
    Source = GetInteractionTableData("EmailClicked")
in
    Source;

shared EmailContainsBlacklistedLinks = let
    Source = GetInteractionTableData("EmailContainsBlacklistedLinks")
in
    Source;

shared EmailDelivered = let
    Source = GetInteractionTableData("EmailDelivered")
in
    Source;

shared EmailFeedbackLoop = let
    Source = GetInteractionTableData("EmailFeedbackLoop")
in
    Source;

shared EmailForwarded = let
    Source = GetInteractionTableData("EmailForwarded")
in
    Source;

shared EmailHardBounced = let
    Source = GetInteractionTableData("EmailHardBounced")
in
    Source;

shared EmailOpened = let
    Source = GetInteractionTableData("EmailOpened")
in
    Source;

shared EmailSendingFailed = let
    Source = GetInteractionTableData("EmailSendingFailed")
in
    Source;

shared EmailSent = let
    Source = GetInteractionTableData("EmailSent")
in
    Source;

shared EmailSoftBounced = let
    Source = GetInteractionTableData("EmailSoftBounced")
in
    Source;

shared EmailSubscriptionSubmit = let
    Source = GetInteractionTableData("EmailSubscriptionSubmit")
in
    Source;

shared InvalidRecipientAddress = let
    Source = GetInteractionTableData("InvalidRecipientAddress")
in
    Source;

[ Description = "Enter the URL of the CRM organization, like https://Contoso.crm4.dynamics.com" ]
shared #"@CRMOrgUrl" = "https://mkttest1031sg807p09.crm10.dynamics.com" meta [IsParameterQuery=true, List={}, DefaultValue=..., Type="Text", IsParameterQueryRequired=true];

[ Description = "Enter the account name of your Azure Storage Account" ]
shared #"@AzureStorageAccountName" = "cabeln2" meta [IsParameterQuery=true, List={}, DefaultValue=..., Type="Text", IsParameterQueryRequired=true];

[ Description = "Enter the name of your Azure Storage Blob Container" ]
shared #"@AzureStorageBlobContainerName" = "mkttest1031sg807p09" meta [IsParameterQuery=true, List={}, DefaultValue=..., Type="Text", IsParameterQueryRequired=true];

[ Description = "The number of days back in time for which interactions data will be loaded.#(lf)(If this parameter is empty no data range filter will be applied)" ]
shared #"@LoadInteractionsForNumberOfDaysBack" = 10 meta [IsParameterQuery=true, List={7, 14, 31, 180, 365}, DefaultValue=7, Type="Number", IsParameterQueryRequired=false];

shared Segments = let
    Accounts = GetCDST_CustomProfileTable("msdyncrm_segment"),
    #"Removed Other Columns" = Table.SelectColumns(Accounts,{"createdon", "modifiedon", "msdyncrm_segmentid", "msdyncrm_segmentmemberids", "msdyncrm_segmentname", "msdyncrm_segmentsize", "msdyncrm_segmenttype", "statecode_display", "statuscode_display"}),
    #"Changed Type" = Table.TransformColumnTypes(#"Removed Other Columns",{{"createdon", type date}, {"modifiedon", type date}}),
    #"Renamed Columns" = Table.RenameColumns(#"Changed Type",{{"msdyncrm_segmentname", "Name"}, {"msdyncrm_segmentsize", "Segment Size"}, {"msdyncrm_segmenttype", "Segment Type Id"}, {"statecode_display", "State"}, {"statuscode_display", "Status"}, {"msdyncrm_segmentid", "Segment Id"}}),
    #"Added Conditional Column" = Table.AddColumn(#"Renamed Columns", "Segment Type", each if [Segment Type Id] = 192350001 then "Static" else if [Segment Type Id] = 192350000 then "Dynamic" else "Compound"),
    #"Parsed JSON" = Table.TransformColumns(#"Added Conditional Column",{{"msdyncrm_segmentmemberids", Json.Document}}),
    #"Renamed Columns1" = Table.RenameColumns(#"Parsed JSON",{{"msdyncrm_segmentmemberids", "Segment Members"}}),
    #"Added Custom" = Table.AddColumn(#"Renamed Columns1", "Static Member Count", each if [Segment Type Id] = 192350001 then List.Count([Segment Members]) else null),
    #"Changed Type1" = Table.TransformColumnTypes(#"Added Custom",{{"Static Member Count", Int64.Type}, {"Segment Type", type text}}),
    #"Removed Columns" = Table.RemoveColumns(#"Changed Type1",{"Segment Type Id"})
in
    #"Removed Columns";

shared SegmentMembers = let
    Source = Segments,
    #"Removed Other Columns" = Table.SelectColumns(Source,{"Segment Id", "Segment Members"}),
    #"Expanded Segment Members" = Table.ExpandListColumn(#"Removed Other Columns", "Segment Members"),
    #"Filtered Rows" = Table.SelectRows(#"Expanded Segment Members", each [Segment Members] <> null and [Segment Members] <> ""),
    #"Extracted Text After Delimiter" = Table.TransformColumns(#"Filtered Rows", {{"Segment Members", each Text.AfterDelimiter(_, "crm"), type text}}),
    #"Renamed Columns" = Table.RenameColumns(#"Extracted Text After Delimiter",{{"Segment Members", "Contact Id"}})
in
    #"Renamed Columns";

shared KPI_EmailUniqueEmailOpened = let
    Source = EmailOpened,
    #"Grouped Rows" = Table.Group(Source, {"MessageId", "ContactId", "AccountId"}, {{"Count", each Table.RowCount(_), type number}}),
    #"Changed Type" = Table.TransformColumnTypes(#"Grouped Rows",{{"Count", Int64.Type}}),
    #"Renamed Columns" = Table.RenameColumns(#"Changed Type",{{"Count", "Unique Opens"}})
in
    #"Renamed Columns";

shared KPI_EmailUniqueEmailClicked = let
    Source = EmailClicked,
    #"Grouped Rows" = Table.Group(Source, {"MessageId", "ContactId", "AccountId"}, {{"Count", each Table.RowCount(_), type number}}),
    #"Changed Type" = Table.TransformColumnTypes(#"Grouped Rows",{{"Count", Int64.Type}}),
    #"Renamed Columns" = Table.RenameColumns(#"Changed Type",{{"Count", "Unique Clicks"}})
in
    #"Renamed Columns";

shared KPI_JourneyUniqueEmailOpened = let
    Source = EmailOpened,
    #"Grouped Rows" = Table.Group(Source, {"MessageId", "CustomerJourneyId", "ContactId", "AccountId"}, {{"Count", each Table.RowCount(_), type number}}),
    #"Changed Type" = Table.TransformColumnTypes(#"Grouped Rows",{{"Count", Int64.Type}}),
    #"Renamed Columns" = Table.RenameColumns(#"Changed Type",{{"Count", "Unique Opens"}})
in
    #"Renamed Columns";

shared KPI_JourneyUniqueEmailClicked = let
    Source = EmailClicked,
    #"Grouped Rows" = Table.Group(Source, {"MessageId", "CustomerJourneyId", "ContactId", "AccountId"}, {{"Count", each Table.RowCount(_), type number}})
in
    #"Grouped Rows";

shared KPI_MarketingEmailKPIs = let
    Source = MarketingEmails,
    #"Removed Other Columns" = Table.SelectColumns(Source,{"MessageId", "Message Name"}),
    #"Email Sent" = Table.NestedJoin(#"Removed Other Columns",{"MessageId"},EmailSent,{"MessageId"},"EmailSent",JoinKind.LeftOuter),
    #"Aggregated EmailSent" = Table.AggregateTableColumn(#"Email Sent", "EmailSent", {{"Id", List.Count, "Email Sent"}}),
    #"Email Opened" = Table.NestedJoin(#"Aggregated EmailSent",{"MessageId"},EmailOpened,{"MessageId"},"EmailOpened",JoinKind.LeftOuter),
    #"Aggregated EmailOpened" = Table.AggregateTableColumn(#"Email Opened", "EmailOpened", {{"Id", List.Count, "Email Opened"}}),
    #"Merged Queries2" = Table.NestedJoin(#"Aggregated EmailOpened",{"MessageId"},EmailClicked,{"MessageId"},"EmailClicked",JoinKind.LeftOuter),
    #"Aggregated EmailClicked" = Table.AggregateTableColumn(#"Merged Queries2", "EmailClicked", {{"Id", List.Count, "Total Clicks"}})
in
    #"Aggregated EmailClicked";