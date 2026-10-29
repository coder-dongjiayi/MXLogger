#requires -Version 7.0
[CmdletBinding()]
param(
    [string]$ExecutableDirectory = $PSScriptRoot,
    [string]$ReportDirectory = (Join-Path $PWD 'mxlogger-profile'),
    [ValidateRange(1, 31)][int]$Rounds = 7,
    [ValidateRange(1, 65536)][int]$SampleStride = 64,
    [ValidateSet('Coalesced', 'PerRecord')][string]$FileTimeMode = 'Coalesced'
)

$ErrorActionPreference = 'Stop'
$normalExe = Join-Path $ExecutableDirectory 'MXLoggerDemo.exe'
$diagnosticExe = Join-Path $ExecutableDirectory 'MXLoggerProfile.exe'
foreach ($executable in @($normalExe, $diagnosticExe)) {
    if (-not (Test-Path $executable -PathType Leaf)) { throw "Missing executable: $executable" }
}
$runDirectory = Join-Path ([IO.Path]::GetFullPath($ReportDirectory)) ('run-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
New-Item -ItemType Directory -Path $runDirectory | Out-Null
Write-Host "MXLogger performance diagnostics. Reports: $runDirectory"
Write-Host "Discarding warmups, then running $Rounds baseline/diagnostic pairs (plaintext + AES)."

function Invoke-Measurement([string]$Executable, [string[]]$Arguments, [string]$LogPath) {
    $start = [Diagnostics.ProcessStartInfo]::new([IO.Path]::GetFullPath($Executable))
    $start.UseShellExecute = $false
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in $Arguments) { $start.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    try {
        [void]$process.Start()
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(600000)) {
            $process.Kill($true)
            $process.WaitForExit()
            throw "Measurement timed out: $LogPath"
        }
        ($stdout.GetAwaiter().GetResult() + $stderr.GetAwaiter().GetResult()) | Set-Content -LiteralPath $LogPath
        if ($process.ExitCode -ne 0) { throw "Measurement failed ($($process.ExitCode)): $LogPath" }
    } finally { $process.Dispose() }
}
function Read-Report([string]$Directory, [string]$Name) {
    $result = Get-Content -LiteralPath (Join-Path $Directory $Name) -Raw | ConvertFrom-Json
    if (-not $result.passed -or @($result.cases).Count -ne 2) { throw "Invalid measurement report: $Directory/$Name" }
    return $result
}
function Get-Statistics([double[]]$Values) {
    $ordered = @($Values | Sort-Object)
    if (-not $ordered.Count) { throw 'No samples to summarize' }
    $middle = [int][Math]::Floor($ordered.Count / 2)
    $median = if ($ordered.Count % 2) { $ordered[$middle] } else { ($ordered[$middle - 1] + $ordered[$middle]) / 2 }
    return [ordered]@{ minimum = $ordered[0]; median = $median; maximum = $ordered[-1] }
}

$previousCache = [Environment]::GetEnvironmentVariable('MXLOGGER_WINDOWS_MAPPING_CACHE', 'Process')
$previousTime = [Environment]::GetEnvironmentVariable('MXLOGGER_WINDOWS_FILE_TIME_COALESCING', 'Process')
$measurements = @()
try {
    $env:MXLOGGER_WINDOWS_MAPPING_CACHE = '1'
    $env:MXLOGGER_WINDOWS_FILE_TIME_COALESCING = if ($FileTimeMode -eq 'Coalesced') { '1' } else { '0' }
    Write-Host "File modification time policy: $FileTimeMode"
    # Discard one warmup for each executable. Initialization, flush, validation,
    # child startup and report I/O are outside each executable's write timer.
    foreach ($kind in @('baseline', 'diagnostic')) {
        Write-Host "Warmup: $kind"
        $directory = Join-Path $runDirectory "warmup-$kind"
        New-Item -ItemType Directory -Path $directory | Out-Null
        $executable = if ($kind -eq 'baseline') { $normalExe } else { $diagnosticExe }
        $arguments = if ($kind -eq 'baseline') {
            @('--benchmark', '--report-dir', $directory)
        } else { @('--report-dir', $directory, '--sample-stride', "$SampleStride") }
        Invoke-Measurement $executable $arguments (Join-Path $directory 'process.log')
        $name = if ($kind -eq 'baseline') { 'benchmark.json' } else { 'profile.json' }
        [void](Read-Report $directory $name)
    }
    for ($round = 0; $round -lt $Rounds; ++$round) {
        # Alternate process order to reduce systematic temperature/load drift.
        $order = if ($round % 2) { @('diagnostic', 'baseline') } else { @('baseline', 'diagnostic') }
        $pair = [ordered]@{ round = $round + 1 }
        foreach ($kind in $order) {
            Write-Host "Round $($round + 1)/${Rounds}: $kind (writing and verifying 100,000 plaintext + AES records)"
            $directory = Join-Path $runDirectory "round-$($round + 1)-$kind"
            New-Item -ItemType Directory -Path $directory | Out-Null
            if ($kind -eq 'baseline') {
                Invoke-Measurement $normalExe @('--benchmark', '--report-dir', $directory) (Join-Path $directory 'process.log')
                $pair[$kind] = Read-Report $directory 'benchmark.json'
            } else {
                $offset = $round % $SampleStride
                Invoke-Measurement $diagnosticExe @('--report-dir', $directory, '--sample-stride', "$SampleStride", '--sample-offset', "$offset") (Join-Path $directory 'process.log')
                $pair[$kind] = Read-Report $directory 'profile.json'
                if ($pair[$kind].backend -ne 'windows') { throw 'Windows backend required for performance comparisons' }
            }
        }
        foreach ($kind in @('baseline', 'diagnostic')) {
            if ($pair[$kind].file_time_coalescing -ne ($FileTimeMode -eq 'Coalesced')) {
                throw "File time policy mismatch: $kind. Use matching, up-to-date executable files."
            }
        }
        $measurements += [PSCustomObject]$pair
    }
    $apiDirectory = Join-Path $runDirectory 'api'
    New-Item -ItemType Directory -Path $apiDirectory | Out-Null
    Invoke-Measurement $diagnosticExe @('--microbench', '--report-dir', $apiDirectory) (Join-Path $apiDirectory 'process.log')
    $api = Read-Report $apiDirectory 'microbench.json'
} finally {
    [Environment]::SetEnvironmentVariable('MXLOGGER_WINDOWS_MAPPING_CACHE', $previousCache, 'Process')
    [Environment]::SetEnvironmentVariable('MXLOGGER_WINDOWS_FILE_TIME_COALESCING', $previousTime, 'Process')
}

$cases = foreach ($encrypted in @($false, $true)) {
    $normalCases = @($measurements | ForEach-Object { $_.baseline.cases | Where-Object { $_.encrypted -eq $encrypted } })
    $diagnosticCases = @($measurements | ForEach-Object { $_.diagnostic.cases | Where-Object { $_.encrypted -eq $encrypted } })
    if ($normalCases.Count -ne $Rounds -or $diagnosticCases.Count -ne $Rounds) { throw 'Missing plaintext/AES cases' }
    foreach ($item in @($normalCases) + @($diagnosticCases)) {
        if (-not $item.passed -or $item.records -ne 100000) { throw 'Invalid measured record count or validation result' }
    }
    $baseline = Get-Statistics @($normalCases | ForEach-Object { $_.seconds })
    $diagnostic = Get-Statistics @($diagnosticCases | ForEach-Object { $_.seconds })
    $difference = 100 * ($diagnostic.median / $baseline.median - 1)
    $stages = foreach ($name in $diagnosticCases[0].stages.name) {
        $rows = @($diagnosticCases | ForEach-Object { $_.stages | Where-Object { $_.name -eq $name } })
        $known = @($rows | Where-Object { $null -ne $_.estimated_exclusive_ms })
        [PSCustomObject]@{
            name = $name
            median_estimated_ms = if ($known.Count -eq $Rounds) { (Get-Statistics @($known.estimated_exclusive_ms)).median } else { $null }
            median_estimated_share_percent = if ($known.Count -eq $Rounds) { (Get-Statistics @($known.estimated_share_percent)).median } else { $null }
            calls = Get-Statistics @($rows.calls)
        }
    }
    [PSCustomObject]@{
        encrypted = $encrypted
        records = 100000
        baseline_seconds = $baseline
        diagnostic_seconds = $diagnostic
        diagnostic_relative_difference_percent = $difference
        diagnostic_overhead_warning = ($difference -gt 5)
        stages = @($stages | Sort-Object median_estimated_ms -Descending)
    }
}
$summary = [ordered]@{
    schema_version = 1
    passed = $true
    machine = [Environment]::MachineName
    os = [Runtime.InteropServices.RuntimeInformation]::OSDescription
    processor = $env:PROCESSOR_IDENTIFIER
    logical_processors = [Environment]::ProcessorCount
    baseline_sha256 = (Get-FileHash -LiteralPath $normalExe -Algorithm SHA256).Hash
    diagnostic_sha256 = (Get-FileHash -LiteralPath $diagnosticExe -Algorithm SHA256).Hash
    rounds = $Rounds
    sample_stride = $SampleStride
    configuration = $measurements[0].diagnostic.configuration
    mapping_cache = $true
    file_time_mode = $FileTimeMode
    report_directory = $runDirectory
    scope = '100,000 synchronous log() calls per case; console off; no UI/progress; flush/readback excluded; one discarded warmup per executable'
    notes = @(
        'Only baseline_seconds measure the normal executable without profiling hooks.'
        'Diagnostic stages are exclusive sampling estimates of foreground wall time, including waits; background CPU is not added.'
        'Stage medians need not sum to the median wall time. Missing samples are null, not measured zero.'
        'If diagnostic relative difference exceeds 5%, retry with -SampleStride 256. Diagnostic and baseline executables also differ in code layout.'
        'Isolated API microbenchmarks validate candidates; their times cannot be directly subtracted from real log() timings.'
        'Use the same local Windows machine/disk for comparisons; hosted CI timings are not a fixed performance threshold.'
    )
    cases = @($cases)
    api_microbench = $api
}
$summary | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath (Join-Path $runDirectory 'summary.json')
$lines = [Collections.Generic.List[string]]::new()
$lines.Add("MXLogger Windows write profile: $runDirectory")
$lines.Add("Rounds: $Rounds; sample stride: $SampleStride; file time mode: $FileTimeMode; normal and diagnostic executables alternated")
foreach ($case in $cases) {
    $label = if ($case.encrypted) { 'AES-CFB-128' } else { 'Plaintext' }
    $lines.Add("$label baseline seconds: median=$($case.baseline_seconds.median), min=$($case.baseline_seconds.minimum), max=$($case.baseline_seconds.maximum)")
    $lines.Add("Diagnostic median=$($case.diagnostic_seconds.median); relative difference=$([Math]::Round($case.diagnostic_relative_difference_percent, 2))%")
    if ($case.diagnostic_overhead_warning) { $lines.Add('WARNING: measurement perturbation >5%; retry with -SampleStride 256 before interpreting small stages.') }
    foreach ($stage in $case.stages) {
        $milliseconds = if ($null -eq $stage.median_estimated_ms) { 'n/a' } else { [Math]::Round($stage.median_estimated_ms, 3) }
        $share = if ($null -eq $stage.median_estimated_share_percent) { 'n/a' } else { [Math]::Round($stage.median_estimated_share_percent, 2) }
        $lines.Add("  $($stage.name): median estimated ms=$milliseconds, share %=$share, calls=$($stage.calls.median)")
    }
}
foreach ($item in $api.cases) { $lines.Add("API $($item.name): $($item.mean_us) us/call (or lock/unlock pair)") }
$lines.Add('PASS: every measured run verified count, order and plaintext/AES decoding after timing.')
$lines | Set-Content -LiteralPath (Join-Path $runDirectory 'summary.txt')
$lines | Write-Output
