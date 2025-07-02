# Generate system load to create interesting metrics for testing
param(
    [int]$DurationSeconds = 120,
    [switch]$Background
)

$ErrorActionPreference = "Continue"

Write-Host "Starting load generation for $DurationSeconds seconds..."

if ($Background) {
    Write-Host "Running in background mode..."
}

# Function to generate CPU load
function Start-CpuLoad {
    param([int]$Seconds)
    
    $endTime = (Get-Date).AddSeconds($Seconds)
    $jobs = @()
    
    # Start multiple background jobs to create CPU load
    for ($i = 1; $i -le 4; $i++) {
        $job = Start-Job -ScriptBlock {
            param($EndTime)
            while ((Get-Date) -lt $EndTime) {
                $result = 1..1000 | ForEach-Object { $_ * $_ }
                Start-Sleep -Milliseconds 10
            }
        } -ArgumentList $endTime
        $jobs += $job
    }
    
    return $jobs
}

# Function to generate memory load
function Start-MemoryLoad {
    param([int]$Seconds)
    
    $endTime = (Get-Date).AddSeconds($Seconds)
    
    $job = Start-Job -ScriptBlock {
        param($EndTime)
        $arrays = @()
        $counter = 0
        
        while ((Get-Date) -lt $EndTime) {
            # Allocate memory in chunks
            $array = New-Object byte[] (10MB)
            $arrays += $array
            $counter++
            
            # Prevent excessive memory usage
            if ($counter -gt 20) {
                $arrays = @()
                $counter = 0
                [System.GC]::Collect()
            }
            
            Start-Sleep -Seconds 2
        }
    } -ArgumentList $endTime
    
    return $job
}

# Function to generate disk I/O load
function Start-DiskLoad {
    param([int]$Seconds)
    
    $endTime = (Get-Date).AddSeconds($Seconds)
    
    $job = Start-Job -ScriptBlock {
        param($EndTime)
        $tempDir = Join-Path $env:TEMP "alloy-test-load"
        
        if (-not (Test-Path $tempDir)) {
            New-Item -ItemType Directory -Path $tempDir | Out-Null
        }
        
        $counter = 0
        while ((Get-Date) -lt $EndTime) {
            $fileName = Join-Path $tempDir "testfile_$counter.tmp"
            
            # Write some data
            $data = "x" * 1024 * 100  # 100KB
            $data | Out-File -FilePath $fileName
            
            # Read it back
            $readData = Get-Content -Path $fileName -Raw
            
            # Clean up
            Remove-Item -Path $fileName -Force -ErrorAction SilentlyContinue
            
            $counter++
            Start-Sleep -Milliseconds 500
        }
        
        # Clean up temp directory
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    } -ArgumentList $endTime
    
    return $job
}

# Function to generate network activity
function Start-NetworkLoad {
    param([int]$Seconds)
    
    $endTime = (Get-Date).AddSeconds($Seconds)
    
    $job = Start-Job -ScriptBlock {
        param($EndTime)
        
        while ((Get-Date) -lt $EndTime) {
            try {
                # Make some HTTP requests to generate network activity
                $null = Invoke-WebRequest -Uri "http://httpbin.org/bytes/1024" -UseBasicParsing -TimeoutSec 5
                $null = Invoke-WebRequest -Uri "http://httpbin.org/delay/1" -UseBasicParsing -TimeoutSec 10
            } catch {
                # Ignore errors, just generating load
            }
            Start-Sleep -Seconds 3
        }
    } -ArgumentList $endTime
    
    return $job
}

# Function to create Windows Event Log entries
function Start-EventLogLoad {
    param([int]$Seconds)
    
    $endTime = (Get-Date).AddSeconds($Seconds)
    
    $job = Start-Job -ScriptBlock {
        param($EndTime)
        $counter = 0
        
        while ((Get-Date) -lt $EndTime) {
            try {
                # Create custom event log entries
                $eventId = 1000 + ($counter % 10)
                $message = "Test event generated for metrics collection - Counter: $counter"
                
                Write-EventLog -LogName Application -Source "Application" -EventId $eventId -Message $message -EntryType Information
            } catch {
                # If we can't write to Application log, skip
            }
            
            $counter++
            Start-Sleep -Seconds 5
        }
    } -ArgumentList $endTime
    
    return $job
}

# Start all load generation jobs
Write-Host "Starting CPU load generation..."
$cpuJobs = Start-CpuLoad -Seconds $DurationSeconds

Write-Host "Starting memory load generation..."
$memoryJob = Start-MemoryLoad -Seconds $DurationSeconds

Write-Host "Starting disk I/O load generation..."
$diskJob = Start-DiskLoad -Seconds $DurationSeconds

Write-Host "Starting network load generation..."
$networkJob = Start-NetworkLoad -Seconds $DurationSeconds

Write-Host "Starting event log generation..."
$eventJob = Start-EventLogLoad -Seconds $DurationSeconds

# Collect all jobs
$allJobs = $cpuJobs + $memoryJob + $diskJob + $networkJob + $eventJob

if (-not $Background) {
    # Wait for all jobs to complete if not running in background
    Write-Host "Waiting for load generation to complete..."
    
    $startTime = Get-Date
    while ((Get-Date) -lt $startTime.AddSeconds($DurationSeconds + 30)) {
        $runningJobs = $allJobs | Where-Object { $_.State -eq "Running" }
        
        if ($runningJobs.Count -eq 0) {
            Write-Host "All load generation jobs completed."
            break
        }
        
        Write-Host "Load generation in progress... ($($runningJobs.Count) jobs still running)"
        Start-Sleep -Seconds 10
    }
    
    # Clean up jobs
    $allJobs | Stop-Job -PassThru | Remove-Job
    Write-Host "Load generation completed and cleaned up."
} else {
    Write-Host "Load generation started in background. Jobs will run for $DurationSeconds seconds."
    Write-Host "Job IDs: $($allJobs.Id -join ', ')"
} 