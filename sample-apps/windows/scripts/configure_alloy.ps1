# Configure Alloy service with the generated configuration
$ErrorActionPreference = "Stop"

$configPath = Resolve-Path "config\alloy-config.alloy"
$installPath = "C:\Program Files\GrafanaLabs\Alloy"
$serviceConfigPath = Join-Path $installPath "config.alloy"

Write-Host "Configuring Alloy service..."

# Ensure the install directory exists
if (-not (Test-Path $installPath)) {
    Write-Error "Alloy installation directory not found at: $installPath"
    exit 1
}

# Copy configuration to Alloy installation directory
try {
    Copy-Item -Path $configPath -Destination $serviceConfigPath -Force
    Write-Host "Configuration copied to: $serviceConfigPath"
} catch {
    Write-Error "Failed to copy configuration: $_"
    exit 1
}

# Verify configuration file exists
if (-not (Test-Path $serviceConfigPath)) {
    Write-Error "Configuration file not found at expected location: $serviceConfigPath"
    exit 1
}

Write-Host "Alloy service configured successfully."

# Check if service exists and update its configuration
$serviceName = "Alloy"
$service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

if ($service) {
    Write-Host "Alloy service found. Service will use the new configuration on next start."
    
    # Stop service if running to apply new config
    if ($service.Status -eq "Running") {
        Write-Host "Stopping Alloy service to apply new configuration..."
        Stop-Service -Name $serviceName -Force
        Write-Host "Alloy service stopped."
    }
} else {
    Write-Host "Alloy service not found. This is expected if this is the first configuration."
}

Write-Host "Alloy configuration completed." 