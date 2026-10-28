#requires -Version 7.0
[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')][string]$Configuration = 'Debug',
    [switch]$Benchmark,
    [switch]$ProfileWrites
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$build = Join-Path $repo "build/windows-native-demo/$Configuration"
$reports = Join-Path $build 'self-test'
$package = Join-Path $build 'package'
New-Item -ItemType Directory -Force $build, $reports | Out-Null

cmake -S (Join-Path $repo 'platform/Windows/MXLoggerDemo') -B $build -A x64 '-DMXLOGGER_BUILD_PROFILE=ON' '-DMXLOGGER_BUILD_TESTS=ON' 2>&1 | Tee-Object (Join-Path $build 'configure.log')
if ($LASTEXITCODE -ne 0) { throw "Demo configure failed: $LASTEXITCODE" }
cmake --build $build --config $Configuration --parallel 2>&1 | Tee-Object (Join-Path $build 'build.log')
if ($LASTEXITCODE -ne 0) { throw "Demo build failed: $LASTEXITCODE" }
ctest --test-dir (Join-Path $build 'core') -C $Configuration -R MXLoggerProfileCollector '--no-tests=error' --output-on-failure 2>&1 | Tee-Object (Join-Path $build 'profile-collector-tests.log')
if ($LASTEXITCODE -ne 0) { throw "Profile collector tests failed: $LASTEXITCODE" }

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
        foreach ($log in @('model/report.txt', 'ui-report.txt', 'benchmark.txt')) {
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

if ($Benchmark) {
    # Both runs use the exact same executable and log() loop. The baseline
    # disables retention only; all locking and correctness checks remain on.
    $previous = [Environment]::GetEnvironmentVariable('MXLOGGER_WINDOWS_MAPPING_CACHE', 'Process')
    $results = @{}
    try {
        foreach ($mode in @('transient', 'cached')) {
            $env:MXLOGGER_WINDOWS_MAPPING_CACHE = if ($mode -eq 'transient') { '0' } else { '1' }
            $directory = Join-Path $build "benchmark/$mode"
            Write-Host ">> 100,000 writes, $mode, plaintext + AES"
            Invoke-DemoCheck '--benchmark' $directory 600000
            $result = Get-Content (Join-Path $directory 'benchmark.json') -Raw | ConvertFrom-Json
            if (-not $result.passed) { throw "Benchmark verification failed: $mode" }
            $results[$mode] = $result
        }
    } finally {
        [Environment]::SetEnvironmentVariable('MXLOGGER_WINDOWS_MAPPING_CACHE', $previous, 'Process')
    }
    $comparison = for ($i = 0; $i -lt 2; $i++) {
        $before = $results['transient'].cases[$i]
        $after = $results['cached'].cases[$i]
        [PSCustomObject]@{
            encrypted = $after.encrypted
            records = $after.records
            transient_seconds = $before.seconds
            cached_seconds = $after.seconds
            speedup = [Math]::Round($before.seconds / $after.seconds, 2)
        }
    }
    $comparison | ConvertTo-Json | Set-Content (Join-Path $build 'benchmark/comparison.json')
    $comparison | Format-Table | Out-String | Write-Host
}

if ($ProfileWrites) {
    & (Join-Path $PSScriptRoot 'profile_windows_demo.ps1') -ExecutableDirectory (Split-Path $exe) -ReportDirectory (Join-Path $build 'profile')
}

cmake --install $build --config $Configuration --prefix $package 2>&1 | Tee-Object (Join-Path $build 'install.log')
if ($LASTEXITCODE -ne 0) { throw "Demo packaging failed: $LASTEXITCODE" }
$archive = Join-Path $build "MXLoggerDemo-windows-x64-$Configuration.zip"
Compress-Archive -Path (Join-Path $package '*') -DestinationPath $archive -Force
Write-Host "PASS: $archive"
