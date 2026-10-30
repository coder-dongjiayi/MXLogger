#requires -Version 7.0
[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')][string]$Configuration = 'Debug',
    [string]$PackagePath,
    [string]$DemoOutputDirectory,
    [switch]$SkipExample
)
$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'Run the real Windows DLL tests on Windows.' }
if ($DemoOutputDirectory -and ($Configuration -ne 'Release' -or $SkipExample)) {
    throw 'DemoOutputDirectory requires Release with example verification enabled.'
}
if ($DemoOutputDirectory) { $DemoOutputDirectory = [IO.Path]::GetFullPath($DemoOutputDirectory) }
$repo = Split-Path $PSScriptRoot -Parent
$plugin = Join-Path $repo 'platform/flutter_mxlogger'
$build = Join-Path $repo "build/flutter-windows-tests/$Configuration"
New-Item -ItemType Directory -Force $build | Out-Null
$previousLibrary = $env:MXLOGGER_FFI_LIBRARY_PATH
$previousLocal = $env:MXLOGGER_LOCAL_NATIVE
$previousRoot = $env:MXLOGGER_LOCAL_NATIVE_ROOT
$previousReport = $env:MXLOGGER_SMOKE_REPORT
$previousBinary = $env:MXLOGGER_WINDOWS_BINARY_DIR
$consumer = $null
try {
    python (Join-Path $repo 'scripts/sync_flutter_native.py') --check
    if ($LASTEXITCODE -ne 0) { throw 'Shared ABI headers are stale' }
    if (-not $PackagePath) {
        # Stage 2: this is a private test fixture, not a published deliverable.
        & (Join-Path $PSScriptRoot 'build_windows_nuget.ps1') -PackageOnly
        $PackagePath = Join-Path $repo 'build/windows-sdk/packages/MXLogger.Native.2.3.0.nupkg'
    }
    $PackagePath = (Resolve-Path -LiteralPath $PackagePath).Path
    $restore = Join-Path $build 'restored'
    if (Test-Path $restore) { Remove-Item -LiteralPath $restore -Recurse -Force }
    nuget.exe install MXLogger.Native -Version 2.3.0 -Source (Split-Path $PackagePath -Parent) `
        -OutputDirectory $restore -NoCache -DirectDownload -NonInteractive -PackageSaveMode nupkg `
        2>&1 | Tee-Object (Join-Path $build 'nuget-restore.log')
    if ($LASTEXITCODE -ne 0) { throw 'Local test NuGet restore failed' }
    $restoredPackage = Join-Path $restore 'MXLogger.Native.2.3.0/MXLogger.Native.2.3.0.nupkg'
    if ((Get-FileHash $PackagePath).Hash -ne (Get-FileHash $restoredPackage).Hash) { throw 'NuGet restored a different package' }
    python (Join-Path $repo 'scripts/prepare_flutter_windows.py') --package $restoredPackage
    if ($LASTEXITCODE -ne 0) { throw 'Cannot prepare Flutter binaries from restored package' }
    $binary = Join-Path $plugin 'windows/bin/x64'
    $manifest = Get-Content (Join-Path $binary 'manifest.json') -Raw | ConvertFrom-Json
    $provenance = $manifest.local_core
    $expectedHash = (Get-FileHash (Join-Path $repo 'Core/mxlogger.cpp') -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($provenance.checkout -ne $repo -or $provenance.mxlogger_cpp_sha256 -ne $expectedHash) {
        throw 'The test DLL did not come from this checkout Core'
    }
    $manifest | ConvertTo-Json -Depth 20 | Set-Content (Join-Path $build 'local-core.json')
    $dll = Join-Path $binary "$Configuration/mxlogger_ffi.dll"
    if (-not (Test-Path $dll)) { throw "Missing DLL: $dll" }
    $cache = Get-Content (Join-Path $repo 'build/windows-sdk/ffi/CMakeCache.txt') -Raw
    if ($cache -notmatch '(?m)^CMAKE_LINKER:[^=]+=(.+)$') { throw 'MSVC linker not found' }
    $dumpbin = Join-Path (Split-Path ($Matches[1].Trim()) -Parent) 'dumpbin.exe'
    $exports = & $dumpbin /exports $dll | Out-String
    if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect DLL exports' }
    $exports | Set-Content (Join-Path $build 'exports.log')
    $header = Get-Content (Join-Path $repo 'Core/ffi/mxlogger_ffi.h') -Raw
    foreach ($match in [regex]::Matches($header, '\bflutter_mxlogger_\w+(?=\s*\()')) {
        if ($exports -notmatch "\b$($match.Value)\b") { throw "Missing C export: $($match.Value)" }
    }
    $env:MXLOGGER_FFI_LIBRARY_PATH = $dll
    Push-Location $plugin
    try {
        flutter pub get 2>&1 | Tee-Object (Join-Path $build 'pub.log')
        if ($LASTEXITCODE -ne 0) { throw 'pub get failed' }
        flutter test --no-pub --reporter expanded 2>&1 | Tee-Object (Join-Path $build 'dart-tests.log')
        if ($LASTEXITCODE -ne 0) { throw 'Real Windows Dart FFI tests failed' }
    } finally { Pop-Location }

    if (-not $SkipExample) {
        # Copy the package alone. There is deliberately no sibling checkout Core,
        # and no native-source/binary override, so pub distribution is exercised.
        $consumer = Join-Path ([IO.Path]::GetTempPath()) ('mxlogger-flutter-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Force $consumer | Out-Null
        # Copy current sources (also works before committing this change).
        robocopy $plugin (Join-Path $consumer 'plugin') /E /XD build .dart_tool .gradle .cxx Pods .symlinks ephemeral .build .swiftpm FlutterFramework /XF '*.dylib' local.properties /NFL /NDL /NJH /NJS /NP | Out-Null
        if ($LASTEXITCODE -ge 8) { throw 'Consumer copy failed' }
        $env:MXLOGGER_FFI_LIBRARY_PATH = $null
        $env:MXLOGGER_LOCAL_NATIVE = $null
        $env:MXLOGGER_LOCAL_NATIVE_ROOT = $null
        $env:MXLOGGER_WINDOWS_BINARY_DIR = $null
        $example = Join-Path $consumer 'plugin/example'
        $mode = $Configuration.ToLowerInvariant()
        Push-Location $example
        try {
            flutter pub get 2>&1 | Tee-Object (Join-Path $build 'consumer-pub.log')
            if ($LASTEXITCODE -ne 0) { throw 'Consumer pub get failed' }
            flutter build windows "--$mode" --no-pub 2>&1 | Tee-Object (Join-Path $build 'demo-build.log')
            if ($LASTEXITCODE -ne 0) { throw 'Windows Flutter Demo build failed' }
            if ($DemoOutputDirectory) {
                # Preserve the real lib/main.dart app BEFORE the smoke entrypoint
                # overwrites the build directory. Never distribute the smoke runner.
                $demoBundle = Join-Path $consumer 'MXLogger Flutter Release Demo'
                Copy-Item (Join-Path $example 'build/windows/x64/runner/Release') $demoBundle -Recurse
                Rename-Item (Join-Path $demoBundle 'example.exe') 'MXLoggerFlutterDemo.exe'
                foreach ($required in @('MXLoggerFlutterDemo.exe', 'flutter_windows.dll', 'mxlogger_ffi.dll',
                                        'data/icudtl.dat', 'data/app.so', 'data/flutter_assets')) {
                    if (-not (Test-Path (Join-Path $demoBundle $required))) { throw "Incomplete Demo bundle: $required" }
                }
                if ((Get-FileHash (Join-Path $demoBundle 'mxlogger_ffi.dll')).Hash -ne (Get-FileHash $dll).Hash) {
                    throw 'Release Demo bundled a different DLL'
                }
                # App-local VC runtime: a user's machine need not have VS installed.
                $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
                $vs = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
                if ($LASTEXITCODE -ne 0 -or -not $vs) { throw 'Visual Studio C++ installation not found' }
                $redist = Get-ChildItem (Join-Path $vs 'VC/Redist/MSVC/*/x64/Microsoft.VC*.CRT') -Directory |
                    Sort-Object { [version]$_.Parent.Parent.Name } -Descending | Select-Object -First 1
                if (-not $redist) { throw 'Visual C++ redistributable DLL directory not found' }
                Copy-Item (Join-Path $redist.FullName '*.dll') $demoBundle -Force
                foreach ($runtime in @('msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll')) {
                    if (-not (Test-Path (Join-Path $demoBundle $runtime))) { throw "Missing runtime: $runtime" }
                }
                Copy-Item (Join-Path $repo 'LICENSE.TXT') $demoBundle
                @'
MXLogger Flutter Demo - Windows x64 Release

Extract the complete download to a folder, then run MXLoggerFlutterDemo.exe.
Keep all DLLs and the data directory beside the executable.
This is the interactive demo, built from example/lib/main.dart.
'@ | Set-Content (Join-Path $demoBundle 'README.txt') -Encoding utf8
            }
            flutter build windows "--$mode" --no-pub -t integration_test/windows_release_smoke.dart `
                2>&1 | Tee-Object (Join-Path $build 'consumer-build.log')
            if ($LASTEXITCODE -ne 0) { throw 'Windows Flutter consumer build failed' }
        } finally { Pop-Location }
        $bundle = Join-Path $example "build/windows/x64/runner/$Configuration"
        if (-not (Test-Path (Join-Path $bundle 'mxlogger_ffi.dll'))) { throw 'FFI DLL missing from app bundle' }
        if ((Get-FileHash (Join-Path $bundle 'mxlogger_ffi.dll')).Hash -ne (Get-FileHash $dll).Hash) {
            throw 'Flutter bundled a different DLL configuration'
        }
        # The consuming app must only import binaries, never build an embedded Core.
        if (Get-ChildItem (Join-Path $example 'build/windows') -Recurse -Filter 'MXLoggerCore.vcxproj') {
            throw 'Flutter unexpectedly compiled Core sources'
        }
        $relocated = Join-Path $consumer 'Relocated app with spaces'
        Copy-Item $bundle $relocated -Recurse
        $env:MXLOGGER_SMOKE_REPORT = Join-Path $build 'consumer-report.json'
        $start = [Diagnostics.ProcessStartInfo]::new((Join-Path $relocated 'example.exe'))
        $start.UseShellExecute = $false
        $start.WorkingDirectory = $relocated
        $process = [Diagnostics.Process]::Start($start)
        try {
            if (-not $process.WaitForExit(180000)) { $process.Kill($true); throw 'Relocated Flutter runner timed out' }
            if ($process.ExitCode -ne 0) { throw 'Relocated Flutter runner failed; see consumer-report.json' }
        } finally { $process.Dispose() }
        $report = Get-Content $env:MXLOGGER_SMOKE_REPORT -Raw | ConvertFrom-Json
        if (-not $report.passed -or $report.coreVersion -ne '2.3.0' -or $report.records -ne 102) { throw 'Bad consumer report' }
        if (($Configuration -eq 'Release') -ne $report.release) { throw 'Wrong Flutter build mode' }
        if ($DemoOutputDirectory) {
            # Launch the preserved interactive app separately. A visible window
            # is shown by the native runner only after Flutter renders a frame.
            $start = [Diagnostics.ProcessStartInfo]::new((Join-Path $demoBundle 'MXLoggerFlutterDemo.exe'))
            $start.UseShellExecute = $false
            $start.WorkingDirectory = $demoBundle
            $process = [Diagnostics.Process]::Start($start)
            try {
                $timer = [Diagnostics.Stopwatch]::StartNew()
                while ($true) {
                    $process.Refresh()
                    if ($process.HasExited) { throw "Interactive Demo exited early: $($process.ExitCode)" }
                    if ($process.MainWindowHandle -ne [IntPtr]::Zero -and $process.MainWindowTitle -eq 'MXLogger Flutter Demo') { break }
                    if ($timer.Elapsed.TotalSeconds -ge 60) { throw 'Interactive Demo did not show its first frame' }
                    Start-Sleep -Milliseconds 250
                }
                [ordered]@{ passed = $true; configuration = 'Release'; title = $process.MainWindowTitle } |
                    ConvertTo-Json | Set-Content (Join-Path $build 'demo-window.json')
            } finally {
                if (-not $process.HasExited) { $process.Kill($true); $process.WaitForExit() }
                $process.Dispose()
            }
            if (Test-Path $DemoOutputDirectory) { Remove-Item -LiteralPath $DemoOutputDirectory -Recurse -Force }
            New-Item -ItemType Directory -Force (Split-Path $DemoOutputDirectory -Parent) | Out-Null
            Copy-Item $demoBundle $DemoOutputDirectory -Recurse
            Write-Host "PASS: interactive Release Demo: $DemoOutputDirectory"
        }
    }
    Write-Host "PASS: Windows Flutter FFI $Configuration"
} finally {
    $env:MXLOGGER_FFI_LIBRARY_PATH = $previousLibrary
    $env:MXLOGGER_LOCAL_NATIVE = $previousLocal
    $env:MXLOGGER_LOCAL_NATIVE_ROOT = $previousRoot
    $env:MXLOGGER_SMOKE_REPORT = $previousReport
    $env:MXLOGGER_WINDOWS_BINARY_DIR = $previousBinary
    if ($consumer -and (Test-Path $consumer)) { Remove-Item $consumer -Recurse -Force }
}
