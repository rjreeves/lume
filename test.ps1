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

# Column tracking: multi-char names, single- and two-char symbols, a string
# literal's column is its opening quote (not its first content character),
# a tab counts as one column (not visually expanded), and newline/eof each
# report the column right after the line's last real character.
$tokenColumns = (& $Lume tokens (Join-Path $PSScriptRoot 'examples\token_columns.lume')) -join "`n"
Assert-Contains 'token columns: multi-char name' '1:4  name  add' $tokenColumns
Assert-Contains 'token columns: two-char symbol' '1:24  symbol  ->' $tokenColumns
Assert-Contains 'token columns: indented name after return' '2:3  name  return' $tokenColumns
Assert-Contains 'token columns: name after tab indent' '4:2  name  val' $tokenColumns
Assert-Contains 'token columns: string column is its opening quote' '4:10  string  hi' $tokenColumns
Assert-Contains 'token columns: eof column' '5:1  eof' $tokenColumns

$control = & $Lume run (Join-Path $PSScriptRoot 'examples\control_flow.lume')
if ($LASTEXITCODE -ne 0) { throw "control flow exited $LASTEXITCODE" }
Assert-Equal 'control flow' "control flow works`n10" ($control -join "`n")

$booleanOps = & $Lume run (Join-Path $PSScriptRoot 'examples\boolean_operators.lume')
if ($LASTEXITCODE -ne 0) { throw "boolean operators exited $LASTEXITCODE" }
Assert-Equal 'and/or/not with short-circuiting' "false`ntrue`ncalled and-right-2`ntrue`ncalled or-right-2`ntrue`nfalse`ntrue`ntrue`nfalse" ($booleanOps -join "`n")

$invalidBooleanOp = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_boolean_operator.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "invalid boolean operator validation should exit 1" }
Assert-Equal 'boolean operator requires bool operands' 'E0617 line 2: condition must be bool, got int' ($invalidBooleanOp -join "`n")

$ifExpression = & $Lume run (Join-Path $PSScriptRoot 'examples\if_expression.lume')
if ($LASTEXITCODE -ne 0) { throw "if expression exited $LASTEXITCODE" }
Assert-Equal 'if/else as an expression' "1`n2`nbig`n15`n42" ($ifExpression -join "`n")

$invalidIfExprTypes = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_if_expression_types.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "if-expression type mismatch validation should exit 1" }
Assert-Equal 'if-expression branches must agree on type' 'E0736 line 2: if-expression branches must return one type; expected int, got str' ($invalidIfExprTypes -join "`n")

$invalidIfExprNoElse = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_if_expression_no_else.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "if-expression missing else validation should exit 1" }
Assert-Equal 'if-expression requires else' 'E0733 line 2: if-expression requires `else`' ($invalidIfExprNoElse -join "`n")

$functions = & $Lume run (Join-Path $PSScriptRoot 'examples\functions.lume')
if ($LASTEXITCODE -ne 0) { throw "functions exited $LASTEXITCODE" }
Assert-Equal 'functions and recursion' "42`n120" ($functions -join "`n")

$modules = & $Lume run (Join-Path $PSScriptRoot 'examples\modules.lume')
if ($LASTEXITCODE -ne 0) { throw "modules exited $LASTEXITCODE" }
Assert-Equal 'recursive modules' '25' ($modules -join "`n")

$lists = & $Lume run (Join-Path $PSScriptRoot 'examples\lists.lume')
if ($LASTEXITCODE -ne 0) { throw "lists exited $LASTEXITCODE" }
Assert-Equal 'typed lists' "3`n20`n40" ($lists -join "`n")

$multilineList = & $Lume run (Join-Path $PSScriptRoot 'examples\multiline_list.lume')
if ($LASTEXITCODE -ne 0) { throw "multiline_list exited $LASTEXITCODE" }
Assert-Equal 'multi-line list literals' "3`n2`n0" ($multilineList -join "`n")

$multilineCallArgs = & $Lume run (Join-Path $PSScriptRoot 'examples\multiline_call_arguments.lume')
if ($LASTEXITCODE -ne 0) { throw "multiline_call_arguments exited $LASTEXITCODE" }
Assert-Equal 'multi-line call/record/variant construction arguments' "30`n1`n2`n7" ($multilineCallArgs -join "`n")

$invalidMultilineList = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_multiline_list.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "invalid_multiline_list should exit 1" }
Assert-Equal 'multi-line list literal missing comma reports a line number' 'E0104 line 4: expected `,` or `]` in list literal' ($invalidMultilineList -join "`n")

$records = & $Lume run (Join-Path $PSScriptRoot 'examples\records.lume')
if ($LASTEXITCODE -ne 0) { throw "records exited $LASTEXITCODE" }
Assert-Equal 'typed records' "Ada@Sydney`n36`ntools" ($records -join "`n")

$typedJson = & $Lume run (Join-Path $PSScriptRoot 'examples\typed_json.lume')
if ($LASTEXITCODE -ne 0) { throw "typed JSON exited $LASTEXITCODE" }
Assert-Equal 'typed JSON records' "Ada`nSydney`nGrace" ($typedJson -join "`n")

$invalidTypedJson = & $Lume run (Join-Path $PSScriptRoot 'examples\invalid_typed_json.lume')
if ($LASTEXITCODE -ne 0) { throw "invalid typed JSON example exited $LASTEXITCODE" }
Assert-Equal 'typed JSON path error' 'User.age must be int' ($invalidTypedJson -join "`n")

# The subprocess-embedding contract (docs/using-lume-the-fast-one.md
# section 22) - typed JSON in via a CLI argument, typed JSON out via
# stdout, with print()/eprint() kept on separate streams. Only the
# .lume side runs here; examples/embed_demo_host.py demonstrates the
# same contract from a genuinely different host language and is run
# manually (python3 examples/embed_demo_host.py), not wired into this
# suite, to avoid making a Python interpreter a hard dependency of the
# main test run.
$embedDemoPath = Join-Path $PSScriptRoot 'examples\embed_demo.lume'
$embedDemoOk = & $Lume run $embedDemoPath '{"n": 5}'
if ($LASTEXITCODE -ne 0) { throw "embed_demo success path exited $LASTEXITCODE" }
Assert-Equal 'embed_demo produces typed JSON on stdout' '{"input":5,"squared":25}' ($embedDemoOk -join "`n")

$embedDemoErr = & $Lume run $embedDemoPath '{"n": -3}' 2>&1
if ($LASTEXITCODE -ne 1) { throw "embed_demo negative-n path should exit 1" }
Assert-Equal 'embed_demo reports a negative n on stderr, not stdout' 'invalid argument: n must be positive, got -3' ($embedDemoErr -join "`n")

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

$jsonDecodeEnumFieldOk = & $Lume run (Join-Path $PSScriptRoot 'examples\json_decode_enum_field.lume')
if ($LASTEXITCODE -ne 0) { throw "json decode enum field exited $LASTEXITCODE" }
Assert-Equal 'json decoding into an enum field inside a record' "{`"name`":`"a`",`"status`":{`"variant`":`"running`",`"started_at`":100}}`nrunning at 100`npending`ndone" ($jsonDecodeEnumFieldOk -join "`n")

$pathFunctions = & $Lume run (Join-Path $PSScriptRoot 'examples\path_functions.lume')
if ($LASTEXITCODE -ne 0) { throw "path functions exited $LASTEXITCODE" }
Assert-Equal 'path functions' "reports/2026`nsummary.csv`nreports/2026`nsummary`ncsv`nnone" ($pathFunctions -join "`n")

$strFromInt = & $Lume run (Join-Path $PSScriptRoot 'examples\str_from_int.lume')
if ($LASTEXITCODE -ne 0) { throw "str.from_int exited $LASTEXITCODE" }
Assert-Equal 'str.from_int' "42!`n0`n-7" ($strFromInt -join "`n")

$invalidStrFromInt = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_str_from_int_args.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "str.from_int argument validation should exit 1" }
Assert-Equal 'str.from_int requires int' 'E0730 line 2: builtin `str.from_int` requires int' ($invalidStrFromInt -join "`n")

$strToInt = & $Lume run (Join-Path $PSScriptRoot 'examples\str_to_int.lume')
if ($LASTEXITCODE -ne 0) { throw "str.to_int exited $LASTEXITCODE" }
Assert-Equal 'str.to_int' "42`n0`n-7`nfalse`ncannot parse ``not a number`` as int" ($strToInt -join "`n")

$invalidStrToInt = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_str_to_int_args.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "str.to_int argument validation should exit 1" }
Assert-Equal 'str.to_int requires str' 'E0746 line 2: builtin `str.to_int` requires str' ($invalidStrToInt -join "`n")

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
$cursor = 140
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

# A cache whose source hash still matches the current program, but whose
# embedded build-hash field (bytes [68:132), see decodeArtifact's own
# header layout comment) doesn't match the running lume.exe's own
# compilerBuildHash() - simulating a real .lume file untouched across a
# lume.exe upgrade - must be treated as a miss and transparently
# recompiled, not silently reused. `lume run` (not `exec`, which never
# compares hashes at all) is what actually exercises compileOrCache.
$buildHashCheckSource = Join-Path $PSScriptRoot 'dist\build-hash-check.lume'
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'examples\functions.lume') -Destination $buildHashCheckSource -Force
$buildHashCheckLbc = "$buildHashCheckSource.lbc"
Remove-Item -LiteralPath $buildHashCheckLbc -ErrorAction SilentlyContinue
$firstRun = & $Lume run $buildHashCheckSource
if ($LASTEXITCODE -ne 0) { throw "build-hash-check first run exited $LASTEXITCODE" }
$patchedBuildHashBytes = [IO.File]::ReadAllBytes($buildHashCheckLbc)
[Text.Encoding]::UTF8.GetBytes(('0' * 64)).CopyTo($patchedBuildHashBytes, 68)
[IO.File]::WriteAllBytes($buildHashCheckLbc, $patchedBuildHashBytes)
$secondRun = & $Lume run $buildHashCheckSource
if ($LASTEXITCODE -ne 0) { throw "build-hash-check second run exited $LASTEXITCODE" }
Assert-Equal 'stale build hash is transparently recompiled, not reused' "42`n120" ($secondRun -join "`n")
$rewrittenBytes = [IO.File]::ReadAllBytes($buildHashCheckLbc)
$rewrittenBuildHash = [Text.Encoding]::UTF8.GetString($rewrittenBytes, 68, 64)
if ($rewrittenBuildHash -eq ('0' * 64)) { throw "cache was not rewritten with the real build hash after the mismatch" }

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
$cursor = 140
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

# A function call's return value previously couldn't have a field
# accessed directly (`result.value(decoded).name` was E0206 expected
# `)`) - get_field already worked generically on whatever's on the
# stack, only the lexer/parser needed a small additive change (a
# standalone `.` token, and a postfix chain in parsePrimary), not the
# full dotted-name rewrite ROADMAP.md originally assumed was needed.
$chainedField = & $Lume run (Join-Path $PSScriptRoot 'examples\chained_field_access.lume')
if ($LASTEXITCODE -ne 0) { throw "chained field access exited $LASTEXITCODE" }
Assert-Equal 'chained field access on a call result, a plain call, and a parenthesized with-update' "widget`ngadget`n99" ($chainedField -join "`n")

# result.to_result bridges the shorthand result<T,E> every I/O builtin
# returns into a real, matchable Result<T,E> - the two representations
# are otherwise non-interchangeable (SPEC.md's "Two different Result
# representations"). Both the Ok and Err paths must reach their own
# match arm with the payload intact, and the bridged value must
# type-check against a plain Result<str, str>-typed parameter.
$resultBridgeOk = & $Lume run (Join-Path $PSScriptRoot 'examples\result_bridge.lume') (Join-Path $PSScriptRoot 'examples\result_bridge_input.txt')
if ($LASTEXITCODE -ne 0) { throw "result.to_result Ok path exited $LASTEXITCODE" }
Assert-Equal 'result.to_result bridges an Ok shorthand result into a matchable Result' 'ok: bridged' ($resultBridgeOk -join "`n")

$resultBridgeMissingPath = Join-Path $PSScriptRoot 'examples\does_not_exist_result_bridge.txt'
$resultBridgeErr = & $Lume run (Join-Path $PSScriptRoot 'examples\result_bridge.lume') $resultBridgeMissingPath
if ($LASTEXITCODE -ne 0) { throw "result.to_result Err path exited $LASTEXITCODE" }
Assert-Equal 'result.to_result bridges an Err shorthand result into a matchable Result' ('err: cannot read file `' + $resultBridgeMissingPath + '`') ($resultBridgeErr -join "`n")

$resultBridgeTypeError = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_result_to_result.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "result.to_result on a non-result value should fail to compile" }
Assert-Equal 'result.to_result requires a result value' 'E0622 line 2: result operation requires result value' ($resultBridgeTypeError -join "`n")

# The two Result representations are now the same runtime value (resultOk/
# resultErr build the same "v:"-tagged shape buildVariant does for a
# hand-built Result.Ok/Result.Err) - result.to_result above still works as
# a validating identity, but none of these four cases need it: a builtin's
# own result can be matched directly, returned from a Result<T,E>-typed
# signature, and result.is_ok/value/error accept a hand-built Result.Ok/Err.
$resultUnifyOk = & $Lume run (Join-Path $PSScriptRoot 'examples\result_unification.lume') (Join-Path $PSScriptRoot 'examples\result_bridge_input.txt')
if ($LASTEXITCODE -ne 0) { throw "result_unification Ok path exited $LASTEXITCODE" }
Assert-Equal 'match and Result<T,E> return type work directly on a builtin result' "match-ok: bridged`ngeneric-ok: bridged`nis_ok: true`nvalue: hand-built`nis_ok: false`nerror: boom" ($resultUnifyOk -join "`n")

$resultUnifyMissingPath = Join-Path $PSScriptRoot 'examples\does_not_exist_result_bridge.txt'
$resultUnifyErr = & $Lume run (Join-Path $PSScriptRoot 'examples\result_unification.lume') $resultUnifyMissingPath
if ($LASTEXITCODE -ne 0) { throw "result_unification Err path exited $LASTEXITCODE" }
Assert-Equal 'match and Result<T,E> return type work directly on a builtin error' ('match-err: cannot read file `' + $resultUnifyMissingPath + '`' + "`n" + 'generic-err: cannot read file `' + $resultUnifyMissingPath + '`' + "`nis_ok: true`nvalue: hand-built`nis_ok: false`nerror: boom") ($resultUnifyErr -join "`n")

# Duration is a real record type (not a plain int) for type safety -
# time.now() + duration.minutes(5) and time.now() + userId type-check
# identically today since both are plain int, but a Duration can't be
# mistaken for an unrelated int at compile time.
$durationTypeOutput = & $Lume run (Join-Path $PSScriptRoot 'examples\duration_type.lume')
if ($LASTEXITCODE -ne 0) { throw "duration_type example exited $LASTEXITCODE" }
Assert-Equal 'Duration type construction, field access, arithmetic, and the time.now() bridge' "300`n3900`n3300`n600`ntrue" ($durationTypeOutput -join "`n")

$durationTypeError = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_duration_arithmetic.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "Duration.add on a plain int should fail to compile" }
Assert-Equal 'Duration.add rejects a plain int in place of a Duration' 'E0743 line 2: builtin `Duration.add` requires (Duration, Duration)' ($durationTypeError -join "`n")

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

# api-docs renders builtinNames()/builtinCounts() as Markdown instead of
# JSON (lume api's own format) - same source data, so it can't drift from
# the compiler. Anchor on a couple of stable lines rather than the whole
# multi-hundred-line body, matching this file's light-touch style for
# build-output commands.
$apiDocs = & $Lume api-docs
if ($LASTEXITCODE -ne 0) { throw "api-docs exited $LASTEXITCODE" }
Assert-Equal 'api-docs starts with the reference heading' '# Lume Builtin Reference' ($apiDocs | Select-Object -First 1)
Assert-Contains 'api-docs groups builtins by namespace' '## str' ($apiDocs -join "`n")
Assert-Contains 'api-docs lists a known builtin with its arity' '- `str.upper` - 1 argument(s)' ($apiDocs -join "`n")

# Timing output isn't a good fit for exact-match assertions (matches the
# existing `benchmark` command, which has zero test.ps1 coverage of its own
# for the same reason) - just confirm profile runs and reports every
# expected bucket, not any particular value.
$profileOutput = & $Lume profile (Join-Path $PSScriptRoot 'examples\functions.lume') 5
if ($LASTEXITCODE -ne 0) { throw "profile exited $LASTEXITCODE" }
$profileText = $profileOutput -join "`n"
Assert-Contains 'profile reports iterations' 'iterations=5' $profileText
Assert-Contains 'profile reports lex time' 'lex_total_ms=' $profileText
Assert-Contains 'profile reports scan time' 'scan_total_ms=' $profileText
Assert-Contains 'profile reports compile time' 'compile_total_ms=' $profileText
Assert-Contains 'profile reports an estimated remaining-phases bucket' 'estimated_codegen_verify_patch_total_ms=' $profileText

$fmtEdgeCasesPath = Join-Path $PSScriptRoot 'examples\fmt_edge_cases.lume'
$fmtEdgeCasesCheck = & $Lume fmt $fmtEdgeCasesPath --check
if ($LASTEXITCODE -ne 0) { throw "fmt --check should not be confused by braces inside comments/strings" }
Assert-Equal 'fmt ignores braces inside comments and strings' 'ok' ($fmtEdgeCasesCheck -join "`n")

$fmtMisindentedPath = Join-Path $PSScriptRoot 'dist\fmt_edge_cases_misindented.lume'
(Get-Content -LiteralPath $fmtEdgeCasesPath | ForEach-Object { $_.Trim() }) -join "`n" | Set-Content -LiteralPath $fmtMisindentedPath -NoNewline -Encoding utf8
& $Lume fmt $fmtMisindentedPath | Out-Null
if ($LASTEXITCODE -ne 0) { throw "fmt (write mode) on a misindented file should exit 0" }
$fmtReformatted = (Get-Content -LiteralPath $fmtMisindentedPath -Raw).Trim()
$fmtCanonical = (Get-Content -LiteralPath $fmtEdgeCasesPath -Raw).Trim()
Assert-Equal 'fmt reformats misindented source back to canonical, comments/strings intact' $fmtCanonical $fmtReformatted

$fmtIdempotentCheck = & $Lume fmt $fmtMisindentedPath --check
if ($LASTEXITCODE -ne 0) { throw "fmt --check on fmt's own output should exit 0 (idempotency)" }
Assert-Equal 'fmt output is idempotent under --check' 'ok' ($fmtIdempotentCheck -join "`n")

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

# An incomplete function signature (no closing paren, the single most
# common state while a user is actively typing) must report a clean
# diagnostic, not panic - confirmed live before this fix:
# parameterNames/parameterTypes/functionReturnType/typeNext/
# genericParameters/genericConstraints all had at least one token-walking
# loop with no eof bound, and List.getOrPanic's resulting out-of-bounds
# panic crashed not just this `check` but the entire `lume lsp` server
# process on any didOpen/didChange with the same incomplete text.
$incompleteSignature = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_incomplete_function_signature.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "incomplete function signature should exit 1, not panic" }
Assert-Equal 'incomplete function signature reports a diagnostic, not a panic' 'E0201 missing `fn main`' ($incompleteSignature -join "`n")

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

$genericDispatchFunctionValue = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_generic_dispatch_function_value.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "generic dispatch as a function value should exit 1" }
Assert-Equal 'generic dispatch cannot be used as a function value' 'E0740 line 16: generic dispatch `T.name` cannot be used as a function value' ($genericDispatchFunctionValue -join "`n")

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

# from_json's decode_json op previously had no handler in callPure (the
# restricted evaluator a test body runs through), so it fell into that
# function's generic "uses unsupported operation" fallback - confirmed
# live before this fixture existed. decodeRecordJson is pure (no [io]),
# so callPure now handles it directly, mirroring execute()'s own handling.
$nativeTestsJson = & $Lume test (Join-Path $PSScriptRoot 'examples\native_tests_json.lume')
if ($LASTEXITCODE -ne 0) { throw "from_json inside a test body exited $LASTEXITCODE" }
Assert-Equal 'from_json works inside a test body' "PASS from_json works inside a test body`n1 passed; 0 failed" ($nativeTestsJson -join "`n")

# The same class of gap decode_json above already closed once -
# match/if-expression/? all used to fail anywhere in a test body's or a
# list.*/map.* callback's reachable call graph (BACKLOG.md items 2/3),
# confirmed live before callPure gained these opcodes.
$callbackMatchPropagate = & $Lume test (Join-Path $PSScriptRoot 'examples\callback_match_propagate.lume')
if ($LASTEXITCODE -ne 0) { throw "callback_match_propagate exited $LASTEXITCODE" }
Assert-Equal 'match/if-expression/propagate work inside callPure' "PASS match and if-expression work transitively inside a list.map callback`nPASS ? propagates a failure out of a test body`nPASS ? propagates a success out of a test body`n3 passed; 0 failed" ($callbackMatchPropagate -join "`n")

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

# A `|` in a declared test name used to shift the marker's trailing timeout
# field, silently disabling it (parseInt on non-numeric text falls back to
# 0, meaning "no timeout") - so a hanging test with a `|` in its name never
# timed out at all. These cover the fix: the name round-trips intact (not
# truncated at the `|`) in both plain and --json output, the timeout still
# fires, and --filter can target a `|`-containing name via literal substring.
$pipeNamePath = Join-Path $PSScriptRoot 'examples\native_tests_pipe_name.lume'
$pipeNameId = ($pipeNamePath -replace '\\', '\\')

$pipeNameTests = & $Lume test $pipeNamePath 2>&1
if ($LASTEXITCODE -ne 1) { throw "pipe-in-name native test should exit 1" }
Assert-Equal 'native test name preserves a literal pipe character' "PASS adds|two values`nFAIL hangs|past its own timeout (line 5): test timed out after 50ms`n1 passed; 1 failed" ($pipeNameTests -join "`n")

$pipeNameJson = & $Lume test $pipeNamePath --json 2>&1
if ($LASTEXITCODE -ne 1) { throw "pipe-in-name json native test should exit 1" }
$pipeNameJsonExpected = "{`"event`":`"test`",`"id`":`"$pipeNameId#adds|two values`",`"name`":`"adds|two values`",`"status`":`"pass`",`"line`":1,`"message`":`"`"}" + "`n" + `
  "{`"event`":`"test`",`"id`":`"$pipeNameId#hangs|past its own timeout`",`"name`":`"hangs|past its own timeout`",`"status`":`"fail`",`"line`":5,`"message`":`"test timed out after 50ms`"}" + "`n" + `
  '{"event":"summary","passed":1,"failed":1,"total":2}'
Assert-Equal 'structured test output preserves a literal pipe character' $pipeNameJsonExpected ($pipeNameJson -join "`n")

$pipeNameFiltered = & $Lume test $pipeNamePath --filter 'adds|two'
if ($LASTEXITCODE -ne 0) { throw "filter targeting a pipe-containing name exited $LASTEXITCODE" }
Assert-Equal 'filter matches a literal pipe character in a test name' "PASS adds|two values`n1 passed; 0 failed" ($pipeNameFiltered -join "`n")

$packagesAppDir = Join-Path $PSScriptRoot 'examples\packages\app'
$installOutput = & $Lume install $packagesAppDir
if ($LASTEXITCODE -ne 0) { throw "lume install exited $LASTEXITCODE" }
$lockContent = Get-Content -LiteralPath (Join-Path $packagesAppDir 'lume.lock.json') -Raw
$lockJson = $lockContent | ConvertFrom-Json
# sourceHash's own value is deliberately not pinned to a literal here (only
# its shape and determinism are checked) - confirmed live that Path.join's
# exact output for a transitively-resolved ".." path can legitimately
# differ between two individually-correct Certo builds, which previously
# made this assertion fail on a fresh build with no actual regression.
# Everything else in the lock file (name/path/version/dependencies/direct)
# has no such Certo-build sensitivity and stays exactly pinned.
$hashPattern = '^[0-9a-f]{64}$'
Assert-Equal 'package install: resolved[0] is mathutils' 'mathutils|../mathutils|0.1.0|formatting' "$($lockJson.resolved[0].name)|$($lockJson.resolved[0].path)|$($lockJson.resolved[0].version)|$($lockJson.resolved[0].dependencies -join ',')"
Assert-Equal 'package install: resolved[1] is formatting' 'formatting|../formatting|0.1.0|' "$($lockJson.resolved[1].name)|$($lockJson.resolved[1].path)|$($lockJson.resolved[1].version)|$($lockJson.resolved[1].dependencies -join ',')"
Assert-Equal 'package install: direct dependency list' 'mathutils,formatting' ($lockJson.direct -join ',')
if ($lockJson.resolved[0].sourceHash -notmatch $hashPattern) { throw "mathutils sourceHash is not a 64-char hex string: $($lockJson.resolved[0].sourceHash)" }
if ($lockJson.resolved[1].sourceHash -notmatch $hashPattern) { throw "formatting sourceHash is not a 64-char hex string: $($lockJson.resolved[1].sourceHash)" }

$reinstallOutput = & $Lume install $packagesAppDir
if ($LASTEXITCODE -ne 0) { throw "second lume install exited $LASTEXITCODE" }
$reinstallJson = (Get-Content -LiteralPath (Join-Path $packagesAppDir 'lume.lock.json') -Raw) | ConvertFrom-Json
Assert-Equal 'package install: sourceHash is deterministic on this machine (mathutils)' $lockJson.resolved[0].sourceHash $reinstallJson.resolved[0].sourceHash
Assert-Equal 'package install: sourceHash is deterministic on this machine (formatting)' $lockJson.resolved[1].sourceHash $reinstallJson.resolved[1].sourceHash

$packagesRun = & $Lume run (Join-Path $packagesAppDir 'app.lume')
if ($LASTEXITCODE -ne 0) { throw "package app example exited $LASTEXITCODE" }
Assert-Equal 'package use resolution' "36`nDONE" ($packagesRun -join "`n")

# `lume install --check` re-resolves and compares against the existing lock
# file instead of overwriting it - a CI gate for "someone edited lume.json
# and forgot to re-run install," which run/check/test can't catch on their
# own (they only ever read the lock file, by design, never the manifest).
$checkFreshInstall = & $Lume install $packagesAppDir --check
if ($LASTEXITCODE -ne 0) { throw "install --check on a freshly-installed project should exit 0" }
Assert-Equal 'install --check accepts an up-to-date lock file' 'ok' ($checkFreshInstall -join "`n")

$staleLockAppDir = Join-Path $PSScriptRoot 'examples\packages\stale_lock_app'
$checkStale = & $Lume install $staleLockAppDir --check 2>&1
if ($LASTEXITCODE -ne 1) { throw "install --check on a stale lock file should exit 1" }
Assert-Equal 'install --check rejects a lock file that no longer matches lume.json' "E0739 lock file ``$staleLockAppDir/lume.lock.json`` is out of date with ``$staleLockAppDir/lume.json``" ($checkStale -join "`n")
$staleLockContent = (Get-Content -LiteralPath (Join-Path $staleLockAppDir 'lume.lock.json') -Raw).Trim()
Assert-Equal 'install --check never writes, even on mismatch' '{"resolved":[],"direct":[]}' $staleLockContent

# Copied as a sibling of mathutils, not into dist/ - its manifest declares
# mathutils via a relative "../mathutils" path, which only still resolves
# from another directory directly under examples\packages.
$missingLockDir = Join-Path $PSScriptRoot 'examples\packages\missing-lock-check'
if (Test-Path -LiteralPath $missingLockDir) { Remove-Item -LiteralPath $missingLockDir -Recurse -Force }
Copy-Item -LiteralPath $staleLockAppDir -Destination $missingLockDir -Recurse
Remove-Item -LiteralPath (Join-Path $missingLockDir 'lume.lock.json')
$checkMissing = & $Lume install $missingLockDir --check 2>&1
if ($LASTEXITCODE -ne 1) { throw "install --check with no lock file at all should exit 1" }
Assert-Equal 'install --check rejects a missing lock file' "E0739 lock file ``$missingLockDir/lume.lock.json`` is out of date with ``$missingLockDir/lume.json``" ($checkMissing -join "`n")
Remove-Item -LiteralPath $missingLockDir -Recurse -Force

# `install --check`'s lock comparison also has to catch a dependency's own
# `.lume` source being hand-edited after the lock file was written, even
# though the dependency's manifest (name/version) never changed - a
# manifest-only comparison can't see that, only a hash of the dependency's
# actual source can (lume.lock.json's per-dependency `sourceHash` field).
# Uses a private copy of mathutils, not the shared examples\packages\
# mathutils fixture other tests depend on, since this test needs to
# actually mutate a dependency's source file on disk.
$driftDepDir = Join-Path $PSScriptRoot 'examples\packages\source_drift_dep'
if (Test-Path -LiteralPath $driftDepDir) { Remove-Item -LiteralPath $driftDepDir -Recurse -Force }
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'examples\packages\mathutils') -Destination $driftDepDir -Recurse
$driftAppDir = Join-Path $PSScriptRoot 'examples\packages\source_drift_app'
if (Test-Path -LiteralPath $driftAppDir) { Remove-Item -LiteralPath $driftAppDir -Recurse -Force }
New-Item -ItemType Directory -Path $driftAppDir | Out-Null
Set-Content -LiteralPath (Join-Path $driftAppDir 'lume.json') -Value '{"name":"source_drift_app","version":"0.1.0","dependencies":[{"name":"mathutils","path":"../source_drift_dep"}]}' -NoNewline

$driftInstall = & $Lume install $driftAppDir
if ($LASTEXITCODE -ne 0) { throw "source drift app install exited $LASTEXITCODE" }
$driftCheckClean = & $Lume install $driftAppDir --check
if ($LASTEXITCODE -ne 0) { throw "install --check on an untouched dependency should exit 0" }
Assert-Equal 'install --check accepts a dependency whose source is untouched' 'ok' ($driftCheckClean -join "`n")

Add-Content -LiteralPath (Join-Path $driftDepDir 'ops.lume') -Value "`npub fn ops.cube(value: int) -> int {`n  return value * value * value`n}"
$driftCheckDirty = & $Lume install $driftAppDir --check 2>&1
if ($LASTEXITCODE -ne 1) { throw "install --check on a hand-edited dependency source file should exit 1" }
Assert-Equal 'install --check catches a dependency source file edited without re-running install' "E0739 lock file ``$driftAppDir/lume.lock.json`` is out of date with ``$driftAppDir/lume.json``" ($driftCheckDirty -join "`n")

Remove-Item -LiteralPath $driftAppDir -Recurse -Force
Remove-Item -LiteralPath $driftDepDir -Recurse -Force

$cyclicOutput = & $Lume install (Join-Path $PSScriptRoot 'examples\packages\cyclic-a') 2>&1
if ($LASTEXITCODE -ne 1) { throw "cyclic package install should exit 1" }
Assert-Equal 'package dependency cycle validation' 'E0709 dependency cycle at `cyclic-b`' ($cyclicOutput -join "`n")

# A malformed manifest (missing name/version) and an unreadable one used to be
# reported under different, conflated codes depending only on whether it was
# the root package's own manifest or a dependency's - readManifestVersion is
# now the single source of truth both paths call through, so the same
# condition gets the same code everywhere.
$malformedRootDir = Join-Path $PSScriptRoot 'examples\packages\malformed_root'
$malformedRootOutput = & $Lume install $malformedRootDir 2>&1
if ($LASTEXITCODE -ne 1) { throw "malformed root manifest install should exit 1" }
Assert-Equal 'malformed root manifest reports E0737' "E0737 manifest ``$malformedRootDir/lume.json`` requires string ``name`` and ``version`` fields" ($malformedRootOutput -join "`n")

$malformedDepAppDir = Join-Path $PSScriptRoot 'examples\packages\malformed_dep_app'
$malformedDepOutput = & $Lume install $malformedDepAppDir 2>&1
if ($LASTEXITCODE -ne 1) { throw "malformed dependency manifest install should exit 1" }
Assert-Equal 'malformed dependency manifest reports the same E0737, no extra wrapping' "E0737 manifest ``$malformedDepAppDir/../malformed_dep/lume.json`` requires string ``name`` and ``version`` fields" ($malformedDepOutput -join "`n")

$missingDepAppDir = Join-Path $PSScriptRoot 'examples\packages\missing_dep_app'
$missingDepOutput = & $Lume install $missingDepAppDir 2>&1
if ($LASTEXITCODE -ne 1) { throw "missing dependency directory install should exit 1" }
Assert-Equal 'missing dependency manifest reports E0705, matching an unreadable root manifest' "E0705 cannot read manifest ``$missingDepAppDir/../does_not_exist/lume.json``" ($missingDepOutput -join "`n")

# Package isolation: a package may only `use` what it itself declares in its
# own lume.json, not merely what's present anywhere in the resolved tree
# (diamond_app -> foo/bar, both -> baz; isolation_violation_app -> leaky/bar,
# where leaky only declares baz and illegitimately reaches for bar).
$diamondAppDir = Join-Path $PSScriptRoot 'examples\packages\diamond_app'
$diamondInstall = & $Lume install $diamondAppDir
if ($LASTEXITCODE -ne 0) { throw "diamond package install exited $LASTEXITCODE" }
$diamondRun = & $Lume run (Join-Path $diamondAppDir 'diamond_app.lume')
if ($LASTEXITCODE -ne 0) { throw "diamond package app exited $LASTEXITCODE" }
Assert-Equal 'shared transitive dependency (diamond) resolves once' "hello from baz`nhello from bar" ($diamondRun -join "`n")

$violationAppDir = Join-Path $PSScriptRoot 'examples\packages\isolation_violation_app'
$violationInstall = & $Lume install $violationAppDir
if ($LASTEXITCODE -ne 0) { throw "isolation violation package install exited $LASTEXITCODE" }
$violationRun = & $Lume run (Join-Path $violationAppDir 'isolation_violation_app.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "undeclared cross-package use should exit 1" }
Assert-Contains 'undeclared dependency is not visible' 'E0701 cannot read module' ($violationRun -join "`n")

# A lume.lock.json that exists but isn't valid JSON used to be silently
# treated as "zero dependencies" (readFile succeeded, Json.parse's result
# just didn't look like an array to JsonValue.isArray), producing a
# confusing "cannot read module" pointing nowhere near the real cause -
# fixed to report the corruption directly instead. Its checked-in
# lume.lock.json is deliberately invalid (not generated by `lume install`,
# since the whole fixture is about the file already being wrong).
$corruptLockAppDir = Join-Path $PSScriptRoot 'examples\packages\corrupt_lock_app'
$corruptLockRun = & $Lume run (Join-Path $corruptLockAppDir 'corrupt_lock_app.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "corrupt lock file run should exit 1" }
Assert-Equal 'corrupt lock file reports E0738, not a misleading E0701' "E0738 cannot parse lock file ``$corruptLockAppDir/lume.lock.json``" ($corruptLockRun -join "`n")

# Git-based dependencies ({name, git, ref} manifest entries - ROADMAP.md's
# "Distribution and interoperability" design sketch). Resolved through a
# real `git` binary (Process.run; failures surface as E0748), never over
# the network here: each remote is a throwaway local bare repo this test
# run builds fresh under the system temp directory, not checked into the
# repo - a real .git tree doesn't fit as a static fixture the way the
# plain-file package fixtures above do, and building it fresh keeps the
# suite hermetic and offline.
$gitFixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("lume_git_test_" + [System.Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $gitFixtureRoot -Force | Out-Null

$mathutilsRemote = Join-Path $gitFixtureRoot 'mathutils-remote.git'
$mathutilsWork = Join-Path $gitFixtureRoot 'mathutils-work'
git init --bare -q $mathutilsRemote
git clone -q $mathutilsRemote $mathutilsWork
Set-Content -LiteralPath (Join-Path $mathutilsWork 'lume.json') -Value '{"name":"mathutils","version":"0.1.0"}' -NoNewline
Set-Content -LiteralPath (Join-Path $mathutilsWork 'ops.lume') -Value "pub fn ops.square(value: int) -> int {`n  return value * value`n}" -NoNewline
Push-Location $mathutilsWork
git add -A
git -c user.email=test@lume.dev -c user.name=lume-test commit -q -m 'mathutils v0.1.0'
git branch -M main
git tag v1.0.0
git push -q origin main --tags
Pop-Location
$mathutilsSha = (git --git-dir="$mathutilsRemote" rev-parse v1.0.0).Trim()
$mathutilsRemoteUrl = $mathutilsRemote -replace '\\', '/'

function New-GitDepApp([string]$Name, [string]$Ref) {
  $dir = Join-Path $gitFixtureRoot $Name
  New-Item -ItemType Directory -Path $dir -Force | Out-Null
  $manifest = '{"name":"' + $Name + '","version":"0.1.0","dependencies":[{"name":"mathutils","git":"' + $mathutilsRemoteUrl + '","ref":"' + $Ref + '"}]}'
  Set-Content -LiteralPath (Join-Path $dir 'lume.json') -Value $manifest -NoNewline
  Set-Content -LiteralPath (Join-Path $dir 'app.lume') -Value "use mathutils.ops`n`nfn main(args: [str]) -> int {`n  print(ops.square(7))`n  return 0`n}" -NoNewline
  return $dir
}

# Tag, branch, and raw commit SHA all resolve to the same commit - `ref`
# can be any of the three (resolveGitDependency's own contract).
foreach ($case in @(
  @{ Label = 'tag';    Ref = 'v1.0.0' },
  @{ Label = 'branch'; Ref = 'main' },
  @{ Label = 'commit'; Ref = $mathutilsSha }
)) {
  $appDir = New-GitDepApp "git-app-$($case.Label)" $case.Ref
  $installOut = & $Lume install $appDir
  if ($LASTEXITCODE -ne 0) { throw "git dependency install ($($case.Label)) exited $LASTEXITCODE" }
  $lock = (Get-Content -LiteralPath (Join-Path $appDir 'lume.lock.json') -Raw) | ConvertFrom-Json
  Assert-Equal "git dependency ($($case.Label)): resolves to the tagged commit" $mathutilsSha ($lock.resolved[0].path -replace '^.*[\\/]', '')
  Assert-Equal "git dependency ($($case.Label)): lock records declared ref" $case.Ref $lock.resolved[0].ref
  Assert-Equal "git dependency ($($case.Label)): lock records declared git URL" $mathutilsRemoteUrl $lock.resolved[0].git
  if ($lock.resolved[0].sourceHash -notmatch $hashPattern) { throw "git dependency ($($case.Label)) sourceHash is not a 64-char hex string: $($lock.resolved[0].sourceHash)" }
  $runOut = & $Lume run (Join-Path $appDir 'app.lume')
  if ($LASTEXITCODE -ne 0) { throw "git dependency app run ($($case.Label)) exited $LASTEXITCODE" }
  Assert-Equal "git dependency ($($case.Label)): app runs against the cloned package" '49' ($runOut -join "`n")
}

# Malformed entries: both `path`/`git`, and `git` without `ref`, both
# collapse onto the same E0747 - see resolveDependencies's own comment on
# why these share one code rather than a code each.
$badBothDir = Join-Path $gitFixtureRoot 'bad-both'
New-Item -ItemType Directory -Path $badBothDir -Force | Out-Null
Set-Content -LiteralPath (Join-Path $badBothDir 'lume.json') -Value ('{"name":"bad-both","version":"0.1.0","dependencies":[{"name":"x","path":"../x","git":"' + $mathutilsRemoteUrl + '","ref":"v1.0.0"}]}') -NoNewline
$badBothOutput = & $Lume install $badBothDir 2>&1
if ($LASTEXITCODE -ne 1) { throw "dependency declaring both path and git should exit 1" }
Assert-Contains 'git dependency validation: both path and git' 'E0747' ($badBothOutput -join "`n")

$badNoRefDir = Join-Path $gitFixtureRoot 'bad-noref'
New-Item -ItemType Directory -Path $badNoRefDir -Force | Out-Null
Set-Content -LiteralPath (Join-Path $badNoRefDir 'lume.json') -Value ('{"name":"bad-noref","version":"0.1.0","dependencies":[{"name":"x","git":"' + $mathutilsRemoteUrl + '"}]}') -NoNewline
$badNoRefOutput = & $Lume install $badNoRefDir 2>&1
if ($LASTEXITCODE -ne 1) { throw "git dependency without ref should exit 1" }
Assert-Contains 'git dependency validation: git without ref' 'E0747' ($badNoRefOutput -join "`n")

# A `git` command failure (here: a ref that doesn't exist) surfaces as
# E0748 with the underlying git error folded in, not a generic failure.
$badRefDir = Join-Path $gitFixtureRoot 'bad-ref'
New-Item -ItemType Directory -Path $badRefDir -Force | Out-Null
Set-Content -LiteralPath (Join-Path $badRefDir 'lume.json') -Value ('{"name":"bad-ref","version":"0.1.0","dependencies":[{"name":"x","git":"' + $mathutilsRemoteUrl + '","ref":"does-not-exist"}]}') -NoNewline
$badRefOutput = & $Lume install $badRefDir 2>&1
if ($LASTEXITCODE -ne 1) { throw "git dependency with a nonexistent ref should exit 1" }
Assert-Contains 'git dependency validation: nonexistent ref reports E0748' 'E0748' ($badRefOutput -join "`n")

# Transitive git dependency: a git-resolved package that itself declares a
# `git` dependency is walked the same recursive way a local `path` entry
# already is (resolveDependencies's own "source-kind-agnostic from that
# point on" framing).
$formattingRemote = Join-Path $gitFixtureRoot 'formatting-remote.git'
$formattingWork = Join-Path $gitFixtureRoot 'formatting-work'
git init --bare -q $formattingRemote
git clone -q $formattingRemote $formattingWork
Set-Content -LiteralPath (Join-Path $formattingWork 'lume.json') -Value '{"name":"formatting","version":"0.1.0"}' -NoNewline
Set-Content -LiteralPath (Join-Path $formattingWork 'fmt.lume') -Value "pub fn fmt.shout(value: str) -> str {`n  return value`n}" -NoNewline
Push-Location $formattingWork
git add -A
git -c user.email=test@lume.dev -c user.name=lume-test commit -q -m 'formatting v0.1.0'
git branch -M main
git tag v1.0.0
git push -q origin main --tags
Pop-Location
$formattingRemoteUrl = $formattingRemote -replace '\\', '/'

$mathutilsWithDepRemote = Join-Path $gitFixtureRoot 'mathutils-with-dep-remote.git'
$mathutilsWithDepWork = Join-Path $gitFixtureRoot 'mathutils-with-dep-work'
git init --bare -q $mathutilsWithDepRemote
git clone -q $mathutilsWithDepRemote $mathutilsWithDepWork
$mathutilsWithDepManifest = '{"name":"mathutils","version":"0.1.0","dependencies":[{"name":"formatting","git":"' + $formattingRemoteUrl + '","ref":"v1.0.0"}]}'
Set-Content -LiteralPath (Join-Path $mathutilsWithDepWork 'lume.json') -Value $mathutilsWithDepManifest -NoNewline
Set-Content -LiteralPath (Join-Path $mathutilsWithDepWork 'ops.lume') -Value "pub fn ops.square(value: int) -> int {`n  return value * value`n}" -NoNewline
Push-Location $mathutilsWithDepWork
git add -A
git -c user.email=test@lume.dev -c user.name=lume-test commit -q -m 'mathutils (with a git dependency) v0.1.0'
git branch -M main
git tag v1.0.0
git push -q origin main --tags
Pop-Location
$mathutilsWithDepRemoteUrl = $mathutilsWithDepRemote -replace '\\', '/'

$transitiveAppDir = Join-Path $gitFixtureRoot 'transitive-app'
New-Item -ItemType Directory -Path $transitiveAppDir -Force | Out-Null
$transitiveManifest = '{"name":"transitive-app","version":"0.1.0","dependencies":[{"name":"mathutils","git":"' + $mathutilsWithDepRemoteUrl + '","ref":"v1.0.0"}]}'
Set-Content -LiteralPath (Join-Path $transitiveAppDir 'lume.json') -Value $transitiveManifest -NoNewline
Set-Content -LiteralPath (Join-Path $transitiveAppDir 'app.lume') -Value "use mathutils.ops`n`nfn main(args: [str]) -> int {`n  print(ops.square(7))`n  return 0`n}" -NoNewline

$transitiveInstall = & $Lume install $transitiveAppDir
if ($LASTEXITCODE -ne 0) { throw "transitive git dependency install exited $LASTEXITCODE" }
$transitiveLock = (Get-Content -LiteralPath (Join-Path $transitiveAppDir 'lume.lock.json') -Raw) | ConvertFrom-Json
Assert-Equal 'transitive git dependency: both packages resolved' 'mathutils,formatting' (($transitiveLock.resolved | ForEach-Object { $_.name }) -join ',')
Assert-Equal "transitive git dependency: direct dependency list is just the root's own" 'mathutils' ($transitiveLock.direct -join ',')
$transitiveRun = & $Lume run (Join-Path $transitiveAppDir 'app.lume')
if ($LASTEXITCODE -ne 0) { throw "transitive git dependency app run exited $LASTEXITCODE" }
Assert-Equal 'transitive git dependency: app runs against the cloned package tree' '49' ($transitiveRun -join "`n")

Remove-Item -LiteralPath $gitFixtureRoot -Recurse -Force

# examples/taskgraph - the "validate representative shell/Python
# replacement programs" 0.2 milestone criterion (ROADMAP.md). A real,
# substantial multi-module program (dependency-graph resolution, cycle
# detection, transitive-closure target scoping, subprocess execution,
# failure/skip propagation, JSON reporting) that existed and had been
# manually verified once (PR #40) but was never wired into this suite,
# confirmed live before this block existed - nothing would have caught
# a regression in it.
$taskgraphDir = Join-Path $PSScriptRoot 'examples\taskgraph'
$taskgraphMain = Join-Path $PSScriptRoot 'examples\taskgraph.lume'
$taskgraphReport = Join-Path $taskgraphDir 'taskgraph-report.json'

$taskgraphDryRun = & $Lume run $taskgraphMain (Join-Path $taskgraphDir 'tasks.json') '--dry-run'
if ($LASTEXITCODE -ne 0) { throw "taskgraph dry-run exited $LASTEXITCODE" }
Assert-Equal 'taskgraph dry-run plans a topological order' "planned order:`ninstall`nlint (after install)`nbuild (after install)`ntest (after build)`nrelease (after build, test, lint)" ($taskgraphDryRun -join "`n")

$taskgraphRun = & $Lume run $taskgraphMain (Join-Path $taskgraphDir 'tasks.json')
if ($LASTEXITCODE -ne 0) { throw "taskgraph real execution exited $LASTEXITCODE" }
Assert-Contains 'taskgraph runs all five tasks and reports zero failures' "passed:`n5`nfailed:`n0`nskipped:`n0" ($taskgraphRun -join "`n")
if (-not (Test-Path -LiteralPath $taskgraphReport)) { throw "taskgraph did not write its JSON report" }
Remove-Item -LiteralPath $taskgraphReport -Force

$taskgraphCycle = & $Lume run $taskgraphMain (Join-Path $taskgraphDir 'tasks_cycle.json') '--dry-run' 2>&1
if ($LASTEXITCODE -ne 1) { throw "taskgraph cycle detection should exit 1" }
Assert-Equal 'taskgraph detects a dependency cycle' 'dependency cycle detected involving task build' ($taskgraphCycle -join "`n")

$taskgraphFailure = & $Lume run $taskgraphMain (Join-Path $taskgraphDir 'tasks_failure.json')
if ($LASTEXITCODE -ne 1) { throw "taskgraph should exit 1 when a task fails" }
$taskgraphFailureText = $taskgraphFailure -join "`n"
Assert-Contains 'taskgraph reports a failed task' 'FAIL  build' $taskgraphFailureText
Assert-Contains 'taskgraph skips tasks depending on a failed one' "SKIP  test - dependency failed: build`nSKIP  release - dependency failed: test" $taskgraphFailureText
Assert-Contains 'taskgraph failure summary counts are correct' "passed:`n1`nfailed:`n1`nskipped:`n2" $taskgraphFailureText
if (Test-Path -LiteralPath $taskgraphReport) { Remove-Item -LiteralPath $taskgraphReport -Force }

$taskgraphNativeTests = & $Lume test (Join-Path $PSScriptRoot 'examples\taskgraph_test.lume')
if ($LASTEXITCODE -ne 0) { throw "taskgraph native tests exited $LASTEXITCODE" }
Assert-Equal 'taskgraph native test suite passes' "PASS contains_name finds an existing entry and rejects a missing one`nPASS first_unresolved_name reports the first task missing from resolved`nPASS first_unresolved_name reports nothing once every task resolved`nPASS join_names joins with a comma and space`nPASS to_json encodes a run's payload-carrying outcome enum`nPASS graph.validate accepts a task set with satisfied dependencies`nPASS graph.validate rejects a duplicate task name`nPASS graph.validate rejects a self-dependency`nPASS graph.validate rejects an unknown dependency`nPASS graph.order returns a topological order for a linear chain`nPASS graph.order detects a dependency cycle`nPASS graph.transitive_closure restricts to a target and its dependencies, in original manifest order`nPASS graph.transitive_closure rejects an unknown target`n13 passed; 0 failed" ($taskgraphNativeTests -join "`n")

$taskBoardNativeTests = & $Lume test (Join-Path $PSScriptRoot 'examples\task_board_test.lume')
if ($LASTEXITCODE -ne 0) { throw "task_board native tests exited $LASTEXITCODE" }
Assert-Equal 'task_board native test suite passes' "PASS classify_priority maps levels to the right variant`nPASS classify_status maps every status code, defaulting to pending`nPASS model.parse decodes a JSON manifest into promoted tasks`nPASS model.parse reports an error for malformed JSON`nPASS rules.validate accepts a task set with unique, non-empty titles and ids`nPASS rules.validate rejects an empty title`nPASS rules.validate rejects a duplicate id`nPASS board counts each status independently`nPASS board.total_priority_weight sums every task's weight`nPASS board.filter_blocked keeps only blocked tasks`nPASS board.next_task picks the highest-priority open task`nPASS board.next_task reports none when every task is done`nPASS board.complete_task marks only the targeted task done`nPASS render.task formats id, priority, title, and status`nPASS render.board joins every task's line with a trailing newline`nPASS insights.search matches titles containing the needle`nPASS insights.first_match reports the first matching task, or none`nPASS insights.short_title_count counts titles under 30 characters`nPASS insights.export writes the rendered board to disk`n19 passed; 0 failed" ($taskBoardNativeTests -join "`n")

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

# A Content-Length that parses as a valid integer but is negative used to
# reach readBytes with that negative count and hang the server forever (0%
# CPU, no response, no crash for a client to notice and restart from) -
# confirmed live before this test existed. It's now treated the same as an
# unparsable header: the server exits instead of hanging.
$lspNegLenPsi = New-Object System.Diagnostics.ProcessStartInfo
$lspNegLenPsi.FileName = $Lume
$lspNegLenPsi.Arguments = 'lsp'
$lspNegLenPsi.RedirectStandardInput = $true
$lspNegLenPsi.RedirectStandardOutput = $true
$lspNegLenPsi.RedirectStandardError = $true
$lspNegLenPsi.UseShellExecute = $false
$lspNegLenProc = [System.Diagnostics.Process]::Start($lspNegLenPsi)
try {
  $negLenHeader = [System.Text.Encoding]::ASCII.GetBytes("Content-Length: -1`r`n`r`n")
  $lspNegLenProc.StandardInput.BaseStream.Write($negLenHeader, 0, $negLenHeader.Length)
  $lspNegLenProc.StandardInput.BaseStream.Flush()
  if (-not $lspNegLenProc.WaitForExit(5000)) { throw 'lsp server should exit on a negative Content-Length, not hang' }
  Assert-Equal 'lsp exits instead of hanging on a negative Content-Length' '0' "$($lspNegLenProc.ExitCode)"
} finally {
  if (-not $lspNegLenProc.HasExited) { $lspNegLenProc.Kill() }
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
  Assert-Equal 'lsp initialize advertises definitionProvider' 'True' "$($initResponse.result.capabilities.definitionProvider)"
  Assert-Equal 'lsp initialize advertises hoverProvider' 'True' "$($initResponse.result.capabilities.hoverProvider)"
  Assert-Equal 'lsp initialize advertises referencesProvider' 'True' "$($initResponse.result.capabilities.referencesProvider)"
  Assert-Equal 'lsp initialize advertises renameProvider' 'True' "$($initResponse.result.capabilities.renameProvider)"
  Assert-Equal 'lsp initialize advertises completionProvider' 'True' "$($null -ne $initResponse.result.capabilities.completionProvider)"
  Assert-Equal 'lsp initialize advertises codeActionProvider' 'True' "$($initResponse.result.capabilities.codeActionProvider)"
  Assert-Equal 'lsp initialize advertises documentSymbolProvider' 'True' "$($initResponse.result.capabilities.documentSymbolProvider)"

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

  # Diagnostics resolve one level of use imports: a call to a name declared
  # only in examples\cross_file_lsp_helper.lume (a real file on disk, added
  # for the cross-file definition PR) must not report a false "unknown
  # function" - confirmed live before this fix that it did, even though the
  # identical source compiles and runs correctly from the command line.
  $diagImportUri = 'file:///' + ((Join-Path $PSScriptRoot 'examples\diag_cross_file_main.lume') -replace '\\', '/')
  $diagImportSource = "use cross_file_lsp_helper`n`nfn main(args: [str]) -> int {`n  print(add(1, 2))`n  return 0`n}`n"
  $didOpenDiagImport = @{ jsonrpc = '2.0'; method = 'textDocument/didOpen'; params = @{ textDocument = @{ uri = $diagImportUri; text = $diagImportSource } } } | ConvertTo-Json -Depth 10 -Compress
  Send-LspMessage $lspProc $didOpenDiagImport
  $diagImportDiag = Read-LspMessage $lspProc | ConvertFrom-Json
  Assert-Equal 'lsp diagnostics suppress a false positive from an unresolved import' '0' "$($diagImportDiag.params.diagnostics.Count)"

  # A genuine, unrelated error in the same file must still be reported
  # correctly (with the single-file's own, correct line number) - the fix
  # must not silently swallow real problems just because imports exist.
  $diagImportBrokenSource = "use cross_file_lsp_helper`n`nfn main(args: [str]) -> int {`n  return undefinedVariable`n}`n"
  $didChangeDiagImportBroken = @{ jsonrpc = '2.0'; method = 'textDocument/didChange'; params = @{ textDocument = @{ uri = $diagImportUri }; contentChanges = @(@{ text = $diagImportBrokenSource }) } } | ConvertTo-Json -Depth 10 -Compress
  Send-LspMessage $lspProc $didChangeDiagImportBroken
  $diagImportBrokenDiag = Read-LspMessage $lspProc | ConvertFrom-Json
  Assert-Equal 'lsp still reports a genuine error alongside a resolved import' 'E0210' $diagImportBrokenDiag.params.diagnostics[0].code
  Assert-Equal 'lsp genuine-error line number is unaffected by the imported source' '3' "$($diagImportBrokenDiag.params.diagnostics[0].range.start.line)"

  # An import that doesn't resolve to anything real must behave exactly as
  # before - the original diagnostic still reported, nothing silently
  # swallowed just because a (bogus) use statement is present.
  $diagBadImportUri = 'file:///' + ((Join-Path $PSScriptRoot 'examples\diag_bad_import.lume') -replace '\\', '/')
  $diagBadImportSource = "use does_not_exist_anywhere`n`nfn main(args: [str]) -> int {`n  print(add(1, 2))`n  return 0`n}`n"
  $didOpenDiagBadImport = @{ jsonrpc = '2.0'; method = 'textDocument/didOpen'; params = @{ textDocument = @{ uri = $diagBadImportUri; text = $diagBadImportSource } } } | ConvertTo-Json -Depth 10 -Compress
  Send-LspMessage $lspProc $didOpenDiagBadImport
  $diagBadImportDiag = Read-LspMessage $lspProc | ConvertFrom-Json
  Assert-Equal 'lsp still reports unknown function when the import does not resolve' 'E0216' $diagBadImportDiag.params.diagnostics[0].code

  # go-to-definition: `add` is declared at 0-indexed line 0, columns 3-6; the
  # call site on line 5 references it. The document store is looked up by a
  # URI Text parsed from a *different* JSON-RPC message than the one that
  # inserted it - this is exactly the case that surfaced Certo's Map being
  # pointer-equality keyed (crates/stdlib/src/collections.rs), which is why
  # the document store is two parallel lists searched by Text.eq, not a Map.
  $defSource = "fn add(a: int, b: int) -> int {`n  return a + b`n}`n`nfn main(args: [str]) -> int {`n  print(add(1, 2))`n  return 0`n}`n"
  $defUri = 'file:///definition.lume'
  $didOpenDef = @{ jsonrpc = '2.0'; method = 'textDocument/didOpen'; params = @{ textDocument = @{ uri = $defUri; text = $defSource } } } | ConvertTo-Json -Depth 10 -Compress
  Send-LspMessage $lspProc $didOpenDef
  Read-LspMessage $lspProc | Out-Null

  $defReq = @{ jsonrpc = '2.0'; id = 10; method = 'textDocument/definition'; params = @{ textDocument = @{ uri = $defUri }; position = @{ line = 5; character = 9 } } } | ConvertTo-Json -Depth 10 -Compress
  Send-LspMessage $lspProc $defReq
  $defResp = Read-LspMessage $lspProc | ConvertFrom-Json
  Assert-Equal 'go-to-definition finds the call site''s declaration' $defUri $defResp.result.uri
  Assert-Equal 'go-to-definition start line' '0' "$($defResp.result.range.start.line)"
  Assert-Equal 'go-to-definition start character' '3' "$($defResp.result.range.start.character)"
  Assert-Equal 'go-to-definition end character' '6' "$($defResp.result.range.end.character)"

  $defReqWhitespace = @{ jsonrpc = '2.0'; id = 11; method = 'textDocument/definition'; params = @{ textDocument = @{ uri = $defUri }; position = @{ line = 5; character = 0 } } } | ConvertTo-Json -Depth 10 -Compress
  Send-LspMessage $lspProc $defReqWhitespace
  $defRespWhitespace = Read-LspMessage $lspProc | ConvertFrom-Json
  Assert-Equal 'go-to-definition on whitespace returns null' '' "$($defRespWhitespace.result)"

  $defReqUndeclared = @{ jsonrpc = '2.0'; id = 12; method = 'textDocument/definition'; params = @{ textDocument = @{ uri = $defUri }; position = @{ line = 5; character = 3 } } } | ConvertTo-Json -Depth 10 -Compress
  Send-LspMessage $lspProc $defReqUndeclared
  $defRespUndeclared = Read-LspMessage $lspProc | ConvertFrom-Json
  Assert-Equal 'go-to-definition on an undeclared name (print) returns null' '' "$($defRespUndeclared.result)"

  # hover: reuses the same $defUri document (fn add(a: int, b: int) -> int
  # declared, called from main). Hovering the call site shows the full
  # signature (parameterNames/parameterTypes/functionReturnType, already
  # exercised elsewhere in the compiler for protocol methods - reused as-is,
  # no new parsing). A record/enum name would show only the bare "type
  # Name"/"enum Name" line (not attempted here - no record/enum in this
  # fixture); see BENCHMARKS.md-style notes in the PR for the field-list
  # follow-up this defers.
  $hoverReq = @{ jsonrpc = '2.0'; id = 13; method = 'textDocument/hover'; params = @{ textDocument = @{ uri = $defUri }; position = @{ line = 5; character = 9 } } } | ConvertTo-Json -Depth 10 -Compress
  Send-LspMessage $lspProc $hoverReq
  $hoverResp = Read-LspMessage $lspProc | ConvertFrom-Json
  Assert-Equal 'hover on a function call shows its signature' 'fn add(a: int, b: int): int' $hoverResp.result.contents.value
  Assert-Equal 'hover response content kind is plaintext' 'plaintext' $hoverResp.result.contents.kind

  $hoverReqWhitespace = @{ jsonrpc = '2.0'; id = 14; method = 'textDocument/hover'; params = @{ textDocument = @{ uri = $defUri }; position = @{ line = 5; character = 0 } } } | ConvertTo-Json -Depth 10 -Compress
  Send-LspMessage $lspProc $hoverReqWhitespace
  $hoverRespWhitespace = Read-LspMessage $lspProc | ConvertFrom-Json
  Assert-Equal 'hover on whitespace returns null' '' "$($hoverRespWhitespace.result)"

  # references/rename: reuses $defUri (fn add declared once, called once from
  # main - 2 occurrences total: the declaration at line 0 and the call site
  # at line 5). context.includeDeclaration isn't read by the server - the
  # response always includes every occurrence regardless of that flag.
  $refsReq = @{ jsonrpc = '2.0'; id = 15; method = 'textDocument/references'; params = @{ textDocument = @{ uri = $defUri }; position = @{ line = 5; character = 9 }; context = @{ includeDeclaration = $true } } } | ConvertTo-Json -Depth 10 -Compress
  Send-LspMessage $lspProc $refsReq
  $refsResp = Read-LspMessage $lspProc | ConvertFrom-Json
  Assert-Equal 'references finds both the declaration and the call site' '2' "$($refsResp.result.Count)"
  Assert-Equal 'references first location is the declaration' '0' "$($refsResp.result[0].range.start.line)"
  Assert-Equal 'references second location is the call site' '5' "$($refsResp.result[1].range.start.line)"

  $refsReqWhitespace = @{ jsonrpc = '2.0'; id = 16; method = 'textDocument/references'; params = @{ textDocument = @{ uri = $defUri }; position = @{ line = 5; character = 0 } } } | ConvertTo-Json -Depth 10 -Compress
  Send-LspMessage $lspProc $refsReqWhitespace
  $refsRespWhitespace = Read-LspMessage $lspProc | ConvertFrom-Json
  Assert-Equal 'references on whitespace returns null' '' "$($refsRespWhitespace.result)"

  $renameReq = @{ jsonrpc = '2.0'; id = 17; method = 'textDocument/rename'; params = @{ textDocument = @{ uri = $defUri }; position = @{ line = 5; character = 9 }; newName = 'sum' } } | ConvertTo-Json -Depth 10 -Compress
  Send-LspMessage $lspProc $renameReq
  $renameResp = Read-LspMessage $lspProc | ConvertFrom-Json
  $renameEdits = $renameResp.result.changes.$defUri
  Assert-Equal 'rename produces edits for both occurrences' '2' "$($renameEdits.Count)"
  Assert-Equal 'rename edit newText matches the requested name' 'sum' $renameEdits[0].newText
  Assert-Equal 'rename edit range matches the declaration' '0' "$($renameEdits[0].range.start.line)"

  $renameReqWhitespace = @{ jsonrpc = '2.0'; id = 18; method = 'textDocument/rename'; params = @{ textDocument = @{ uri = $defUri }; position = @{ line = 5; character = 0 }; newName = 'sum' } } | ConvertTo-Json -Depth 10 -Compress
  Send-LspMessage $lspProc $renameReqWhitespace
  $renameRespWhitespace = Read-LspMessage $lspProc | ConvertFrom-Json
  Assert-Equal 'rename on whitespace returns null' '' "$($renameRespWhitespace.result)"

  # cross-file definition: one level of direct `use` imports, resolved the
  # same way the real compiler resolves them (importedModules/
  # resolveModulePath). Needs a *real* file on disk - examples\
  # cross_file_lsp_helper.lume - since this is the first LSP test in this
  # arc where the requested name isn't declared in the open document at
  # all. The "main" side is an in-memory-only document (its own uri never
  # needs to exist on disk - only Path.dirname of it matters, to resolve
  # `use cross_file_lsp_helper` against the real examples directory).
  $crossFileHelperPath = Join-Path $PSScriptRoot 'examples\cross_file_lsp_helper.lume'
  $crossFileHelperUri = 'file:///' + ($crossFileHelperPath -replace '\\', '/')
  $crossFileMainUri = 'file:///' + ((Join-Path $PSScriptRoot 'examples\cross_file_lsp_main.lume') -replace '\\', '/')
  $crossFileMainSource = "use cross_file_lsp_helper`n`nfn main(args: [str]) -> int {`n  print(add(1, 2))`n  return 0`n}`n"
  $didOpenCrossFileMain = @{ jsonrpc = '2.0'; method = 'textDocument/didOpen'; params = @{ textDocument = @{ uri = $crossFileMainUri; text = $crossFileMainSource } } } | ConvertTo-Json -Depth 10 -Compress
  Send-LspMessage $lspProc $didOpenCrossFileMain
  Read-LspMessage $lspProc | Out-Null

  $crossFileDefReq = @{ jsonrpc = '2.0'; id = 22; method = 'textDocument/definition'; params = @{ textDocument = @{ uri = $crossFileMainUri }; position = @{ line = 3; character = 9 } } } | ConvertTo-Json -Depth 10 -Compress
  Send-LspMessage $lspProc $crossFileDefReq
  $crossFileDefResp = Read-LspMessage $lspProc | ConvertFrom-Json
  Assert-Equal 'cross-file definition resolves to the imported file' $crossFileHelperUri $crossFileDefResp.result.uri
  Assert-Equal 'cross-file definition range matches the declaration' '0' "$($crossFileDefResp.result.range.start.line)"

  # Regression check: a same-file declaration must still resolve without
  # ever touching the cross-file path.
  Send-LspMessage $lspProc $defReq
  $sameFileDefResp = Read-LspMessage $lspProc | ConvertFrom-Json
  Assert-Equal 'same-file definition still resolves unchanged' $defUri $sameFileDefResp.result.uri

  # cross-file hover: reuses the exact same fixture and position as
  # cross-file definition above - both share lspResolveCrossFileDeclaration,
  # generalized from definition's own original cross-file walk specifically
  # so hover didn't need a second, near-duplicate one.
  $crossFileHoverReq = @{ jsonrpc = '2.0'; id = 23; method = 'textDocument/hover'; params = @{ textDocument = @{ uri = $crossFileMainUri }; position = @{ line = 3; character = 9 } } } | ConvertTo-Json -Depth 10 -Compress
  Send-LspMessage $lspProc $crossFileHoverReq
  $crossFileHoverResp = Read-LspMessage $lspProc | ConvertFrom-Json
  Assert-Equal 'cross-file hover shows the imported function signature' 'fn add(a: int, b: int): int' $crossFileHoverResp.result.contents.value

  # Regression check: same-file hover must still resolve without ever
  # touching the cross-file path.
  Send-LspMessage $lspProc $hoverReq
  $sameFileHoverResp = Read-LspMessage $lspProc | ConvertFrom-Json
  Assert-Equal 'same-file hover still resolves unchanged' 'fn add(a: int, b: int): int' $sameFileHoverResp.result.contents.value

  # cross-file references: examples\cross_file_lsp_helper.lume also declares
  # add_three, which calls add(a, b) internally - a real occurrence inside
  # the imported file itself, not just its declaration. Three locations
  # expected total: the call site in the current document, the declaration
  # in the imported file, and that internal call inside add_three.
  $crossFileRefsReq = @{ jsonrpc = '2.0'; id = 24; method = 'textDocument/references'; params = @{ textDocument = @{ uri = $crossFileMainUri }; position = @{ line = 3; character = 9 } } } | ConvertTo-Json -Depth 10 -Compress
  Send-LspMessage $lspProc $crossFileRefsReq
  $crossFileRefsResp = Read-LspMessage $lspProc | ConvertFrom-Json
  Assert-Equal 'cross-file references finds occurrences across both files' '3' "$($crossFileRefsResp.result.Count)"
  Assert-Equal 'cross-file references first location is the current document call site' $crossFileMainUri $crossFileRefsResp.result[0].uri
  Assert-Equal 'cross-file references second location is the imported declaration' $crossFileHelperUri $crossFileRefsResp.result[1].uri
  Assert-Equal 'cross-file references third location is an internal call inside the import' $crossFileHelperUri $crossFileRefsResp.result[2].uri
  Assert-Equal 'cross-file references internal-call line is correct' '5' "$($crossFileRefsResp.result[2].range.start.line)"

  # Regression check: same-file-only references must be unaffected.
  Send-LspMessage $lspProc $refsReq
  $sameFileRefsResp = Read-LspMessage $lspProc | ConvertFrom-Json
  Assert-Equal 'same-file references still resolves unchanged' '2' "$($sameFileRefsResp.result.Count)"

  # cross-file rename: same fixture, same shape as cross-file references,
  # but a WorkspaceEdit's changes field is keyed by uri rather than a flat
  # array - the imported file's edits (its declaration and the internal
  # call inside add_three) get their own key, not entries appended to the
  # current document's own edit list.
  $crossFileRenameReq = @{ jsonrpc = '2.0'; id = 25; method = 'textDocument/rename'; params = @{ textDocument = @{ uri = $crossFileMainUri }; position = @{ line = 3; character = 9 }; newName = 'sum' } } | ConvertTo-Json -Depth 10 -Compress
  Send-LspMessage $lspProc $crossFileRenameReq
  $crossFileRenameResp = Read-LspMessage $lspProc | ConvertFrom-Json
  $crossFileRenameKeys = $crossFileRenameResp.result.changes.PSObject.Properties.Name
  Assert-Equal 'cross-file rename touches both files' '2' "$($crossFileRenameKeys.Count)"
  $crossFileRenameMainEdits = $crossFileRenameResp.result.changes.$crossFileMainUri
  $crossFileRenameHelperEdits = $crossFileRenameResp.result.changes.$crossFileHelperUri
  Assert-Equal 'cross-file rename edits one occurrence in the current document' '1' "$($crossFileRenameMainEdits.Count)"
  Assert-Equal 'cross-file rename edits both occurrences in the imported file' '2' "$($crossFileRenameHelperEdits.Count)"
  Assert-Equal 'cross-file rename newText matches the requested name' 'sum' $crossFileRenameHelperEdits[0].newText

  # Regression check: same-file-only rename must still produce a single-key
  # WorkspaceEdit, unchanged.
  Send-LspMessage $lspProc $renameReq
  $sameFileRenameResp = Read-LspMessage $lspProc | ConvertFrom-Json
  $sameFileRenameKeys = $sameFileRenameResp.result.changes.PSObject.Properties.Name
  Assert-Equal 'same-file rename still touches only one file' '1' "$($sameFileRenameKeys.Count)"

  # code actions: the one unambiguous, deterministic quick fix - insert a
  # missing `fn main` stub at end of file. Applying the returned edit must
  # produce source that actually compiles, not just look plausible.
  $noMainUri = 'file:///no_main.lume'
  $noMainSource = 'fn helper() -> int { return 1 }'
  $didOpenNoMain = @{ jsonrpc = '2.0'; method = 'textDocument/didOpen'; params = @{ textDocument = @{ uri = $noMainUri; text = $noMainSource } } } | ConvertTo-Json -Depth 10 -Compress
  Send-LspMessage $lspProc $didOpenNoMain
  $noMainDiag = Read-LspMessage $lspProc | ConvertFrom-Json
  Assert-Equal 'lsp reports missing fn main' 'E0201' $noMainDiag.params.diagnostics[0].code

  $codeActionReq = @{ jsonrpc = '2.0'; id = 26; method = 'textDocument/codeAction'; params = @{ textDocument = @{ uri = $noMainUri }; range = @{ start = @{ line = 0; character = 0 }; end = @{ line = 0; character = 0 } }; context = @{ diagnostics = $noMainDiag.params.diagnostics } } } | ConvertTo-Json -Depth 10 -Compress
  Send-LspMessage $lspProc $codeActionReq
  $codeActionResp = Read-LspMessage $lspProc | ConvertFrom-Json
  Assert-Equal 'code action offers exactly one fix for missing fn main' '1' "$($codeActionResp.result.Count)"
  Assert-Equal 'code action title' 'Insert `fn main`' $codeActionResp.result[0].title
  Assert-Equal 'code action kind is quickfix' 'quickfix' $codeActionResp.result[0].kind

  $noMainEdit = $codeActionResp.result[0].edit.changes.$noMainUri[0]
  $fixedSource = $noMainSource + $noMainEdit.newText
  $fixedPath = Join-Path $env:TEMP 'code_action_fixed_temp.lume'
  Set-Content -LiteralPath $fixedPath -Value $fixedSource -NoNewline
  try {
    & $Lume check $fixedPath | Out-Null
    Assert-Equal 'applying the code action edit produces source that compiles' '0' "$LASTEXITCODE"
  } finally {
    Remove-Item -LiteralPath $fixedPath -ErrorAction SilentlyContinue
  }

  # A diagnostic that doesn't match a known fix must return zero actions,
  # not an error or a malformed one.
  $undefinedUri = 'file:///undefined_for_code_action.lume'
  $undefinedSource = "fn main(args: [str]) -> int {`n  return undefinedVariable`n}`n"
  $didOpenUndefined = @{ jsonrpc = '2.0'; method = 'textDocument/didOpen'; params = @{ textDocument = @{ uri = $undefinedUri; text = $undefinedSource } } } | ConvertTo-Json -Depth 10 -Compress
  Send-LspMessage $lspProc $didOpenUndefined
  $undefinedDiag = Read-LspMessage $lspProc | ConvertFrom-Json
  $codeActionReqUndefined = @{ jsonrpc = '2.0'; id = 27; method = 'textDocument/codeAction'; params = @{ textDocument = @{ uri = $undefinedUri }; range = @{ start = @{ line = 1; character = 0 }; end = @{ line = 1; character = 0 } }; context = @{ diagnostics = $undefinedDiag.params.diagnostics } } } | ConvertTo-Json -Depth 10 -Compress
  Send-LspMessage $lspProc $codeActionReqUndefined
  $codeActionRespUndefined = Read-LspMessage $lspProc | ConvertFrom-Json
  Assert-Equal 'code actions for an unrelated diagnostic is empty' '0' "$($codeActionRespUndefined.result.Count)"

  # code actions: "add missing use import" - a call to a function that
  # exists in a real sibling .lume file (examples\lsp_add_import\greeter.lume)
  # but isn't imported yet. Applying the edit must actually compile, same
  # bar as the fn-main fix above.
  $addImportUri = 'file:///' + ((Join-Path $PSScriptRoot 'examples\lsp_add_import\main_probe.lume') -replace '\\', '/')
  $addImportSource = "fn main(args: [str]) -> int {`n  print(str.from_int(add_import_greeting()))`n  return 0`n}`n"
  $didOpenAddImport = @{ jsonrpc = '2.0'; method = 'textDocument/didOpen'; params = @{ textDocument = @{ uri = $addImportUri; text = $addImportSource } } } | ConvertTo-Json -Depth 10 -Compress
  Send-LspMessage $lspProc $didOpenAddImport
  $addImportDiag = Read-LspMessage $lspProc | ConvertFrom-Json
  Assert-Equal 'lsp reports unknown function for the un-imported call' 'E0216' $addImportDiag.params.diagnostics[0].code

  $addImportReq = @{ jsonrpc = '2.0'; id = 28; method = 'textDocument/codeAction'; params = @{ textDocument = @{ uri = $addImportUri }; range = @{ start = @{ line = 1; character = 0 }; end = @{ line = 1; character = 0 } }; context = @{ diagnostics = $addImportDiag.params.diagnostics } } } | ConvertTo-Json -Depth 10 -Compress
  Send-LspMessage $lspProc $addImportReq
  $addImportResp = Read-LspMessage $lspProc | ConvertFrom-Json
  Assert-Equal 'add-use-import offers exactly one fix' '1' "$($addImportResp.result.Count)"
  Assert-Equal 'add-use-import title names the sibling module' 'Add `use greeter`' $addImportResp.result[0].title
  Assert-Equal 'add-use-import kind is quickfix' 'quickfix' $addImportResp.result[0].kind

  $addImportEdit = $addImportResp.result[0].edit.changes.$addImportUri[0]
  Assert-Equal 'add-use-import inserts at the top of the file when no imports exist' '0' "$($addImportEdit.range.start.line)"
  $addImportFixedSource = $addImportEdit.newText + $addImportSource
  # Written next to the real sibling greeter.lume, not $env:TEMP - `use
  # greeter` resolves relative to the checked file's own directory, so the
  # compiled-check must run from the same directory as the fixture.
  $addImportFixedPath = Join-Path $PSScriptRoot 'examples\lsp_add_import\code_action_add_import_fixed_temp.lume'
  Set-Content -LiteralPath $addImportFixedPath -Value $addImportFixedSource -NoNewline
  try {
    & $Lume check $addImportFixedPath | Out-Null
    Assert-Equal 'applying the add-use-import edit produces source that compiles' '0' "$LASTEXITCODE"
  } finally {
    Remove-Item -LiteralPath $addImportFixedPath -ErrorAction SilentlyContinue
  }

  # Insertion must land after an existing leading use block, not at the top
  # of the file - examples\lsp_add_import_existing\ has two real sibling
  # files: one already imported (existing.lume), one not (target.lume).
  $addImportExistingUri = 'file:///' + ((Join-Path $PSScriptRoot 'examples\lsp_add_import_existing\main_probe.lume') -replace '\\', '/')
  $addImportExistingSource = "use existing`n`nfn main(args: [str]) -> int {`n  print(str.from_int(add_import_target()))`n  return 0`n}`n"
  $didOpenAddImportExisting = @{ jsonrpc = '2.0'; method = 'textDocument/didOpen'; params = @{ textDocument = @{ uri = $addImportExistingUri; text = $addImportExistingSource } } } | ConvertTo-Json -Depth 10 -Compress
  Send-LspMessage $lspProc $didOpenAddImportExisting
  $addImportExistingDiag = Read-LspMessage $lspProc | ConvertFrom-Json
  $addImportExistingReq = @{ jsonrpc = '2.0'; id = 29; method = 'textDocument/codeAction'; params = @{ textDocument = @{ uri = $addImportExistingUri }; range = @{ start = @{ line = 3; character = 0 }; end = @{ line = 3; character = 0 } }; context = @{ diagnostics = $addImportExistingDiag.params.diagnostics } } } | ConvertTo-Json -Depth 10 -Compress
  Send-LspMessage $lspProc $addImportExistingReq
  $addImportExistingResp = Read-LspMessage $lspProc | ConvertFrom-Json
  Assert-Equal 'add-use-import (with existing import) offers exactly one fix' '1' "$($addImportExistingResp.result.Count)"
  Assert-Equal 'add-use-import (with existing import) title' 'Add `use target`' $addImportExistingResp.result[0].title
  $addImportExistingEdit = $addImportExistingResp.result[0].edit.changes.$addImportExistingUri[0]
  Assert-Equal 'add-use-import inserts right after the existing use block, not at the top' '1' "$($addImportExistingEdit.range.start.line)"

  # Ambiguity: two sibling files (alpha.lume/beta.lume) both declare the
  # same missing name - both must be offered, not just the first match.
  $addImportAmbiguousUri = 'file:///' + ((Join-Path $PSScriptRoot 'examples\lsp_add_import_ambiguous\main_probe.lume') -replace '\\', '/')
  $addImportAmbiguousSource = "fn main(args: [str]) -> int {`n  print(str.from_int(add_import_ambiguous()))`n  return 0`n}`n"
  $didOpenAddImportAmbiguous = @{ jsonrpc = '2.0'; method = 'textDocument/didOpen'; params = @{ textDocument = @{ uri = $addImportAmbiguousUri; text = $addImportAmbiguousSource } } } | ConvertTo-Json -Depth 10 -Compress
  Send-LspMessage $lspProc $didOpenAddImportAmbiguous
  $addImportAmbiguousDiag = Read-LspMessage $lspProc | ConvertFrom-Json
  $addImportAmbiguousReq = @{ jsonrpc = '2.0'; id = 30; method = 'textDocument/codeAction'; params = @{ textDocument = @{ uri = $addImportAmbiguousUri }; range = @{ start = @{ line = 1; character = 0 }; end = @{ line = 1; character = 0 } }; context = @{ diagnostics = $addImportAmbiguousDiag.params.diagnostics } } } | ConvertTo-Json -Depth 10 -Compress
  Send-LspMessage $lspProc $addImportAmbiguousReq
  $addImportAmbiguousResp = Read-LspMessage $lspProc | ConvertFrom-Json
  Assert-Equal 'ambiguous add-use-import offers one fix per matching sibling' '2' "$($addImportAmbiguousResp.result.Count)"
  $addImportAmbiguousTitles = $addImportAmbiguousResp.result | ForEach-Object { $_.title } | Sort-Object
  Assert-Equal 'ambiguous add-use-import titles name each distinct sibling' 'Add `use alpha`,Add `use beta`' ($addImportAmbiguousTitles -join ',')

  # code actions: "did you mean" - a genuine typo of a known name, not a
  # missing import. Candidate pool is builtins plus file-local fn
  # declarations (the same flat pool completion/add-import already use),
  # scored by edit distance. Applying the edit must actually compile, same
  # bar as every other fix in this arc.
  $dymBuiltinUri = 'file:///dym_builtin.lume'
  $dymBuiltinSource = "fn main(args: [str]) -> int {`n  print(str.form_int(1))`n  return 0`n}`n"
  $didOpenDymBuiltin = @{ jsonrpc = '2.0'; method = 'textDocument/didOpen'; params = @{ textDocument = @{ uri = $dymBuiltinUri; text = $dymBuiltinSource } } } | ConvertTo-Json -Depth 10 -Compress
  Send-LspMessage $lspProc $didOpenDymBuiltin
  $dymBuiltinDiag = Read-LspMessage $lspProc | ConvertFrom-Json
  Assert-Equal 'lsp reports unknown function for the misspelled builtin' 'E0216' $dymBuiltinDiag.params.diagnostics[0].code

  $dymBuiltinReq = @{ jsonrpc = '2.0'; id = 31; method = 'textDocument/codeAction'; params = @{ textDocument = @{ uri = $dymBuiltinUri }; range = @{ start = @{ line = 1; character = 0 }; end = @{ line = 1; character = 0 } }; context = @{ diagnostics = $dymBuiltinDiag.params.diagnostics } } } | ConvertTo-Json -Depth 10 -Compress
  Send-LspMessage $lspProc $dymBuiltinReq
  $dymBuiltinResp = Read-LspMessage $lspProc | ConvertFrom-Json
  Assert-Equal 'did-you-mean offers exactly one fix for a misspelled builtin' '1' "$($dymBuiltinResp.result.Count)"
  Assert-Equal 'did-you-mean title names the closest builtin' 'Change to `str.from_int`' $dymBuiltinResp.result[0].title
  Assert-Equal 'did-you-mean kind is quickfix' 'quickfix' $dymBuiltinResp.result[0].kind

  $dymBuiltinEdit = $dymBuiltinResp.result[0].edit.changes.$dymBuiltinUri[0]
  Assert-Equal 'did-you-mean edit targets the misspelled token, not column 0' '8' "$($dymBuiltinEdit.range.start.character)"
  $dymBuiltinFixedSource = $dymBuiltinSource.Substring(0, [int]$dymBuiltinSource.IndexOf('str.form_int')) + $dymBuiltinEdit.newText + $dymBuiltinSource.Substring([int]$dymBuiltinSource.IndexOf('str.form_int') + 'str.form_int'.Length)
  $dymBuiltinFixedPath = Join-Path $env:TEMP 'code_action_dym_builtin_fixed_temp.lume'
  Set-Content -LiteralPath $dymBuiltinFixedPath -Value $dymBuiltinFixedSource -NoNewline
  try {
    & $Lume check $dymBuiltinFixedPath | Out-Null
    Assert-Equal 'applying the did-you-mean builtin edit produces source that compiles' '0' "$LASTEXITCODE"
  } finally {
    Remove-Item -LiteralPath $dymBuiltinFixedPath -ErrorAction SilentlyContinue
  }

  $dymLocalUri = 'file:///dym_local.lume'
  $dymLocalSource = "fn add_numbers(a: int, b: int) -> int {`n  return a + b`n}`n`nfn main(args: [str]) -> int {`n  print(str.from_int(add_numbrs(1, 2)))`n  return 0`n}`n"
  $didOpenDymLocal = @{ jsonrpc = '2.0'; method = 'textDocument/didOpen'; params = @{ textDocument = @{ uri = $dymLocalUri; text = $dymLocalSource } } } | ConvertTo-Json -Depth 10 -Compress
  Send-LspMessage $lspProc $didOpenDymLocal
  $dymLocalDiag = Read-LspMessage $lspProc | ConvertFrom-Json
  $dymLocalReq = @{ jsonrpc = '2.0'; id = 32; method = 'textDocument/codeAction'; params = @{ textDocument = @{ uri = $dymLocalUri }; range = @{ start = @{ line = 5; character = 0 }; end = @{ line = 5; character = 0 } }; context = @{ diagnostics = $dymLocalDiag.params.diagnostics } } } | ConvertTo-Json -Depth 10 -Compress
  Send-LspMessage $lspProc $dymLocalReq
  $dymLocalResp = Read-LspMessage $lspProc | ConvertFrom-Json
  Assert-Equal 'did-you-mean offers exactly one fix for a misspelled file-local function' '1' "$($dymLocalResp.result.Count)"
  Assert-Equal 'did-you-mean title names the closest file-local function' 'Change to `add_numbers`' $dymLocalResp.result[0].title

  $dymLocalEdit = $dymLocalResp.result[0].edit.changes.$dymLocalUri[0]
  $dymLocalFixedSource = $dymLocalSource -replace 'add_numbrs', $dymLocalEdit.newText
  $dymLocalFixedPath = Join-Path $env:TEMP 'code_action_dym_local_fixed_temp.lume'
  Set-Content -LiteralPath $dymLocalFixedPath -Value $dymLocalFixedSource -NoNewline
  try {
    & $Lume check $dymLocalFixedPath | Out-Null
    Assert-Equal 'applying the did-you-mean local-function edit produces source that compiles' '0' "$LASTEXITCODE"
  } finally {
    Remove-Item -LiteralPath $dymLocalFixedPath -ErrorAction SilentlyContinue
  }

  # No close match at all must return zero actions, not a wild guess.
  $dymNoneUri = 'file:///dym_none.lume'
  $dymNoneSource = "fn main(args: [str]) -> int {`n  print(str.from_int(zzzqqqxxxwwwnoclose()))`n  return 0`n}`n"
  $didOpenDymNone = @{ jsonrpc = '2.0'; method = 'textDocument/didOpen'; params = @{ textDocument = @{ uri = $dymNoneUri; text = $dymNoneSource } } } | ConvertTo-Json -Depth 10 -Compress
  Send-LspMessage $lspProc $didOpenDymNone
  $dymNoneDiag = Read-LspMessage $lspProc | ConvertFrom-Json
  $dymNoneReq = @{ jsonrpc = '2.0'; id = 33; method = 'textDocument/codeAction'; params = @{ textDocument = @{ uri = $dymNoneUri }; range = @{ start = @{ line = 1; character = 0 }; end = @{ line = 1; character = 0 } }; context = @{ diagnostics = $dymNoneDiag.params.diagnostics } } } | ConvertTo-Json -Depth 10 -Compress
  Send-LspMessage $lspProc $dymNoneReq
  $dymNoneResp = Read-LspMessage $lspProc | ConvertFrom-Json
  Assert-Equal 'did-you-mean returns zero actions when nothing is close enough' '0' "$($dymNoneResp.result.Count)"

  # documentSymbol: reuses lspDeclarationSites as-is, so it's flat (no
  # nesting) - an impl method's own `fn` surfaces as its own entry, not
  # nested under its type. Point-range only (range == selectionRange).
  $docSymUri = 'file:///doc_symbol.lume'
  $docSymSource = "type Point = { x: int, y: int }`n`nenum Shape { Circle(r: int), Square(s: int) }`n`nfn area(p: Point) -> int {`n  return p.x * p.y`n}`n`nimpl Shape {`n  fn describe(self) -> int {`n    return 0`n  }`n}`n"
  $didOpenDocSym = @{ jsonrpc = '2.0'; method = 'textDocument/didOpen'; params = @{ textDocument = @{ uri = $docSymUri; text = $docSymSource } } } | ConvertTo-Json -Depth 10 -Compress
  Send-LspMessage $lspProc $didOpenDocSym
  Read-LspMessage $lspProc | Out-Null

  $docSymReq = @{ jsonrpc = '2.0'; id = 34; method = 'textDocument/documentSymbol'; params = @{ textDocument = @{ uri = $docSymUri } } } | ConvertTo-Json -Depth 10 -Compress
  Send-LspMessage $lspProc $docSymReq
  $docSymResp = Read-LspMessage $lspProc | ConvertFrom-Json
  Assert-Equal 'documentSymbol returns one entry per declaration, including an impl method' '4' "$($docSymResp.result.Count)"
  Assert-Equal 'documentSymbol names the record type' 'Point' $docSymResp.result[0].name
  Assert-Equal 'documentSymbol kind for a record type is Struct (23)' '23' "$($docSymResp.result[0].kind)"
  Assert-Equal 'documentSymbol names the enum' 'Shape' $docSymResp.result[1].name
  Assert-Equal 'documentSymbol kind for an enum is Enum (10)' '10' "$($docSymResp.result[1].kind)"
  Assert-Equal 'documentSymbol names the function' 'area' $docSymResp.result[2].name
  Assert-Equal 'documentSymbol kind for a function is Function (12)' '12' "$($docSymResp.result[2].kind)"
  Assert-Equal 'documentSymbol includes an impl method as its own flat entry' 'describe' $docSymResp.result[3].name
  Assert-Equal 'documentSymbol range matches selectionRange' 'True' "$($docSymResp.result[0].range.start.character -eq $docSymResp.result[0].selectionRange.start.character)"

  $docSymReqUnopened = @{ jsonrpc = '2.0'; id = 35; method = 'textDocument/documentSymbol'; params = @{ textDocument = @{ uri = 'file:///doc_symbol_never_opened.lume' } } } | ConvertTo-Json -Depth 10 -Compress
  Send-LspMessage $lspProc $docSymReqUnopened
  $docSymRespUnopened = Read-LspMessage $lspProc | ConvertFrom-Json
  Assert-Equal 'documentSymbol on a never-opened uri returns an empty array, not an error' '0' "$($docSymRespUnopened.result.Count)"

  # completion: no scope resolution - every builtin plus every fn/type/enum
  # declared in the open document, unfiltered by cursor position or partial
  # word. Spot checks, not an exhaustive enumeration of every builtin (the
  # list is large and would make this brittle against future additions).
  $compReq = @{ jsonrpc = '2.0'; id = 19; method = 'textDocument/completion'; params = @{ textDocument = @{ uri = $defUri }; position = @{ line = 5; character = 9 } } } | ConvertTo-Json -Depth 10 -Compress
  Send-LspMessage $lspProc $compReq
  $compResp = Read-LspMessage $lspProc | ConvertFrom-Json
  $compLabels = $compResp.result | ForEach-Object { $_.label }
  Assert-Equal 'completion includes the file-local declaration' 'True' "$($compLabels -contains 'add')"
  Assert-Equal 'completion includes a builtin' 'True' "$($compLabels -contains 'str.len')"
  $addCompletion = $compResp.result | Where-Object { $_.label -eq 'add' } | Select-Object -First 1
  Assert-Equal 'completion item for a function declaration has Function kind' '3' "$($addCompletion.kind)"

  $compReqNeverOpened = @{ jsonrpc = '2.0'; id = 20; method = 'textDocument/completion'; params = @{ textDocument = @{ uri = 'file:///never_opened_completion.lume' }; position = @{ line = 0; character = 0 } } } | ConvertTo-Json -Depth 10 -Compress
  Send-LspMessage $lspProc $compReqNeverOpened
  $compRespNeverOpened = Read-LspMessage $lspProc | ConvertFrom-Json
  $compLabelsNeverOpened = $compRespNeverOpened.result | ForEach-Object { $_.label }
  Assert-Equal 'completion still returns builtins for a never-opened uri' 'True' "$($compLabelsNeverOpened -contains 'str.len')"

  # An incomplete function signature must not crash the whole server -
  # it did before this fix (didOpen on this exact source killed the
  # process, taking every other open document's diagnostics/definition/
  # hover/references/rename/completion down with it). Confirms the server
  # both publishes a diagnostic AND stays genuinely responsive afterward
  # (a second request, not just "hasn't exited yet").
  $incompleteSource = "fn broken(a: int, b: int`n`nfn main(args: [str]) -> int {`n  print(broken(1, 2))`n  return 0`n}`n"
  $incompleteUri = 'file:///incomplete_signature.lume'
  $didOpenIncomplete = @{ jsonrpc = '2.0'; method = 'textDocument/didOpen'; params = @{ textDocument = @{ uri = $incompleteUri; text = $incompleteSource } } } | ConvertTo-Json -Depth 10 -Compress
  Send-LspMessage $lspProc $didOpenIncomplete
  $incompleteDiag = Read-LspMessage $lspProc | ConvertFrom-Json
  Assert-Equal 'lsp survives didOpen on an incomplete function signature' '1' "$($incompleteDiag.params.diagnostics.Count)"

  Send-LspMessage $lspProc '{"jsonrpc":"2.0","id":21,"method":"initialize","params":{}}'
  $postCrashInit = Read-LspMessage $lspProc | ConvertFrom-Json
  Assert-Equal 'lsp stays responsive after an incomplete signature' '1' "$($postCrashInit.result.capabilities.textDocumentSync)"

  Send-LspMessage $lspProc '{"jsonrpc":"2.0","id":2,"method":"shutdown"}'
  $shutdownResponse = Read-LspMessage $lspProc | ConvertFrom-Json
  Assert-Equal 'lsp shutdown responds with a null result' '' "$($shutdownResponse.result)"

  Send-LspMessage $lspProc '{"jsonrpc":"2.0","method":"exit"}'
  if (-not $lspProc.WaitForExit(5000)) { throw 'lsp server did not exit after an exit notification' }
  Assert-Equal 'lsp exits cleanly' '0' "$($lspProc.ExitCode)"
} finally {
  if (-not $lspProc.HasExited) { $lspProc.Kill() }
}

# workspace/symbol needs its own session, initialized with a real rootUri -
# the shared session above never sends one, so its own workspaceRoot stays
# "" for its whole lifetime (by design: an empty root degrades to an empty
# result rather than an error). examples\lsp_workspace_symbol\ has two
# fixture files, one in a subdirectory (sub\beta.lume), to exercise the
# recursive walkDir walk, not just the root directory.
$wsSymbolRoot = Join-Path $PSScriptRoot 'examples\lsp_workspace_symbol'
$wsSymbolRootUri = 'file:///' + ($wsSymbolRoot -replace '\\', '/')
$wsSymbolPsi = New-Object System.Diagnostics.ProcessStartInfo
$wsSymbolPsi.FileName = $Lume
$wsSymbolPsi.Arguments = 'lsp'
$wsSymbolPsi.RedirectStandardInput = $true
$wsSymbolPsi.RedirectStandardOutput = $true
$wsSymbolPsi.RedirectStandardError = $true
$wsSymbolPsi.UseShellExecute = $false
$wsSymbolProc = [System.Diagnostics.Process]::Start($wsSymbolPsi)
try {
  $wsSymbolInitReq = @{ jsonrpc = '2.0'; id = 1; method = 'initialize'; params = @{ rootUri = $wsSymbolRootUri } } | ConvertTo-Json -Depth 10 -Compress
  Send-LspMessage $wsSymbolProc $wsSymbolInitReq
  $wsSymbolInitResp = Read-LspMessage $wsSymbolProc | ConvertFrom-Json
  Assert-Equal 'lsp initialize advertises workspaceSymbolProvider' 'True' "$($wsSymbolInitResp.result.capabilities.workspaceSymbolProvider)"
  Send-LspMessage $wsSymbolProc '{"jsonrpc":"2.0","method":"initialized","params":{}}'

  $wsSymbolAlphaUri = 'file:///' + ((Join-Path $wsSymbolRoot 'alpha.lume') -replace '\\', '/')
  $wsSymbolBetaUri = 'file:///' + ((Join-Path $wsSymbolRoot 'sub\beta.lume') -replace '\\', '/')

  $wsSymbolReq1 = @{ jsonrpc = '2.0'; id = 2; method = 'workspace/symbol'; params = @{ query = 'alpha' } } | ConvertTo-Json -Depth 10 -Compress
  Send-LspMessage $wsSymbolProc $wsSymbolReq1
  $wsSymbolResp1 = Read-LspMessage $wsSymbolProc | ConvertFrom-Json
  Assert-Equal 'workspace/symbol query matches both alpha.lume declarations' '2' "$($wsSymbolResp1.result.Count)"
  Assert-Equal 'workspace/symbol result names the function' 'workspace_symbol_alpha_fn' $wsSymbolResp1.result[0].name
  Assert-Equal 'workspace/symbol result kind for a function is Function (12)' '12' "$($wsSymbolResp1.result[0].kind)"
  Assert-Equal 'workspace/symbol result location points at the real file' $wsSymbolAlphaUri $wsSymbolResp1.result[0].location.uri

  $wsSymbolReq2 = @{ jsonrpc = '2.0'; id = 3; method = 'workspace/symbol'; params = @{ query = 'BETA' } } | ConvertTo-Json -Depth 10 -Compress
  Send-LspMessage $wsSymbolProc $wsSymbolReq2
  $wsSymbolResp2 = Read-LspMessage $wsSymbolProc | ConvertFrom-Json
  Assert-Equal 'workspace/symbol query is case-insensitive' '1' "$($wsSymbolResp2.result.Count)"
  Assert-Equal 'workspace/symbol finds a declaration in a subdirectory (recursive walkDir)' $wsSymbolBetaUri $wsSymbolResp2.result[0].location.uri
  Assert-Equal 'workspace/symbol kind for an enum is Enum (10)' '10' "$($wsSymbolResp2.result[0].kind)"

  $wsSymbolReqEmpty = @{ jsonrpc = '2.0'; id = 4; method = 'workspace/symbol'; params = @{ query = '' } } | ConvertTo-Json -Depth 10 -Compress
  Send-LspMessage $wsSymbolProc $wsSymbolReqEmpty
  $wsSymbolRespEmpty = Read-LspMessage $wsSymbolProc | ConvertFrom-Json
  Assert-Equal 'workspace/symbol empty query returns every declaration across the workspace' '3' "$($wsSymbolRespEmpty.result.Count)"

  $wsSymbolReqNoMatch = @{ jsonrpc = '2.0'; id = 5; method = 'workspace/symbol'; params = @{ query = 'zzznomatch' } } | ConvertTo-Json -Depth 10 -Compress
  Send-LspMessage $wsSymbolProc $wsSymbolReqNoMatch
  $wsSymbolRespNoMatch = Read-LspMessage $wsSymbolProc | ConvertFrom-Json
  Assert-Equal 'workspace/symbol returns an empty array when nothing matches' '0' "$($wsSymbolRespNoMatch.result.Count)"
} finally {
  if (-not $wsSymbolProc.HasExited) { $wsSymbolProc.Kill() }
}

Write-Host 'All Lume smoke tests passed.'
