param(
    [string]$ToolchainRoot = '',
    [string]$SdkRoot = 'C:\Program Files (x86)\Windows Kits\10',
    [string]$SdkVersion = '10.0.26100.0'
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
if (!$ToolchainRoot) { $ToolchainRoot = Join-Path (Split-Path (Split-Path $root -Parent) -Parent) 'lumiatunnel\.tools' }
$compilerRoot = Join-Path $ToolchainRoot 'msvc-arm\VC\Tools\MSVC\14.44.35207'
$armLib = Join-Path $ToolchainRoot 'sdk-arm\extracted\Windows Kits\10\Lib\10.0.22621.0'
$generator = Join-Path $ToolchainRoot 'cppwinrt\bin\cppwinrt.exe'
$compiler = Join-Path $compilerRoot 'bin\Hostx64\arm\cl.exe'
$linker = Join-Path $compilerRoot 'bin\Hostx64\arm\link.exe'
foreach ($file in @($compiler, $linker, $generator, "$armLib\um\arm\WindowsApp.lib")) {
    if (!(Test-Path -LiteralPath $file)) { throw "Required ARM32 toolchain file missing: $file. See w10m/README.md." }
}
$build = Join-Path $root 'build'
$stage = Join-Path $build 'stage'
$dist = Join-Path $root 'dist'
$generated = Join-Path $build 'generated'
New-Item -ItemType Directory -Force -Path $build,$stage,$dist | Out-Null
if (!(Test-Path -LiteralPath "$generated\winrt\Windows.UI.Xaml.h")) {
    & $generator -input "$SdkRoot\UnionMetadata\$SdkVersion\Windows.winmd" -output $generated
    if ($LASTEXITCODE) { throw 'C++/WinRT generation failed' }
}
$env:INCLUDE = "$root\third_party\opus\include;$root\third_party\ogg\include;$generated;$compilerRoot\include;$SdkRoot\Include\$SdkVersion\ucrt;$SdkRoot\Include\$SdkVersion\shared;$SdkRoot\Include\$SdkVersion\um;$SdkRoot\Include\$SdkVersion\winrt"
$env:LIB = "$compilerRoot\lib\arm\store;$compilerRoot\lib\arm;$armLib\um\arm;$armLib\ucrt\arm"
& "$PSScriptRoot\build-codecs.ps1" -CompilerRoot $compilerRoot -Build "$build\codecs" -Target arm
$flags = @('/nologo','/c','/std:c++20','/EHsc','/MT','/O1','/utf-8','/W4','/bigobj','/Zc:__cplusplus',
    '/DUNICODE','/D_UNICODE','/DWIN32','/D_WIN32','/DWINAPI_FAMILY=WINAPI_FAMILY_APP',
    '/D_WIN32_WINNT=0x0A00','/DWINVER=0x0A00','/DWINRT_LEAN_AND_MEAN','/DNOMINMAX')
& $compiler @flags "$root\app\App.cpp" "/Fo$build\App.obj"
if ($LASTEXITCODE) { throw 'ARM32 compilation failed' }
& $compiler @flags "$root\third_party\qrcodegen.cpp" "/Fo$build\qrcodegen.obj"
if ($LASTEXITCODE) { throw 'QR encoder compilation failed' }
& $linker /nologo /MACHINE:ARM /APPCONTAINER /SUBSYSTEM:WINDOWS,6.03 /NODEFAULTLIB:kernel32.lib /OPT:REF /OPT:ICF "$build\App.obj" "$build\qrcodegen.obj" "$build\codecs\codecs.lib" "/OUT:$stage\Komet.exe" WindowsApp.lib
if ($LASTEXITCODE) { throw 'ARM32 linking failed' }
Copy-Item -LiteralPath "$root\app\Package.appxmanifest" -Destination "$stage\AppxManifest.xml"
& python "$PSScriptRoot\make-assets.py" "$stage\Assets"
if ($LASTEXITCODE) { throw 'Asset generation failed' }
Copy-Item -LiteralPath (Join-Path (Split-Path $root -Parent) 'LICENSE') -Destination "$stage\LICENSE.txt"
Copy-Item -LiteralPath "$root\third_party\LICENSE.json" -Destination "$stage\LICENSE.json.txt"
Copy-Item -LiteralPath "$root\third_party\qrcodegen.hpp" -Destination "$stage\qrcodegen-source-and-license.txt"
Copy-Item -LiteralPath "$root\third_party\zstd\LICENSE" -Destination "$stage\LICENSE.zstd.txt"
Copy-Item -LiteralPath "$root\third_party\lz4\LICENSE" -Destination "$stage\LICENSE.lz4.txt"
Copy-Item -LiteralPath "$root\third_party\LICENSE.kolibri" -Destination "$stage\LICENSE.kolibri.txt"
foreach ($codec in @('opus', 'opusfile', 'ogg')) {
    Copy-Item -LiteralPath "$root\third_party\$codec\COPYING" -Destination "$stage\LICENSE.$codec.txt"
}
Copy-Item -LiteralPath "$root\third_party\webp\COPYING" -Destination "$stage\LICENSE.webp.txt"
[xml]$manifest = Get-Content -LiteralPath "$root\app\Package.appxmanifest" -Raw
$version = $manifest.Package.Identity.Version
& "$SdkRoot\bin\$SdkVersion\x64\makeappx.exe" pack /d $stage /p "$dist\Komet.W10M_${version}_ARM.appx" /o
if ($LASTEXITCODE) { throw 'APPX packing failed' }
Write-Output "Unsigned package: $dist\Komet.W10M_${version}_ARM.appx"
