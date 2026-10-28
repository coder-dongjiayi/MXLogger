#requires -Version 7.0
[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')][string]$Configuration = 'Debug'
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$build = Join-Path $repo "build/windows-native-demo/$Configuration"
$reports = Join-Path $build 'self-test'
$package = Join-Path $build 'package'
New-Item -ItemType Directory -Force $build, $reports | Out-Null

cmake -S (Join-Path $repo 'Windows/MXLoggerDemo') -B $build -A x64 2>&1 | Tee-Object (Join-Path $build 'configure.log')
if ($LASTEXITCODE -ne 0) { throw "Demo configure failed: $LASTEXITCODE" }
cmake --build $build --config $Configuration --parallel 2>&1 | Tee-Object (Join-Path $build 'build.log')
if ($LASTEXITCODE -ne 0) { throw "Demo build failed: $LASTEXITCODE" }

# A GUI subsystem executable needs an explicit process wait to propagate failures.
$exe = Join-Path $build "bin/$Configuration/MXLoggerDemo.exe"
$start = [System.Diagnostics.ProcessStartInfo]::new($exe)
$start.UseShellExecute = $false
$start.ArgumentList.Add('--self-test')
$start.ArgumentList.Add('--report-dir')
$start.ArgumentList.Add($reports)
$process = [System.Diagnostics.Process]::Start($start)
try {
    if (-not $process.WaitForExit(180000)) {
        $process.Kill($true)
        throw 'Demo self-test timed out after 180 seconds'
    }
    if ($process.ExitCode -ne 0) { throw "Demo self-test failed: $($process.ExitCode); see $reports" }
} finally {
    $process.Dispose()
    if (Test-Path (Join-Path $reports 'model/report.txt')) { Get-Content (Join-Path $reports 'model/report.txt') }
    if (Test-Path (Join-Path $reports 'ui-report.txt')) { Get-Content (Join-Path $reports 'ui-report.txt') }
}
if (-not (Get-Content (Join-Path $reports 'model/report.json') -Raw | ConvertFrom-Json).passed) {
    throw 'Demo model report did not pass'
}
if (-not (Select-String -Path (Join-Path $reports 'ui-report.txt') -Pattern '^PASS ' -Quiet)) {
    throw 'Demo UI report is missing its PASS result'
}
foreach ($image in @('actions-en.png', 'actions-zh.png', 'configuration-zh.png')) {
    if (-not (Test-Path (Join-Path $reports $image))) { throw "Missing UI screenshot: $image" }
}

cmake --install $build --config $Configuration --prefix $package 2>&1 | Tee-Object (Join-Path $build 'install.log')
if ($LASTEXITCODE -ne 0) { throw "Demo packaging failed: $LASTEXITCODE" }
$archive = Join-Path $build "MXLoggerDemo-windows-x64-$Configuration.zip"
Compress-Archive -Path (Join-Path $package '*') -DestinationPath $archive -Force
Write-Host "PASS: $archive"
