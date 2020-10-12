let

//authUrl = "https://dat-b.osisoft.com/identity/connect/token",
authUrl = "https://dat-b.osisoft.com/identity",

namespaceId = "Production",

tenantId = "<tenant-id>",

apiVersion = "v1-preview",

assetId = "2587cba4-63a6-4f80-9c20-76c81ec6913e",

// verify time format
//theTime = DateTimeZone.UtcNow(),
//aTime = DateTimeZone.RemoveZone(theTime),

//endTime = DateTime.From(DateTimeZone.UtcNow()) # converts to local time, no good, OCS expects UTC by default
endTime = DateTimeZone.RemoveZone(DateTimeZone.UtcNow()),
startTime = Date.AddDays(endTime,-5),

// Original@Derek
// dataViewUri = "https://dat-b.osisoft.com/api/"&apiVersion&"/Tenants/"&tenantId&"/Namespaces/"&namespaceId&"/Assets/"&assetId&"/Data/sampled?startIndex="&DateTimeZone.ToText(startIndex,"yyyy-MM-ddTHH:mm:ssZ")&"&intervals=960&endIndex="&DateTimeZone.ToText(endIndex,"yyyy-MM-ddTHH:mm:ssZ"),

// parameterize variables
// dataViewUri = "https://dat-b.osisoft.com/api/"&apiVersion&"/Tenants/"&tenantId&"/Namespaces/"&namespaceId&"/Assets/"&assetId&"/Data/sampled?startIndex="&DateTime.ToText(startTime)&"&intervals=960&endIndex="&DateTime.ToText(endTime),

// explore avoiding refresh error with Power BI Service
dataViewUri = "/api/"&apiVersion&"/Tenants/"&tenantId&"/Namespaces/"&namespaceId&"/Assets/"&assetId&"/Data/sampled?startIndex="&DateTime.ToText(startTime)&"&intervals=960&endIndex="&DateTime.ToText(endTime),

clientsecret = "<client-secret>",

escapedClientSecret = Uri.EscapeDataString(clientsecret),

clientid = "<client-id>",

resourceUri = "https://dat-b.osisoft.com",

authPOSTBody = "client_id="&clientid&"&client_secret="&escapedClientSecret&"&grant_type=client_credentials",

authPOSTBodyBinary = Text.ToBinary(authPOSTBody),

// https://community.powerbi.com/t5/Report-Server/Query-contains-unsupported-function-Function-name-Web-Contents/td-p/887698
// Web.Contents("https://xxxxxx.xxxxxx.net", [RelativePath=RelativePath, Headers=Headers, Query=Query])

GetJson = Web.Contents("https://dat-b.osisoft.com/identity",

    [RelativePath="/connect/token",

    Timeout=#duration(0, 0, 30, 0),

     Headers=[#"Content-Type"="application/x-www-form-urlencoded;charset=UTF-8",

     Accept="application/json"],

     Content=authPOSTBodyBinary]),

FormatAsJson = Json.Document(GetJson),

 

// Gets token from the Json response

AccessToken = FormatAsJson[access_token],

AccessTokenHeader = "bearer " & AccessToken,

GetJsonQuery = Json.Document(Web.Contents("https://dat-b.osisoft.com", 
    [Headers=[Authorization=AccessTokenHeader],
    RelativePath=dataViewUri
    ])),

    #"Converted to Table" = Table.FromList(GetJsonQuery, Splitter.SplitByNothing(), null, null, ExtraValues.Error),

    #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", {"Measurement", "Result"}, {"Measurement", "Result"}),

    #"Expanded Result2" = Table.ExpandListColumn(#"Expanded Column1", "Result"),

    #"Expanded Result" = Table.ExpandRecordColumn(#"Expanded Result2", "Result", {"Timestamp", "Value"}, {"Timestamp", "Value"})

in

    #"Expanded Result"
