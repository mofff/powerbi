let

//
// User configuration section - start
//

// Tenant information
namespaceId = "<namespace-id>",
tenantId = "<tenant-id>",
apiVersion = "v1-preview",

// Credentials - Note: use a client associated with read-only roles
clientsecret = "<client_secret>",
clientid = "<client_id>",

// PI Cloud Asset to query, using asset id either as an entered parameter or default specified after else in quotes
assetId = if asset <> null then asset else "2587cba4-63a6-4f80-9c20-76c81ec6913e",

// Number of days for report, using entered report_period_days parameter or default of 14
report_period = if report_period_days <> null then report_period_days else 14,

endIndex = DateTimeZone.RemoveZone(DateTimeZone.UtcNow()), // Specify end date for the report as "now"
startIndex = Date.StartOfDay(Date.AddDays(endIndex,-report_period)), // Specify start date as a negative number to get the day at 12:00:00 AM

// verify dates - for debugging
//test = DateTime.ToText(startIndex,"yyyy-MM-ddTHH:mm:ssZ"),
//test2 = DateTime.ToText(endIndex,"yyyy-MM-ddTHH:mm:ssZ"),

//
// User configuration section - end
//

resourceUri = "https://dat-b.osisoft.com",
// split URL to avoid Power BI Service error regarding unsupported function Web.Contents
authUrlPart1 = resourceUri&"/identity",
authUrlPart2 = "/connect/token",

// PI Cloud REST API query
dataQuery = "/../api/"
    &apiVersion&
    "/Tenants/"
    &tenantId&
    "/Namespaces/"
    &namespaceId&
    "/Assets/"
    &assetId&
    "/Data/sampled?startIndex="
    &DateTime.ToText(startIndex)&
    "&intervals=960&endIndex="
    &DateTime.ToText(endIndex),

// Construct message for authentication
escapedClientSecret = Uri.EscapeDataString(clientsecret),
authPOSTBody = "client_id="&clientid&"&client_secret="&escapedClientSecret&"&grant_type=client_credentials",
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

#"Expanded Result" = Table.ExpandRecordColumn(#"Expanded Result2", "Result", {"Timestamp", "Value"}, {"Timestamp", "Value"})

in

#"Expanded Result"
