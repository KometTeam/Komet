param(
    [string]$VcRoot = 'D:\Microsoft Visual Studio\18\Community\VC\Tools\MSVC\14.51.36231',
    [string]$SdkRoot = 'C:\Program Files (x86)\Windows Kits\10',
    [string]$SdkVersion = '10.0.26100.0',
    [switch]$Session,
    [switch]$Network
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$build = Join-Path $root 'build\tests'
New-Item -ItemType Directory -Force -Path $build | Out-Null
$env:INCLUDE = "$root\third_party\opus\include;$root\third_party\ogg\include;$root\build\generated;$VcRoot\include;$SdkRoot\Include\$SdkVersion\ucrt;$SdkRoot\Include\$SdkVersion\shared;$SdkRoot\Include\$SdkVersion\um;$SdkRoot\Include\$SdkVersion\winrt"
$env:LIB = "$VcRoot\lib\x64;$SdkRoot\Lib\$SdkVersion\um\x64;$SdkRoot\Lib\$SdkVersion\ucrt\x64"
$env:PATH = "$VcRoot\bin\Hostx64\x64;" + $env:PATH
& "$PSScriptRoot\build-codecs.ps1" -CompilerRoot $VcRoot -Build "$build\codecs" -Target x64
$units = @('protocol', 'auth', 'audio', 'images', 'chat_state')
if ($Session) { $units += 'session' }
if ($Network) { $units += @('handshake', 'tls') }
foreach ($unit in $units) {
    & "$VcRoot\bin\Hostx64\x64\cl.exe" /nologo /std:c++20 /EHsc /MT /O1 /utf-8 /W4 /bigobj /Zc:__cplusplus /DNOMINMAX /DWINRT_LEAN_AND_MEAN "$root\tests\$unit.cpp" "/Fo$build\$unit.obj" "/Fe$build\$unit.exe" /link WindowsApp.lib "$build\codecs\codecs.lib"
    if ($LASTEXITCODE) { throw "$unit compile failed" }
    if ($unit -eq 'session') { & python "$root\tests\session-server.py" "$build\$unit.exe" }
    else { & "$build\$unit.exe" }
    if ($LASTEXITCODE) { throw "$unit test failed" }
}
