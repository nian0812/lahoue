param([switch]$Capture)
$ErrorActionPreference = 'Continue'
$root = 'D:\Game\LaHoue'
$runRoot = "$root\.work\standalone"
$env:APPDATA = "$root\.work\standalone_appdata"
$engine = 'C:\Users\Admin\Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe'
New-Item -ItemType Directory -Force -Path $runRoot | Out-Null
foreach ($folder in @('autoload','data','resources','scripts','scenes','tests')) { Copy-Item -LiteralPath "$root\$folder" -Destination $runRoot -Recurse -Force }
Copy-Item -LiteralPath "$root\project.godot" -Destination $runRoot -Force
if (-not (Test-Path "$runRoot\assets")) { New-Item -ItemType Junction -Path "$runRoot\assets" -Target "$root\assets" | Out-Null }
if (-not (Test-Path "$runRoot\.godot")) { New-Item -ItemType Junction -Path "$runRoot\.godot" -Target "$root\.work\validation\.godot" | Out-Null }
$userDir = if ($Capture) { 'lahoue_codex_final_visual_capture' } else { 'lahoue_codex_settings_test' }
[IO.File]::WriteAllText("$runRoot\override.cfg", "[application]`nconfig/use_custom_user_dir=true`nconfig/custom_user_dir_name=`"$userDir`"`n", [Text.UTF8Encoding]::new($false))
if ($Capture) {
 & $engine --verbose --path $runRoot --scene res://tests/final_visual_capture.tscn --audio-driver Dummy --log-file "$root/.work/logs/final_visual_capture.log"
 exit $LASTEXITCODE
}
foreach ($stage in @('write','read-windowed','read-fullscreen')) {
 & $engine --path $runRoot --scene res://tests/resolution_settings_test.tscn --audio-driver Dummy --log-file "$root/.work/logs/settings_$stage.log" -- $stage
 if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
