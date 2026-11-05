param([string]$SdkRoot = 'C:\Program Files (x86)\Windows Kits\10', [string]$SdkVersion = '10.0.26100.0')
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$privateDir = Join-Path $root '.private'
$dist = Join-Path $root 'dist'
$pfx = Join-Path $privateDir 'Komet.W10M.Development.pfx'
$secret = Join-Path $privateDir 'password.txt'
$cer = Join-Path $dist 'Komet.W10M.Development.cer'
[xml]$manifest = Get-Content -LiteralPath "$root\app\Package.appxmanifest" -Raw
$version = $manifest.Package.Identity.Version
$package = Join-Path $dist "Komet.W10M_${version}_ARM.appx"
New-Item -ItemType Directory -Force -Path $privateDir | Out-Null
if (!(Test-Path -LiteralPath $pfx)) {
    $bytes = New-Object byte[] 32
    $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
    try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
    $password = [Convert]::ToBase64String($bytes)
    $rsa = [Security.Cryptography.RSA]::Create(2048)
    try {
        $request = [Security.Cryptography.X509Certificates.CertificateRequest]::new(
            'CN=Komet W10M Development', $rsa, [Security.Cryptography.HashAlgorithmName]::SHA256,
            [Security.Cryptography.RSASignaturePadding]::Pkcs1)
        $request.CertificateExtensions.Add([Security.Cryptography.X509Certificates.X509BasicConstraintsExtension]::new($false, $false, 0, $true))
        $request.CertificateExtensions.Add([Security.Cryptography.X509Certificates.X509KeyUsageExtension]::new([Security.Cryptography.X509Certificates.X509KeyUsageFlags]::DigitalSignature, $true))
        $eku = [Security.Cryptography.OidCollection]::new()
        [void]$eku.Add([Security.Cryptography.Oid]::new('1.3.6.1.5.5.7.3.3'))
        $request.CertificateExtensions.Add([Security.Cryptography.X509Certificates.X509EnhancedKeyUsageExtension]::new($eku, $true))
        $cert = $request.CreateSelfSigned([DateTimeOffset]::UtcNow.AddDays(-1), [DateTimeOffset]::UtcNow.AddYears(5))
        [IO.File]::WriteAllBytes($pfx, $cert.Export([Security.Cryptography.X509Certificates.X509ContentType]::Pfx, $password))
        [IO.File]::WriteAllText($secret, $password)
    } finally { $rsa.Dispose() }
}
$password = [IO.File]::ReadAllText($secret)
$stored = [Security.Cryptography.X509Certificates.X509Certificate2]::new($pfx, $password)
[IO.File]::WriteAllBytes($cer, $stored.Export([Security.Cryptography.X509Certificates.X509ContentType]::Cert))
$stored.Dispose()
& "$SdkRoot\bin\$SdkVersion\x64\signtool.exe" sign /fd SHA256 /f $pfx /p $password $package
if ($LASTEXITCODE) { throw 'APPX signing failed' }
Add-Type -AssemblyName System.Security
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($package)
try {
    $entry = $archive.GetEntry('AppxSignature.p7x')
    if (!$entry) { throw 'Signature entry missing' }
    $stream = $entry.Open()
    $memory = [IO.MemoryStream]::new()
    try { $stream.CopyTo($memory); $bytes = $memory.ToArray() }
    finally { $stream.Dispose(); $memory.Dispose() }
    $cms = [Security.Cryptography.Pkcs.SignedCms]::new()
    $cms.Decode($bytes[4..($bytes.Length - 1)])
    $cms.CheckSignature($true)
    Write-Output 'PASS: cryptographic APPX CMS signature verification. Phone trust remains a device installation step.'
} finally { $archive.Dispose() }
