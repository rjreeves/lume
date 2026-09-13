param(
  [string]$Lume = (Join-Path $PSScriptRoot 'dist\lume.exe')
)

$ErrorActionPreference = 'Stop'

function Assert-Equal([string]$Name, [string]$Expected, [string]$Actual) {
  if ($Expected -cne $Actual.Trim()) {
    throw "$Name failed: expected '$Expected', got '$Actual'"
  }
  Write-Host "PASS $Name"
}

function Assert-Contains([string]$Name, [string]$Expected, [string]$Actual) {
  if (-not $Actual.Contains($Expected)) {
    throw "$Name failed: expected text '$Expected', got '$Actual'"
  }
  Write-Host "PASS $Name"
}

$arithmetic = & $Lume run (Join-Path $PSScriptRoot 'examples\arithmetic.lume')
if ($LASTEXITCODE -ne 0) { throw "arithmetic exited $LASTEXITCODE" }
Assert-Equal 'arithmetic' '42' ($arithmetic -join "`n")

$greeting = & $Lume run (Join-Path $PSScriptRoot 'examples\greeting.lume')
if ($LASTEXITCODE -ne 0) { throw "greeting exited $LASTEXITCODE" }
Assert-Equal 'string concatenation' 'hello, Lume' ($greeting -join "`n")

$control = & $Lume run (Join-Path $PSScriptRoot 'examples\control_flow.lume')
if ($LASTEXITCODE -ne 0) { throw "control flow exited $LASTEXITCODE" }
Assert-Equal 'control flow' "control flow works`n10" ($control -join "`n")

$functions = & $Lume run (Join-Path $PSScriptRoot 'examples\functions.lume')
if ($LASTEXITCODE -ne 0) { throw "functions exited $LASTEXITCODE" }
Assert-Equal 'functions and recursion' "42`n120" ($functions -join "`n")

$modules = & $Lume run (Join-Path $PSScriptRoot 'examples\modules.lume')
if ($LASTEXITCODE -ne 0) { throw "modules exited $LASTEXITCODE" }
Assert-Equal 'recursive modules' '25' ($modules -join "`n")

$lists = & $Lume run (Join-Path $PSScriptRoot 'examples\lists.lume')
if ($LASTEXITCODE -ne 0) { throw "lists exited $LASTEXITCODE" }
Assert-Equal 'typed lists' "3`n20`n40" ($lists -join "`n")

$records = & $Lume run (Join-Path $PSScriptRoot 'examples\records.lume')
if ($LASTEXITCODE -ne 0) { throw "records exited $LASTEXITCODE" }
Assert-Equal 'typed records' "Ada@Sydney`n36`ntools" ($records -join "`n")

$typedJson = & $Lume run (Join-Path $PSScriptRoot 'examples\typed_json.lume')
if ($LASTEXITCODE -ne 0) { throw "typed JSON exited $LASTEXITCODE" }
Assert-Equal 'typed JSON records' "Ada`nSydney`nGrace" ($typedJson -join "`n")

$invalidTypedJson = & $Lume run (Join-Path $PSScriptRoot 'examples\invalid_typed_json.lume')
if ($LASTEXITCODE -ne 0) { throw "invalid typed JSON example exited $LASTEXITCODE" }
Assert-Equal 'typed JSON path error' 'User.age must be int' ($invalidTypedJson -join "`n")

$jsonEncode = & $Lume run (Join-Path $PSScriptRoot 'examples\json_encode.lume')
if ($LASTEXITCODE -ne 0) { throw "json encode exited $LASTEXITCODE" }
Assert-Equal 'json encode' "{`"name`":`"Ada`",`"age`":30,`"active`":true,`"tags`":[`"admin`",`"eng`"],`"address`":{`"city`":`"London`"}}`ntrue`ntrue`ntrue`ntrue`ntrue" ($jsonEncode -join "`n")

$jsonEncodeEnum = & $Lume run (Join-Path $PSScriptRoot 'examples\json_encode_enum.lume')
if ($LASTEXITCODE -ne 0) { throw "json encode enum exited $LASTEXITCODE" }
Assert-Equal 'json encode enum' "true`n{`"variant`":`"waiting`"}`ntrue`n{`"variant`":`"done`",`"code`":7}`ntrue`n{`"variant`":`"Some`",`"value`":1}`ntrue`n{`"variant`":`"None`"}" ($jsonEncodeEnum -join "`n")

$pathFunctions = & $Lume run (Join-Path $PSScriptRoot 'examples\path_functions.lume')
if ($LASTEXITCODE -ne 0) { throw "path functions exited $LASTEXITCODE" }
Assert-Equal 'path functions' "reports/2026`nsummary.csv`nreports/2026`nsummary`ncsv`nnone" ($pathFunctions -join "`n")

$dirList = & $Lume run (Join-Path $PSScriptRoot 'examples\dir_list.lume')
if ($LASTEXITCODE -ne 0) { throw "dir list exited $LASTEXITCODE" }
Assert-Equal 'directory listing' "2`nmath_test.lume`ntext_test.lume" ($dirList -join "`n")

$invalidDirList = & $Lume run (Join-Path $PSScriptRoot 'examples\invalid_dir_list.lume')
if ($LASTEXITCODE -ne 0) { throw "invalid dir list exited $LASTEXITCODE" }
Assert-Equal 'directory listing missing path' 'false' ($invalidDirList -join "`n")

$timeFunctions = & $Lume run (Join-Path $PSScriptRoot 'examples\time_functions.lume')
if ($LASTEXITCODE -ne 0) { throw "time functions exited $LASTEXITCODE" }
Assert-Equal 'time functions' "true`n1970-01-01T00:00:00Z`n2023-11-14T22:13:20Z" ($timeFunctions -join "`n")

$invalidTimeToIso = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_time_to_iso.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "time.to_iso validation should exit 1" }
Assert-Equal 'time.to_iso requires int' 'E0699 builtin `time.to_iso` requires int' ($invalidTimeToIso -join "`n")

$timeCalendar = & $Lume run (Join-Path $PSScriptRoot 'examples\time_calendar.lume')
if ($LASTEXITCODE -ne 0) { throw "time calendar exited $LASTEXITCODE" }
Assert-Equal 'time calendar components' "2023`n11`n14`n22`n13`n20" ($timeCalendar -join "`n")

$invalidTimeYear = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_time_year_args.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "time.year validation should exit 1" }
Assert-Equal 'time.year requires int' 'E0699 builtin `time.year` requires int' ($invalidTimeYear -join "`n")

$timeFormat = & $Lume run (Join-Path $PSScriptRoot 'examples\time_format.lume')
if ($LASTEXITCODE -ne 0) { throw "time format exited $LASTEXITCODE" }
Assert-Equal 'time format' "2023-11-14`n22:13:20`n2023-11-14T22:13:20Z" ($timeFormat -join "`n")

$invalidTimeFormat = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_time_format_args.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "time.format validation should exit 1" }
Assert-Equal 'time.format requires (int, str)' 'E0715 builtin `time.format` requires (int, str)' ($invalidTimeFormat -join "`n")

$enums = & $Lume run (Join-Path $PSScriptRoot 'examples\enums.lume')
if ($LASTEXITCODE -ne 0) { throw "enums exited $LASTEXITCODE" }
Assert-Equal 'enum construction' ('{"$enum":"JobState","$variant":"pending"}' + "`n" + '{"$enum":"JobState","$variant":"completed","code":"i:0"}') ($enums -join "`n")

$match = & $Lume run (Join-Path $PSScriptRoot 'examples\match.lume')
if ($LASTEXITCODE -ne 0) { throw "match exited $LASTEXITCODE" }
Assert-Equal 'match expressions and payload destructuring' "-1`n0" ($match -join "`n")

$recordUpdate = & $Lume run (Join-Path $PSScriptRoot 'examples\record_update.lume')
if ($LASTEXITCODE -ne 0) { throw "record update exited $LASTEXITCODE" }
Assert-Equal 'immutable nested record updates' "false`nlight`ntrue`n2`ndark" ($recordUpdate -join "`n")

$generics = & $Lume run (Join-Path $PSScriptRoot 'examples\generics.lume')
if ($LASTEXITCODE -ne 0) { throw "generics exited $LASTEXITCODE" }
Assert-Equal 'generic functions' "42`nlume`ntrue" ($generics -join "`n")

$constrainedGenerics = & $Lume run (Join-Path $PSScriptRoot 'examples\constrained_generics.lume')
if ($LASTEXITCODE -ne 0) { throw "constrained generics exited $LASTEXITCODE" }
Assert-Equal 'constrained generic functions' "true`nlume`n42`nfast" ($constrainedGenerics -join "`n")

$protocols = & $Lume run (Join-Path $PSScriptRoot 'examples\protocols.lume')
if ($LASTEXITCODE -ne 0) { throw "protocols exited $LASTEXITCODE" }
Assert-Equal 'protocol-constrained generics' "Ada`nAda" ($protocols -join "`n")

$genericData = & $Lume run (Join-Path $PSScriptRoot 'examples\generic_data.lume')
if ($LASTEXITCODE -ne 0) { throw "generic data exited $LASTEXITCODE" }
Assert-Equal 'generic records and enums' "42`nready" ($genericData -join "`n")

$listFunctions = & $Lume run (Join-Path $PSScriptRoot 'examples\list_functions.lume')
if ($LASTEXITCODE -ne 0) { throw "list functions exited $LASTEXITCODE" }
Assert-Equal 'generic list functions' "6`n2`n2`n10`n4" ($listFunctions -join "`n")

$maps = & $Lume run (Join-Path $PSScriptRoot 'examples\maps.lume')
if ($LASTEXITCODE -ne 0) { throw "maps exited $LASTEXITCODE" }
Assert-Equal 'typed maps' "2`n92`n-1`ntrue`nfalse`n2`n2`n1" ($maps -join "`n")

$mapFunctions = & $Lume run (Join-Path $PSScriptRoot 'examples\map_functions.lume')
if ($LASTEXITCODE -ne 0) { throw "map functions exited $LASTEXITCODE" }
Assert-Equal 'generic map functions' "4`n2`n1`n6" ($mapFunctions -join "`n")

$eqImpl = & $Lume run (Join-Path $PSScriptRoot 'examples\eq_impl.lume')
if ($LASTEXITCODE -ne 0) { throw "eq impl exited $LASTEXITCODE" }
Assert-Equal 'explicit Eq implementation' "0`nhome`nfalse" ($eqImpl -join "`n")

$closures = & $Lume run (Join-Path $PSScriptRoot 'examples\closures.lume')
if ($LASTEXITCODE -ne 0) { throw "closures exited $LASTEXITCODE" }
Assert-Equal 'closures and function values' "12`n14`n2`n11" ($closures -join "`n")

$propagation = & $Lume run (Join-Path $PSScriptRoot 'examples\result_propagation.lume')
if ($LASTEXITCODE -ne 0) { throw "result propagation exited $LASTEXITCODE" }
Assert-Equal 'result propagation operator' "42`nstopped" ($propagation -join "`n")

$artifactPath = Join-Path $PSScriptRoot 'dist\test-functions.lbc'
& $Lume build (Join-Path $PSScriptRoot 'examples\functions.lume') $artifactPath | Out-Null
if ($LASTEXITCODE -ne 0) { throw "bytecode build exited $LASTEXITCODE" }
$artifactRun = & $Lume exec $artifactPath
if ($LASTEXITCODE -ne 0) { throw "bytecode execution exited $LASTEXITCODE" }
Assert-Equal 'persistent bytecode' "42`n120" ($artifactRun -join "`n")

$invalidArtifactPath = Join-Path $PSScriptRoot 'dist\invalid.lbc'
[IO.File]::WriteAllBytes($invalidArtifactPath, [byte[]](76, 66, 67))
$invalidArtifactRun = & $Lume exec $invalidArtifactPath 2>&1
if ($LASTEXITCODE -ne 1) { throw "invalid bytecode should exit 1" }
Assert-Contains 'truncated bytecode rejection' 'E0401 invalid bytecode artifact' ($invalidArtifactRun -join "`n")

$coreApi = & $Lume run (Join-Path $PSScriptRoot 'examples\core_api.lume') (Join-Path $PSScriptRoot 'examples\data.json')
if ($LASTEXITCODE -ne 0) { throw "core APIs exited $LASTEXITCODE" }
Assert-Equal 'core APIs' "1`n28`ntrue`nLUME`n1`ntrue`n0" ($coreApi -join "`n")

$processResult = & $Lume run (Join-Path $PSScriptRoot 'examples\process.lume')
if ($LASTEXITCODE -ne 0) { throw "process example exited $LASTEXITCODE" }
Assert-Equal 'structured process result' "true`n0`nhello from process" ($processResult -join "`n")

$processConfig = & $Lume run (Join-Path $PSScriptRoot 'examples\process_config.lume')
if ($LASTEXITCODE -ne 0) { throw "process config example exited $LASTEXITCODE" }
Assert-Equal 'richer process configuration' "HELLO LUME`nhello_from_lume`nfalse" ($processConfig -join "`n")

# The first of two network-dependent checks in this suite: a live GET against
# http://example.com, chosen because its content has been stable for over a decade.
$httpGet = & $Lume run (Join-Path $PSScriptRoot 'examples\http_get.lume')
if ($LASTEXITCODE -ne 0) { throw "http get example exited $LASTEXITCODE" }
Assert-Equal 'http get' "200`ntrue`ntrue" ($httpGet -join "`n")

# The second network-dependent check: httpbin.org echoes the request back, which is the
# only way to prove a POST/PUT body and content-type were genuinely sent, not just that
# some response came back.
$httpPostPutDelete = & $Lume run (Join-Path $PSScriptRoot 'examples\http_post_put_delete.lume')
if ($LASTEXITCODE -ne 0) { throw "http post/put/delete example exited $LASTEXITCODE" }
Assert-Equal 'http post/put/delete' "true`ntrue`ntrue`ntrue`ntrue" ($httpPostPutDelete -join "`n")

# The third network-dependent check: httpbin.org's /headers endpoint echoes every header
# it received, the only way to prove a custom header was genuinely sent. Everything else
# in this suite beyond these three checks is local.
$httpRequestHeaders = & $Lume run (Join-Path $PSScriptRoot 'examples\http_request_headers.lume')
if ($LASTEXITCODE -ne 0) { throw "http request headers example exited $LASTEXITCODE" }
Assert-Equal 'http request custom headers' "true`ntrue" ($httpRequestHeaders -join "`n")

# The fourth network-dependent check: httpbin.org's /post endpoint echoes the request
# body back, the only way to prove a bytes body was genuinely sent (not just some text).
$httpRequestBytes = & $Lume run (Join-Path $PSScriptRoot 'examples\http_request_bytes.lume')
if ($LASTEXITCODE -ne 0) { throw "http request bytes example exited $LASTEXITCODE" }
Assert-Equal 'http request bytes' "true`ntrue`ntrue`ntrue" ($httpRequestBytes -join "`n")

$fixtures = & $Lume run (Join-Path $PSScriptRoot 'examples\fixtures.lume')
if ($LASTEXITCODE -ne 0) { throw "fixtures example exited $LASTEXITCODE" }
Assert-Equal 'test fixtures' "true`nhello fixture`ntrue`nfalse`nfalse`ntrue`nabc`nfalse" ($fixtures -join "`n")

$structured = & $Lume run (Join-Path $PSScriptRoot 'examples\structured_errors.lume') (Join-Path $PSScriptRoot 'examples\data.json')
if ($LASTEXITCODE -ne 0) { throw "structured success exited $LASTEXITCODE" }
Assert-Equal 'structured error success' '{"NAME":"LUME","VERSION":1}' ($structured -join "`n")

$missingPath = Join-Path $PSScriptRoot 'examples\missing.json'
$structuredFailure = & $Lume run (Join-Path $PSScriptRoot 'examples\structured_errors.lume') $missingPath 2>&1
if ($LASTEXITCODE -ne 1) { throw "structured failure should exit 1" }
Assert-Equal 'structured error propagation' ('cannot read file `' + $missingPath + '`') ($structuredFailure -join "`n")

$roundTripPath = Join-Path $PSScriptRoot 'dist\round-trip.txt'
$fileWrite = & $Lume run (Join-Path $PSScriptRoot 'examples\file_write.lume') $roundTripPath
if ($LASTEXITCODE -ne 0) { throw "file write exited $LASTEXITCODE" }
Assert-Equal 'file write and read' 'round trip' ($fileWrite -join "`n")

$bytesBasics = & $Lume run (Join-Path $PSScriptRoot 'examples\bytes_basics.lume')
if ($LASTEXITCODE -ne 0) { throw "bytes basics exited $LASTEXITCODE" }
Assert-Equal 'bytes basics' "hello world`n11" ($bytesBasics -join "`n")

$bytesFileRoundtrip = & $Lume run (Join-Path $PSScriptRoot 'examples\bytes_file_roundtrip.lume')
if ($LASTEXITCODE -ne 0) { throw "bytes file roundtrip exited $LASTEXITCODE" }
Assert-Equal 'bytes file roundtrip' "true`nroundtrip content`n17`ntrue" ($bytesFileRoundtrip -join "`n")

$invalidBytesToStr = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_bytes_to_str_args.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "bytes.to_str validation should exit 1" }
Assert-Equal 'bytes.to_str requires bytes' 'E0712 builtin `bytes.to_str` requires bytes' ($invalidBytesToStr -join "`n")

$check = & $Lume check (Join-Path $PSScriptRoot 'examples\arithmetic.lume')
if ($LASTEXITCODE -ne 0) { throw "check exited $LASTEXITCODE" }
Assert-Equal 'check' 'ok' ($check -join "`n")

$immutable = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_immutable.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "immutable validation should exit 1" }
Assert-Equal 'immutable validation' 'E0215 line 3: cannot assign to immutable `answer`' ($immutable -join "`n")

$undefined = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_undefined.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "undefined validation should exit 1" }
Assert-Equal 'undefined validation' 'E0210 line 2: undefined binding `missing`' ($undefined -join "`n")

$duplicate = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_duplicate.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "duplicate validation should exit 1" }
Assert-Equal 'duplicate validation' 'E0211 line 3: duplicate binding `answer`' ($duplicate -join "`n")

$scope = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_scope.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "scope validation should exit 1" }
Assert-Equal 'block scope validation' 'E0210 line 6: undefined binding `inside`' ($scope -join "`n")

$unknownFunction = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_function.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "unknown function validation should exit 1" }
Assert-Equal 'unknown function validation' 'E0216 line 2: unknown function `unknown`' ($unknownFunction -join "`n")

$arity = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_arity.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "arity validation should exit 1" }
Assert-Equal 'arity validation' 'E0217 line 2: function `add` expects 2 arguments, got 1' ($arity -join "`n")

$duplicateFunction = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_duplicate_function.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "duplicate function validation should exit 1" }
Assert-Equal 'duplicate function validation' 'E0222 line 5: duplicate function `main`' ($duplicateFunction -join "`n")

$builtinArity = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_builtin_arity.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "builtin arity validation should exit 1" }
Assert-Equal 'builtin arity validation' 'E0217 line 2: function `str.len` expects 1 arguments, got 2' ($builtinArity -join "`n")

$assignmentType = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_assignment_type.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "assignment type validation should exit 1" }
Assert-Equal 'assignment type validation' 'E0611 line 3: cannot assign str to int' ($assignmentType -join "`n")

$conditionType = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_condition_type.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "condition type validation should exit 1" }
Assert-Equal 'condition type validation' 'E0617 line 2: condition must be bool, got int' ($conditionType -join "`n")

$returnType = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_return_type.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "return type validation should exit 1" }
Assert-Equal 'return type validation' 'E0618 line 2: return type mismatch; expected int, got str' ($returnType -join "`n")

$argumentType = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_argument_type.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "argument type validation should exit 1" }
Assert-Equal 'argument type validation' 'E0609 line 2: argument type mismatch calling `add`; expected int, got str' ($argumentType -join "`n")

$listType = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_list_type.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "list type validation should exit 1" }
Assert-Equal 'list homogeneity validation' 'E0616 line 2: list elements must have one type' ($listType -join "`n")

$recordFieldType = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_record_field_type.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "record field type validation should exit 1" }
Assert-Equal 'record field type validation' 'E0633 line 7: field `age` of `User` expects int, got str' ($recordFieldType -join "`n")

$recordField = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_record_field.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "record field validation should exit 1" }
Assert-Equal 'record field validation' 'E0635 line 7: record `User` has no field `age`' ($recordField -join "`n")

$recordMissing = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_record_missing.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "missing record field validation should exit 1" }
Assert-Equal 'missing record field validation' 'E0631 line 7: missing field `age` for record `User`' ($recordMissing -join "`n")

$jsonDecodeInput = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_json_decode_input.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "JSON decoder input validation should exit 1" }
Assert-Equal 'typed JSON input validation' 'E0638 line 6: `User.from_json` requires str, got int' ($jsonDecodeInput -join "`n")

$enumPayloadType = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_enum_payload_type.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "enum payload type validation should exit 1" }
Assert-Equal 'enum payload type validation' 'E0645 line 6: field `code` of `JobState.completed` expects int, got str' ($enumPayloadType -join "`n")

$enumVariant = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_enum_variant.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "unknown enum variant validation should exit 1" }
Assert-Equal 'unknown enum variant validation' 'E0641 line 6: enum `JobState` has no variant `running`' ($enumVariant -join "`n")

$enumMissing = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_enum_missing.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "missing enum payload validation should exit 1" }
Assert-Equal 'missing enum payload validation' 'E0642 line 6: missing field `code` for variant `JobState.completed`' ($enumMissing -join "`n")

$matchExhaustive = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_match_exhaustive.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "non-exhaustive match validation should exit 1" }
Assert-Equal 'match exhaustiveness validation' 'E0653 line 7: non-exhaustive match on `State`; missing `off`' ($matchExhaustive -join "`n")

$matchDuplicate = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_match_duplicate.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "duplicate match validation should exit 1" }
Assert-Equal 'duplicate match arm validation' 'E0652 line 7: duplicate match arm `on`' ($matchDuplicate -join "`n")

$matchVariant = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_match_variant.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "unknown match variant validation should exit 1" }
Assert-Equal 'unknown match variant validation' 'E0651 line 7: enum `State` has no variant `broken`' ($matchVariant -join "`n")

$matchArmType = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_match_arm_type.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "match arm type validation should exit 1" }
Assert-Equal 'match arm type validation' 'E0654 line 7: match arms must return one type; expected str, got int' ($matchArmType -join "`n")

$matchPayloadArity = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_match_payload_arity.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "match payload arity validation should exit 1" }
Assert-Equal 'match payload arity validation' 'E0655 line 7: variant `completed` exposes 1 payload values, pattern binds 2' ($matchPayloadArity -join "`n")

$matchPayloadDuplicate = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_match_payload_duplicate.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "duplicate match payload binding should exit 1" }
Assert-Equal 'duplicate match payload binding' 'E0656 line 7: duplicate payload binding `item`' ($matchPayloadDuplicate -join "`n")

$matchPayloadScope = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_match_payload_scope.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "match payload scope validation should exit 1" }
Assert-Equal 'match payload arm scope' 'E0210 line 11: undefined binding `code`' ($matchPayloadScope -join "`n")

$recordUpdateField = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_record_update_field.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "record update field validation should exit 1" }
Assert-Equal 'record update field validation' 'E0663 line 7: record `User` has no field `age`' ($recordUpdateField -join "`n")

$recordUpdateType = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_record_update_type.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "record update type validation should exit 1" }
Assert-Equal 'record update type validation' 'E0662 line 7: field `retries` of `User` expects int, got str' ($recordUpdateType -join "`n")

$recordUpdateDuplicate = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_record_update_duplicate.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "duplicate record update validation should exit 1" }
Assert-Equal 'duplicate record update validation' 'E0661 line 7: duplicate record update field `name`' ($recordUpdateDuplicate -join "`n")

$recordUpdateSource = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_record_update_source.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "record update source validation should exit 1" }
Assert-Equal 'record update source validation' 'E0660 line 3: `with` requires a record, got int' ($recordUpdateSource -join "`n")

$processArgs = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_process_args.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "process argument validation should exit 1" }
Assert-Equal 'process argument validation' 'E0619 process.run requires (str, [str])' ($processArgs -join "`n")

$processInputArgs = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_process_run_with_input_args.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "process run_with_input argument validation should exit 1" }
Assert-Equal 'process run_with_input argument validation' 'E0700 process.run_with_input requires (str, [str], str)' ($processInputArgs -join "`n")

$processEnvArgs = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_process_run_with_env_args.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "process run_with_env argument validation should exit 1" }
Assert-Equal 'process run_with_env argument validation' 'E0700 process.run_with_env requires (str, [str], Map<str,str>)' ($processEnvArgs -join "`n")

$httpGetArgs = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_http_get_args.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "http get argument validation should exit 1" }
Assert-Equal 'http get argument validation' 'E0608 builtin `http.get` requires str' ($httpGetArgs -join "`n")

$httpPostArgs = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_http_post_args.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "http post argument validation should exit 1" }
Assert-Equal 'http post argument validation' 'E0710 builtin `http.post` requires (str, str, str)' ($httpPostArgs -join "`n")

$httpRequestArgs = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_http_request_args.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "http request argument validation should exit 1" }
Assert-Equal 'http request argument validation' 'E0711 http.request requires (str, str, Map<str,str>, str)' ($httpRequestArgs -join "`n")

$envSetArgs = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_env_set_args.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "env set argument validation should exit 1" }
Assert-Equal 'env set argument validation' 'E0607 builtin `env.set` requires str arguments' ($envSetArgs -join "`n")

$unwrap = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_unwrap.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "unwrap validation should exit 1" }
Assert-Equal 'unwrap context validation' 'E0624 line 2: `!` requires an enclosing result-returning function' ($unwrap -join "`n")

$genericArgument = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_generic_argument.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "generic argument validation should exit 1" }
Assert-Equal 'generic substitution validation' 'E0609 line 6: argument type mismatch calling `same`; expected str, got int' ($genericArgument -join "`n")

$genericConstraint = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_generic_constraint.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "generic constraint validation should exit 1" }
Assert-Equal 'generic constraint validation' 'E0680 line 6: type `str` does not satisfy `Number` for `T` calling `requires_number`' ($genericConstraint -join "`n")

$genericConstraintName = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_generic_constraint_name.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "unknown generic constraint should exit 1" }
Assert-Equal 'generic constraint name validation' 'E0679 line 1: unknown generic constraint `Printable`' ($genericConstraintName -join "`n")

$protocolConstraint = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_protocol_constraint.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "missing protocol implementation should exit 1" }
Assert-Equal 'protocol implementation constraint' 'E0680 line 12: type `User` does not satisfy `Named` for `T` calling `keep_named`' ($protocolConstraint -join "`n")

$protocolImpl = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_protocol_impl.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "unknown protocol implementation should exit 1" }
Assert-Equal 'unknown protocol implementation' 'E0258 unknown protocol `Missing` in implementation' ($protocolImpl -join "`n")

$protocolMissingMethod = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_protocol_missing_method.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "missing protocol method should exit 1" }
Assert-Equal 'missing protocol method' 'E0262 implementation of `Named` for `User` is missing method `name`' ($protocolMissingMethod -join "`n")

$protocolMethodType = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_protocol_method_type.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "protocol method signature mismatch should exit 1" }
Assert-Equal 'protocol method signature' 'E0263 method `User.name` does not match protocol signature' ($protocolMethodType -join "`n")

$protocolExtraMethod = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_protocol_extra_method.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "extra protocol method should exit 1" }
Assert-Equal 'extra protocol method' 'E0264 method `code` is not declared by protocol `Named`' ($protocolExtraMethod -join "`n")

$genericDispatchUnknownMethod = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_generic_dispatch_unknown_method.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "generic dispatch unknown method should exit 1" }
Assert-Equal 'generic dispatch unknown method' 'E0689 line 16: protocol `Named` declares no method `missing`' ($genericDispatchUnknownMethod -join "`n")

$genericDispatchBuiltinConstraint = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_generic_dispatch_builtin_constraint.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "generic dispatch builtin constraint should exit 1" }
Assert-Equal 'generic dispatch builtin constraint' 'E0687 line 2: built-in constraint `Number` has no callable methods' ($genericDispatchBuiltinConstraint -join "`n")

$genericDispatchWrongArgumentCount = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_generic_dispatch_non_self_method.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "generic dispatch wrong argument count should exit 1" }
Assert-Equal 'generic dispatch wrong argument count' 'E0690 line 16: generic dispatch of `T.compare` requires exactly 2 argument(s), got 1' ($genericDispatchWrongArgumentCount -join "`n")

$genericDispatchNoSelfParameter = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_generic_dispatch_no_self_parameter.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "generic dispatch no Self parameter should exit 1" }
Assert-Equal 'generic dispatch no Self parameter' 'E0691 line 16: `Factory.create` is not yet supported for generic dispatch; exactly one `Self` parameter is required' ($genericDispatchNoSelfParameter -join "`n")

$genericDispatchNonSelfArgumentType = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_generic_dispatch_non_self_argument_type.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "generic dispatch non-Self argument type should exit 1" }
Assert-Equal 'generic dispatch non-Self argument type' 'E0692 line 16: argument type mismatch calling `T.compare`; expected int, got str' ($genericDispatchNonSelfArgumentType -join "`n")

$genericDispatchMultiParam = & $Lume run (Join-Path $PSScriptRoot 'examples\generic_dispatch_multi_param.lume')
if ($LASTEXITCODE -ne 0) { throw "generic dispatch multi-parameter exited $LASTEXITCODE" }
Assert-Equal 'generic dispatch multi-parameter' "true`nfalse" ($genericDispatchMultiParam -join "`n")

$multiConstraint = & $Lume run (Join-Path $PSScriptRoot 'examples\multi_constraint.lume')
if ($LASTEXITCODE -ne 0) { throw "multi-constraint generics exited $LASTEXITCODE" }
Assert-Equal 'multi-constraint generics' "5`nHello, Ada" ($multiConstraint -join "`n")

$genericDispatchAmbiguous = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_generic_dispatch_ambiguous_method.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "generic dispatch ambiguous method should exit 1" }
Assert-Equal 'generic dispatch ambiguous method' 'E0694 line 10: call to `T.describe` is ambiguous - Named, Labeled all declare method `describe`' ($genericDispatchAmbiguous -join "`n")

$multiConstraintUnsatisfied = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_multi_constraint_unsatisfied.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "multi-constraint unsatisfied should exit 1" }
Assert-Equal 'multi-constraint unsatisfied' 'E0680 line 20: type `User` does not satisfy `Number` for `T` calling `keep`' ($multiConstraintUnsatisfied -join "`n")

$mapRequiresMap = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_map_requires_map.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "map requires-a-map validation should exit 1" }
Assert-Equal 'map requires a map' 'E0695 `map.len` requires a Map' ($mapRequiresMap -join "`n")

$mapKeyTypeMismatch = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_map_key_type_mismatch.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "map key type mismatch validation should exit 1" }
Assert-Equal 'map key type mismatch' 'E0696 `map.get` key type does not match map key type' ($mapKeyTypeMismatch -join "`n")

$mapKeyNotEligible = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_map_key_not_eligible.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "map key eligibility validation should exit 1" }
Assert-Equal 'map key not eligible' 'E0697 map key type must be int, str, bool, or a type with `impl Eq for <Type> {}`' ($mapKeyNotEligible -join "`n")

$ordImpl = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_ord_impl.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "Ord impl validation should exit 1" }
Assert-Equal 'Ord impl still rejected' 'E0258 unknown protocol `Ord` in implementation' ($ordImpl -join "`n")

$mapValueTypeMismatch = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_map_value_type_mismatch.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "map value type mismatch validation should exit 1" }
Assert-Equal 'map value type mismatch' 'E0698 map.set value type does not match map value type' ($mapValueTypeMismatch -join "`n")

$mapCallback = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_map_callback.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "map callback validation should exit 1" }
Assert-Equal 'map callback validation' 'E0673 callback parameter type does not match map value type' ($mapCallback -join "`n")

$listCallback = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_list_callback.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "list callback validation should exit 1" }
Assert-Equal 'list callback validation' 'E0673 callback parameter type does not match list element type' ($listCallback -join "`n")

$closureReturn = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_closure_return.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "closure return validation should exit 1" }
Assert-Equal 'closure return validation' 'E0676 line 3: closure return type mismatch; expected int, got str' ($closureReturn -join "`n")

$closureCapture = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_closure_capture_mutable.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "mutable closure capture validation should exit 1" }
Assert-Equal 'immutable closure capture validation' 'E0678 line 4: closure cannot capture mutable binding `offset`' ($closureCapture -join "`n")

$closureScopeLeak = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_closure_scope_leak.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "closure scope leak validation should exit 1" }
Assert-Equal 'closure scope leak validation' 'E0210 line 6: undefined binding `value`' ($closureScopeLeak -join "`n")

$closureMatchScopeLeak = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_closure_match_scope_leak.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "nested closure/match scope leak validation should exit 1" }
Assert-Equal 'nested closure/match scope leak validation' 'E0210 line 12: undefined binding `code`' ($closureMatchScopeLeak -join "`n")

$propagate = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_propagate.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "propagation validation should exit 1" }
Assert-Equal 'propagation context validation' 'E0624 line 2: `?` requires an enclosing result-returning function' ($propagate -join "`n")

$propagateError = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_propagate_error_type.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "propagation error type validation should exit 1" }
Assert-Equal 'propagation error type validation' 'E0625 line 6: propagated error type mismatch; expected str, got bool' ($propagateError -join "`n")

$missingModule = & $Lume check (Join-Path $PSScriptRoot 'examples\module_missing.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "missing module validation should exit 1" }
Assert-Contains 'missing module validation' 'E0701 cannot read module' ($missingModule -join "`n")

$moduleCycle = & $Lume check (Join-Path $PSScriptRoot 'examples\module_cycle.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "module cycle validation should exit 1" }
Assert-Contains 'module cycle validation' 'E0702 module import cycle' ($moduleCycle -join "`n")

$bytecode = & $Lume bytecode (Join-Path $PSScriptRoot 'examples\arithmetic.lume')
if ($LASTEXITCODE -ne 0) { throw "bytecode exited $LASTEXITCODE" }
if (-not (($bytecode -join "`n") -match 'mul')) { throw 'bytecode did not contain mul' }
Write-Host 'PASS bytecode'

$nativeTests = & $Lume test (Join-Path $PSScriptRoot 'examples\native_tests.lume')
if ($LASTEXITCODE -ne 0) { throw "native test runner exited $LASTEXITCODE" }
Assert-Equal 'native test runner' "PASS adds two values`nPASS recognizes present values`n2 passed; 0 failed" ($nativeTests -join "`n")

$filteredTests = & $Lume test (Join-Path $PSScriptRoot 'examples\native_tests.lume') --filter present
if ($LASTEXITCODE -ne 0) { throw "filtered native test runner exited $LASTEXITCODE" }
Assert-Equal 'native test filtering' "PASS recognizes present values`n1 passed; 0 failed" ($filteredTests -join "`n")

$nativeSuite = & $Lume test (Join-Path $PSScriptRoot 'examples\native_suite')
if ($LASTEXITCODE -ne 0) { throw "native test directory discovery exited $LASTEXITCODE" }
Assert-Contains 'native test directory math discovery' 'PASS math works' ($nativeSuite -join "`n")
Assert-Contains 'native test directory text discovery' 'PASS text works' ($nativeSuite -join "`n")

$nativeFailure = & $Lume test (Join-Path $PSScriptRoot 'examples\native_tests_failing.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "failing native test should exit 1" }
Assert-Equal 'native test failure' "FAIL shows expected and actual values (line 1): expected 42, got 41`n0 passed; 1 failed" ($nativeFailure -join "`n")

# The "id" field embeds the test's source path exactly as it was passed on
# the command line, JSON-escaped - not a portable/hashed value, just enough
# to disambiguate same-named tests across files and give a --filter target
# that reruns exactly one test. Expected strings below build that path the
# same way the invocation itself does, rather than hardcoding it, since an
# absolute path varies by checkout location.
$nativeTestsPath = Join-Path $PSScriptRoot 'examples\native_tests.lume'
$nativeTestsFailingPath = Join-Path $PSScriptRoot 'examples\native_tests_failing.lume'
$nativeTestsId = ($nativeTestsPath -replace '\\', '\\')
$nativeTestsFailingId = ($nativeTestsFailingPath -replace '\\', '\\')

$jsonTests = & $Lume test $nativeTestsPath --json
if ($LASTEXITCODE -ne 0) { throw "json native test runner exited $LASTEXITCODE" }
$jsonTestsExpected = "{`"event`":`"test`",`"id`":`"$nativeTestsId#adds two values`",`"name`":`"adds two values`",`"status`":`"pass`",`"line`":9,`"message`":`"`"}" + "`n" + `
  "{`"event`":`"test`",`"id`":`"$nativeTestsId#recognizes present values`",`"name`":`"recognizes present values`",`"status`":`"pass`",`"line`":14,`"message`":`"`"}" + "`n" + `
  '{"event":"summary","passed":2,"failed":0,"total":2}'
Assert-Equal 'structured test output' $jsonTestsExpected ($jsonTests -join "`n")

$jsonFailure = & $Lume test $nativeTestsFailingPath --json 2>&1
if ($LASTEXITCODE -ne 1) { throw "json failing native test should exit 1" }
$jsonFailureExpected = "{`"event`":`"test`",`"id`":`"$nativeTestsFailingId#shows expected and actual values`",`"name`":`"shows expected and actual values`",`"status`":`"fail`",`"line`":1,`"message`":`"expected 42, got 41`"}" + "`n" + `
  '{"event":"summary","passed":0,"failed":1,"total":1}'
Assert-Equal 'structured test output failure' $jsonFailureExpected ($jsonFailure -join "`n")

$jsonFilterOrder = & $Lume test $nativeTestsPath --json --filter adds
if ($LASTEXITCODE -ne 0) { throw "json test runner with --json before --filter exited $LASTEXITCODE" }
$jsonFilterOrderExpected = "{`"event`":`"test`",`"id`":`"$nativeTestsId#adds two values`",`"name`":`"adds two values`",`"status`":`"pass`",`"line`":9,`"message`":`"`"}" + "`n" + `
  '{"event":"summary","passed":1,"failed":0,"total":1}'
Assert-Equal 'structured test output with --json before --filter' $jsonFilterOrderExpected ($jsonFilterOrder -join "`n")

$filterByPathFragment = & $Lume test $nativeTestsPath --filter 'native_tests.lume'
if ($LASTEXITCODE -ne 0) { throw "filter by path fragment exited $LASTEXITCODE" }
Assert-Equal 'filter matches path fragment via stable id' "PASS adds two values`nPASS recognizes present values`n2 passed; 0 failed" ($filterByPathFragment -join "`n")

$packagesAppDir = Join-Path $PSScriptRoot 'examples\packages\app'
$installOutput = & $Lume install $packagesAppDir
if ($LASTEXITCODE -ne 0) { throw "lume install exited $LASTEXITCODE" }
$lockContent = Get-Content -LiteralPath (Join-Path $packagesAppDir 'lume.lock.json') -Raw
Assert-Equal 'package install writes lock file' '{"dependencies":[{"name":"mathutils","path":"../mathutils","version":"0.1.0"},{"name":"formatting","path":"../formatting","version":"0.1.0"}]}' $lockContent.Trim()

$packagesRun = & $Lume run (Join-Path $packagesAppDir 'app.lume')
if ($LASTEXITCODE -ne 0) { throw "package app example exited $LASTEXITCODE" }
Assert-Equal 'package use resolution' "36`nDONE" ($packagesRun -join "`n")

$cyclicOutput = & $Lume install (Join-Path $PSScriptRoot 'examples\packages\cyclic-a') 2>&1
if ($LASTEXITCODE -ne 1) { throw "cyclic package install should exit 1" }
Assert-Equal 'package dependency cycle validation' 'E0709 dependency cycle at `cyclic-b`' ($cyclicOutput -join "`n")

Write-Host 'All Lume smoke tests passed.'
