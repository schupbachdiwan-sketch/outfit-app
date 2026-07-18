$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Try China mirror first, fallback to Google
$baseUrls = @(
    "https://storage.flutter-io.cn/flutter_infra_release/releases",
    "https://storage.googleapis.com/flutter_infra_release/releases"
)

Write-Output "Getting latest Flutter stable version..."
$release = Invoke-RestMethod -Uri 'https://storage.flutter-io.cn/flutter_infra_release/releases/releases_windows.json'
$stable = $release.releases | Where-Object { $_.channel -eq 'stable' } | Select-Object -First 1
$version = $stable.version
$archivePath = $stable.archive
Write-Output "Version: $version"

foreach ($base in $baseUrls) {
    $url = "$base/$archivePath"
    Write-Output "Trying: $url"
    try {
        Invoke-WebRequest -Uri $url -OutFile "C:\flutter.zip" -ErrorAction Stop
        Write-Output "Download successful!"
        break
    } catch {
        Write-Output "Failed, trying next mirror..."
    }
}

if (-not (Test-Path "C:\flutter.zip")) {
    Write-Output "ERROR: All download mirrors failed."
    exit 1
}

Write-Output "Extracting to C:\flutter..."
Expand-Archive -Path "C:\flutter.zip" -DestinationPath "C:\" -Force
Remove-Item "C:\flutter.zip" -Force
Write-Output "Flutter SDK v$version installed to C:\flutter"
