section Section1;

shared GetCleanedCRMOrgUrl = ()=> let
    Source = #"@CRMOrgUrl",
    #"Trimmed Text" = Text.TrimEnd(Text.Trim(Source), "/")
in
    #"Trimmed Text";

shared #"#CDSTHubSource" = let
    Url = #"@CRMOrgUrl",
    //TrimmedUrl = Text.TrimEnd(Text.Trim(Url), "/"), // We cannot trim the URL because then data sourcewill not be recognized
    Source = Cds.Contents(Url, [ReorderColumns=null, UseFormattedValue=null])
in
    Source;

shared #"#CDSTEntitySource" = let
    Url = #"@CRMOrgUrl",
    //TrimmedUrl = Text.TrimEnd(Text.Trim(Url), "/"), // We cannot trim the URL because then data sourcewill not be recognized
    Source = Cds.Entities(Url, [ReorderColumns=null, UseFormattedValue=true])
in
    Source;

shared #"#CDST_CDMProfiles" = let
    Source = #"#CDSTHubSource",
    
    CustomProfiles = Source{[Group="cdm"]}[Data],
    CoreTable = Table.SelectColumns(CustomProfiles,{"EntitySetName", "SchemaName"}),
    Result = Table.Buffer(CoreTable)
in
    Result;

shared #"#CDST_CustomProfiles" = let
    Source = #"#CDSTHubSource",
    
    CustomProfiles = Source{[Group="custom"]}[Data],
    #"Sorted Rows" = Table.Sort(CustomProfiles,{{"EntitySetName", Order.Ascending}}),
    CoreTable = Table.SelectColumns(#"Sorted Rows",{"EntitySetName", "SchemaName"}),
    Result = Table.Buffer(CoreTable)
in
    Result;

[ Description = "Loads the table of profile instances for a specific custom Profile" ]
shared GetCDST_EntityTable = let
    Source = (#"schema name" as text) =>
        let
            Source = #"#CDSTEntitySource",
            Entities = Source{[Group="entities"]}[Data],
            DataTable = Entities{[SchemaName=#"schema name"]}[Data]
        in
            DataTable
in
    Source;

shared #"#CDST_SystemProfiles" = let
    Source = #"#CDSTHubSource",
    
    CustomProfiles = Source{[Group="system"]}[Data],
    CoreTable = Table.SelectColumns(CustomProfiles,{"Name"}),
    Result = Table.Buffer(CoreTable)
in
    Result;

[ Description = "Loads the table of profile instances for a specific CDM Profile" ]
shared GetCDST_CDMProfileTable = (#"schema name" as text) =>
        let
            Source = #"#CDSTHubSource",
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
            Source = #"#CDSTHubSource",
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
    #"Removed Content" = Table.RemoveColumns(Source,{"Content","Name","Date modified"})
in
    #"Removed Content";

shared #"#FilteredStorageContainerContentIndex" = let
    Source = Table.NestedJoin(#"#StorageContainerContentIndex",{"Interaction Name"},#"!LoadedInteractions",{"Interaction Name"},"!LoadedInteractions",JoinKind.Inner),
    #"Removed Columns" = Table.RemoveColumns(Source,{"!LoadedInteractions"}),
    // Filter by the number of daysback
    FilterByRecency = if (not (#"@LoadInteractionsForNumberOfDaysBack" is null))
      then Table.SelectRows(#"Removed Columns", each [DaysFromToday] >= -#"@LoadInteractionsForNumberOfDaysBack")
      else #"Removed Columns"
in
    FilterByRecency;

shared LoadFileContent = (#"File Name" as text) =>

let
    Source = #"#StorageContainers",
    #"Container" = Source{[Name=#"@AzureStorageBlobContainerName"]}[Data],
    #"ContentColumnOnly" = Table.SelectColumns(Container,{"Content", "Name"}),
    Content = if(Table.Contains(#"ContentColumnOnly",[Name=#"File Name"])) 
      then #"ContentColumnOnly"{[Name=#"File Name"]}[Content] 
      else BinaryFormat.Null
in
    Content;

shared LoadInteractionFileContent = (#"Interaction Name" as text, #"File Name" as text) =>

let
    #"TheFileName" = "csv/" & #"Interaction Name" & "/" & #"File Name",
   Content = LoadFileContent (#"TheFileName")
in
    Content;

shared #"%InteractionModel" = let
    StaticModelFile = LoadFileContent("modelStatic.json"), 
    ModelFile = if (StaticModelFile <> BinaryFormat.Null) then StaticModelFile else LoadFileContent("model.json"), 

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
    Result = Table.TransformColumnTypes(#"Promoted Headers",{{"Timestamp", type datetimezone}}, "en-US")
in
    Result;

shared ParseInteractionFileContent = (content as binary) =>
  let
    // it is important to use QuotesStyle.Csv, because otherwise multiline parameters like in form submitted values will not be parsed  
    #"Imported CSV" = Csv.Document(content,[Delimiter=",", Encoding=1252, QuoteStyle=QuoteStyle.Csv]),
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
    #"Merged Queries" = Table.NestedJoin(#"Remove Columns",{"Interaction Name"},#"!LoadedInteractions",{"Interaction Name"},"!LoadedInteractions",JoinKind.Inner),
    #"Removed Columns" = Table.RemoveColumns(#"Merged Queries",{"!LoadedInteractions"})
    //Result = Table.Buffer(#"Removed Columns")
in
    #"Removed Columns";

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
           // Interction timestamp is stored in US datetimezone format in interaction store - this should be fixed going forward
           #"Transformed" = Table.TransformColumnTypes(InteractionTable,{{"Timestamp", type datetimezone}}, "en-US"),
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

shared #"!ProductVersion" = let
    Source = Table.FromRows(Json.Document(Binary.Decompress(Binary.FromText("i45W8slMKkosqlTSUTLUMzUw0DO0NDQwMFKK1YlWckosTnVJLEkMzi8tSk4txqbEMS8xp7IqtQhDLhYA", BinaryEncoding.Base64), Compression.Deflate)), let _t = ((type text) meta [Serialized.Text = true]) in type table [Product = _t, Version = _t]),
    #"Changed Type" = Table.TransformColumnTypes(Source,{{"Product", type text}, {"Version", type text}}),
    #"Added Custom" = Table.AddColumn(#"Changed Type", "Rendered", each [Product] & ": " & [Version])
in
    #"Added Custom";

shared #"!KnownInteractions" = let
    Source = Table.FromRows(Json.Document(Binary.Decompress(Binary.FromText("lVXbcuIwDP0XnvsTJaWz7NBpJ4HtQ6cPjiMSD47tlWW6/P3KAXpJnDR9JOdIPpKOxMvL4laSOio6ZdaQkLTUVh6gWtws9kJ7WLzejFH4lwdDM5irfwRohJ4fUQTnELxX1kyx75R3gmQzrfcJrYy5TH0vlO5xmbNX2Arip3L4G8DTBO5dLKFP6KSABurnRhAEGbZpQWl28GTbrBHGgP5B3AZENY/++YF0RR0D8LcNaOCaLQdpsdq5SgzK/Mpf87C7dhUksM9dtTyCbshLG4wcRSeA5WnnAUfhu+C0kizytqqihUaJayNiv+BS3yjvQXXeuc5ZkPiOmoOOTUpTM1Z3Lo8wfP4e8yvjl1rIg1aeE2yUOST0s9VYNqZadA9QlRy/sdYlUItvAqtU4C/+PjqRCObQWoJRyqMDkyiqAFOl9+4K0zDG7mn0nQh+I6UIpZeoXGfBULaqN1pDvCKpdV0dWU7WgDyszRDIoeahnJ09jWaChfXr5d63ZzX9ZyPyR3nV/742R6EVN14qp/iJlJ/fOU6ftnaCEQcBmCLEw1HwanNDbe/2Rf/FPXnXPjzIj4Ee92f/siEVfc39JLzfNmhD3cy6TTmnQJAUH/7Ykw+8iKc+aC5kTrYC6pb79gBtCegz9gvFs1enad3Scnm+UW5VDaZxYV3MVabRnfEjON8kHvxM3QGPcEqe5i2qup6Z5sLlv59ni4e9tm+zwp6hjF5Mtf8CDcz6+h8=", BinaryEncoding.Base64), Compression.Deflate)), let _t = ((type text) meta [Serialized.Text = true]) in type table [#"Interaction Name" = _t, #"Load Data" = _t]),
    #"Changed Type" = Table.TransformColumnTypes(Source,{{"Interaction Name", type text}, {"Load Data", type logical}})
in
    #"Changed Type";

shared #"!LoadedInteractions" = let
    Source = #"!KnownInteractions",
    #"Filtered Rows" = Table.SelectRows(Source, each ([Load Data] = true))
in
    #"Filtered Rows";

[ Description = "Enter the URL of the CRM organization, like https://Contoso.crm4.dynamics.com" ]
shared #"@CRMOrgUrl" = "https://mktdemospring.crm.dynamics.com" meta [IsParameterQuery=true, List={}, DefaultValue=..., Type="Text", IsParameterQueryRequired=true];

[ Description = "Enter the account name of your Azure Storage Account" ]
shared #"@AzureStorageAccountName" = "cabeln2" meta [IsParameterQuery=true, List={}, DefaultValue=..., Type="Text", IsParameterQueryRequired=true];

[ Description = "Enter the name of your Azure Storage Blob Container" ]
shared #"@AzureStorageBlobContainerName" = "mktdemospring" meta [IsParameterQuery=true, List={}, DefaultValue=..., Type="Text", IsParameterQueryRequired=true];

[ Description = "The number of days back in time for which interactions data will be loaded.#(lf)(If this parameter is empty no data range filter will be applied)" ]
shared #"@LoadInteractionsForNumberOfDaysBack" = 31 meta [IsParameterQuery=true, List={7, 14, 31, 180, 365}, DefaultValue=7, Type="Number", IsParameterQueryRequired=false];

[ Description = "Enter the ID of the Marketing Application in your org" ]
shared #"@MarketingAppId" = "c1b8fe39-53b4-e911-a968-000d3a13cead" meta [IsParameterQuery=true, List={"c4d57347-9420-e911-a9af-000d3a1cf0ea", "fe8e15b8-92b5-e811-a982-000d3a1ada5f", "1a030b50-8826-e911-a978-000d3a346695"}, DefaultValue="c4d57347-9420-e911-a9af-000d3a1cf0ea", Type="Text", IsParameterQueryRequired=true];

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

shared InvalidSenderAddress = let
    Source = GetInteractionTableData("InvalidSenderAddress")
in
    Source;

shared GetEntityFormUrl = let
    Source = (#"entity" as text, #"id" as text) =>
let
    URL = @#"@CRMOrgUrl"&
    "/main.aspx?appid="&#"@MarketingAppId"&
    "&pagetype=entityrecord"&
    "&etn="&#"entity"&
    "&id="&#"id"
in
    URL
in
    Source;