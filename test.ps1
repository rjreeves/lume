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

$helloDefault = & $Lume run (Join-Path $PSScriptRoot 'examples\hello.lume')
if ($LASTEXITCODE -ne 0) { throw "hello (default) exited $LASTEXITCODE" }
Assert-Equal 'hello with no args' 'hello, world' ($helloDefault -join "`n")

$helloArg = & $Lume run (Join-Path $PSScriptRoot 'examples\hello.lume') 'Ada'
if ($LASTEXITCODE -ne 0) { throw "hello (arg) exited $LASTEXITCODE" }
Assert-Equal 'hello with an arg' 'hello, Ada' ($helloArg -join "`n")

$wordCount = & $Lume run (Join-Path $PSScriptRoot 'examples\word_count.lume') (Join-Path $PSScriptRoot 'examples\word_count_sample.txt')
if ($LASTEXITCODE -ne 0) { throw "word count exited $LASTEXITCODE" }
Assert-Equal 'word count (character count)' '10' ($wordCount -join "`n")

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

$jsonDecodeEnum = & $Lume run (Join-Path $PSScriptRoot 'examples\json_decode_enum.lume')
if ($LASTEXITCODE -ne 0) { throw "json decode enum exited $LASTEXITCODE" }
Assert-Equal 'json decode enum' "0`n7`n7" ($jsonDecodeEnum -join "`n")

$jsonDecodeEnumVariant = & $Lume run (Join-Path $PSScriptRoot 'examples\invalid_json_decode_enum_variant.lume')
if ($LASTEXITCODE -ne 0) { throw "json decode enum unknown variant exited $LASTEXITCODE" }
Assert-Equal 'json decode enum unknown variant' 'State has unknown variant `unknown` of `State`' ($jsonDecodeEnumVariant -join "`n")

$jsonDecodeEnumField = & $Lume run (Join-Path $PSScriptRoot 'examples\invalid_json_decode_enum_field.lume')
if ($LASTEXITCODE -ne 0) { throw "json decode enum missing field exited $LASTEXITCODE" }
Assert-Equal 'json decode enum missing field' 'State is missing field `code`' ($jsonDecodeEnumField -join "`n")

$jsonDecodeEnumShape = & $Lume run (Join-Path $PSScriptRoot 'examples\invalid_json_decode_enum_shape.lume')
if ($LASTEXITCODE -ne 0) { throw "json decode enum wrong shape exited $LASTEXITCODE" }
Assert-Equal 'json decode enum wrong shape' 'State must be State' ($jsonDecodeEnumShape -join "`n")

$pathFunctions = & $Lume run (Join-Path $PSScriptRoot 'examples\path_functions.lume')
if ($LASTEXITCODE -ne 0) { throw "path functions exited $LASTEXITCODE" }
Assert-Equal 'path functions' "reports/2026`nsummary.csv`nreports/2026`nsummary`ncsv`nnone" ($pathFunctions -join "`n")

$strFromInt = & $Lume run (Join-Path $PSScriptRoot 'examples\str_from_int.lume')
if ($LASTEXITCODE -ne 0) { throw "str.from_int exited $LASTEXITCODE" }
Assert-Equal 'str.from_int' "42!`n0`n-7" ($strFromInt -join "`n")

$invalidStrFromInt = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_str_from_int_args.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "str.from_int argument validation should exit 1" }
Assert-Equal 'str.from_int requires int' 'E0730 line 2: builtin `str.from_int` requires int' ($invalidStrFromInt -join "`n")

$dirList = & $Lume run (Join-Path $PSScriptRoot 'examples\dir_list.lume')
if ($LASTEXITCODE -ne 0) { throw "dir list exited $LASTEXITCODE" }
Assert-Equal 'directory listing' "2`nmath_test.lume`ntext_test.lume" ($dirList -join "`n")

$invalidDirList = & $Lume run (Join-Path $PSScriptRoot 'examples\invalid_dir_list.lume')
if ($LASTEXITCODE -ne 0) { throw "invalid dir list exited $LASTEXITCODE" }
Assert-Equal 'directory listing missing path' 'false' ($invalidDirList -join "`n")

$dirWalk = & $Lume run (Join-Path $PSScriptRoot 'examples\dir_walk.lume')
if ($LASTEXITCODE -ne 0) { throw "dir walk exited $LASTEXITCODE" }
Assert-Equal 'recursive directory walk' "1`n2`n3" ($dirWalk -join "`n")

$dirWalkMissing = & $Lume run (Join-Path $PSScriptRoot 'examples\invalid_dir_walk_missing.lume')
if ($LASTEXITCODE -ne 0) { throw "dir walk missing path exited $LASTEXITCODE" }
Assert-Equal 'dir walk missing path' 'cannot list directory `examples/does_not_exist_at_all`' ($dirWalkMissing -join "`n")

$nestedSuite = & $Lume test (Join-Path $PSScriptRoot 'examples\native_suite_nested')
if ($LASTEXITCODE -ne 0) { throw "recursive test discovery exited $LASTEXITCODE" }
Assert-Contains 'recursive test discovery finds top-level test' 'PASS top level works' ($nestedSuite -join "`n")
Assert-Contains 'recursive test discovery finds nested test' 'PASS nested works' ($nestedSuite -join "`n")

$ignoreSuiteDir = Join-Path $PSScriptRoot 'examples\native_suite_with_ignore'
$unignoredSuite = & $Lume test $ignoreSuiteDir 2>&1
if ($LASTEXITCODE -ne 1) { throw "unignored suite with a failing nested test should exit 1" }
Assert-Contains 'without --ignore, node_modules is still walked' 'FAIL should never run' ($unignoredSuite -join "`n")

$ignoredSuite = & $Lume test $ignoreSuiteDir --ignore node_modules
if ($LASTEXITCODE -ne 0) { throw "--ignore node_modules should skip the failing nested test, exited $LASTEXITCODE" }
Assert-Contains '--ignore node_modules runs the top-level test' 'PASS real test passes' ($ignoredSuite -join "`n")
Assert-Contains '--ignore node_modules skips the subdirectory entirely' '1 passed; 0 failed' ($ignoredSuite -join "`n")

$timeFunctions = & $Lume run (Join-Path $PSScriptRoot 'examples\time_functions.lume')
if ($LASTEXITCODE -ne 0) { throw "time functions exited $LASTEXITCODE" }
Assert-Equal 'time functions' "true`n1970-01-01T00:00:00Z`n2023-11-14T22:13:20Z" ($timeFunctions -join "`n")

$invalidTimeToIso = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_time_to_iso.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "time.to_iso validation should exit 1" }
Assert-Equal 'time.to_iso requires int' 'E0699 line 2: builtin `time.to_iso` requires int' ($invalidTimeToIso -join "`n")

$timeCalendar = & $Lume run (Join-Path $PSScriptRoot 'examples\time_calendar.lume')
if ($LASTEXITCODE -ne 0) { throw "time calendar exited $LASTEXITCODE" }
Assert-Equal 'time calendar components' "2023`n11`n14`n22`n13`n20" ($timeCalendar -join "`n")

$invalidTimeYear = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_time_year_args.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "time.year validation should exit 1" }
Assert-Equal 'time.year requires int' 'E0699 line 2: builtin `time.year` requires int' ($invalidTimeYear -join "`n")

$timeFormat = & $Lume run (Join-Path $PSScriptRoot 'examples\time_format.lume')
if ($LASTEXITCODE -ne 0) { throw "time format exited $LASTEXITCODE" }
Assert-Equal 'time format' "2023-11-14`n22:13:20`n2023-11-14T22:13:20Z" ($timeFormat -join "`n")

$invalidTimeFormat = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_time_format_args.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "time.format validation should exit 1" }
Assert-Equal 'time.format requires (int, str)' 'E0715 line 2: builtin `time.format` requires (int, str)' ($invalidTimeFormat -join "`n")

$timeTimezone = & $Lume run (Join-Path $PSScriptRoot 'examples\time_timezone.lume')
if ($LASTEXITCODE -ne 0) { throw "time timezone exited $LASTEXITCODE" }
Assert-Equal 'time timezone' "true`n2023-11-14T17:13:20-05:00`ntrue`n2023-11-14 17:13:20`nfalse`nunknown timezone ``Not/AZone``" ($timeTimezone -join "`n")

$invalidTimeInTimezone = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_time_in_timezone_args.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "time.in_timezone validation should exit 1" }
Assert-Equal 'time.in_timezone requires (int, str)' 'E0716 line 2: builtin `time.in_timezone` requires (int, str)' ($invalidTimeInTimezone -join "`n")

$durationUnits = & $Lume run (Join-Path $PSScriptRoot 'examples\duration_units.lume')
if ($LASTEXITCODE -ne 0) { throw "duration units exited $LASTEXITCODE" }
Assert-Equal 'duration units' "42`n300`n7200`n86400`ntrue" ($durationUnits -join "`n")

$invalidDuration = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_duration_args.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "duration.minutes validation should exit 1" }
Assert-Equal 'duration.minutes requires int' 'E0699 line 2: builtin `duration.minutes` requires int' ($invalidDuration -join "`n")

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

$ordImplRun = & $Lume run (Join-Path $PSScriptRoot 'examples\ord_impl.lume')
if ($LASTEXITCODE -ne 0) { throw "ord impl exited $LASTEXITCODE" }
Assert-Equal 'explicit Ord implementation' "true`ntrue`nfalse`nfalse`n250`n100`n250" ($ordImplRun -join "`n")

$genericOperators = & $Lume run (Join-Path $PSScriptRoot 'examples\generic_operators.lume')
if ($LASTEXITCODE -ne 0) { throw "generic operators exited $LASTEXITCODE" }
Assert-Equal 'generic operators on a constrained type parameter' "5`nfoobar`n2" ($genericOperators -join "`n")

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

# A structurally-valid artifact (correct magic/hash/counts/framing) whose
# instructions were produced by an incompatible build - simulated here by
# patching one real "return" opcode's bytes in place, same length, so no
# other offset shifts - must be rejected cleanly rather than silently
# skipping the unrecognized instruction and corrupting execution.
$staleArtifactBytes = [IO.File]::ReadAllBytes($artifactPath)
$cursor = 76
$patchedOffset = -1
while ($cursor -lt $staleArtifactBytes.Length) {
  $opLength = [BitConverter]::ToInt64($staleArtifactBytes, $cursor)
  $opStart = $cursor + 8
  $op = [Text.Encoding]::UTF8.GetString($staleArtifactBytes, $opStart, $opLength)
  if ($op -eq 'return') { $patchedOffset = $opStart }
  $cursor = $opStart + $opLength
  $textLength = [BitConverter]::ToInt64($staleArtifactBytes, $cursor)
  $cursor = $cursor + 8 + $textLength + 16
}
if ($patchedOffset -lt 0) { throw 'no return opcode found to patch in test-functions.lbc' }
[Text.Encoding]::UTF8.GetBytes('zzzzzz').CopyTo($staleArtifactBytes, $patchedOffset)
$staleArtifactPath = Join-Path $PSScriptRoot 'dist\stale-opcode.lbc'
[IO.File]::WriteAllBytes($staleArtifactPath, $staleArtifactBytes)
$staleArtifactRun = & $Lume exec $staleArtifactPath 2>&1
if ($LASTEXITCODE -ne 1) { throw "stale-opcode bytecode should exit 1" }
Assert-Contains 'unrecognized bytecode operation rejection' 'E0725' ($staleArtifactRun -join "`n")

# callBuiltin's own diagnostics (as opposed to checkBuiltinTypes' compile-
# time twin) only run at actual execution, never during `lume check` on
# real source - since a legitimate call already passed typechecking by
# the time it reaches this path. Reached here the same way as the stale-
# opcode case above: patch a real, already-typechecked "call" instruction
# to target a different, incompatible builtin of the same name length
# (str.len -> map.len, both 7 bytes, no offset shift needed), simulating
# the only way this runtime path is ever actually reachable - a stale or
# hand-tampered bytecode artifact, not anything expressible in source.
$builtinCheckPath = Join-Path $PSScriptRoot 'dist\callbuiltin-runtime-check.lbc'
& $Lume build (Join-Path $PSScriptRoot 'examples\callbuiltin_runtime_check.lume') $builtinCheckPath | Out-Null
if ($LASTEXITCODE -ne 0) { throw "callbuiltin runtime check build exited $LASTEXITCODE" }
$builtinCheckBytes = [IO.File]::ReadAllBytes($builtinCheckPath)
$cursor = 76
$textPatchOffset = -1
while ($cursor -lt $builtinCheckBytes.Length) {
  $opLength = [BitConverter]::ToInt64($builtinCheckBytes, $cursor)
  $opStart = $cursor + 8
  $op = [Text.Encoding]::UTF8.GetString($builtinCheckBytes, $opStart, $opLength)
  $cursor = $opStart + $opLength
  $textLength = [BitConverter]::ToInt64($builtinCheckBytes, $cursor)
  $textStart = $cursor + 8
  $text = [Text.Encoding]::UTF8.GetString($builtinCheckBytes, $textStart, $textLength)
  if ($op -eq 'call' -and $text -eq 'str.len') { $textPatchOffset = $textStart }
  $cursor = $textStart + $textLength + 16
}
if ($textPatchOffset -lt 0) { throw 'no call to str.len found to patch in callbuiltin-runtime-check.lbc' }
[Text.Encoding]::UTF8.GetBytes('map.len').CopyTo($builtinCheckBytes, $textPatchOffset)
[IO.File]::WriteAllBytes($builtinCheckPath, $builtinCheckBytes)
$builtinCheckRun = & $Lume exec $builtinCheckPath 2>&1
if ($LASTEXITCODE -ne 1) { throw "callbuiltin runtime check should exit 1" }
Assert-Equal 'callBuiltin runtime diagnostic carries a line number' 'E0695 line 3: builtin `map.len` expected Map' ($builtinCheckRun -join "`n")

$coreApi = & $Lume run (Join-Path $PSScriptRoot 'examples\core_api.lume') (Join-Path $PSScriptRoot 'examples\data.json')
if ($LASTEXITCODE -ne 0) { throw "core APIs exited $LASTEXITCODE" }
Assert-Equal 'core APIs' "1`n28`ntrue`nLUME`n1`ntrue`n0" ($coreApi -join "`n")

$processResult = & $Lume run (Join-Path $PSScriptRoot 'examples\process.lume')
if ($LASTEXITCODE -ne 0) { throw "process example exited $LASTEXITCODE" }
Assert-Equal 'structured process result' "true`n0`nhello from process" ($processResult -join "`n")

$processConfig = & $Lume run (Join-Path $PSScriptRoot 'examples\process_config.lume')
if ($LASTEXITCODE -ne 0) { throw "process config example exited $LASTEXITCODE" }
Assert-Equal 'richer process configuration' "HELLO LUME`nhello_from_lume`nfalse" ($processConfig -join "`n")

$processOptions = & $Lume run (Join-Path $PSScriptRoot 'examples\process_run_with_options.lume')
if ($LASTEXITCODE -ne 0) { throw "process run_with_options exited $LASTEXITCODE" }
Assert-Equal 'process run_with_options (working directory and timeout)' "C:\Users`n0`n-1" ($processOptions -join "`n")

$processOptionsArgs = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_process_run_with_options_args.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "process run_with_options argument validation should exit 1" }
Assert-Equal 'process run_with_options argument validation' 'E0727 line 2: process.run_with_options requires (str, [str], str, int)' ($processOptionsArgs -join "`n")

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

# The fifth network-dependent check: httpbin.org/json serves a fixed, never-changing
# document, chosen (like example.com above) so a typed decode of a live response is
# actually deterministic.
$httpJson = & $Lume run (Join-Path $PSScriptRoot 'examples\http_json.lume')
if ($LASTEXITCODE -ne 0) { throw "http json example exited $LASTEXITCODE" }
Assert-Equal 'http json decode' "Yours Truly`nSample Slide Show" ($httpJson -join "`n")

# The sixth network-dependent check: a request-time-bounded fetch of example.com's
# own stable page, once with a tiny limit (proving truncation) and once unlimited.
$httpLimit = & $Lume run (Join-Path $PSScriptRoot 'examples\http_request_with_limit.lume')
if ($LASTEXITCODE -ne 0) { throw "http request with limit example exited $LASTEXITCODE" }
Assert-Equal 'http request with limit' "true`ntrue`nfalse`ntrue" ($httpLimit -join "`n")

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
Assert-Equal 'bytes.to_str requires bytes' 'E0712 line 2: builtin `bytes.to_str` requires bytes' ($invalidBytesToStr -join "`n")

$check = & $Lume check (Join-Path $PSScriptRoot 'examples\arithmetic.lume')
if ($LASTEXITCODE -ne 0) { throw "check exited $LASTEXITCODE" }
Assert-Equal 'check' 'ok' ($check -join "`n")

$immutable = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_immutable.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "immutable validation should exit 1" }
Assert-Equal 'immutable validation' 'E0215 line 3: cannot assign to immutable `answer`' ($immutable -join "`n")

$undefined = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_undefined.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "undefined validation should exit 1" }
Assert-Equal 'undefined validation' 'E0210 line 2: undefined binding `missing`' ($undefined -join "`n")

$badTestTimeout = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_test_timeout.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "test timeout clause validation should exit 1" }
Assert-Equal 'test timeout clause validation' 'E0724 line 1: expected integer timeout value in milliseconds' ($badTestTimeout -join "`n")

$badProcessAssertion = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_process_assertion.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "process assertion receiver validation should exit 1" }
Assert-Equal 'process assertion receiver validation' 'E0718 line 2: expect.exit_code requires a process result' ($badProcessAssertion -join "`n")

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

$namedAfterPositional = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_call_named_after_positional.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "named-after-positional argument validation should exit 1" }
Assert-Equal 'named argument after positional argument validation' 'E0106 line 6: named argument cannot follow positional argument' ($namedAfterPositional -join "`n")

$positionalAfterNamed = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_call_positional_after_named.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "positional-after-named argument validation should exit 1" }
Assert-Equal 'positional argument after named argument validation' 'E0105 line 6: positional argument cannot follow named argument' ($positionalAfterNamed -join "`n")

$missingCallComma = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_call_missing_comma.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "missing call comma validation should exit 1" }
Assert-Equal 'missing comma in argument list validation' 'E0103 line 6: expected `,` or `)` in argument list' ($missingCallComma -join "`n")

$closureMissingParen = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_closure_missing_paren.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "closure missing paren validation should exit 1" }
Assert-Equal 'closure missing paren validation' 'E0122 line 2: expected `(` after `fn`' ($closureMissingParen -join "`n")

$closureParamName = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_closure_param_name.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "closure param name validation should exit 1" }
Assert-Equal 'closure param name validation' 'E0123 line 2: expected closure parameter name' ($closureParamName -join "`n")

$closureDuplicateParam = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_closure_duplicate_param.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "closure duplicate param validation should exit 1" }
Assert-Equal 'closure duplicate param validation' 'E0124 line 2: duplicate closure parameter `x`' ($closureDuplicateParam -join "`n")

$closureMissingColon = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_closure_missing_colon.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "closure missing colon validation should exit 1" }
Assert-Equal 'closure missing colon validation' 'E0125 line 2: expected `:` after closure parameter' ($closureMissingColon -join "`n")

$closureMissingComma = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_closure_missing_comma.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "closure missing comma validation should exit 1" }
Assert-Equal 'closure missing comma validation' 'E0126 line 2: expected `,` or `)` in closure parameters' ($closureMissingComma -join "`n")

$closureMissingReturnType = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_closure_missing_return_type.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "closure missing return type validation should exit 1" }
Assert-Equal 'closure missing return type validation' 'E0127 line 2: closure requires a return type' ($closureMissingReturnType -join "`n")

$closureMissingArrow = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_closure_missing_arrow.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "closure missing arrow validation should exit 1" }
Assert-Equal 'closure missing arrow validation' 'E0128 line 2: expected `=>` before closure body' ($closureMissingArrow -join "`n")

$matchMissingBrace = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_match_missing_brace.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "match missing brace validation should exit 1" }
Assert-Equal 'match missing brace validation' 'E0110 line 7: expected `{` after match value' ($matchMissingBrace -join "`n")

$matchVariantName = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_match_variant_name.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "match variant name validation should exit 1" }
Assert-Equal 'match variant name validation' 'E0111 line 8: expected variant name in match arm' ($matchVariantName -join "`n")

$matchBindingName = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_match_binding_name.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "match binding name validation should exit 1" }
Assert-Equal 'match binding name validation' 'E0115 line 9: expected payload binding name' ($matchBindingName -join "`n")

$matchBindingComma = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_match_binding_comma.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "match binding comma validation should exit 1" }
Assert-Equal 'match binding comma validation' 'E0116 line 9: expected `,` or `)` in variant pattern' ($matchBindingComma -join "`n")

$matchMissingArrow = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_match_missing_arrow.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "match missing arrow validation should exit 1" }
Assert-Equal 'match missing arrow validation' 'E0112 line 8: expected `=>` after match variant' ($matchMissingArrow -join "`n")

$matchNoArms = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_match_no_arms.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "match no arms validation should exit 1" }
Assert-Equal 'match no arms validation' 'E0114 line 8: match expression requires at least one arm' ($matchNoArms -join "`n")

$matchUnterminated = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_match_unterminated.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "match unterminated validation should exit 1" }
Assert-Equal 'match unterminated validation' 'E0113 line 11: unterminated match expression' ($matchUnterminated -join "`n")

$blockUnterminated = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_block_unterminated.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "unterminated block validation should exit 1" }
Assert-Equal 'unterminated block validation' 'E0202 line 4: unterminated block' ($blockUnterminated -join "`n")

$recordUpdateMissingBrace = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_record_update_missing_brace.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "record update missing brace validation should exit 1" }
Assert-Equal 'record update missing brace validation' 'E0117 line 7: expected `{` after `with`' ($recordUpdateMissingBrace -join "`n")

$recordUpdateFieldName = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_record_update_field_name.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "record update field name validation should exit 1" }
Assert-Equal 'record update field name validation' 'E0118 line 8: expected field name in record update' ($recordUpdateFieldName -join "`n")

$recordUpdateMissingColon = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_record_update_missing_colon.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "record update missing colon validation should exit 1" }
Assert-Equal 'record update missing colon validation' 'E0119 line 8: expected `:` after updated field' ($recordUpdateMissingColon -join "`n")

$recordUpdateUnterminated = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_record_update_unterminated.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "record update unterminated validation should exit 1" }
Assert-Equal 'record update unterminated validation' 'E0120 line 10: unterminated record update' ($recordUpdateUnterminated -join "`n")

$recordUpdateNoFields = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_record_update_no_fields.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "record update no fields validation should exit 1" }
Assert-Equal 'record update no fields validation' 'E0121 line 8: record update requires at least one field' ($recordUpdateNoFields -join "`n")

$recordName = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_record_name.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "record name validation should exit 1" }
Assert-Equal 'record name validation' 'E0230 line 1: expected record name' ($recordName -join "`n")

$recordUnterminated = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_record_unterminated.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "record unterminated validation should exit 1" }
Assert-Equal 'record unterminated validation' 'E0236 line 4: unterminated record `User`' ($recordUnterminated -join "`n")

$enumName = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_enum_name.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "enum name validation should exit 1" }
Assert-Equal 'enum name validation' 'E0240 line 1: expected enum name' ($enumName -join "`n")

$enumUnterminated = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_enum_unterminated.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "enum unterminated validation should exit 1" }
Assert-Equal 'enum unterminated validation' 'E0248 line 5: unterminated enum `State`' ($enumUnterminated -join "`n")

$bindingName = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_binding_name.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "binding name validation should exit 1" }
Assert-Equal 'binding name validation' 'E0203 line 2: expected binding name' ($bindingName -join "`n")

$bindingEquals = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_binding_equals.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "binding equals validation should exit 1" }
Assert-Equal 'binding equals validation' 'E0204 line 2: expected `=`' ($bindingEquals -join "`n")

$printMissingParen = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_print_missing_paren.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "print missing paren validation should exit 1" }
Assert-Equal 'print missing paren validation' 'E0205 line 2: expected `(`' ($printMissingParen -join "`n")

$printMissingCloseParen = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_print_missing_close_paren.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "print missing close paren validation should exit 1" }
Assert-Equal 'print missing close paren validation' 'E0206 line 2: expected `)`' ($printMissingCloseParen -join "`n")

$unsupportedStatement = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_unsupported_statement.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "unsupported statement validation should exit 1" }
Assert-Equal 'unsupported statement validation' 'E0207 line 2: unsupported statement `123`' ($unsupportedStatement -join "`n")

$ifMissingBrace = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_if_missing_brace.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "if missing brace validation should exit 1" }
Assert-Equal 'if missing brace validation' 'E0212 line 2: expected `{` after if condition' ($ifMissingBrace -join "`n")

$elseMissingBrace = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_else_missing_brace.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "else missing brace validation should exit 1" }
Assert-Equal 'else missing brace validation' 'E0213 line 4: expected `{` after else' ($elseMissingBrace -join "`n")

$whileMissingBrace = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_while_missing_brace.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "while missing brace validation should exit 1" }
Assert-Equal 'while missing brace validation' 'E0214 line 2: expected `{` after while condition' ($whileMissingBrace -join "`n")

$functionName = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_function_name.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "function name validation should exit 1" }
Assert-Equal 'function name validation' 'E0221 line 1: expected function name' ($functionName -join "`n")

$implMethodNoBody = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_impl_method_no_body.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "impl method no body validation should exit 1" }
Assert-Equal 'impl method no body validation' 'E0223 line 4: function `Widget.describe` has no body' ($implMethodNoBody -join "`n")

$functionNoBody = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_function_no_body.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "function no body validation should exit 1" }
Assert-Equal 'function no body validation' 'E0223 line 3: function `broken` has no body' ($functionNoBody -join "`n")

$testNoBody = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_test_no_body.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "test no body validation should exit 1" }
Assert-Equal 'test no body validation' 'E0225 line 3: test `sample` has no body' ($testNoBody -join "`n")

$protocolName = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_protocol_name.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "protocol name validation should exit 1" }
Assert-Equal 'protocol name validation' 'E0250 line 1: expected protocol name' ($protocolName -join "`n")

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
Assert-Equal 'process argument validation' 'E0619 line 2: process.run requires (str, [str])' ($processArgs -join "`n")

$processInputArgs = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_process_run_with_input_args.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "process run_with_input argument validation should exit 1" }
Assert-Equal 'process run_with_input argument validation' 'E0700 line 2: process.run_with_input requires (str, [str], str)' ($processInputArgs -join "`n")

$processEnvArgs = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_process_run_with_env_args.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "process run_with_env argument validation should exit 1" }
Assert-Equal 'process run_with_env argument validation' 'E0700 line 2: process.run_with_env requires (str, [str], Map<str,str>)' ($processEnvArgs -join "`n")

$httpGetArgs = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_http_get_args.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "http get argument validation should exit 1" }
Assert-Equal 'http get argument validation' 'E0608 line 2: builtin `http.get` requires str' ($httpGetArgs -join "`n")

$httpPostArgs = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_http_post_args.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "http post argument validation should exit 1" }
Assert-Equal 'http post argument validation' 'E0710 line 2: builtin `http.post` requires (str, str, str)' ($httpPostArgs -join "`n")

$httpRequestArgs = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_http_request_args.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "http request argument validation should exit 1" }
Assert-Equal 'http request argument validation' 'E0711 line 2: http.request requires (str, str, Map<str,str>, str)' ($httpRequestArgs -join "`n")

$httpRequestWithLimitArgs = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_http_request_with_limit_args.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "http request with limit argument validation should exit 1" }
Assert-Equal 'http request with limit argument validation' 'E0729 line 2: http.request_with_limit requires (str, str, Map<str,str>, str, int)' ($httpRequestWithLimitArgs -join "`n")

$envSetArgs = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_env_set_args.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "env set argument validation should exit 1" }
Assert-Equal 'env set argument validation' 'E0607 line 2: builtin `env.set` requires str arguments' ($envSetArgs -join "`n")

$unwrap = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_unwrap.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "unwrap validation should exit 1" }
Assert-Equal 'unwrap context validation' 'E0624 line 2: `!` requires an enclosing result-returning function' ($unwrap -join "`n")

$genericArgument = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_generic_argument.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "generic argument validation should exit 1" }
Assert-Equal 'generic substitution validation' 'E0609 line 6: argument type mismatch calling `same`; expected str, got int' ($genericArgument -join "`n")

$genericConstraint = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_generic_constraint.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "generic constraint validation should exit 1" }
Assert-Equal 'generic constraint validation' 'E0680 line 6: type `str` does not satisfy `Number` for `T` calling `requires_number`' ($genericConstraint -join "`n")

$genericOperatorConstraint = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_generic_operator.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "generic operator constraint validation should exit 1" }
Assert-Equal 'generic operator constraint validation' 'E0613 line 2: incompatible operand types T and T' ($genericOperatorConstraint -join "`n")

$genericConstraintName = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_generic_constraint_name.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "unknown generic constraint should exit 1" }
Assert-Equal 'generic constraint name validation' 'E0679 line 1: unknown generic constraint `Printable`' ($genericConstraintName -join "`n")

$protocolConstraint = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_protocol_constraint.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "missing protocol implementation should exit 1" }
Assert-Equal 'protocol implementation constraint' 'E0680 line 12: type `User` does not satisfy `Named` for `T` calling `keep_named`' ($protocolConstraint -join "`n")

$protocolImpl = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_protocol_impl.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "unknown protocol implementation should exit 1" }
Assert-Equal 'unknown protocol implementation' 'E0258 line 5: unknown protocol `Missing` in implementation' ($protocolImpl -join "`n")

$protocolMissingMethod = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_protocol_missing_method.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "missing protocol method should exit 1" }
Assert-Equal 'missing protocol method' 'E0262 line 9: implementation of `Named` for `User` is missing method `name`' ($protocolMissingMethod -join "`n")

$protocolMethodType = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_protocol_method_type.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "protocol method signature mismatch should exit 1" }
Assert-Equal 'protocol method signature' 'E0263 line 9: method `User.name` does not match protocol signature' ($protocolMethodType -join "`n")

$protocolExtraMethod = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_protocol_extra_method.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "extra protocol method should exit 1" }
Assert-Equal 'extra protocol method' 'E0264 line 9: method `code` is not declared by protocol `Named`' ($protocolExtraMethod -join "`n")

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
Assert-Equal 'map requires a map' 'E0695 line 2: `map.len` requires a Map' ($mapRequiresMap -join "`n")

$mapKeyTypeMismatch = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_map_key_type_mismatch.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "map key type mismatch validation should exit 1" }
Assert-Equal 'map key type mismatch' 'E0696 line 3: `map.get` key type does not match map key type' ($mapKeyTypeMismatch -join "`n")

$mapKeyNotEligible = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_map_key_not_eligible.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "map key eligibility validation should exit 1" }
Assert-Equal 'map key not eligible' 'E0697 line 6: map key type must be int, str, bool, or a type with `impl Eq for <Type> {}`' ($mapKeyNotEligible -join "`n")

$ordImpl = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_ord_impl.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "Ord impl missing method validation should exit 1" }
Assert-Equal 'Ord impl missing method validation' 'E0262 line 6: implementation of `Ord` for `Point` is missing method `compare`' ($ordImpl -join "`n")

$ordImplSignature = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_ord_impl_signature.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "Ord impl signature validation should exit 1" }
Assert-Equal 'Ord impl signature validation' 'E0263 line 5: method `Money.compare` does not match protocol signature' ($ordImplSignature -join "`n")

$orderedComparison = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_ordered_comparison.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "ordered comparison validation should exit 1" }
Assert-Equal 'ordered comparison validation' 'E0615 line 9: ordered comparison requires int or a type with `impl Ord for <Type> {}`' ($orderedComparison -join "`n")

$mapValueTypeMismatch = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_map_value_type_mismatch.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "map value type mismatch validation should exit 1" }
Assert-Equal 'map value type mismatch' 'E0698 line 3: map.set value type does not match map value type' ($mapValueTypeMismatch -join "`n")

$mapCallback = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_map_callback.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "map callback validation should exit 1" }
Assert-Equal 'map callback validation' 'E0673 line 7: callback parameter type does not match map value type' ($mapCallback -join "`n")

$listCallback = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_list_callback.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "list callback validation should exit 1" }
Assert-Equal 'list callback validation' 'E0673 line 6: callback parameter type does not match list element type' ($listCallback -join "`n")

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

$nativeTimeout = & $Lume test (Join-Path $PSScriptRoot 'examples\native_tests_timeout.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "native test timeout should exit 1" }
Assert-Equal 'native test timeout' "PASS completes well within its timeout`nFAIL hangs past its timeout (line 5): test timed out after 50ms`n1 passed; 1 failed" ($nativeTimeout -join "`n")

$nativeProcessAssertions = & $Lume test (Join-Path $PSScriptRoot 'examples\native_tests_process.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "native process assertion test should exit 1" }
Assert-Equal 'process-output assertions' "PASS process exit code and stdout can be asserted`nFAIL process assertions report a mismatch (line 7): expected exit code 1, got 0`n1 passed; 1 failed" ($nativeProcessAssertions -join "`n")

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

# lume lsp is a persistent stdio JSON-RPC server, not a one-shot command, so
# it needs its own framed-message client rather than a plain stdout compare.
function Send-LspMessage([System.Diagnostics.Process]$Proc, [string]$Json) {
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($Json)
  $header = "Content-Length: $($bytes.Length)`r`n`r`n"
  $headerBytes = [System.Text.Encoding]::ASCII.GetBytes($header)
  $stream = $Proc.StandardInput.BaseStream
  $stream.Write($headerBytes, 0, $headerBytes.Length)
  $stream.Write($bytes, 0, $bytes.Length)
  $stream.Flush()
}

function Read-LspMessage([System.Diagnostics.Process]$Proc) {
  $stream = $Proc.StandardOutput.BaseStream
  $contentLength = -1
  $lineBytes = New-Object System.Collections.Generic.List[byte]
  while ($true) {
    $b = $stream.ReadByte()
    if ($b -eq -1) { throw 'lsp server closed stdout unexpectedly' }
    if ($b -eq 13) { continue }
    if ($b -eq 10) {
      $line = [System.Text.Encoding]::ASCII.GetString($lineBytes.ToArray())
      if ($line -eq '') { break }
      if ($line -like 'Content-Length:*') { $contentLength = [int]($line.Substring(15).Trim()) }
      $lineBytes.Clear()
    } else {
      $lineBytes.Add([byte]$b)
    }
  }
  if ($contentLength -lt 0) { throw 'lsp response missing Content-Length' }
  $bodyBytes = New-Object byte[] $contentLength
  $read = 0
  while ($read -lt $contentLength) {
    $n = $stream.Read($bodyBytes, $read, $contentLength - $read)
    if ($n -le 0) { throw 'lsp server closed stdout mid-body' }
    $read += $n
  }
  return [System.Text.Encoding]::UTF8.GetString($bodyBytes)
}

$lspPsi = New-Object System.Diagnostics.ProcessStartInfo
$lspPsi.FileName = $Lume
$lspPsi.Arguments = 'lsp'
$lspPsi.RedirectStandardInput = $true
$lspPsi.RedirectStandardOutput = $true
$lspPsi.RedirectStandardError = $true
$lspPsi.UseShellExecute = $false
$lspProc = [System.Diagnostics.Process]::Start($lspPsi)
try {
  Send-LspMessage $lspProc '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}'
  $initResponse = Read-LspMessage $lspProc | ConvertFrom-Json
  Assert-Equal 'lsp initialize advertises full-document sync' '1' "$($initResponse.result.capabilities.textDocumentSync)"

  Send-LspMessage $lspProc '{"jsonrpc":"2.0","method":"initialized","params":{}}'

  $brokenUri = 'file:///broken.lume'
  $brokenSource = "fn main(args: [str]) -> int {`n  return undefinedVariable`n}`n"
  $didOpenBroken = @{ jsonrpc = '2.0'; method = 'textDocument/didOpen'; params = @{ textDocument = @{ uri = $brokenUri; text = $brokenSource } } } | ConvertTo-Json -Depth 10 -Compress
  Send-LspMessage $lspProc $didOpenBroken
  $brokenDiag = Read-LspMessage $lspProc | ConvertFrom-Json
  Assert-Equal 'lsp publishes diagnostics for the opened uri' $brokenUri $brokenDiag.params.uri
  Assert-Equal 'lsp reports one diagnostic for a compile error' '1' "$($brokenDiag.params.diagnostics.Count)"
  Assert-Equal 'lsp diagnostic code matches lume check' 'E0210' $brokenDiag.params.diagnostics[0].code
  Assert-Equal 'lsp diagnostic line is 0-indexed' '1' "$($brokenDiag.params.diagnostics[0].range.start.line)"
  Assert-Equal 'lsp diagnostic message matches lume check' 'undefined binding `undefinedVariable`' $brokenDiag.params.diagnostics[0].message

  $validUri = 'file:///valid.lume'
  $validSource = "fn main(args: [str]) -> int {`n  return 0`n}`n"
  $didOpenValid = @{ jsonrpc = '2.0'; method = 'textDocument/didOpen'; params = @{ textDocument = @{ uri = $validUri; text = $validSource } } } | ConvertTo-Json -Depth 10 -Compress
  Send-LspMessage $lspProc $didOpenValid
  $validDiag = Read-LspMessage $lspProc | ConvertFrom-Json
  Assert-Equal 'lsp reports no diagnostics for valid source' '0' "$($validDiag.params.diagnostics.Count)"

  $didChangeFixed = @{ jsonrpc = '2.0'; method = 'textDocument/didChange'; params = @{ textDocument = @{ uri = $brokenUri }; contentChanges = @(@{ text = $validSource }) } } | ConvertTo-Json -Depth 10 -Compress
  Send-LspMessage $lspProc $didChangeFixed
  $changedDiag = Read-LspMessage $lspProc | ConvertFrom-Json
  Assert-Equal 'lsp didChange re-checks the full new text' '0' "$($changedDiag.params.diagnostics.Count)"

  $didClose = @{ jsonrpc = '2.0'; method = 'textDocument/didClose'; params = @{ textDocument = @{ uri = $validUri } } } | ConvertTo-Json -Depth 10 -Compress
  Send-LspMessage $lspProc $didClose
  $closedDiag = Read-LspMessage $lspProc | ConvertFrom-Json
  Assert-Equal 'lsp didClose clears diagnostics' '0' "$($closedDiag.params.diagnostics.Count)"

  Send-LspMessage $lspProc '{"jsonrpc":"2.0","id":2,"method":"shutdown"}'
  $shutdownResponse = Read-LspMessage $lspProc | ConvertFrom-Json
  Assert-Equal 'lsp shutdown responds with a null result' '' "$($shutdownResponse.result)"

  Send-LspMessage $lspProc '{"jsonrpc":"2.0","method":"exit"}'
  if (-not $lspProc.WaitForExit(5000)) { throw 'lsp server did not exit after an exit notification' }
  Assert-Equal 'lsp exits cleanly' '0' "$($lspProc.ExitCode)"
} finally {
  if (-not $lspProc.HasExited) { $lspProc.Kill() }
}

Write-Host 'All Lume smoke tests passed.'
