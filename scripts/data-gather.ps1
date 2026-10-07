# HCL Universal Orchestrator - Docker Compose Data Gather Script
# Aligned with K8s data-gather script structure
# Includes OCLI definitions extraction
# Compatible with PowerShell 5.0+

param(
    [switch]$Help = $false,
    [string]$OcliPath = "",
    [string]$OcliContext = "",
    [switch]$SkipDefs = $false
)

# Help function
function Print-Usage {
    Write-Host "Usage: .\data-gather.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Help           Show this help message"
    Write-Host "  -OcliPath <path> [Optional] Path to OCLI executable (if omitted, will check system PATH)"
    Write-Host "  -OcliContext <ctx> [Optional] Specify OCLI context for definitions extraction"
    Write-Host "  -SkipDefs       [Optional] Skip gathering definitions from OCLI"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\data-gather.ps1"
    Write-Host "  .\data-gather.ps1 -OcliPath C:\ocli\ocli.exe"
    Write-Host "  .\data-gather.ps1 -SkipDefs"
    exit 0
}

# Color functions for output
function Write-Header {
    param([string]$Message)
    Write-Host "================================================== " -ForegroundColor Magenta
    Write-Host " $Message" -ForegroundColor Magenta
    Write-Host "================================================== " -ForegroundColor Magenta
}

function Write-Success {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Red
}

function Write-Info {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Cyan
}

# Format OCLI command for display
function Format-OcliCommand {
    param([string[]]$Arguments)
    return ($Arguments -join ' ')
}

# Write OCLI command being executed
function Write-OcliCommand {
    param(
        [string]$OcliPath,
        [string[]]$OcliArgs,
        [string[]]$CommandArgs
    )
    $command = @($OcliPath) + @($OcliArgs) + @($CommandArgs)
    Write-Info "Executing: $(Format-OcliCommand -Arguments $command)"
}

# Show help if requested
if ($Help) {
    Print-Usage
}

# Validate Docker is installed
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Error "Docker is not installed or not found in PATH. Please install Docker to proceed."
    exit 1
}

Write-Header "Universal Orchestrator Data Gather Script"
Write-Host ""

# Check for existing folders/files
function Check-ExistingFolders {
    $foldersToCheck = @("logs", "configuration", "definitions")

    foreach ($folder in $foldersToCheck) {
        if (Test-Path $folder) {
            Write-Warning "Folder '$folder' already exists."
            $response = Read-Host "Do you want to remove it before proceeding? [y/N]"
            if ($response -eq 'y' -or $response -eq 'Y') {
                Remove-Item -Recurse -Force $folder
                Write-Success "Folder '$folder' removed."
            } else {
                Write-Error "Cannot proceed with existing '$folder' folder. Remove it manually and rerun the script."
                exit 1
            }
        }
    }

    if (Test-Path "data-gather.zip") {
        Write-Warning "File 'data-gather.zip' already exists."
        $response = Read-Host "Do you want to remove it before proceeding? [y/N]"
        if ($response -eq 'y' -or $response -eq 'Y') {
            Remove-Item -Force "data-gather.zip"
            Write-Success "File 'data-gather.zip' removed."
        } else {
            Write-Error "Cannot proceed with existing 'data-gather.zip'. Remove it manually and rerun the script."
            exit 1
        }
    }
}

# Gather logs and configuration, create archive
function Gather-Logs {
    Write-Info "Gathering logs using Docker"

    # Create logs directory
    New-Item -ItemType Directory -Path "logs" -Force > $null

    # System and Docker info
    Write-Host "  Collecting system information..."
    @"
=== System Information ===
Generated: $(Get-Date)
PowerShell Version: $($PSVersionTable.PSVersion)

=== Docker Information ===
$(docker --version)

=== Container Status ===
"@ | Out-File -FilePath "logs\system_info.txt" -Encoding utf8
    cmd /c "docker ps -a >> logs\system_info.txt 2>&1"

    # Docker Compose logs
    Write-Host "  Collecting Docker Compose logs..."
    @"
=== Docker Compose Logs ===
Generated: $(Get-Date)

"@ | Out-File -FilePath "logs\docker_compose_logs.txt" -Encoding utf8
    cmd /c "docker compose logs --timestamps >> logs\docker_compose_logs.txt 2>&1"

    # Individual container logs
    Write-Host "  Collecting container logs..."
    New-Item -ItemType Directory -Path "logs\container_logs" -Force > $null
    $containers = @(& docker ps -a --format='{{.Names}}' 2>&1 | Where-Object { $_ -notmatch "warning|LC_ALL" })
    $containerCount = 0

    foreach ($container in $containers) {
        if ($container -and $container -ne "NAMES") {
            $sanitized = $container -replace '[^a-zA-Z0-9._-]', '_'
            cmd /c "docker logs --timestamps $container > logs\container_logs\$sanitized`_logs.txt 2>&1"
            $containerCount++
        }
    }

    Write-Host "  Collected logs from $containerCount containers"

    # Health status
    Write-Host "  Collecting health status..."
    @"
=== Container Health Status ===
Generated: $(Get-Date)

"@ | Out-File -FilePath "logs\health_status.txt" -Encoding utf8
    cmd /c "docker ps -a >> logs\health_status.txt 2>&1"

    Write-Info "Finished gathering logs"

    # Gather configuration
    Write-Info "Gathering configuration"

    # Create configuration directory
    New-Item -ItemType Directory -Path "configuration" -Force > $null

    # Docker Compose file
    Write-Host "  Collecting Docker Compose configuration..."
    if (Test-Path "docker-compose.yml") {
        Copy-Item -Path "docker-compose.yml" -Destination "configuration\docker-compose.yml" -Force
        Write-Host "    Found docker-compose.yml"
    } elseif (Test-Path "docker-compose.yaml") {
        Copy-Item -Path "docker-compose.yaml" -Destination "configuration\docker-compose.yaml" -Force
        Write-Host "    Found docker-compose.yaml"
    } else {
        Write-Warning "    No docker-compose file found"
    }

    # Infrastructure information
    Write-Host "  Collecting Docker infrastructure..."
    @"
=== Docker Networks ===
"@ | Out-File -FilePath "configuration\docker_infrastructure.txt" -Encoding utf8
    cmd /c "docker network ls >> configuration\docker_infrastructure.txt 2>&1"
    @"

=== Docker Volumes ===
"@ | Out-File -FilePath "configuration\docker_infrastructure.txt" -Encoding utf8 -Append
    cmd /c "docker volume ls >> configuration\docker_infrastructure.txt 2>&1"
    @"

=== Container Details ===
"@ | Out-File -FilePath "configuration\docker_infrastructure.txt" -Encoding utf8 -Append

    $containers = @(& docker ps -a --format='{{.Names}}' 2>&1 | Where-Object { $_ -notmatch "warning|LC_ALL" })
    foreach ($container in $containers) {
        if ($container -and $container -ne "NAMES") {
            @"

--- Container: $container ---
"@ | Out-File -FilePath "configuration\docker_infrastructure.txt" -Encoding utf8 -Append
            cmd /c "docker inspect $container >> configuration\docker_infrastructure.txt 2>&1"
        }
    }

    # Environment files
    Write-Host "  Collecting environment configuration..."
    $envDir = "configuration\environment"
    New-Item -ItemType Directory -Path $envDir -Force > $null

    $envCount = 0
    Get-ChildItem -Path "." -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*.env" -or $_.Name -like ".env*" } | ForEach-Object {
        $content = Get-Content -Path $_.FullName -ErrorAction SilentlyContinue
        if ($content) {
            $output = @()
            foreach ($line in $content) {
                if ($line -match "PASSWORD|TOKEN|SECRET|KEY|CREDENTIAL") {
                    $output += ($line -replace "=.*", "=***REDACTED***")
                } else {
                    $output += $line
                }
            }
            $output -join [Environment]::NewLine | Out-File -FilePath (Join-Path $envDir $_.Name) -NoNewline -Force
            $envCount++
        }
    }

    if ($envCount -gt 0) {
        Write-Host "    Found and collected $envCount environment file(s)"
    } else {
        Write-Warning "    No environment files found"
    }

    Write-Info "Finished gathering configuration"

    # Create archive with logs and configuration
    Write-Info "Creating data-gather.zip archive..."
    try {
        Compress-Archive -Path "logs", "configuration" -DestinationPath "data-gather.zip" -Force -ErrorAction Stop
        Write-Success "Created data-gather.zip"
    } catch {
        Write-Error "Failed to create archive: $_"
        exit 1
    }

    # Cleanup logs and configuration directories
    Remove-Item -Recurse -Force "logs"
    Remove-Item -Recurse -Force "configuration"

    Write-Info "Logs and configuration gathering completed."
}

# Gather definitions from OCLI
function Gather-Definitions {
    param([string]$OcliPath, [string]$OcliContext)

    Write-Info "Gathering definitions using OCLI"

    New-Item -ItemType Directory -Path "definitions" -Force > $null

    $ocliArgs = @()
    if (-not [string]::IsNullOrWhiteSpace($OcliContext)) {
        $ocliArgs += "-context"
        $ocliArgs += $OcliContext
        Write-Info "Gathering definitions using OCLI at $OcliPath with context: $OcliContext"
    } else {
        Write-Info "Gathering definitions using OCLI at $OcliPath using current context"
    }

    # Array of OCLI extracts
    $extracts = @(
        @{name = "allJobs.txt"; query = "from jd=@/@#@/@"},
        @{name = "allJobStreams.txt"; query = "from js=@/@#@/@"},
        @{name = "allWorkstations.txt"; query = "from ws=@/@"},
        @{name = "allUsers.txt"; query = "from user=@/@#@"},
        @{name = "allCalendar.txt"; query = "from cal=@/@"},
        @{name = "allFolders.txt"; query = "from fol=@/@"},
        @{name = "allACL.txt"; query = "from acl=@"},
        @{name = "allRoles.txt"; query = "from srol=@"},
        @{name = "allVariableTables.txt"; query = "from vt=@/@"},
        @{name = "allAPIKeys.txt"; query = "from api=@"},
        @{name = "allEventSources.txt"; query = "from eventsource=@/@"},
        @{name = "allResources.txt"; query = "from res=@/@"},
        @{name = "allHumanTaskQueues.txt"; query = "from htq=@/@"},
        @{name = "allAIAgents.txt"; query = "from aiagent=@/@"},
        @{name = "allEndpoints.txt"; query = "from endpoints=@/@"},
        @{name = "allRunCycleGroups.txt"; query = "from rcg=@/@"}
    )

    $defsCollected = 0

    foreach ($extract in $extracts) {
        Write-Host "  Extracting $($extract.name)..."
        # Use forward slashes for OCLI path compatibility
        $outputPath = "definitions/$($extract.name)"
        $commandArgs = @('model', 'extract', $outputPath, $extract.query)
        Write-OcliCommand -OcliPath $OcliPath -OcliArgs $ocliArgs -CommandArgs $commandArgs

        # Execute OCLI - it will write directly to the output file
        & $OcliPath @ocliArgs @commandArgs 2>&1 > $null
        if ($LASTEXITCODE -eq 0) {
            $defsCollected++
        } else {
            Write-Warning "  Failed to extract $($extract.name)"
        }
    }

    Write-Success "Extracted $defsCollected definition files"
    Write-Info "Definitions extraction completed."
}

# Resolve OCLI context interactively
function Resolve-OcliContext {
    if ($SkipDefs -or -not [string]::IsNullOrWhiteSpace($OcliContext)) {
        return
    }

    $maxConfirmationAttempts = 3
    for ($attempt = 1; $attempt -le $maxConfirmationAttempts; $attempt++) {
        $useCurrentContext = Read-Host "Use current OCLI context for definitions extraction? [Y/n]"
        if ([string]::IsNullOrWhiteSpace($useCurrentContext) -or $useCurrentContext -match '^[yY]([eE][sS])?$') {
            $global:OcliContext = ""
            return
        }

        if ($useCurrentContext -match '^[nN]([oO])?$') {
            break
        }

        Write-Warning "Please answer y or n."

        if ($attempt -eq $maxConfirmationAttempts) {
            Write-Error "No valid answer provided. Exiting."
            exit 1
        }
    }

    $maxContextAttempts = 3
    for ($attempt = 1; $attempt -le $maxContextAttempts; $attempt++) {
        $typedContext = Read-Host "Enter OCLI context name"
        if (-not [string]::IsNullOrWhiteSpace($typedContext)) {
            $global:OcliContext = $typedContext
            return
        }

        Write-Warning "OCLI context cannot be empty."
    }

    Write-Error "No OCLI context provided. Exiting."
    exit 1
}

# Main execution
Check-ExistingFolders

# Gather logs and configuration, create archive
Gather-Logs

# Handle definitions gathering
if (-not $OcliPath -and -not $SkipDefs) {
    if (Get-Command ocli -ErrorAction SilentlyContinue) {
        $OcliPath = (Get-Command ocli).Source
        Write-Info "Found OCLI in PATH. It will be used for definitions gathering."
    } else {
        Write-Warning "OCLI path not provided and not found in PATH. Definitions gathering will be skipped."
        Write-Warning "Provide OCLI path with -OcliPath parameter to gather definitions."
        $SkipDefs = $true
    }
}

if ($SkipDefs) {
    Write-Warning "Skipping definitions gathering."
    exit 0
}

Resolve-OcliContext

# Gather definitions and update archive
Gather-Definitions -OcliPath $OcliPath -OcliContext $OcliContext

Write-Info "Adding extracted definitions to data-gather.zip file..."
try {
    Compress-Archive -Path "definitions" -Update -DestinationPath "data-gather.zip" -ErrorAction Stop
    Write-Success "Added extracted definitions to data-gather.zip file."
    Remove-Item -Recurse -Force "definitions"
} catch {
    Write-Error "Failed to update data-gather.zip with definitions: $_"
    if (Test-Path "definitions") {
        Remove-Item -Recurse -Force "definitions"
    }
    exit 1
}

Write-Host ""
Write-Success "Data collection completed successfully!"
Write-Host ""
Write-Host "Output file: data-gather.zip"
Write-Host ""
Write-Info "Next steps:"
Write-Host "  1. Review the archive contents"
Write-Host "  2. Verify no sensitive data was included"
Write-Host "  3. Share with HCL Support if needed"
Write-Host ""

exit 0
