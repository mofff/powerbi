// 20201013.03 
// Power BI example accessing PI Cloud to query an asset
// Usage:
// Update expressions namespaceId,tenantId,apiVersion (if required),clientId,clientSecret,assetId (or comment if not required)
// If necessary update
//  1. date(s)
//  2. REST API query

let
    //
    // User configuration section - start
    //

    // Tenant information
    namespaceId = "<namespace-id>",
    tenantId = "<tenant-id>",
    // apiVersion = "v1",
    apiVersion = "v1-preview",

    // Credentials - Note: use a client associated with read-only roles
    clientId = "<client-id>",
    clientSecret = "<client-secret>",

    // PI Cloud Asset to query, using asset id either as an entered parameter or default specified after else in quotes
    // If asset is defined as a parameter, comment out next line:
    asset = null,
    assetId = if asset <> null then asset else "<asset-id>",

    // Number of days for report, using entered report_period_days parameter or default of 14
    // if report_period_days is defined as a parameter, comment out next line:
    report_period_days = null,
    report_period = if report_period_days <> null then report_period_days else 14,

    // set query date
    endIndex = DateTimeZone.RemoveZone(DateTimeZone.UtcNow()), // Specify end date for the report as "now"
    startIndex = Date.StartOfDay(Date.AddDays(endIndex,-report_period)), // Specify start date as a negative number to get the day at 12:00:00 AM

    // verify dates - for debugging
    //test = DateTime.ToText(startIndex,"yyyy-MM-ddTHH:mm:ssZ"),
    //test2 = DateTime.ToText(endIndex,"yyyy-MM-ddTHH:mm:ssZ"),

    //
    // Specify query
    //

    // PI Cloud REST API query - sampled, note/update intervals as required
    //dataQuery = "/../api/"
    //    &apiVersion&
    //    "/Tenants/"
    //    &tenantId&
    //    "/Namespaces/"
    //    &namespaceId&
    //    "/Assets/"
    //    &assetId&
    //    "/Data/sampled?startIndex="
    //    &DateTime.ToText(startIndex)&
    //    "&intervals=960&endIndex="
    //    &DateTime.ToText(endIndex),

    // PI Cloud REST API query - window
    dataQuery = "/../api/"
        &apiVersion&
        "/Tenants/"
        &tenantId&
        "/Namespaces/"
        &namespaceId&
        "/Assets/"
        &assetId&
        "/Data?startIndex="
        &DateTime.ToText(startIndex)&
        "&endIndex="
        &DateTime.ToText(endIndex)&
        "&count=250000",

    //
    // User configuration section - end
    //

    resourceUri = "https://dat-b.osisoft.com",
    // split URL to avoid Power BI Service error regarding unsupported function Web.Contents
    authUrlPart1 = resourceUri&"/identity",
    authUrlPart2 = "/connect/token",

    // Construct message for authentication
    escapedClientSecret = Uri.EscapeDataString(clientSecret),
    authPOSTBody = "client_id="&clientId&"&client_secret="&escapedClientSecret&"&grant_type=client_credentials",
    authPOSTBodyBinary = Text.ToBinary(authPOSTBody),

    // Authentiate

    GetJson = Web.Contents(authUrlPart1,

        [RelativePath=authUrlPart2,

         Timeout=#duration(0, 0, 30, 0),

         Headers=[#"Content-Type"="application/x-www-form-urlencoded;charset=UTF-8",

         Accept="application/json"],

         Content=authPOSTBodyBinary]
    ),

    FormatAsJson = Json.Document(GetJson),

    // Get token from the Json response

    AccessToken = FormatAsJson[access_token],

    AccessTokenHeader = "bearer " & AccessToken,

    // Query PI Cloud REST API

    GetJsonQuery = Json.Document(
        Web.Contents(
            resourceUri,
            [RelativePath=dataQuery, 
            Headers=[Authorization=AccessTokenHeader]
            ]
        )
    ),

    #"Converted to Table" = Table.FromList(GetJsonQuery, Splitter.SplitByNothing(), null, null, ExtraValues.Error),

    #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", {"Measurement", "Result"}, {"Measurement", "Result"}),

    #"Expanded Result2" = Table.ExpandListColumn(#"Expanded Column1", "Result"),

    #"Expanded Result" = Table.ExpandRecordColumn(#"Expanded Result2", "Result", {"Timestamp", "Value"}, {"Timestamp", "Value"}),

    #"Changed Type" = Table.TransformColumnTypes(#"Expanded Result",{{"Measurement", type text}, {"Timestamp", type datetime}, {"Value", type number}})

in

    #"Changed Type"
