#requires -Version 7.0
[CmdletBinding()]
param(
    [string]$Toolset = 'v143',
    # Used only for stage-2 test fixtures, after the global Core test gate.
    # Stage-3 distribution always uses the full validation path.
    [switch]$PackageOnly
)

$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'Build this MSVC native package on Windows.' }
$repo = Split-Path $PSScriptRoot -Parent
$build = Join-Path $repo 'build/windows-sdk'
$logs = Join-Path $build 'logs'
$stage = Join-Path $build 'nuget-stage'
$packages = Join-Path $build 'packages'
if (Test-Path $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
New-Item -ItemType Directory -Force $logs, $stage, $packages | Out-Null
$versionText = Get-Content (Join-Path $repo 'Core/mxlogger_version.hpp') -Raw
if ($versionText -notmatch '#define MXLOGGER_CORE_VERSION "(\d+\.\d+\.\d+)"') { throw 'Core version is missing' }
$version = $Matches[1]
$nuget = (Get-Command nuget.exe -ErrorAction Stop).Source
$buildTests = if ($PackageOnly) { 'OFF' } else { 'ON' }

foreach ($crt in @('MD', 'MT')) {
    $nativeBuild = Join-Path $build "core-$crt"
    $prefix = Join-Path $build "install-$crt"
    $runtime = if ($crt -eq 'MD') { 'MultiThreaded$<$<CONFIG:Debug>:Debug>DLL' } else { 'MultiThreaded$<$<CONFIG:Debug>:Debug>' }
    cmake -S (Join-Path $repo 'Core') -B $nativeBuild -A x64 -T $Toolset `
        '-DCMAKE_POLICY_DEFAULT_CMP0091=NEW' "-DCMAKE_MSVC_RUNTIME_LIBRARY=$runtime" `
        '-DMXLOGGER_INSTALL=ON' "-DMXLOGGER_BUILD_TESTS=$buildTests" '-DCMAKE_INSTALL_LIBDIR=lib' `
        2>&1 | Tee-Object (Join-Path $logs "configure-$crt.log")
    if ($LASTEXITCODE -ne 0) { throw "Core configure failed: $crt" }
    foreach ($configuration in @('Debug', 'Release')) {
        cmake --build $nativeBuild --config $configuration --parallel 2>&1 | Tee-Object (Join-Path $logs "build-$crt-$configuration.log")
        if ($LASTEXITCODE -ne 0) { throw "Core build failed: $crt/$configuration" }
        if (-not $PackageOnly) {
            ctest --test-dir $nativeBuild -C $configuration --output-on-failure '--no-tests=error' `
            2>&1 | Tee-Object (Join-Path $logs "tests-$crt-$configuration.log")
            if ($LASTEXITCODE -ne 0) { throw "Core tests failed: $crt/$configuration" }
        }
        cmake --install $nativeBuild --config $configuration --prefix $prefix `
            2>&1 | Tee-Object (Join-Path $logs "install-$crt-$configuration.log")
        if ($LASTEXITCODE -ne 0) { throw "Core install failed: $crt/$configuration" }
        $destination = Join-Path $stage "build/native/lib/x64/$crt/$configuration"
        New-Item -ItemType Directory -Force $destination | Out-Null
        $library = if ($configuration -eq 'Debug') { 'MXLoggerCored.lib' } else { 'MXLoggerCore.lib' }
        Copy-Item (Join-Path $prefix "lib/$library") (Join-Path $destination 'MXLoggerCore.lib') -Force
    }
    if ($PackageOnly) { continue }
    # Consume the installed CMake SDK, without access to Core's source includes.
    $consumerBuild = Join-Path $build "cmake-consumer-$crt"
    cmake -S (Join-Path $repo 'platform/Windows/tests/package_consumer') -B $consumerBuild -A x64 -T $Toolset `
        "-DCMAKE_PREFIX_PATH=$prefix" '-DCMAKE_POLICY_DEFAULT_CMP0091=NEW' "-DCMAKE_MSVC_RUNTIME_LIBRARY=$runtime" `
        2>&1 | Tee-Object (Join-Path $logs "cmake-consumer-$crt.log")
    if ($LASTEXITCODE -ne 0) { throw 'Installed SDK consumer configure failed' }
    foreach ($configuration in @('Debug', 'Release')) {
        cmake --build $consumerBuild --config $configuration --parallel 2>&1 | Tee-Object (Join-Path $logs "consumer-$crt-$configuration.log")
        if ($LASTEXITCODE -ne 0) { throw 'Installed SDK consumer build failed' }
        ctest --test-dir $consumerBuild -C $configuration --output-on-failure '--no-tests=error' `
            2>&1 | Tee-Object (Join-Path $logs "consumer-tests-$crt-$configuration.log")
        if ($LASTEXITCODE -ne 0) { throw 'Installed SDK consumer run failed' }
    }
}

& (Join-Path $PSScriptRoot 'build_windows_ffi.ps1') -Toolset $Toolset `
    -BuildDirectory (Join-Path $build 'ffi') -Destination (Join-Path $stage 'build/native/ffi/x64')
# Prove the binary dependency came from this checkout, for all three builds.
python (Join-Path $PSScriptRoot 'check_local_core.py') `
    --cmake-cache (Join-Path $build 'core-MD/CMakeCache.txt') `
    --cmake-cache (Join-Path $build 'core-MT/CMakeCache.txt') `
    --cmake-cache (Join-Path $build 'ffi/CMakeCache.txt') --output (Join-Path $logs 'local-core.json')
if ($LASTEXITCODE -ne 0) { throw 'NuGet did not use checkout Core' }
$include = Join-Path $stage 'build/native/include'
New-Item -ItemType Directory -Force $include | Out-Null
Copy-Item (Join-Path $repo 'Core/mxlogger.hpp'), (Join-Path $repo 'Core/mxlogger_util.hpp') $include -Force
Copy-Item (Join-Path $repo 'Core/ffi/mxlogger_ffi.h') $include -Force
Copy-Item (Join-Path $repo 'platform/Windows/nuget/MXLogger.Native.targets') (Join-Path $stage 'build/native') -Force
Copy-Item (Join-Path $repo 'LICENSE.TXT') $stage -Force
Copy-Item (Join-Path $repo 'platform/Windows/README.md') (Join-Path $stage 'README.md') -Force
& $nuget pack (Join-Path $repo 'platform/Windows/nuget/MXLogger.Native.nuspec') -Version $version `
    -BasePath $stage -OutputDirectory $packages -NonInteractive 2>&1 | Tee-Object (Join-Path $logs 'nuget-pack.log')
if ($LASTEXITCODE -ne 0) { throw 'NuGet pack failed' }
if ($PackageOnly) {
    Write-Host 'Test fixture packed; full SDK validation is deferred to stage 3.'
    return
}

# Restore the actual nupkg from a local feed and build a standalone .vcxproj.
$consumer = Join-Path $build 'nuget-consumer'
New-Item -ItemType Directory -Force $consumer | Out-Null
foreach ($file in @('consumer.vcxproj', 'packages.config')) {
    (Get-Content (Join-Path $repo "platform/Windows/tests/nuget_consumer/$file") -Raw).Replace('@VERSION@', $version) |
        Set-Content (Join-Path $consumer $file) -Encoding utf8
}
Copy-Item (Join-Path $repo 'platform/Windows/tests/package_consumer/main.cpp') $consumer -Force
# Do not reuse an older restored package with the same development version.
$restored = Join-Path $consumer "packages/MXLogger.Native.$version"
if (Test-Path $restored) { Remove-Item -LiteralPath $restored -Recurse -Force }
& $nuget restore (Join-Path $consumer 'packages.config') -PackagesDirectory (Join-Path $consumer 'packages') `
    -Source $packages -NoCache -NonInteractive 2>&1 | Tee-Object (Join-Path $logs 'nuget-restore.log')
if ($LASTEXITCODE -ne 0) { throw 'Local NuGet restore failed' }
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
$msbuild = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -find 'MSBuild/**/Bin/MSBuild.exe' | Select-Object -First 1
if (-not $msbuild) { throw 'MSBuild with C++ tools was not found' }
# Check the targets restored from the nupkg, including explicit source metadata.
# The normal consumer below still verifies real compilation, linking and I/O.
foreach ($standard in @('', 'Default', 'stdcpp14', 'stdcpp17', 'stdcpp20', 'stdcpp23', 'stdcpplatest')) {
    $label = if ($standard) { $standard } else { 'unset' }
    & $msbuild (Join-Path $repo 'platform/Windows/tests/nuget_consumer/language_standard.proj') /nologo `
        "/p:MXLoggerTargets=$(Join-Path $restored 'build/native/MXLogger.Native.targets')" `
        "/p:ProjectLanguageStandard=$standard" `
        2>&1 | Tee-Object (Join-Path $logs "nuget-language-$label.log")
    if ($LASTEXITCODE -ne 0) { throw "NuGet language standard check failed: $label" }
}
foreach ($crt in @('MD', 'MT')) {
    foreach ($configuration in @('Debug', 'Release')) {
        & $msbuild (Join-Path $consumer 'consumer.vcxproj') /nologo /m "/p:Configuration=$configuration" /p:Platform=x64 `
            "/p:PlatformToolset=$Toolset" "/p:MXLoggerRuntimeLibrary=$crt" `
            2>&1 | Tee-Object (Join-Path $logs "nuget-consumer-$crt-$configuration.log")
        if ($LASTEXITCODE -ne 0) { throw 'NuGet consumer build failed' }
        & (Join-Path $consumer "bin/$crt/$configuration/consumer.exe") (Join-Path $consumer "logs-$crt-$configuration") `
            2>&1 | Tee-Object (Join-Path $logs "nuget-run-$crt-$configuration.log")
        if ($LASTEXITCODE -ne 0) { throw 'NuGet consumer read/write check failed' }
    }
}
& $msbuild (Join-Path $consumer 'consumer.vcxproj') /nologo /p:Configuration=Release /p:Platform=x64 `
    "/p:PlatformToolset=$Toolset" /p:MXLoggerRuntimeLibrary=MD /p:ConsumerForceRuntimeLibrary=MultiThreaded `
    2>&1 | Tee-Object (Join-Path $logs 'nuget-crt-mismatch.log')
if ($LASTEXITCODE -eq 0 -or -not (Select-String -Path (Join-Path $logs 'nuget-crt-mismatch.log') -SimpleMatch 'MXLogger.Native CRT mismatch' -Quiet)) {
    throw 'NuGet CRT mismatch validation did not reject an incompatible consumer'
}
Write-Host "PASS: $(Join-Path $packages "MXLogger.Native.$version.nupkg")"
exit 0
