# Start Alloy service and verify it's running
$ErrorActionPreference = "Stop"

$serviceName = "Alloy"
$maxRetries = 5
$retryDelay = 10

Write-Host "Starting Alloy service..."

# Check if service exists
$service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

if (-not $service) {
    Write-Error "Alloy service not found. Please ensure Alloy is installed properly."
    exit 1
}

# Start the service
try {
    Start-Service -Name $serviceName
    Write-Host "Alloy service start command issued."
} catch {
    Write-Error "Failed to start Alloy service: $_"
    exit 1
}

# Wait for service to be running and verify
$retryCount = 0
do {
    Start-Sleep -Seconds $retryDelay
    $service = Get-Service -Name $serviceName
    $retryCount++
    
    Write-Host "Checking service status... Attempt $retryCount/$maxRetries"
    Write-Host "Service Status: $($service.Status)"
    
    if ($service.Status -eq "Running") {
        Write-Host "Alloy service is running successfully!"
        break
    }
    
    if ($retryCount -ge $maxRetries) {
        Write-Error "Alloy service failed to start after $maxRetries attempts. Final status: $($service.Status)"
        exit 1
    }
    
} while ($service.Status -ne "Running")

# Verify metrics endpoint is accessible
Write-Host "Verifying Alloy metrics endpoint..."
$maxEndpointRetries = 6
$endpointRetryDelay = 10
$metricsUrl = "http://localhost:12345/metrics"

for ($i = 1; $i -le $maxEndpointRetries; $i++) {
    try {
        $response = Invoke-WebRequest -Uri $metricsUrl -UseBasicParsing -TimeoutSec 10
        if ($response.StatusCode -eq 200) {
            Write-Host "Alloy metrics endpoint is accessible at: $metricsUrl"
            break
        }
    } catch {
        Write-Host "Metrics endpoint not yet available. Attempt $i/$maxEndpointRetries"
        if ($i -eq $maxEndpointRetries) {
            Write-Warning "Metrics endpoint not accessible at $metricsUrl, but service is running. This may indicate a configuration issue."
        } else {
            Start-Sleep -Seconds $endpointRetryDelay
        }
    }
}

Write-Host "Alloy service startup completed." 