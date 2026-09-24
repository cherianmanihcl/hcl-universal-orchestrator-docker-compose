# Deploying HCL Universal Orchestrator using Docker or Podman

HCL Universal Orchestrator is a modern process orchestration solution designed for deployment via container platforms across public or private cloud environments. A container-based deployment using Docker or Podman ensures a fast and efficient way to launch your environment quickly. It simplifies maintenance, lowers deployment complexity, minimizes IT requirements, and you can quickly set up self-contained orchestration environments. 
The uno-all-in-one-compose package provides the UnO core and optional services. It is designed for environments where you want to manage your prerequisite services independently. To respond to the growing request to make automation opportunities more accessible, HCL Universal Orchestrator containers can be deployed using the following 
supported tools:

**Docker compose**: For standard Docker environments.

**Podman compose**: For daemonless Linux container management, natively utilizing the :z SELinux label for shared volume access.

## Document overview

This document includes the following topics:

 * [Package contents](#Package-contents)
 * [Prerequisites](#Prerequisites)
 * [Resources required](#Resources-required)
 * [Services overview](#Services-overview)
 * [Compose profiles](#Compose-profiles)
 * [Deployment](#Deployment)
 * [Verifying the deployment](#Verifying-the-deployment)
 * [Exposed ports](#Exposed-ports)
 * [Deploying multiple instances of HCL Universal Orchestrator](#Deploying-multiple-instances-of-HCL-Universal-Orchestrator)
 * [Stopping the deployment](#Stopping-the-deployment)
 * [Troubleshooting](#Troubleshooting)
 * [Documentation and Support](#Documentation-and-Support)

## Package contents

The compressed file contains the following files, scripts, and folder:
* **docker-compose.yml**: This file defines the UnO services, including console-aio, externalpod, plugins, agentic, and pilot.
* **main.env**: This file centralizes configuration parameters, such as registry credentials, connectivity settings, and secrets.
* **uno.env**: The environment configuration file that contains unparsed values acting as placeholders. During the deployment, the placeholders in this file dynamically pull their concrete data from the values that you specify in the **main.env** file. 
* **agenticbuilder.env**: This file contains the configuration parameters for the Agentic AI Builder services.
* **pilot.env**: The file contains the attributes that you configure to connect to AI pilot. 
* **downloadImages.sh/.ps1**: These scripts download all required images to a portable **.tar** archive.
* **loadImages.sh/.ps1**: These scripts load images from the **.tar** archive into the local container registry.
* **engines**: This folder contains the **uno.json** file, which specifies the engine connection configuration.
* **scripts**: The folder contains the following scripts:
    *    **generate-certs.sh**: Automatically generates all TLS certificates during the first installation.
    * **fix-files.sh**: Fixes PGVector file permissions and applies the database configuration.
* **security**: Stores the TLS certificates that are automatically generated during deployment.



## Prerequisites

Before you begin verify that your environment meets the following requirements. Configure the connection details for these services in the `main.env` file.

* Podman: Version 5 or later.
* Docker: Installing Docker by using APT is recommended for deployment. If you use Docker installed by using snap, extract the Docker Compose zip files to a user system directory (for example, `/home/ or /home/<username>/`) to avoid permission issues caused by snap confinement.
* Messaging system : Apache Kafka v 3.9 or later OR Redpanda v 25.3 or later. For more information, see [Kafka documentation](https://kafka.apache.org/43/getting-started/) or [Redpanda](https://docs.redpanda.com/agentic-data-plane/home/).
* Database : MongoDB v 8 or later OR Azure DocumentDB (formerly known as Azure Cosmos DB for MongoDB vCore) OR AWS DocumentDB v 5 
	(Note: Support for the DocumentDB platform is strictly limited to Instance-based clusters only). For more information, see [MongoDB documentation](https://www.mongodb.com/docs/) or [Azure Cosmos DB documentation](https://learn.microsoft.com/en-us/azure/cosmos-db/) or [AWS documentation](https://docs.aws.amazon.com/documentdb/).
* Enablement of an OIDC provider for authentication. To configure keycloak as the OIDC provider, see [keycloak documentation](https://www.keycloak.org/documentation).
* Valkey: Version 7 or later is required to configure Agentic AI Builder. 
* PostgreSQL + pgvector (17): required to configure Agentic AI Builder or AI pilot. For more information, see [Installing Required Dependencies (Valkey and PostgreSQL)](https://help.hcl-software.com/UnO/ContinuousDelivery/UnO%20Agentic%20AI%20Builder/agenticai__installation213.html)
* Create a Keycloak realm named 'uno' with the `uno-service` client configured. 
* HCL Universal Orchestrator services communicate over TLS. The certificates are automatically generated and stored in the security folder. If you prefer to use specific certificates, you must provide certificates for the following:

	- The UnO console (`security/certs/`)
	- JWT signing (`security/jwt/`)
	- External agent communication (`security/ext_agt_depot/`)
	- Agentic Builder TLS, if used (`security/agenticbuilder/`)

	Then add these certificate files to the **security** folder.
* Registry Certificates: Download the required SSL/TLS certificate from the container registry, and save it to the `cert` directory in your home directory before you run the installation.
* Hardware requirements
  	| Hardware resource | HCL Universal Orchestrator | Additional: Agentic AI builder | Additional: AI pilot
	|--|--|--|--|
	|RAM  | 16 GB  |4 GB | 6 GB |
	|CPU  | 4 cores  |  2 cores  | 2 cores |
	|Disk space | 50 GB | 18 GB | 2 GB |
	
	These values represent the minimum system requirements. You can tune the resource limits in Docker compose based on your specific requirements.

	

## Services overview

### Core services (started by default)
The following table describes the core services that are started by default when you run the 
Docker compose configuration:

| Service | Port | Description |
|---------|------|-------------|
| **uno-console-aio** | 8442 | UnO Console All-In-One (gateway + orchestrator + all microservices) |
| **hcl-uno-externalpod** | 8450 | External agent communication endpoint |
| **hcl-uno-automation-plugins** | — | Init container: populates the job plugin volume |

### Optional services (activate via compose profiles)
The following table describes the optional services that you can activate by using compose profiles:

| Service | Profile | Port | Description |
|---------|---------|------|-------------|
| **agentic-runner-test** | `agenticbuilder` | — | Agentic AI Builder test runner |
| **agentic-runner-prod** | `agenticbuilder` | — | Agentic AI Builder production runner |
| **agentic-cm** | `agenticbuilder` | — | Agentic AI Builder configuration manager |
| **agentic-ams** | `agenticbuilder` | 8000 | Agentic AI Builder AMS |
| **pilot-core** | `aipilot` | — | AI Pilot Rasa core |
| **pilot-actions** | `aipilot` | — | AI Pilot Rasa actions |
| **pilot-nlg** | `aipilot` | — | AI Pilot NLG service |
| **pilot-backend** | `aipilot` | — | AI Pilot backend (RAG) |

## Compose profiles
The following table describes the available compose profiles and the specific services 
that they start:

| Profile | Services started |
|---------|---------------|
| *(none)* | Core services only |
| `agenticbuilder` | Core + Agentic Builder services |
| `aipilot` | Core + AI Pilot services |
| `full` | All services |


## Deployment

1. Navigate to the extracted **hcl-uno.zip** file location and then open the **main.env** file.
2. Run the following command to log in to the HCL harbor.

 **Docker**:
 
    docker login hclcr.io

 **Podman**:
 
    podman login hclcr.io

3. Enter your credentials when prompted.

    * **Username**: The username to access the HCL public registry.
    * **Password**: The Harbor CLI secret, which you can find in your **User Profile** on the Harbor portal.
	
4. **Applicable for Linux / macOS only**
	
	Run the following commands to grant permissions to the **scripts** and **security** folders:
	```
 	chnod -R scripts
	``` 
    ``` 
    chmod -R 777 security
	```
	Note: This ensures the application can run scripts and generate required directories during deployment.

5. **Applicable for Windows only**

	1. Navigate to the extracted **hcl-uno.zip** file location and then open the **main.env** file.
	2. Update the **QUARKUS_OIDC_AUTH_SERVER_URL** attribute with your machine's IP address.
	
	Example: `https://<your_ip_address>:8443/realms/uno`
 
6. Configure the following attributes in the **main.env** file to connect to the prerequisite services.

| Attributes | Solution |
|-------|---------|
|MongoDB
| QUARKUS_MONGO_URL |  For example, `mongodb://<your-mongodb-host>:<port>` |
| MONGO_USER | Specify the username to access the database. `<mongodb-user>` |
|MONGO_PASSWORD | Specify the user password to access the database. `<mongodb-password>` |
| Kafka
|KAFKA_SERVERS | Enter the hostname and port for the Kafka servers.|
|Keycloak
| QUARKUS_OIDC_AUTH_SERVER_URL | Enter the base URL of the OIDC provider that the application relies on to authenticate users and validate tokens. For example, `https://<your-keycloak-host>:<port>/realms/uno` |
| QUARKUS_OIDC_CLIENT_ID | Enter the unique identifier that your HCL Universal Orchestrator application uses to identify itself to the OIDC server.|
|QUARKUS_OIDC_CREDENTIALS_SECRET| Enter the private password (client secret) assigned to your specific `CLIENT_ID`, used by the application to securely communicate with and authenticate against the OIDC server. |
|Host / networking
|UNO_HOST_IP | Specify the machine IP. |
|UNO_PUBLIC_URL | Specify the public URL or endpoint managed by your load balancer that routes traffic across the cluster of  replicas.  |

  **Note:** To activate the Agentic AI Builder within your deployment, customize the following attributes in the **agenticbuilder.env** file.
|Attributes |
|-------|
|VALKEY_HOST|
|VALKEY_PORT|
|VALKEY_PASSWORD|
|POSTGRES_HOST|
|POSTGRES_PORT|
|POSTGRES_USER|
|POSTGRES_PASSWORD|
|OIDC_SERVER_URL|


7. Run the following command to start the deployment.

**Docker**:

```
docker compose --env-file main.env -f docker-compose.yml up -d
```
**Podman**:

```
podman compose --env-file main.env -f docker-compose.yml up -d
```


**Optional:** 

* Deployment with Agentic AI Builder

To install Agentic AI Builder along with the deployment, run the following command:

**Docker**:

```
docker compose --env-file main.env --profile agenticbuilder -f docker-compose.yml up -d
```
**Podman**:

```
podman compose --env-file main.env --profile agenticbuilder -f docker-compose.yml up -d
```
* Deployment with AI pilot

To install AI pilot along with the deployment, run the following command:

**Docker**
 ```
  docker-compose --env-file main.env --profile aipilot -f docker-compose.yml up -d
  ```
 **Podman**
  ```
   podman-compose --env-file main.env --profile aipilot -f docker-compose.yml up -d
 ```

* Deployment with all services

To install Agentic AI Builder and other services with the deployment, run the following command:

**Docker**:

```
docker compose --env-file main.env --profile full -f docker-compose.yml up -d
```
**Podman**:

```
podman compose --env-file main.env --profile full -f docker-compose.yml up -d
```

8. Download and configure the HCL UnO agent. For more information, see [Installing HCL UnO agent](https://help.hcl-software.com/UnO/ContinuousDelivery/Configuring/t_configuring_orchestrationagent.html).

**Note:** To download and configure Orchestration CLI, see [Installing and authenticating the Orchestration CLI](https://help.hcl-software.com/UnO/ContinuousDelivery/Deployment/installingocli.html).


### Optional: Deploying in an air-gapped environment

To deploy the HCL Universal Orchestrator instance in an air-gapped environment, you can download the images into a portable archive and load them into a local container registry. After you log in to the HCL public registry, complete the following steps:

1. Run the following command to download the images:

	**Linux / macOS**
	```			
	chmod +x downloadImages.sh && ./downloadImages.sh
	```	
	**Windows**
	```			
	.\downloadImages.ps1
	```
	This step creates a **services.img** file that contains all the required images. 
2. Transfer the **services.img** file to your target machine.
3. Run the following command to load the images into the local container registry:
				
	**Linux / macOS**
	```
	chmod +x loadImages.sh && ./loadImages.sh
	```
	**Windows**
	```
	.\loadImages.ps1
	```
	After you load the images, proceed with the deployment steps.
	
	
### Verifying the deployment

To manually verify the deployment, complete the following check.
1. Run the following command to list all the containers in your system:

**Docker**:
```
docker ps -a
```
**Podman**:
```
podman ps -a
```
2. Run the following command to ensure the console is booted up successfully.
```
curl -k https://localhost:8442/q/health/live
```

## Exposed ports

| Port | Service | Protocol |
|------|---------|---------|
| **8442** | UnO Console AIO | HTTPS |
| **8450** | External Pod | HTTP |
| **8460** | Automation Plugins | HTTP |
| **8000** | Agentic AMS *(optional)* | HTTPS |


## Deploying multiple instances of HCL Universal Orchestrator

An active-active setup involves running multiple instances of HCL Universal Orchestrator simultaneously. Install multiple instances of HCL Universal Orchestrator using Docker, and configure each instance to connect to the same MongoDB and Kafka instances.
Verify that your system meets the following requirements:

* An installed instance of HCL Universal Orchestrator using Docker on a primary server.
* A server with 16 GB of RAM. The number of servers depends on the number of instances that you want to install.
* An installed instance of Docker Desktop or Podman Desktop on each server where you want to install HCL Universal Orchestrator.

This configuration ensures high availability. It protects your environment from downtime so that if a single instance fails, the other instances continue to process workloads. A load balancer or DNS mechanism manages the user access and workload distribution over the servers.

**Note**: The AI pilot feature is not supported in an active-active environment.

The following procedure steps explain how to install the instances on two new servers. This procedure refers to the already installed instance as the primary server. The two servers where you install the additional instances are referred to as Replica A and Replica B.

1. Open the **uno-compose-prerequisites.env** file in the primary server and then update the **KAFKA_ADVERTISED_LISTENERS** attribute to include both the replicas.

    **Example**:
   ```
   'SASL_SSL://<Primary_Server_IP_OR_DNS>:9092,PLAINTEXT://<Primary_Server_IP_OR_DNS>:9094'
    ```
3. Open the **generate-certs.sh** script and add the public URL as Subject alternative Name.
	```
    'SASL_SSL://<Primary_Server_IP_OR_DNS>:9092,PLAINTEXT://<Primary_Server_IP_OR_DNS>:9094'
	```
4. Run the following command to start the prerequisites:

    **Docker**
	```
    docker compose --env-file main.env -f uno-compose-prerequisites.yml up -d
	```
    **Podman**
	```
    podman compose --env-file main.env -f uno-compose-prerequisites.yml ps
	```
Perform all the following steps in both replicas.

4. Copy the **hcl-uno.zip** file from the primary server to the destination folders on Replica A and Replica B.

5. Extract the contents from the **hcl-uno.zip** file.

6. Open the folder and grant permissions to the **scripts** and **security** folders.

    **Note**: **Applicable for Linux users only** Use a dedicated standard account with ownership permissions restricted to the folder where the JAR file is located. All required commands must be run as this user and never as an administrator.

    **Note**: **Applicable for Windows users only** The installation requires Local Administrator rights to register services and handle certificates.

7. Run the following command to log into the HCL harbor:

    **Docker**:
	```
    docker login hclcr.io
	```
    **Podman**:
	```
    podman login hclcr.io
	```
8. Enter your credentials when prompted:

    * Username: The username to access the HCL public registry.
    * Password: The Harbor CLI secret, which you can find in your User Profile on the Harbor portal.
 
9. Navigate to the extracted **hcl-uno.zip** file location. Open the **main.env** file, and then update the following mandatory attributes.

| Port | Service | 
|---|---|
| **UNO_HOST_IP** | Specify the replica server IP. | 
| **QUARKUS_OIDC_AUTH_SERVER_URL** | Specify the IP address of the primary server, or the load balancer endpoint (DNS) that routes traffic across the cluster of replicas. For example,`QUARKUS_OIDC_AUTH_SERVER_URL=<https://<Primary_Server_IP_OR_DNS>>:8443/realms/uno` | 
| **QUARKUS_MONGO_URL** | Specify the IP address of the primary server, or the load balancer endpoint (DNS) that routes traffic across the cluster of replicas. For example, `QUARKUS_MONGO_URL=mongodb://<Primary_Server_IP_OR_DNS>:27017`|
| **KAFKA_SERVERS** | Specify the IP address of the primary server, or the load balancer endpoint (DNS) that routes traffic across the cluster of replicas. For example, `KAFKA_SERVERS=<Primary_Server_IP_OR_DNS>:9092` |
| **UNO_PUBLIC_URL** | Specify the public URL or the endpoint managed by your load balancer that routes traffic across the cluster of replicas. |

**Note**: To further customize the installation, you can configure the optional attributes in the **main.env** file. For more information, see the description given for each attribute in the **main.env** file.

**Important**: To include the Agentic AI Builder in the deployment, you must configure the following variables in the **agenticbuilder.env** file:
| Attributes | Description | 
|---|---|
| **VALKEY_HOST** | Specify the IP address of the primary server, or the load balancer endpoint (DNS) that routes traffic across the cluster of replicas. |
| **POSTGRES_HOST** | Specify the IP address of the primary server, or the load balancer endpoint (DNS) that routes traffic across the cluster of replicas. |
| **OIDC_SERVER_URL** | Specify the IP address of the primary server, or the load balancer endpoint (DNS) that routes traffic across the cluster of replicas. | 

10. Copy all the certificates from the security folder of the primary server to the security folders on Replica A and Replica B.

11. Create a network to handle the virtual networking between the Docker containers. 
	
    **Docker**:
	```
	docker network create NETWORK_NAME || true
	```
    **Podman**:
	```
    podman network create NETWORK_NAME || true
	```
12. Navigate to the main directory and run the following command to start the deployment on each replica.

    **Docker**:
	```
    docker compose --env-file main.env -f docker-compose.yml up -d
	```
 	```
    docker compose --env-file main.env -f docker-compose.yml ps
	```
    **Podman**:
	```
    podman compose --env-file main.env -f docker-compose.yml up -d
	```
	```
    podman compose --env-file main.env -f docker-compose.yml ps}
	```

    **Optional**: To install Agentic AI Builder along with the deployment, run the following command:

	   **Docker**:
	  ```
	  docker compose --env-file main.env --profile agenticbuilder -f docker-compose.yml up -d`
	  ```
	  **Podman**:
	  ```
	  podman compose --env-file main.env --profile agenticbuilder -f docker-compose.yml up -d`
	  ```
You have successfully created an active-active setup with two replicas. The load balancer now manages the workload and distributes it among the primary server and the replicas.


## Stopping the deployment

The command to stop the HCL Universal Orchestrator instance depends on how it was deployed. If you deployed only the core services, you do not need to specify a compose profile. If you deployed additional services, you must specify the same compose profile that you used during deployment. The following example shows the command to stop and remove an instance with all services by using the `full` compose profile.

**Docker**:
```
docker compose --env-file main.env --profile full -f docker-compose.yml down
```
**Podman**:
```
podman compose --env-file main.env --profile full -f docker-compose.yml down
```
---


## Troubleshooting

| Issue | Solution |
|-------|---------|
| `console-aio` shows unhealthy | Wait for `automation-plugins` init container to finish. Then check: `docker logs hcl-uno-plugins`.|
| Service fails to connect to Keycloak | Verify `QUARKUS_OIDC_AUTH_SERVER_URL` in `main.env` is reachable from the container. Then check TLS verification setting `QUARKUS_OIDC_TLS_VERIFICATION`. |
| Service fails to connect to MongoDB | Verify `QUARKUS_MONGO_URL` and credentials. Ensure MongoDB TLS matches `QUARKUS_MONGODB_TLS_*` settings. |
| `network not found` error | Create the shared network before deployment: `docker network create hcl-uno-ms-network` |
| Port already in use | Check: `ss -tlnp \| grep :<port>` (Linux) or `netstat -ano \| findstr :<port>` (Windows) |



## Documentation and support

- **Product documentation**: [HCL Universal Orchestrator Documentation](https://help.hcl-software.com/UnO/prod_page/prod-page.html)
- **Support**: Contact HCL Software support for licensed customers.

