#Requires -Version 7.4

param(
    [Parameter(Mandatory)] [ValidateSet('x64', 'arm64')]
    [string] $Architecture,

    [Parameter(Mandatory)] [ValidatePattern('^[0-9A-Za-z][0-9A-Za-z._-]*$')]
    [string] $Version
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
Set-StrictMode -Version Latest

if (-not $IsWindows -or
    [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString() -ne $Architecture -or
    [System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture.ToString() -ne $Architecture) {
    throw "Use native $Architecture Windows and PowerShell; cross-compilation and emulation are not supported."
}

$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$work = "$root/work/symcrypt-windows-$Architecture"
$src = "$work/src"
$build = "$work/build"

# Reuse the Linux source pin rather than maintaining a separate Windows version.
$manifest = Get-Content "$root/cgmanifest.json" -Raw | ConvertFrom-Json
$pins = @($manifest.registrations | Where-Object {
    $_.component.type -eq 'git' -and
    $_.component.git.repositoryUrl -eq 'https://github.com/microsoft/symcrypt'
})
if ($pins.Count -ne 1 -or $pins[0].component.git.commitHash -notmatch '^[0-9a-f]{40}$') {
    throw 'Expected exactly one pinned SymCrypt commit in cgmanifest.json.'
}
$pin = $pins[0].component.git

# Load the matching native compiler and Windows SDK into this process.
$vswhere = "${env:ProgramFiles(x86)}/Microsoft Visual Studio/Installer/vswhere.exe"
$component = @{ x64 = 'x86.x64'; arm64 = 'ARM64' }[$Architecture]
$vs = & $vswhere -latest -products '*' -requires "Microsoft.VisualStudio.Component.VC.Tools.$component" -property installationPath
if (-not $vs) {
    throw "Visual Studio C++ tools for $Architecture are required."
}
Import-Module "$vs/Common7/Tools/Microsoft.VisualStudio.DevShell.dll"
Enter-VsDevShell -VsInstallPath $vs -SkipAutomaticLocation `
    -DevCmdArguments "-arch=$Architecture -host_arch=$Architecture"

# Keep the checkout and build cache between runs. Upstream version generation needs Git metadata.
New-Item -ItemType Directory -Force $src, "$root/out" | Out-Null
if (-not (Test-Path "$src/.git")) {
    git init $src
}
git -C $src fetch --depth 1 "$($pin.repositoryUrl).git" $pin.commitHash
git -C $src checkout --detach FETCH_HEAD

$symcryptArchitecture = @{ x64 = 'AMD64'; arm64 = 'ARM64' }[$Architecture]
# Ninja uses the installed SDK from the native developer shell instead of
# upstream's Visual Studio generator SDK selection (10.0.18362).
# Use /MT and embed debug info so consumers need no CRT DLL or separate library PDBs.
cmake -S $src -B $build -G Ninja `
    "-DSYMCRYPT_TARGET_ARCH=$symcryptArchitecture" `
    "-DCMAKE_C_COMPILER=cl.exe" "-DCMAKE_CXX_COMPILER=cl.exe" `
    -DCMAKE_BUILD_TYPE=RelWithDebInfo `
    -DCMAKE_POLICY_DEFAULT_CMP0091=NEW -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded `
    -DCMAKE_POLICY_DEFAULT_CMP0141=NEW -DCMAKE_MSVC_DEBUG_INFORMATION_FORMAT=Embedded `
    -DSYMCRYPT_USE_ASM=ON -DSYMCRYPT_FIPS_BUILD=OFF `
    -DSYMCRYPT_BUILD_MODULES=OFF -DSYMCRYPT_UNIT_TESTS=ON
cmake --build $build --parallel --target symcrypt_usermodewin8_1 symcryptunittest
& "$build/exe/symcryptunittest.exe" noperftests

# Stage each package in a fresh directory so stale outputs cannot enter the archive.
$stage = "$work/stage-$([guid]::NewGuid().ToString('N'))"
$package = "$stage/package"
try {
    New-Item -ItemType Directory "$package/include", "$package/lib/static" | Out-Null
    # Exclude private build metadata, but include the generated version definitions.
    Get-ChildItem "$src/inc/*.h" -Exclude buildInfo.h | Copy-Item -Destination "$package/include"
    Copy-Item "$src/inc/symcrypt_internal_shared.inc" "$package/include"
    foreach ($library in 'symcrypt_usermodewin8_1', 'symcrypt_common', 'symcrypt_mlkem') {
        Copy-Item "$build/lib/$library.lib" "$package/lib/static"
    }
    Copy-Item "$src/LICENSE.txt", "$src/NOTICE.txt" $package
    @(
        "repository=$($pin.repositoryUrl)"
        "commit=$($pin.commitHash)"
        "architecture=$Architecture"
        'configuration=RelWithDebInfo'
        'runtime=MT'
        'fips=off'
    ) | Set-Content "$package/manifest" -Encoding ascii

    $releaseArchitecture = @{ x64 = 'x86_64'; arm64 = 'aarch64' }[$Architecture]
    $archive = "$root/out/symcrypt-windows.$releaseArchitecture.$Version.tar.gz"
    tar -czf $archive -C $package .

} finally {
    # Remove only this run's staging files; retain the checkout, build cache, and archive.
    if (Test-Path $stage) {
        Remove-Item -LiteralPath $stage -Recurse -Force
    }
}
