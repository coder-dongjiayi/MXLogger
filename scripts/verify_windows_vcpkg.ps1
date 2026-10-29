#requires -Version 7.0
[CmdletBinding()]
param([string]$VcpkgRoot = $env:VCPKG_INSTALLATION_ROOT)

$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'This overlay is validated for native Windows x64.' }
if (-not $VcpkgRoot -or -not (Test-Path (Join-Path $VcpkgRoot 'scripts/buildsystems/vcpkg.cmake'))) {
    throw 'Set VCPKG_INSTALLATION_ROOT or pass -VcpkgRoot to an installed vcpkg checkout.'
}
$repo = Split-Path $PSScriptRoot -Parent
$build = Join-Path $repo 'build/windows-sdk/vcpkg'
$logs = Join-Path $repo 'build/windows-sdk/logs'
New-Item -ItemType Directory -Force $logs | Out-Null
$previousBinarySources = $env:VCPKG_BINARY_SOURCES
try {
    # This overlay packages the local source tree, not a pinned source archive.
    $env:VCPKG_BINARY_SOURCES = 'clear'
    foreach ($triplet in @('x64-windows', 'x64-windows-static')) {
        $consumer = Join-Path $build $triplet
        $installed = Join-Path $consumer 'installed'
        if (Test-Path $installed) { Remove-Item -LiteralPath $installed -Recurse -Force }
        $runtime = if ($triplet -eq 'x64-windows') { 'MultiThreaded$<$<CONFIG:Debug>:Debug>DLL' } else { 'MultiThreaded$<$<CONFIG:Debug>:Debug>' }
        cmake -S (Join-Path $repo 'platform/Windows/tests/package_consumer') -B $consumer -A x64 -T v143 `
            "-DCMAKE_TOOLCHAIN_FILE=$VcpkgRoot/scripts/buildsystems/vcpkg.cmake" `
            "-DVCPKG_TARGET_TRIPLET=$triplet" "-DVCPKG_INSTALLED_DIR=$consumer/installed" `
            "-DVCPKG_OVERLAY_PORTS=$repo/platform/Windows/vcpkg/ports" `
            '-DCMAKE_POLICY_DEFAULT_CMP0091=NEW' "-DCMAKE_MSVC_RUNTIME_LIBRARY=$runtime" `
            2>&1 | Tee-Object (Join-Path $logs "vcpkg-configure-$triplet.log")
        if ($LASTEXITCODE -ne 0) { throw "vcpkg install/configure failed: $triplet" }
        foreach ($configuration in @('Debug', 'Release')) {
            cmake --build $consumer --config $configuration --parallel `
                2>&1 | Tee-Object (Join-Path $logs "vcpkg-build-$triplet-$configuration.log")
            if ($LASTEXITCODE -ne 0) { throw 'vcpkg consumer build failed' }
            ctest --test-dir $consumer -C $configuration --output-on-failure '--no-tests=error' `
                2>&1 | Tee-Object (Join-Path $logs "vcpkg-run-$triplet-$configuration.log")
            if ($LASTEXITCODE -ne 0) { throw 'vcpkg consumer read/write check failed' }
        }
    }
} finally { $env:VCPKG_BINARY_SOURCES = $previousBinarySources }
Write-Host 'PASS: vcpkg x64-windows and x64-windows-static consumers'
