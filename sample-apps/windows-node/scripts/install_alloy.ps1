# Install Grafana Alloy on Windows
# This script downloads and installs the latest version of Grafana Alloy

param(
    [string]$InstallPath = "C:\Program Files\GrafanaLabs\Alloy"
)

$ErrorActionPreference = "Stop"

Write-Host "Installing Grafana Alloy..."

# Create installation directory
if (-not (Test-Path $InstallPath)) {
    New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
}

# Download the latest Alloy installer
$downloadUrl = "https://github.com/grafana/alloy/releases/latest/download/alloy-installer-windows-amd64.exe.zip"
$tempDir = Join-Path $env:TEMP "alloy-install"
$zipFile = Join-Path $tempDir "alloy-installer.zip"
$extractPath = Join-Path $tempDir "extracted"

if (-not (Test-Path $tempDir)) {
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
}

Write-Host "Downloading Alloy installer..."
try {
    Invoke-WebRequest -Uri $downloadUrl -OutFile $zipFile -UseBasicParsing
    Write-Host "Downloaded Alloy installer successfully."
} catch {
    Write-Error "Failed to download Alloy installer: $_"
    exit 1
}

# Extract the installer
Write-Host "Extracting installer..."
try {
    Expand-Archive -Path $zipFile -DestinationPath $extractPath -Force
    $installerPath = Get-ChildItem -Path $extractPath -Filter "*.exe" -Recurse | Select-Object -First 1
    
    if (-not $installerPath) {
        Write-Error "Could not find installer executable in downloaded package"
        exit 1
    }
    
    Write-Host "Found installer at: $($installerPath.FullName)"
} catch {
    Write-Error "Failed to extract installer: $_"
    exit 1
}

# Run the installer silently
Write-Host "Installing Alloy..."
try {
    $arguments = @(
        "/S",
        "/CONFIG=`"$InstallPath\config.alloy`"",
        "/DISABLEREPORTING=yes"
    )
    
    $process = Start-Process -FilePath $installerPath.FullName -ArgumentList $arguments -Wait -PassThru
    
    if ($process.ExitCode -eq 0) {
        Write-Host "Alloy installed successfully."
    } else {
        Write-Error "Alloy installation failed with exit code: $($process.ExitCode)"
        exit 1
    }
} catch {
    Write-Error "Failed to run installer: $_"
    exit 1
}

# Verify installation
$serviceName = "Alloy"
$service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

if ($service) {
    Write-Host "Alloy service found and ready."
} else {
    Write-Host "Alloy service not found, but installation completed. This is expected on first install."
}

# Clean up temporary files
Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "Alloy installation completed."

# Explicitly exit with success code
exit 0 