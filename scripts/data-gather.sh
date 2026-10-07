#!/bin/bash

# HCL Universal Orchestrator - Docker Compose Data Gather Script
# Aligned with K8s data-gather script structure
# Includes OCLI definitions extraction
# Compatible with Bash 4.0+

set +e

# Default values
SKIP_DEFS=false
OCLI_PATH=""
OCLI_CONTEXT=""

# Help function
print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -o, --ocli-path <path>  [Optional] Path to OCLI executable (if omitted, will check system PATH)"
    echo "  -oc, --ocli-context <ctx> [Optional] Specify OCLI context for definitions extraction"
    echo "  -sd, --skip-defs        [Optional] Skip gathering definitions from OCLI"
    echo ""
    echo "Examples:"
    echo "  $0"
    echo "  $0 --ocli-path /usr/local/bin/ocli"
    echo "  $0 --skip-defs"
    echo "  $0 --ocli-path /usr/bin/ocli --ocli-context production"
}

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help) print_usage; exit 0 ;;
        -o|--ocli-path) OCLI_PATH="$2"; shift 2 ;;
        -oc|--ocli-context) OCLI_CONTEXT="$2"; shift 2 ;;
        -sd|--skip-defs) SKIP_DEFS=true; shift ;;
        *) echo "Unknown option: $1"; print_usage; exit 1 ;;
    esac
done

# Color functions
red()     { echo -e "\e[31m$*\e[0m"; }
yellow()  { echo -e "\e[33m$*\e[0m"; }
green()   { echo -e "\e[32m$*\e[0m"; }
cyan()    { echo -e "\e[36m$*\e[0m"; }
magenta() { echo -e "\e[35m$*\e[0m"; }

# Print OCLI command being executed
print_ocli_command() {
    local cmd=("$@")
    local formatted
    printf -v formatted '%q ' "${cmd[@]}"
    cyan "Executing: ${formatted% }"
}

# Check for existing folders/files
check_existing_folders() {
    for folder in logs definitions configuration; do
        if [ -d "$folder" ]; then
            yellow "Folder '$folder' already exists."
            read -r -p "Do you want to remove it before proceeding? [y/N]: " answer
            case "$answer" in
                [yY][eE][sS]|[yY])
                    rm -rf "$folder"
                    green "Folder '$folder' removed."
                    ;;
                *)
                    red "Cannot proceed with existing '$folder' folder. Remove it manually and rerun the script."
                    exit 1
                    ;;
            esac
        fi
    done

    if [ -f "data-gather.zip" ]; then
        yellow "File 'data-gather.zip' already exists."
        read -r -p "Do you want to remove it before proceeding? [y/N]: " answer
        case "$answer" in
            [yY][eE][sS]|[yY])
                rm -f "data-gather.zip"
                green "File 'data-gather.zip' removed."
                ;;
            *)
                red "Cannot proceed with existing 'data-gather.zip'. Remove it manually and rerun the script."
                exit 1
                ;;
        esac
    fi
}

# Gather logs and configuration, create archive
gather_logs() {
    cyan "Gathering logs using Docker"

    mkdir -p logs

    # System and Docker info
    echo "  Collecting system information..."
    {
        echo "=== System Information ==="
        echo "Generated: $(date)"
        echo "Bash Version: $BASH_VERSION"
        echo ""
        echo "=== Docker Information ==="
        docker --version
        echo ""
        echo "=== Container Status ==="
        docker ps -a
    } > logs/system_info.txt 2>&1

    # Docker Compose logs
    echo "  Collecting Docker Compose logs..."
    {
        echo "=== Docker Compose Logs ==="
        echo "Generated: $(date)"
        echo ""
        docker compose logs --timestamps
    } > logs/docker_compose_logs.txt 2>&1

    # Individual container logs
    echo "  Collecting container logs..."
    mkdir -p logs/container_logs
    local containers
    containers=$(docker ps -a --format='{{.Names}}' 2>&1)
    local container_count=0

    while IFS= read -r container; do
        if [ -n "$container" ] && [ "$container" != "NAMES" ]; then
            local sanitized
            sanitized=$(echo "$container" | sed 's/[^a-zA-Z0-9._-]/_/g')
            docker logs --timestamps "$container" > "logs/container_logs/${sanitized}_logs.txt" 2>&1
            ((container_count++))
        fi
    done <<< "$containers"

    echo "  Collected logs from $container_count containers"

    # Health status
    echo "  Collecting health status..."
    {
        echo "=== Container Health Status ==="
        echo "Generated: $(date)"
        echo ""
        docker ps -a
    } > logs/health_status.txt 2>&1

    cyan "Finished gathering logs"

    # Gather configuration
    cyan "Gathering configuration"

    mkdir -p configuration

    # Docker Compose file
    echo "  Collecting Docker Compose configuration..."
    if [ -f "docker-compose.yml" ]; then
        cp "docker-compose.yml" "configuration/docker-compose.yml"
        echo "    Found docker-compose.yml"
    elif [ -f "docker-compose.yaml" ]; then
        cp "docker-compose.yaml" "configuration/docker-compose.yaml"
        echo "    Found docker-compose.yaml"
    else
        yellow "    No docker-compose file found"
    fi

    # Infrastructure information
    echo "  Collecting Docker infrastructure..."
    {
        echo "=== Docker Networks ==="
        docker network ls
        echo ""
        echo "=== Docker Volumes ==="
        docker volume ls
        echo ""
        echo "=== Container Details ==="

        local containers
        containers=$(docker ps -a --format='{{.Names}}' 2>&1)
        while IFS= read -r container; do
            if [ -n "$container" ] && [ "$container" != "NAMES" ]; then
                echo ""
                echo "--- Container: $container ---"
                docker inspect "$container"
            fi
        done <<< "$containers"
    } > configuration/docker_infrastructure.txt 2>&1

    # Environment files
    echo "  Collecting environment configuration..."
    mkdir -p configuration/environment
    local env_count=0

    for env_file in *.env .env*; do
        if [ -f "$env_file" ]; then
            {
                while IFS= read -r line; do
                    if [[ "$line" =~ PASSWORD|TOKEN|SECRET|KEY|CREDENTIAL ]]; then
                        echo "${line%%=*}=***REDACTED***"
                    else
                        echo "$line"
                    fi
                done < "$env_file"
            } > "configuration/environment/$env_file"
            ((env_count++))
        fi
    done

    if [ $env_count -gt 0 ]; then
        echo "    Found and collected $env_count environment file(s)"
    else
        yellow "    No environment files found"
    fi

    cyan "Finished gathering configuration"

    # Create archive with logs and configuration
    cyan "Creating data-gather.zip archive..."

    if ! zip -r data-gather.zip logs configuration > /dev/null 2>&1; then
        red "Failed to create archive. Please check if zip is installed and try again."
        exit 1
    fi

    green "Created data-gather.zip"

    # Cleanup logs and configuration directories
    rm -rf logs configuration

    cyan "Logs and configuration gathering completed."
    return 0
}

# Gather definitions from OCLI
gather_definitions() {
    local ocli_path="$1"
    local ocli_context="$2"
    local context_args=()

    if [ -n "$ocli_context" ]; then
        context_args=(-context "$ocli_context")
        cyan "Gathering definitions using OCLI at $ocli_path with context: $ocli_context"
    else
        cyan "Gathering definitions using OCLI at $ocli_path using current context"
    fi

    mkdir definitions
    local cmd

    cmd=("$ocli_path" "${context_args[@]}" model extract definitions/allJobs.txt from jd=@/@#@/@)
    print_ocli_command "${cmd[@]}"
    "${cmd[@]}"

    cmd=("$ocli_path" "${context_args[@]}" model extract definitions/allJobStreams.txt from js=@/@#@/@)
    print_ocli_command "${cmd[@]}"
    "${cmd[@]}"

    cmd=("$ocli_path" "${context_args[@]}" model extract definitions/allWorkstations.txt from ws=@/@)
    print_ocli_command "${cmd[@]}"
    "${cmd[@]}"

    cmd=("$ocli_path" "${context_args[@]}" model extract definitions/allUsers.txt from user=@/@#@)
    print_ocli_command "${cmd[@]}"
    "${cmd[@]}"

    cmd=("$ocli_path" "${context_args[@]}" model extract definitions/allCalendar.txt from cal=@/@)
    print_ocli_command "${cmd[@]}"
    "${cmd[@]}"

    cmd=("$ocli_path" "${context_args[@]}" model extract definitions/allFolders.txt from fol=@/@)
    print_ocli_command "${cmd[@]}"
    "${cmd[@]}"

    cmd=("$ocli_path" "${context_args[@]}" model extract definitions/allACL.txt from acl=@)
    print_ocli_command "${cmd[@]}"
    "${cmd[@]}"

    cmd=("$ocli_path" "${context_args[@]}" model extract definitions/allRoles.txt from srol=@)
    print_ocli_command "${cmd[@]}"
    "${cmd[@]}"

    cmd=("$ocli_path" "${context_args[@]}" model extract definitions/allVariableTables.txt from vt=@/@)
    print_ocli_command "${cmd[@]}"
    "${cmd[@]}"

    cmd=("$ocli_path" "${context_args[@]}" model extract definitions/allAPIKeys.txt from api=@)
    print_ocli_command "${cmd[@]}"
    "${cmd[@]}"

    cmd=("$ocli_path" "${context_args[@]}" model extract definitions/allEventSources.txt from eventsource=@/@)
    print_ocli_command "${cmd[@]}"
    "${cmd[@]}"

    cmd=("$ocli_path" "${context_args[@]}" model extract definitions/allResources.txt from res=@/@)
    print_ocli_command "${cmd[@]}"
    "${cmd[@]}"

    cmd=("$ocli_path" "${context_args[@]}" model extract definitions/allHumanTaskQueues.txt from htq=@/@)
    print_ocli_command "${cmd[@]}"
    "${cmd[@]}"

    cmd=("$ocli_path" "${context_args[@]}" model extract definitions/allAIAgents.txt from aiagent=@/@)
    print_ocli_command "${cmd[@]}"
    "${cmd[@]}"

    cmd=("$ocli_path" "${context_args[@]}" model extract definitions/allEndpoints.txt from endpoints=@/@)
    print_ocli_command "${cmd[@]}"
    "${cmd[@]}"

    cmd=("$ocli_path" "${context_args[@]}" model extract definitions/allRunCycleGroups.txt from rcg=@/@)
    print_ocli_command "${cmd[@]}"
    "${cmd[@]}"

    cyan "Definitions extraction completed."

    green "Extracted $defs_collected definition files"

    cyan "Adding extracted definitions to data-gather.zip file..."
    zip -r data-gather.zip definitions
    local updateZipCode=$?
    if [ $updateZipCode -ne 0 ]; then
        red "Failed to update data-gather.zip with definitions."
        rm -rf definitions
        return $updateZipCode
    fi

    cyan "Added extracted definitions to data-gather.zip file."
    rm -rf definitions
    cyan "Definitions gathering completed."
    return 0
}

# Prompt for OCLI context if needed
prompt_ocli_context_if_needed() {
    if [ "$SKIP_DEFS" = true ] || [ -n "$OCLI_CONTEXT" ]; then
        return 0
    fi

    local max_confirmation_attempts=3
    local confirmation_attempt=1
    local use_current_context

    while [ $confirmation_attempt -le $max_confirmation_attempts ]; do
        read -r -p "Use current OCLI context for definitions extraction? [Y/n]: " use_current_context
        case "$use_current_context" in
            ""|[yY]|[yY][eE][sS])
                OCLI_CONTEXT=""
                return 0
                ;;
            [nN]|[nN][oO])
                break
                ;;
            *)
                yellow "Please answer y or n."
                ;;
        esac
        ((confirmation_attempt++))
    done

    if [ $confirmation_attempt -gt $max_confirmation_attempts ]; then
        red "No valid answer provided. Exiting."
        exit 1
    fi

    local max_context_attempts=3
    local context_attempt=1
    while [ $context_attempt -le $max_context_attempts ]; do
        read -r -p "Enter OCLI context name: " OCLI_CONTEXT
        if [ -n "$OCLI_CONTEXT" ]; then
            return 0
        fi
        yellow "OCLI context cannot be empty."
        ((context_attempt++))
    done

    red "No OCLI context provided. Exiting."
    exit 1
}

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    red "Docker is not installed or not found in PATH. Please install Docker to proceed."
    exit 1
fi

magenta "=========================================="
magenta " Universal Orchestrator Data Gather Script"
magenta "=========================================="
echo ""

check_existing_folders

# Gather logs and configuration, create archive
gather_logs
logGatherExitCode=$?
if [ $logGatherExitCode -ne 0 ]; then
    exit $logGatherExitCode
fi

# Handle definitions gathering
if [ -z "$OCLI_PATH" ] && [ "$SKIP_DEFS" = false ]; then
    if command -v ocli &> /dev/null; then
        OCLI_PATH="ocli"
        cyan "Found OCLI in PATH. It will be used for definitions gathering."
    else
        yellow "OCLI path not provided and not found in PATH. Definitions gathering will be skipped."
        yellow "Provide OCLI path with --ocli-path parameter to gather definitions."
        SKIP_DEFS=true
    fi
fi

if [ "$SKIP_DEFS" = true ]; then
    yellow "Skipping definitions gathering."
    exit 0
fi

prompt_ocli_context_if_needed

gather_definitions "$OCLI_PATH" "$OCLI_CONTEXT"
definitionsExitCode=$?
if [ $definitionsExitCode -ne 0 ]; then
    exit $definitionsExitCode
fi

echo ""
green "Data collection completed successfully!"
echo ""
echo "Output file: data-gather.zip"
echo ""
cyan "Next steps:"
echo "  1. Review the archive contents"
echo "  2. Verify no sensitive data was included"
echo "  3. Share with HCL Support if needed"
echo ""

exit 0
