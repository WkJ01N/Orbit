param(
  [Parameter(Mandatory = $true)][string]$FlutterSdk,
  [Parameter(Mandatory = $true)][string]$AndroidSdk,
  [string]$DeviceSerial = 'emulator-5554'
)

$ErrorActionPreference = 'Stop'
if ($DeviceSerial -notmatch '^emulator-\d+$') {
  throw 'This test seeds data and changes permissions; use an isolated emulator.'
}
$orbitWorkspace = Split-Path -Parent $PSScriptRoot
$orbitAdb = Join-Path $AndroidSdk 'platform-tools/adb.exe'
if ((& $orbitAdb -s $DeviceSerial shell getprop ro.kernel.qemu).Trim() -ne '1') {
  throw 'An Android emulator is required.'
}
& $orbitAdb -s $DeviceSerial shell am force-stop com.must.orbit.orbit
& $orbitAdb -s $DeviceSerial shell pm revoke com.must.orbit.orbit android.permission.POST_NOTIFICATIONS
$orbitDart = Join-Path $FlutterSdk 'bin/cache/dart-sdk/bin/dart.exe'
$orbitSnapshot = Join-Path $FlutterSdk 'bin/cache/flutter_tools.snapshot'
$orbitOutput = Join-Path $orbitWorkspace 'build/android-device-optimization-test.log'
$orbitErrors = Join-Path $orbitWorkspace 'build/android-device-optimization-stderr.log'
New-Item -ItemType Directory -Path (Join-Path $orbitWorkspace 'build') -Force | Out-Null
$orbitTest = Start-Process -FilePath $orbitDart -ArgumentList @(
  ('"' + $orbitSnapshot + '"'), 'test', '--no-pub',
  'integration_test/orbit_android_test.dart', '-d', $DeviceSerial,
  '--reporter', 'expanded'
) -WorkingDirectory $orbitWorkspace -WindowStyle Hidden -PassThru `
  -RedirectStandardOutput $orbitOutput -RedirectStandardError $orbitErrors
$orbitPrepared = $false
$orbitReturned = $false
$orbitDeadline = [DateTime]::UtcNow.AddMinutes(5)
while (!$orbitTest.HasExited -and [DateTime]::UtcNow -lt $orbitDeadline) {
  $orbitLog = Get-Content -LiteralPath $orbitOutput -Raw -ErrorAction SilentlyContinue
  if ($orbitLog -and !$orbitPrepared -and $orbitLog.Contains('ORBIT_DEVICE_INIT_READY')) {
    & $orbitAdb -s $DeviceSerial shell pm set-permission-flags com.must.orbit.orbit android.permission.POST_NOTIFICATIONS user-fixed user-set
    & $orbitAdb -s $DeviceSerial shell appops set com.must.orbit.orbit SCHEDULE_EXACT_ALARM allow
    $orbitPrepared = $true
  }
  if ($orbitLog -and !$orbitReturned -and $orbitLog.Contains('ORBIT_DEVICE_PERMISSION_READY')) {
    & $orbitAdb -s $DeviceSerial shell dumpsys activity activities |
      Select-String 'topResumedActivity|AppNotificationSettingsActivity' |
      Set-Content (Join-Path $orbitWorkspace 'build/android-device-permission-target.log')
    & $orbitAdb -s $DeviceSerial shell pm clear-permission-flags com.must.orbit.orbit android.permission.POST_NOTIFICATIONS user-fixed
    & $orbitAdb -s $DeviceSerial shell pm grant com.must.orbit.orbit android.permission.POST_NOTIFICATIONS
    & $orbitAdb -s $DeviceSerial shell input keyboard keyevent KEYCODE_BACK
    $orbitReturned = $true
  }
  Start-Sleep -Seconds 1
  $orbitTest.Refresh()
}
if (!$orbitTest.HasExited) {
  Stop-Process -Id $orbitTest.Id -Force
  throw 'Android integration test timed out.'
}
$orbitTest.WaitForExit()
Get-Content -LiteralPath $orbitOutput -Tail 12
if ($orbitTest.ExitCode -ne 0 -or !$orbitPrepared -or !$orbitReturned) {
  Get-Content -LiteralPath $orbitErrors -Tail 12
  throw 'Android integration test failed; inspect build/android-device-optimization-test.log.'
}
