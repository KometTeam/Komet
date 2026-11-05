param(
    [switch]$Fixture,
    [string]$VcRoot = 'D:\Microsoft Visual Studio\18\Community\VC\Tools\MSVC\14.51.36231',
    [string]$SdkRoot = 'C:\Program Files (x86)\Windows Kits\10',
    [string]$SdkVersion = '10.0.26100.0'
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$stage = Join-Path $root 'build\preview'
New-Item -ItemType Directory -Force -Path $stage | Out-Null
$env:INCLUDE = "$root\third_party\opus\include;$root\third_party\ogg\include;$root\build\generated;$VcRoot\include;$SdkRoot\Include\$SdkVersion\ucrt;$SdkRoot\Include\$SdkVersion\shared;$SdkRoot\Include\$SdkVersion\um;$SdkRoot\Include\$SdkVersion\winrt"
$env:LIB = "$VcRoot\lib\x64;$SdkRoot\Lib\$SdkVersion\um\x64;$SdkRoot\Lib\$SdkVersion\ucrt\x64"
$env:PATH = "$VcRoot\bin\Hostx64\x64;" + $env:PATH
& "$PSScriptRoot\build-codecs.ps1" -CompilerRoot $VcRoot -Build "$stage\codecs" -Target x64
$source = if ($Fixture) { "$root\tests\ui_preview.cpp" } else { "$root\app\App.cpp" }
& "$VcRoot\bin\Hostx64\x64\cl.exe" /nologo /std:c++20 /EHsc /MT /O1 /utf-8 /W4 /bigobj /Zc:__cplusplus /DNOMINMAX /DWINRT_LEAN_AND_MEAN /DWINAPI_FAMILY=WINAPI_FAMILY_APP $source "$root\third_party\qrcodegen.cpp" "/Fo$stage\\" "/Fe$stage\Komet.exe" /link /APPCONTAINER /SUBSYSTEM:WINDOWS WindowsApp.lib "$stage\codecs\codecs.lib"
if ($LASTEXITCODE) { throw 'Desktop preview compilation failed' }
$manifest = [IO.File]::ReadAllText("$root\app\Package.appxmanifest").Replace('Name="Komet.W10M"', 'Name="Komet.W10M.Preview"').Replace('ProcessorArchitecture="arm"', 'ProcessorArchitecture="x64"')
[IO.File]::WriteAllText("$stage\AppxManifest.xml", $manifest, [Text.UTF8Encoding]::new($false))
& python "$PSScriptRoot\make-assets.py" "$stage\Assets"
if ($LASTEXITCODE) { throw 'Asset generation failed' }
Add-AppxPackage -Register "$stage\AppxManifest.xml" -ErrorAction Stop
Write-Output 'Registered Komet.W10M.Preview for desktop UI inspection.'
