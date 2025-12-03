# Stop Alloy service and cleanup
$ErrorActionPreference = "Stop"

$serviceName = "Alloy"

Write-Host "Stopping Alloy service..."

# Check if service exists
$service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

if (-not $service) {
    Write-Host "Alloy service not found. Nothing to stop."
    exit 0
}

if ($service.Status -eq "Stopped") {
    Write-Host "Alloy service is already stopped."
} else {
    try {
        Stop-Service -Name $serviceName -Force
        Write-Host "Alloy service stopped successfully."
    } catch {
        Write-Warning "Failed to stop Alloy service: $_"
    }
}

# Optional: Remove service (uncomment if you want to completely remove the service)
# Write-Host "Removing Alloy service..."
# try {
#     Remove-Service -Name $serviceName -Force
#     Write-Host "Alloy service removed."
# } catch {
#     Write-Warning "Failed to remove Alloy service: $_"
# }

Write-Host "Alloy service stop completed." 