#requires -Version 7.0
[CmdletBinding()]
param(
    [string]$Toolset = 'v143',
    [string]$BuildDirectory,
    [Parameter(Mandatory)][string]$Destination
)
$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'Build the Windows DLL on Windows (or a Windows CI runner).' }
$repo = Split-Path $PSScriptRoot -Parent
if (-not $BuildDirectory) { $BuildDirectory = Join-Path $repo 'build/windows-ffi' }
$BuildDirectory = [IO.Path]::GetFullPath($BuildDirectory)
$Destination = [IO.Path]::GetFullPath($Destination)
New-Item -ItemType Directory -Force $BuildDirectory, $Destination | Out-Null
$versionText = Get-Content (Join-Path $repo 'Core/mxlogger_version.hpp') -Raw
if ($versionText -notmatch '#define MXLOGGER_CORE_VERSION "(\d+\.\d+\.\d+)"') { throw 'Core version is missing' }
$version = $Matches[1]
# Allocations are freed inside this module. Static CRT avoids a dependency on
# the developer-only Debug CRT when distributing the Debug DLL for tests.
cmake -S (Join-Path $repo 'Core/ffi') -B $BuildDirectory -A x64 -T $Toolset `
    '-DCMAKE_POLICY_DEFAULT_CMP0091=NEW' '-DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded$<$<CONFIG:Debug>:Debug>' `
    '-DMXLOGGER_BUILD_TESTS=OFF' '-DMXLOGGER_INSTALL=OFF' `
    2>&1 | Tee-Object (Join-Path $BuildDirectory 'configure.log')
if ($LASTEXITCODE -ne 0) { throw 'FFI DLL configure failed' }
python (Join-Path $repo 'scripts/check_local_core.py') --cmake-cache (Join-Path $BuildDirectory 'CMakeCache.txt') `
    --output (Join-Path $BuildDirectory 'local-core.json')
if ($LASTEXITCODE -ne 0) { throw 'FFI DLL did not use checkout Core' }
$hashes = [ordered]@{}
foreach ($configuration in @('Debug', 'Release')) {
    cmake --build $BuildDirectory --config $configuration --target mxlogger_ffi --parallel `
        2>&1 | Tee-Object (Join-Path $BuildDirectory "build-$configuration.log")
    if ($LASTEXITCODE -ne 0) { throw "FFI DLL build failed: $configuration" }
    $dll = (Get-Content (Join-Path $BuildDirectory "mxlogger-ffi-$configuration.txt") -Raw).Trim()
    $directory = Join-Path $Destination $configuration
    New-Item -ItemType Directory -Force $directory | Out-Null
    Copy-Item -LiteralPath $dll -Destination (Join-Path $directory 'mxlogger_ffi.dll') -Force
    $hashes[$configuration] = (Get-FileHash -LiteralPath $dll -Algorithm SHA256).Hash.ToLowerInvariant()
}
[ordered]@{
    core_version = $version
    ffi_abi = 1
    architecture = 'x64'
    sha256 = $hashes
    # Content provenance includes uncommitted changes; version alone is not proof.
    local_core = (Get-Content (Join-Path $BuildDirectory 'local-core.json') -Raw | ConvertFrom-Json)
} | ConvertTo-Json -Depth 20 | Set-Content (Join-Path $Destination 'manifest.json') -Encoding utf8NoBOM
Write-Host "PASS: Windows FFI DLLs staged at $Destination"
