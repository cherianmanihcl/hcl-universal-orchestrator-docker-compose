How to collect data using data gather script
------------

The data-gather script collects comprehensive diagnostic information from an HCL Universal Orchestrator environment that runs on Docker compose. Use this script to capture system configuration, infrastructure topology, and service logs when you troubleshoot issues or escalate cases to HCL Support. 

The data collection script is designed to run non-intrusively in live production environments without interrupting ongoing system operations. It is safe to run while all application components and services are actively running, ensuring zero downtime or service disruption. Throughout the collection process, no containers are stopped, restarted, or modified.

Prerequisites
-------------

Before you run the data gather script, ensure that your environment meets the following requirements.

*   PowerShell: Version 5.0 or later (Windows)
    
*   Bash 4.0 or later (Linux)
    
*   Disk space: Typically, 100 MB to 500 MB of free disk space is required to store the collected logs. Because the script generates temporary working files during collection, ensure that the host system has available free space equal to approximately three times the log size.
    
*   (Optional) Path to the OCLI executable to extract definitions with a preconfigured context. If not provided, the script will try to use the OCLI available in the system PATH.
    

Procedure: Running the data collection script
---------------------------------------------

Follow these steps to run the data collection script from your deployment environment.

*   Windows platforms (PowerShell)
    

  1.  Open PowerShell and navigate to the directory where your **docker-compose.yml** file is located:
    

      `cd ["path_to_docker_compose"]`

  2.  Run the data-gather.ps1 script:
    

      `.\\data-gather.ps1 -OcliPath [path_to_ocli.exe] -OcliContext [context_name]`

Where:

*   **\-OcliPath**
    
    Optional parameter. Specify the file path to the Orchestration CLI executable (ocli.exe).

*   **\-OcliContext**
    
    Optional paramaeter. Specify the context name to query. If you omit this parameter, the script extracts model type definitions for the current context specified in your **config.yaml** file.

    **Notes**:

      *    Omitting definitions: To extract only logs and configuration files without extracting model type definitions, run the script with the `-SkipDefs` parameter:
    
      `.\\data-gather.ps1 -SkipDefs`

    *   Automatic CLI detection: If you do not specify the `-OcliPath` parameter and **ocli.exe** is installed and available in your system path, the script automatically detects the Orchestration CLI to extract definitions.
    

*   Linux or UNIX platforms (Bash)
    

1.  Open a terminal command line and navigate to the directory where your docker-compose.yml file is located:
    

    `cd [path_to_docker_compose]`

2.  Run the data-gather.sh script:
    

    `./data-gather.sh --ocli-path [path_to_ocli] --ocli-context [context_name]`

Where:

*  **--ocli-path**
    
    Specify the file path to the Orchestration CLI executable (ocli.exe).

*   **--ocli-context**
  
    Specify the context name to query. If you omit this parameter, the script extracts model type definitions for the current context specified in your **config.yaml** file.

     **Notes**:
     *   Omitting definitions: To extract only logs and configuration files without extracting model type definitions, run the script with the `-SkipDefs` parameter:
    
    `.\\[data-gather.sh](http://data-gather.sh) - -SkipDefs`

    *   Automatic CLI detection: If you do not specify the `-OcliPath` parameter and **ocli.exe** is installed and available in your system path, the script automatically detects the Orchestration CLI to extract definitions.
    

Folder structure and file management
------------------------------------

By default, the data collection script creates a compressed archive **data-gather.zip** in your current working directory. 

When you decompress the archive, it expands into a root directory containing three primary subdirectories: logs, configuration, and definitions.

*   **Logs directory**
    

    The **logs** directory organizes diagnostic logs and system telemetry into the following files and subdirectories:

    *   System\_info.txt
    
    Captures the underlying host and virtualization environment details, including the PowerShell or shell version (to verify script compatibility), the installed Docker engine version, and a snapshot of all active and stopped containers. Use this file to verify your deployment environment.

    *   Docker\_compose\_logs.txt
    
    Contains the complete, aggregated Docker Compose logs captured across all services in chronological order. Review this file to observe the entire system startup sequence and trace initialization or startup errors.

    *   Health\_status.txt
    
    Provides a real-time status and uptime snapshot for every container in the Docker Compose environment, categorizing services by state (such as running, exited, or error). Use this file to quickly identify unhealthy or terminated services.

    *   Container\_logs
    
    Contains separate, service-specific log files for each container in the deployment (for example, uno-server\_logs.txt and uno-agent\_logs.txt). Use these individual log files to isolate errors within a specific microservice without sorting through the entire aggregated log bundle.

*   **Configuration**
    
    The **configuration** directory stores environmental settings, orchestration templates, and infrastructure specifications:

    *   Docker\_infrastructure.txt
    
    Provides detailed Docker infrastructure metadata, including network configurations, persistent volume mounts and target paths, container network settings, driver information, and configured resource limits. Use this file to inspect container definitions and network connectivity.

    *   docker-compose.yml (or .yaml)
    

    A copy of the Docker Compose configuration file used to deploy the services.

*   **Environment**
    

    A subdirectory containing the application configuration files collected from the deployment directory, such as **uno.env**, **main.env**, **pilot.env**, and any other **\*.env** files. These files contain port mappings, runtime memory limits, and service-specific network settings. Sensitive values (such as passwords, keys, and tokens) are automatically redacted.

*   **Definitions**
    

    An optional directory created only if the Orchestration CLI  is installed in your environment. This directory contains all extracted model type definitions.