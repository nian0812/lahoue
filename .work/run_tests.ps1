param([string]$Filter = '*_test', [switch]$Import)
$ErrorActionPreference = 'Continue'
$root = 'D:\Game\LaHoue'
$validationRoot = "$root\.work\validation"
$env:APPDATA = "$root\.work\test_appdata"
$engine = 'C:\Users\Admin\Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe'
New-Item -ItemType Directory -Force -Path $validationRoot,"$root\.work\logs" | Out-Null
foreach ($folder in @('autoload','data','resources','scripts','scenes','tests')) { Copy-Item -LiteralPath "$root\$folder" -Destination $validationRoot -Recurse -Force }
Copy-Item -LiteralPath "$root\project.godot" -Destination $validationRoot -Force
if (-not (Test-Path "$validationRoot\assets")) { New-Item -ItemType Junction -Path "$validationRoot\assets" -Target "$root\assets" | Out-Null }
if ($Import) { & $engine --headless --path $validationRoot --editor --import --log-file "$root/.work/logs/import.log" *> $null }
$testScenes = Get-ChildItem -LiteralPath "$root\tests" -Filter "$Filter.tscn" | Where-Object { $_.BaseName -ne 'resolution_settings_test' } | Sort-Object Name
$passed = 0
$summary = @()
foreach ($testScene in $testScenes) {
    $sourceText = [IO.File]::ReadAllText([IO.Path]::ChangeExtension($testScene.FullName, '.gd'))
    $isolatedName = [regex]::Match($sourceText, 'lahoue_codex_[a-z0-9_]+').Value
    if (-not $isolatedName) { throw "Missing isolation guard: $($testScene.Name)" }
    [IO.File]::WriteAllText("$validationRoot\override.cfg", "[application]`nconfig/use_custom_user_dir=true`nconfig/custom_user_dir_name=`"$isolatedName`"`n", [Text.UTF8Encoding]::new($false))
    $logPath = "$root/.work/logs/" + $testScene.BaseName + '.log'
    & $engine --headless --path $validationRoot --scene ('res://tests/' + $testScene.Name) --log-file $logPath *> $null
    $code = $LASTEXITCODE
    $logText = [IO.File]::ReadAllText($logPath)
    $ok = $code -eq 0 -and $logText -notmatch 'SCRIPT ERROR|Parse Error|Compile Error|SHADER ERROR|Shader compilation failed|: FAIL\b'
    if ($ok) { $passed++ }
    $line = $testScene.BaseName + ': ' + $(if ($ok) { 'PASS' } else { 'FAIL' })
    $summary += $line
    Write-Output $line
}
$summary += "FULL_SUITE: $passed/$($testScenes.Count) PASS"
$summary | Set-Content -LiteralPath "$root\reports\final_regression.txt" -Encoding utf8
Write-Output $summary[-1]
if ($passed -ne $testScenes.Count) { exit 1 }
