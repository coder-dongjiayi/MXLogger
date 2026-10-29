#requires -Version 7.0
[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')][string]$Configuration = 'Debug'
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$build = Join-Path $repo "build/windows-native-demo/$Configuration"
$reports = Join-Path $build 'self-test'
New-Item -ItemType Directory -Force $build, $reports | Out-Null

cmake -S (Join-Path $repo 'platform/Windows/MXLoggerDemo') -B $build -A x64 '-DMXLOGGER_BUILD_TESTS=OFF' 2>&1 | Tee-Object (Join-Path $build 'configure.log')
if ($LASTEXITCODE -ne 0) { throw "Demo configure failed: $LASTEXITCODE" }
cmake --build $build --config $Configuration --parallel 2>&1 | Tee-Object (Join-Path $build 'build.log')
if ($LASTEXITCODE -ne 0) { throw "Demo build failed: $LASTEXITCODE" }
$exe = Join-Path $build "bin/$Configuration/MXLoggerDemo.exe"
function Invoke-DemoCheck([string]$Mode, [string]$ReportDirectory, [int]$Timeout) {
    New-Item -ItemType Directory -Force $ReportDirectory | Out-Null
    # A GUI subsystem executable needs an explicit wait to propagate failures.
    $start = [System.Diagnostics.ProcessStartInfo]::new($exe)
    $start.UseShellExecute = $false
    $start.ArgumentList.Add($Mode)
    $start.ArgumentList.Add('--report-dir')
    $start.ArgumentList.Add($ReportDirectory)
    $process = [System.Diagnostics.Process]::Start($start)
    try {
        if (-not $process.WaitForExit($Timeout)) {
            $process.Kill($true)
            throw "Demo $Mode timed out"
        }
        if ($process.ExitCode -ne 0) { throw "Demo $Mode failed: $($process.ExitCode); see $ReportDirectory" }
    } finally {
        $process.Dispose()
        foreach ($log in @('model/report.txt', 'ui-report.txt')) {
            $path = Join-Path $ReportDirectory $log
            if (Test-Path $path) { Get-Content $path }
        }
    }
}
Invoke-DemoCheck '--self-test' $reports 180000
if (-not (Get-Content (Join-Path $reports 'model/report.json') -Raw | ConvertFrom-Json).passed) {
    throw 'Demo model report did not pass'
}
if (-not (Select-String -Path (Join-Path $reports 'ui-report.txt') -Pattern '^PASS ' -Quiet)) {
    throw 'Demo UI report is missing its PASS result'
}
foreach ($image in @('actions-en.png', 'actions-zh.png', 'configuration-zh.png')) {
    if (-not (Test-Path (Join-Path $reports $image))) { throw "Missing UI screenshot: $image" }
}

Write-Host "PASS: $exe"
