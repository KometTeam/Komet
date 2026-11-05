param([string]$CompilerRoot, [string]$Build, [ValidateSet('arm','x64')][string]$Target = 'arm')
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
New-Item -ItemType Directory -Force -Path $Build | Out-Null
$sources = @(
    'zstd\common\debug.c', 'zstd\common\entropy_common.c', 'zstd\common\error_private.c',
    'zstd\common\fse_decompress.c', 'zstd\common\xxhash.c', 'zstd\common\zstd_common.c',
    'zstd\decompress\huf_decompress.c', 'zstd\decompress\zstd_ddict.c',
    'zstd\decompress\zstd_decompress.c', 'zstd\decompress\zstd_decompress_block.c',
    'lz4\lz4.c', 'lz4\lz4hc.c', 'lz4\lz4frame.c', 'lz4\xxhash.c')
foreach ($group in @(@('opus_sources.mk', 'OPUS_SOURCES'), @('opus_sources.mk', 'OPUS_SOURCES_FLOAT'), @('celt_sources.mk', 'CELT_SOURCES'), @('silk_sources.mk', 'SILK_SOURCES'), @('silk_sources.mk', 'SILK_SOURCES_FLOAT'))) {
    $makefile = [IO.File]::ReadAllText("$root\third_party\opus\$($group[0])")
    $match = [regex]::Match($makefile, '(?ms)^' + $group[1] + ' = (.*?)(?:\r?\n\r?\n|\z)')
    if (!$match.Success) { throw "Missing Opus source group: $($group[1])" }
    $paths = $match.Groups[1].Value -replace '\\\r?\n', ' '
    foreach ($entry in ($paths -split '\s+')) { if ($entry.EndsWith('.c')) { $sources += 'opus\' + $entry.Replace('/', '\') } }
}
$sources += @('ogg\src\bitwise.c', 'ogg\src\framing.c', 'opusfile\src\info.c', 'opusfile\src\internal.c', 'opusfile\src\opusfile.c', 'opusfile\src\stream.c')
foreach ($folder in @('dec', 'dsp', 'utils')) {
    $makefile = [IO.File]::ReadAllText("$root\third_party\webp\src\$folder\Makefile.am")
    $pattern = if ($folder -eq 'dec') { '(?m)^libwebpdecode_la_SOURCES \+= ([\w]+\.c)\s*$' } else { '(?m)^COMMON_SOURCES \+= ([\w]+\.c)\s*$' }
    foreach ($match in [regex]::Matches($makefile, $pattern)) { $sources += "webp\src\$folder\" + $match.Groups[1].Value }
}
$dsp = [IO.File]::ReadAllText("$root\third_party\webp\src\dsp\Makefile.am")
foreach ($match in [regex]::Matches($dsp, '(?m)^libwebpdspdecode_(?:sse2|sse41|avx2|neon)_la_SOURCES \+= ([\w]+\.c)\s*$')) { $sources += 'webp\src\dsp\' + $match.Groups[1].Value }
$objects = @()
$includes = @("/I$root\third_party\webp", "/I$root\third_party\opus\include", "/I$root\third_party\opus", "/I$root\third_party\opus\celt", "/I$root\third_party\opus\silk", "/I$root\third_party\opus\silk\float", "/I$root\third_party\ogg\include", "/I$root\third_party\opusfile\include")
foreach ($source in $sources) {
    $path = Join-Path $root "third_party\$source"
    $object = Join-Path $Build ($source.Replace('\','_').Replace('.c','.obj'))
    $objects += $object
    if (!(Test-Path -LiteralPath $object) -or (Get-Item $object).LastWriteTimeUtc -lt (Get-Item $path).LastWriteTimeUtc -or (Get-Item $object).LastWriteTimeUtc -lt (Get-Item $PSCommandPath).LastWriteTimeUtc) {
        & "$CompilerRoot\bin\Hostx64\$Target\cl.exe" /nologo /c /TC /MT /O1 /W1 /DWINAPI_FAMILY=WINAPI_FAMILY_APP /DZSTD_DISABLE_ASM /DZSTD_LEGACY_SUPPORT=0 /D_CRT_SECURE_NO_WARNINGS /DOPUS_BUILD /DUSE_ALLOCA /DWEBP_STATIC @includes $path "/Fo$object"
        if ($LASTEXITCODE) { throw "Codec compile failed: $source" }
    }
}
& "$CompilerRoot\bin\Hostx64\$Target\lib.exe" /nologo "/OUT:$Build\codecs.lib" @objects
if ($LASTEXITCODE) { throw 'Codec archive failed' }
