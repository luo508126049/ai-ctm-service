param(
    [ValidateSet("start", "stop", "restart", "status")]
    [string]$Action = "restart",

    [string]$Profile = $env:SPRING_PROFILES_ACTIVE
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$RunDir = Join-Path $ProjectRoot ".run"
$PidFile = Join-Path $RunDir "frontend-service.pid"
$LogFile = Join-Path $RunDir "frontend-service.log"
$Port = 8984
$Url = "http://localhost:$Port/"
if (-not $Profile) {
    $Profile = "local"
}

function Use-JavaHome {
    $ConfiguredJavaHome = [Environment]::GetEnvironmentVariable("JAVA_HOME", "User")
    if (-not $ConfiguredJavaHome) {
        $ConfiguredJavaHome = [Environment]::GetEnvironmentVariable("JAVA_HOME", "Machine")
    }

    if (-not $ConfiguredJavaHome -or -not (Test-Path -LiteralPath (Join-Path $ConfiguredJavaHome "bin\java.exe"))) {
        $Jdk = Get-ChildItem -Path "C:\Program Files\Eclipse Adoptium" -Directory -ErrorAction SilentlyContinue |
            Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName "bin\java.exe") } |
            Sort-Object Name -Descending |
            Select-Object -First 1

        if ($Jdk) {
            $ConfiguredJavaHome = $Jdk.FullName
        }
    }

    if (-not $ConfiguredJavaHome -or -not (Test-Path -LiteralPath (Join-Path $ConfiguredJavaHome "bin\java.exe"))) {
        throw "JAVA_HOME is not configured and no local JDK was found. Install JDK 17 and try again."
    }

    $JavaBin = Join-Path $ConfiguredJavaHome "bin"
    $env:JAVA_HOME = $ConfiguredJavaHome
    if (($env:Path -split ";") -notcontains $JavaBin) {
        $env:Path = "$JavaBin;$env:Path"
    }
}

function Ensure-RunDir {
    if (-not (Test-Path -LiteralPath $RunDir)) {
        New-Item -ItemType Directory -Path $RunDir | Out-Null
    }
}

function Get-RecordedProcess {
    if (-not (Test-Path -LiteralPath $PidFile)) {
        return $null
    }

    $RawPid = Get-Content -LiteralPath $PidFile -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $RawPid) {
        return $null
    }

    $RecordedPid = $RawPid.Trim()
    if (-not $RecordedPid) {
        return $null
    }

    return Get-Process -Id ([int]$RecordedPid) -ErrorAction SilentlyContinue
}

function Get-PortProcess {
    $Connection = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $Connection) {
        return $null
    }

    $Process = Get-Process -Id $Connection.OwningProcess -ErrorAction SilentlyContinue
    if (-not $Process) {
        return $null
    }

    $CommandLine = ""
    $CimProcess = Get-CimInstance Win32_Process -Filter "ProcessId = $($Process.Id)" -ErrorAction SilentlyContinue
    if ($CimProcess) {
        $CommandLine = $CimProcess.CommandLine
    }

    return [PSCustomObject]@{
        Id = $Process.Id
        Name = $Process.ProcessName
        CommandLine = $CommandLine
    }
}

function Test-ProjectProcess($ProcessInfo) {
    if (-not $ProcessInfo) {
        return $false
    }

    return $ProcessInfo.CommandLine -like "*$ProjectRoot*"
}

function Test-PortOpen {
    return $null -ne (Get-PortProcess)
}

function Start-Frontend {
    Ensure-RunDir
    Use-JavaHome

    $ExistingProcess = Get-RecordedProcess
    if ($ExistingProcess) {
        Write-Host "Frontend service is already running. PID: $($ExistingProcess.Id)"
        Write-Host "URL: $Url"
        return
    }

    $PortProcess = Get-PortProcess
    if ($PortProcess) {
        if (Test-ProjectProcess $PortProcess) {
            Set-Content -LiteralPath $PidFile -Value $PortProcess.Id -Encoding ASCII
            Write-Host "Frontend service is already running. PID: $($PortProcess.Id)"
            Write-Host "URL: $Url"
            return
        }

        throw "Port $Port is already in use by $($PortProcess.Name) (PID: $($PortProcess.Id)). Stop that process first, then run this script again."
    }

    $MavenWrapper = Join-Path $ProjectRoot "mvnw.cmd"
    if (-not (Test-Path -LiteralPath $MavenWrapper)) {
        throw "Cannot find mvnw.cmd in project root: $ProjectRoot"
    }

    $Command = "cd /d `"$ProjectRoot`" && `"$MavenWrapper`" spring-boot:run -Dspring-boot.run.profiles=$Profile > `"$LogFile`" 2>&1"
    $Process = Start-Process -FilePath "cmd.exe" -ArgumentList "/c", $Command -WindowStyle Hidden -PassThru
    Set-Content -LiteralPath $PidFile -Value $Process.Id -Encoding ASCII

    Write-Host "Starting frontend service. PID: $($Process.Id)"
    Write-Host "Spring profile: $Profile"
    Write-Host "Log: $LogFile"

    $Started = $false
    for ($i = 0; $i -lt 30; $i++) {
        Start-Sleep -Seconds 1
        if (Test-PortOpen) {
            $Started = $true
            break
        }
        if (-not (Get-Process -Id $Process.Id -ErrorAction SilentlyContinue)) {
            break
        }
    }

    if ($Started) {
        Write-Host "Frontend is ready: $Url"
        return
    }

    Write-Warning "Service did not become ready within 30 seconds. Check the log file for details."
}

function Stop-Frontend {
    $ExistingProcess = Get-RecordedProcess
    if (-not $ExistingProcess) {
        $PortProcess = Get-PortProcess
        if (Test-ProjectProcess $PortProcess) {
            Write-Host "Stopping frontend service found on port $Port. PID: $($PortProcess.Id)"
            & taskkill.exe /PID $PortProcess.Id /T /F | Out-Null
            if (Test-Path -LiteralPath $PidFile) {
                Remove-Item -LiteralPath $PidFile -Force
            }
            Write-Host "Frontend service stopped."
            return
        }

        if (Test-Path -LiteralPath $PidFile) {
            Remove-Item -LiteralPath $PidFile -Force
        }
        Write-Host "Frontend service is not running."
        return
    }

    Write-Host "Stopping frontend service. PID: $($ExistingProcess.Id)"
    & taskkill.exe /PID $ExistingProcess.Id /T /F | Out-Null

    if (Test-Path -LiteralPath $PidFile) {
        Remove-Item -LiteralPath $PidFile -Force
    }

    Write-Host "Frontend service stopped."
}

function Show-Status {
    $ExistingProcess = Get-RecordedProcess
    if ($ExistingProcess) {
        Write-Host "Frontend service is running. PID: $($ExistingProcess.Id)"
        Write-Host "URL: $Url"
        Write-Host "Log: $LogFile"
        Write-Host "Default profile for next start: $Profile"
        return
    }

    $PortProcess = Get-PortProcess
    if ($PortProcess) {
        Write-Host "No recorded PID, but port $Port is listening."
        Write-Host "Process: $($PortProcess.Name) (PID: $($PortProcess.Id))"
        Write-Host "URL: $Url"
        return
    }

    Write-Host "Frontend service is stopped."
}

switch ($Action) {
    "start" { Start-Frontend }
    "stop" { Stop-Frontend }
    "restart" {
        Stop-Frontend
        Start-Frontend
    }
    "status" { Show-Status }
}
