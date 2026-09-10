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

$genericData = & $Lume run (Join-Path $PSScriptRoot 'examples\generic_data.lume')
if ($LASTEXITCODE -ne 0) { throw "generic data exited $LASTEXITCODE" }
Assert-Equal 'generic records and enums' "42`nready" ($genericData -join "`n")

$listFunctions = & $Lume run (Join-Path $PSScriptRoot 'examples\list_functions.lume')
if ($LASTEXITCODE -ne 0) { throw "list functions exited $LASTEXITCODE" }
Assert-Equal 'generic list functions' "6`n2`n2`n10`n4" ($listFunctions -join "`n")

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

$listCallback = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_list_callback.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "list callback validation should exit 1" }
Assert-Equal 'list callback validation' 'E0673 callback parameter type does not match list element type' ($listCallback -join "`n")

$closureReturn = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_closure_return.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "closure return validation should exit 1" }
Assert-Equal 'closure return validation' 'E0676 line 3: closure return type mismatch; expected int, got str' ($closureReturn -join "`n")

$closureCapture = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_closure_capture_mutable.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "mutable closure capture validation should exit 1" }
Assert-Equal 'immutable closure capture validation' 'E0678 line 4: closure cannot capture mutable binding `offset`' ($closureCapture -join "`n")

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

$nativeFailure = & $Lume test (Join-Path $PSScriptRoot 'examples\native_tests_failing.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "failing native test should exit 1" }
Assert-Equal 'native test failure' "FAIL shows expected and actual values (line 1): expected 42, got 41`n0 passed; 1 failed" ($nativeFailure -join "`n")

Write-Host 'All Lume smoke tests passed.'
