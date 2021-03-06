﻿section Strava;

//
// Make sure you have two files called client_id and client_secret in the root of your solution.
// signin to Strava and navigate to https://www.strava.com/settings/api 
// Follow the steps and obtain your client_id and client_secret.
//

client_id = Text.FromBinary(Extension.Contents("client_id"));
client_secret = Text.FromBinary(Extension.Contents("client_secret"));
redirect_uri = "https://oauth.powerbi.com/views/oauthredirect.html";

// strava base URL
api_uri = "https://www.strava.com/api/v3/";

activity_uri = "athlete/activities";
athlete_uri = "athlete";

stream_uri1 = "activities/";
stream_uri2 = "/streams";

// default page size, using the MAX page size to limit the amount of calls to the API
page_size = 200;

windowWidth = 1200;
windowHeight = 1000;

//
// Exported functions
//
// These functions are exported to the M Engine (making them visible to end users), and associates 
// them with the specified Data Source Kind. The Data Source Kind is used when determining which 
// credentials to use during evaluation. Credential matching is done based on the function's parameters. 
// All data source functions associated to the same Data Source Kind must have a matching set of required 
// function parameters, including type, name, and the order in which they appear. 

[DataSource.Kind="Strava", Publish="Strava.UI"]
shared Strava.Contents = StravaData.NavTable;

//
// Data Source definition
//
Strava = [
    TestConnection = (dataSourcePath) => { "Strava.Contents" },
    Authentication = [
        OAuth = [
            StartLogin = StartLogin,
            FinishLogin = FinishLogin,
            Label = Extension.LoadString("AuthenticationLabel")
        ]
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

//
// UI Export definition
//
Strava.UI = [
    Beta = true,
    ButtonText = { Extension.LoadString("FormulaTitle"), Extension.LoadString("FormulaHelp") },
    SourceImage = Strava.Icons,
    SourceTypeImage = Strava.Icons
];

Strava.Icons = [
    Icon16 = { Extension.Contents("Strava16.png"), Extension.Contents("Strava20.png"), Extension.Contents("Strava24.png"), Extension.Contents("Strava32.png") },
    Icon32 = { Extension.Contents("Strava32.png"), Extension.Contents("Strava40.png"), Extension.Contents("Strava48.png"), Extension.Contents("Strava64.png") }
];

//For the navigation tables see this example: https://github.com/Microsoft/DataConnectors/tree/master/samples/TripPin/3-NavTables 

//
// Nav table definition
//
// Define the NAV URL
StravaData.NavTable = () as table =>
    let
        source = #table({"Name", "Data"}, {
            { "Athlete", StravaData.GetObject(athlete_uri,"Athlete")},
            //{ "Activities", StravaData.GetObject(activity_uri,"Activities")},
            { "StreamsBis", StravaData.GetObject(activity_uri, "StreamsBis")},
            { "Streams", StravaData.GetStream(stream_uri1, "3318303283", stream_uri2, "Streams") }
        }),

        // add other columns
        withItemKind = Table.AddColumn(source, "ItemKind", each "Table"),
        withItemName = Table.AddColumn(withItemKind, "ItemName", each "Table"),
        withIsLeaf = Table.AddColumn(withItemName, "IsLeaf", each true),

        functionTable1 = AddNavTableFunctions({[Name = "GetObjects", Data = StravaData.GetObject]}),
        functionTable2 = AddNavTableFunctions({[Name = "GetStreams", Data = StravaData.GetStream]}),

        withFunction = Table.InsertRows(withIsLeaf, Table.RowCount(withIsLeaf), {[ 
            Name = "Functions",
            Data = functionTable1,
            ItemKind = "Folder",
            ItemName = "Folder",
            IsLeaf = false
        ],[ 
            Name = "FunctionsStream",
            Data = functionTable2,
            ItemKind = "Folder",
            ItemName = "Folder",
            IsLeaf = false
        ]
        }),
        
        navTable = Table.ToNavigationTable(withFunction, {"Name"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        navTable;

//Functions to parse Strava data

//Parse the activities by json
 StravaData.Activities = (json) =>
    let
        ConvertToTable = Table.FromList(json, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        #"Expanded Column1" = Table.ExpandRecordColumn( ConvertToTable, "Column1", {"id", "resource_state", "external_id", "upload_id", "athlete", "name", "distance", "moving_time", "elapsed_time", "total_elevation_gain", "type", "start_date", "start_date_local", "timezone", "utc_offset", "start_latlng", "end_latlng", "location_city", "location_state", "location_country", "start_latitude", "start_longitude", "achievement_count", "kudos_count", "comment_count", "athlete_count", "photo_count", "map", "trainer", "commute", "manual", "private", "flagged", "gear_id", "average_speed", "max_speed", "average_cadence", "average_temp", "average_watts", "kilojoules", "device_watts", "has_heartrate", "average_heartrate", "max_heartrate", "elev_high", "elev_low", "pr_count", "total_photo_count", "has_kudoed", "workout_type", "weighted_average_watts", "max_watts"}, {"id", "resource_state", "external_id", "upload_id", "athlete", "name", "distance", "moving_time", "elapsed_time", "total_elevation_gain", "type", "start_date", "start_date_local", "timezone", "utc_offset", "start_latlng", "end_latlng", "location_city", "location_state", "location_country", "start_latitude", "start_longitude", "achievement_count", "kudos_count", "comment_count", "athlete_count", "photo_count", "map", "trainer", "commute", "manual", "private", "flagged", "gear_id", "average_speed", "max_speed", "average_cadence", "average_temp", "average_watts", "kilojoules", "device_watts", "has_heartrate", "average_heartrate", "max_heartrate", "elev_high", "elev_low", "pr_count", "total_photo_count", "has_kudoed", "workout_type", "weighted_average_watts", "max_watts"}),
        #"Removed Columns" = Table.RemoveColumns(#"Expanded Column1",{"resource_state", "upload_id", "athlete", "start_latlng", "end_latlng", "photo_count", "total_photo_count", "external_id"}),
        #"Changed Type" = Table.TransformColumnTypes(#"Removed Columns",{{"total_elevation_gain", Int64.Type}, {"elapsed_time", Int64.Type}, {"moving_time", Int64.Type}, {"distance", type number}}),
        #"Renamed Columns" = Table.RenameColumns(#"Changed Type",{{"start_date", "start_datetime"}}),
        #"Duplicated Column" = Table.DuplicateColumn(#"Renamed Columns", "start_datetime", "start_datetime - Copy"),
        #"Changed Type1" = Table.TransformColumnTypes(#"Duplicated Column",{{"start_datetime - Copy", type datetime}}),
        #"Extracted Date" = Table.TransformColumns(#"Changed Type1",{{"start_datetime - Copy", DateTime.Date}}),
        #"Renamed Columns1" = Table.RenameColumns(#"Extracted Date",{{"start_datetime - Copy", "start_date"}}),
        #"Reordered Columns" = Table.ReorderColumns(#"Renamed Columns1",{"name", "distance", "moving_time", "elapsed_time", "total_elevation_gain", "type", "start_datetime", "start_date", "start_date_local", "timezone", "utc_offset", "location_country", "start_latitude", "start_longitude", "achievement_count", "kudos_count", "comment_count", "athlete_count", "trainer", "commute", "manual", "private", "flagged", "gear_id", "average_speed", "max_speed", "average_cadence", "average_temp", "average_watts", "kilojoules", "device_watts", "has_heartrate", "average_heartrate", "max_heartrate", "elev_high", "elev_low", "pr_count", "has_kudoed", "workout_type", "weighted_average_watts", "max_watts"}),
        #"Changed Type2" = Table.TransformColumnTypes(#"Reordered Columns",{{"start_latitude", type number}, {"start_longitude", type number}, {"achievement_count", Int64.Type}, {"kudos_count", Int64.Type}, {"comment_count", Int64.Type}, {"athlete_count", Int64.Type}, {"trainer", type logical}, {"commute", type logical}, {"manual", type logical}, {"private", type logical}, {"flagged", type logical}, {"average_speed", type number}, {"max_speed", type number}, {"average_cadence", type number}, {"average_temp", type number}, {"average_watts", type number}, {"kilojoules", type number}, {"device_watts", type logical}, {"has_heartrate", type logical}, {"average_heartrate", type number}, {"max_heartrate", Int64.Type}, {"elev_high", type number}, {"elev_low", type number}, {"pr_count", Int64.Type}}),
        #"Changed Type3" = Table.TransformColumnTypes(#"Changed Type2",{{"has_kudoed", type logical}, {"weighted_average_watts", Int64.Type}, {"max_watts", Int64.Type}}),
        #"Changed Typedt" = Table.TransformColumnTypes(#"Changed Type3",{{"start_datetime", type datetime}}),
        #"Changed Type1t" = Table.TransformColumnTypes(#"Changed Typedt",{{"start_datetime", type time}}),
        #"Duplicated Column2" = Table.RenameColumns(#"Changed Type1t", {{"start_datetime", "start_time"}}),
        #"Removed Blank Rows" = Table.SelectRows(#"Duplicated Column2", each not List.IsEmpty(List.RemoveMatchingItems(Record.FieldValues(_), {"", null})))
in
    #"Removed Blank Rows";


//Parse the Athlete by json
StravaData.Athlete = (json) =>
    let
        ConvertToTable = Table.FromList(json, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        tableresult = Record.ToTable(ConvertToTable),
        result = Table.Pivot(tableresult, List.Distinct(tableresult[Name]), "Name", "Value")
in
   result;


//Parse the streams by json
 StravaData.Streams = (json) =>
    let
        ConvertToTable = Table.FromList(json, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        //tableresult = Record.ToTable(ConvertToTable),
        //result = Table.Pivot(tableresult, List.Distinct(tableresult[Name]), "Name", "Value")
        #"Expanded Column1" = Table.ExpandRecordColumn( ConvertToTable, "Column1", {"type", "data"})
        //#"Add column" = Table.AddColumn( #"Expanded Column1", "Stream", StravaData.GetStream(stream_uri1, [id], stream_uri2, "heartrate", "Streams"))
in
    #"Expanded Column1";

//Parse the streams by json
 StravaData.StreamsBis = (json) =>
    let
        ConvertToTable = Table.FromList(json, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        #"Expanded Column1" = Table.ExpandRecordColumn( ConvertToTable, "Column1", {"id"}),
        #"Add column" = Table.AddColumn( #"Expanded Column1", "Stream", each StravaData.GetStream(stream_uri1, "", stream_uri2, "Streams"))
in
    #"Add column";

//All of the paging is based off the Tripin Sample https://github.com/Microsoft/DataConnectors/tree/master/samples/TripPin/5-Paging 

// Add a helper function that can be used to retrieve strava API objects 
// that we haven't exposed in the navigation table. We always take a relative path,
// and append it to the base Strava API URL.
// Note: Taking in a full path is a security issue, as it could potentially leak 
// the bearer token to the url specified in the function parameter. 
// For Strava I added an additional parameter to determine the type of content so we can parse this differently later
StravaData.GetObject = (relativeUrl as text, contentType as text) => StravaData.PagedReader(api_uri & relativeUrl, contentType);

StravaData.GetStream = (relativeUrl1 as text, id as text, relativeurl2 as text, contentType as text) => StravaData.PagedReader(api_uri & relativeUrl1 & id & relativeurl2 & "/key=distance,time,heartrate,cadence,altitude,velocity_smooth,grade_smooth", contentType);

// Read a single page of data.
// If we get back an empty list, it means we are out of pages and should return null.
// For Strava I added an additional parameter to determine the type of content so we can parse this differently later
StravaData.Page = (url as text, page as number, contentType as text) as nullable table =>
    let
        queryOptions = [
            page = Number.ToText(page),
            page_size = Text.From(page_size)
        ],
        queryOptionsStreams = [
            key = "heartrate",
            key_by_type = "true",
            page = Number.ToText(page),
            page_size = Text.From(page_size)
        ],

        content = Web.Contents(url, [ Query = queryOptions ]),

//          content = 
//              if (contentType = "Streams") then
//                  Web.Contents(url, [ Query = queryOptionsStreams ])
//              else
//                  Web.Contents(url, [ Query = queryOptions ]),
// 
        json = Json.Document(content),

        // Responses from the API will either be a single record, or list of records.
        // When we have a single record, we want to format it as a table. Set NextPage to null.
        // When we have a list of records, we convert to a table. Set NextPage to page + 1.
        // When we have an empty list of records, we return null. 
        result =
            if (json is list) then
                if (List.IsEmpty(json)) then 
                    null
                else //Determine how to parse the JSON based on the type of content.
                    if(contentType = "Activities") then
                        StravaData.Activities(json) meta [NextPage = page + 1]
                    else if(contentType = "StreamsBis") then
                        StravaData.StreamsBis(json) meta [NextPage = page + 1]
                    else if(contentType = "Streams") then
                        StravaData.Streams(json) meta [NextPage = null]
                    else
                        StravaData.Athlete(json) meta [NextPage = page + 1]
            else
                Table.FromRecords({json}) meta [NextPage = null] // turn single record into one item list
    in
        result;


// Read all pages of data.
// After every page, we check the "NextPage" record on the metadata of the previous request.
// Table.GenerateByPage will keep asking for more pages until we return null.
StravaData.PagedReader = (url as text, contentType as text) =>
    Table.GenerateByPage((previous) => 
        let
            // if previous is null, then this is our first page of data
            nextPage = if (previous = null) then 1 else Value.Metadata(previous)[NextPage]?,
            // if NextPage was set to null by the previous call, we know we have no more data
            page = if (nextPage <> null) then StravaData.Page(url, nextPage, contentType) else null
        in
            page
    );


// This is a modified version of Table.ToNavigationTable to expose the function invocation dialog in the navigator.
// This works around the issue described here: https://github.com/Microsoft/DataConnectors/issues/30
// The functions argument is a list of records with Name and Data fields.
AddNavTableFunctions = (functions as list) as table =>
    let
        asTable = Table.FromRecords(functions),
        withItemKind = Table.AddColumn(asTable, "ItemKind", each "Function"),
        withIsLeaf = Table.AddColumn(withItemKind, "IsLeaf", each true),

        tableType = Value.Type(withIsLeaf),
        newTableType = Type.AddTableKey(tableType, {"Name"}, true) meta 
        [
            NavigationTable.NameColumn = "Name", 
            NavigationTable.DataColumn = "Data",
            NavigationTable.ItemKindColumn = "ItemKind", 
            NavigationTable.IsLeafColumn = "IsLeaf"
        ],
        navigationTable = Value.ReplaceType(withIsLeaf, newTableType)
    in
        navigationTable;

//For authentication I used: https://github.com/Microsoft/DataConnectors/tree/master/samples/Github

//
// Authentication functions
//
StartLogin = (resourceUrl, state, display) =>
    let
        AuthorizeUrl = "https://www.strava.com/oauth/authorize?" & Uri.BuildQueryString([
            client_id = client_id,
            scope = "read_all,activity:read_all",
            response_type = "code",
            state = state,
            redirect_uri = redirect_uri])
    in
        [
            LoginUri = AuthorizeUrl,
            CallbackUri = redirect_uri,
            WindowHeight = windowHeight,
            WindowWidth = windowWidth,
            Context = null
        ];

FinishLogin = (context, callbackUri, state) =>
    let
        Parts = Uri.Parts(callbackUri)[Query]
    in
        TokenMethod(Parts[code]);

// Called when the access_token has expired, and a refresh_token is available.
// 
//Refresh = (resourceUrl, refresh_token) => TokenMethod("refresh_token", "refresh_token", refresh_token);

TokenMethod = (code) =>
    let
        Response = Web.Contents("https://www.strava.com/oauth/token", [
            Content = Text.ToBinary(Uri.BuildQueryString([
                client_id = client_id,
                client_secret = client_secret,
                code = code,
                redirect_uri = redirect_uri])),
            Headers=[#"Content-type" = "application/x-www-form-urlencoded",#"Accept" = "application/json"]]),
        Parts = Json.Document(Response)
    in
        Parts;

//
// Helper functions
//
 Table.ToNavigationTable = (
    table as table,
    keyColumns as list,
    nameColumn as text,
    dataColumn as text,
    itemKindColumn as text,
    itemNameColumn as text,
    isLeafColumn as text
) as table =>
    let
        tableType = Value.Type(table),
        newTableType = Type.AddTableKey(tableType, keyColumns, true) meta 
        [
            NavigationTable.NameColumn = nameColumn, 
            NavigationTable.DataColumn = dataColumn,
            NavigationTable.ItemKindColumn = itemKindColumn, 
            Preview.DelayColumn = itemNameColumn, 
            NavigationTable.IsLeafColumn = isLeafColumn
        ],
        navigationTable = Value.ReplaceType(table, newTableType)
    in
        navigationTable;

Table.GenerateByPage = (getNextPage as function) as table =>
    let
        listOfPages = List.Generate(
            () => getNextPage(null),
            (lastPage) => lastPage <> null,
            (lastPage) => getNextPage(lastPage)
        ),
        tableOfPages = Table.FromList(listOfPages, Splitter.SplitByNothing(), {"Column1"}),
        firstRow = tableOfPages{0}?
    in
        if (firstRow = null) then
            Table.FromRows({})
        else
            Value.ReplaceType(
                Table.ExpandTableColumn(tableOfPages, "Column1", Table.ColumnNames(firstRow[Column1])),
                Value.Type(firstRow[Column1])
            );
