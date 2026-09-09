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

$processArgs = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_process_args.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "process argument validation should exit 1" }
Assert-Equal 'process argument validation' 'E0619 process.run requires (str, [str])' ($processArgs -join "`n")

$unwrap = & $Lume check (Join-Path $PSScriptRoot 'examples\invalid_unwrap.lume') 2>&1
if ($LASTEXITCODE -ne 1) { throw "unwrap validation should exit 1" }
Assert-Equal 'unwrap context validation' 'E0624 line 2: `!` requires an enclosing result-returning function' ($unwrap -join "`n")

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

Write-Host 'All Lume smoke tests passed.'
