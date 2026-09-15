$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$renderRoot = Join-Path $projectRoot '.work\visual_verify'
$env:APPDATA = Join-Path $projectRoot '.work\visual_appdata'
$enginePath = 'C:\Users\Admin\Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe'
New-Item -ItemType Directory -Force -Path $renderRoot | Out-Null
foreach ($folder in @('autoload','data','resources','scripts','scenes','tests')) {
    Copy-Item -LiteralPath (Join-Path $projectRoot $folder) -Destination $renderRoot -Recurse -Force
}
Copy-Item -LiteralPath (Join-Path $projectRoot 'project.godot') -Destination $renderRoot -Force
if (-not (Test-Path -LiteralPath (Join-Path $renderRoot 'assets'))) {
    New-Item -ItemType Junction -Path (Join-Path $renderRoot 'assets') -Target (Join-Path $projectRoot 'assets') | Out-Null
}
if (-not (Test-Path -LiteralPath (Join-Path $renderRoot '.godot'))) {
    New-Item -ItemType Junction -Path (Join-Path $renderRoot '.godot') -Target (Join-Path $projectRoot '.work\validation\.godot') | Out-Null
}
[IO.File]::WriteAllText((Join-Path $renderRoot 'override.cfg'), "[application]`nconfig/use_custom_user_dir=true`nconfig/custom_user_dir_name=`"lahoue_codex_visual_v2_capture`"`n")
$captureLog = Join-Path $projectRoot '.work\logs\recovery_capture.log'
$run = Start-Process -FilePath $enginePath -ArgumentList @('--path', $renderRoot, '--scene', 'res://tests/visual_completion_capture.tscn', '--audio-driver', 'Dummy', '--log-file', $captureLog) -WindowStyle Hidden -Wait -PassThru
Get-Content -LiteralPath $captureLog -Tail 12
if ((Get-Content -LiteralPath $captureLog -Raw) -match 'SHADER ERROR|SCRIPT ERROR|Parse Error|Compile Error|Shader compilation failed|visual_completion_capture: FAIL') { exit 1 }
exit $run.ExitCode
