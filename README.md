# Cloud Automation Pipelines (CAPs)

## Overview

This repository contains deployment automation pipelines that launch scaled out production ready environments in the cloud. The automation tooling consist of [Terraform](https://www.terraform.io/) as the orchestrator and control plane for infrastructure services and [Concourse](http://concourse-ci.org/) for implementing operational workflows. Pipeline jobs may use a combination of configuration management tools to achieve their objective, but the primary configuration management tool used by the automation pipelines is [Bosh](http://bosh.io/).

A collection of utility scripts are provided in the `bin` folder to help manage multiple environments. Along with these scripts this repository is organized as follows. 

```
.
├── bin           # Utility scripts for managing environments
├── deployments   # Deployments used to bootstrap environments
├── docs          # Additional documentation
├── lib           # Operations pipelines, scripts and templates
├── LICENSE      
└── README.md
```

Each environment is bootstrapped by an inception Virtual Private Cloud (VPC), which sets up infrastructure that secure access to internal resources built via automation pipelines. This repository provides a set of reference deployments which can be extended as required.

## Usage

### Quick Start

To use this framework effectively a collection of shell scripts are provided. It is recommended to use a tool like [direnv](https://direnv.net/) to manage your local environment. 

The IaaS credentials for the IaaS on which an environment should be launched should be provided as environment variables. This can be achieved by exporting the variables from  an `.envrc` file if you are using [direnv](https://direnv.net/) to manage you localized environments. Otherwise simply save them to a shell script and source it before executing the CAPs utilities. 

> You should also add the `<caps repository home>/bin` folder to your path so you can run `caps-*` scripts without providing an explicit absolute or relative path.

Currently CAPs supports creating Pivotal Cloud Foundry environments in the following IaaS environments.

#### Google Cloud Platform (GCP)

CAPs requires certain Google APIs to be enabled. You will need to login to your Google Cloud Platform account via SSO and then run the following command via gcloud or enable each API idividually via the GCP Cloud Console.

```
gcloud auth login --project <PROJECT ID>

gcloud services enable cloudresourcemanager.googleapis.com
gcloud services enable compute.googleapis.com
gcloud services enable storage-api.googleapis.com
gcloud services enable storage-component.googleapis.com 
gcloud services enable dns.googleapis.com
gcloud services enable sqladmin.googleapis.com
gcloud services enable iam.googleapis.com
```

CAPs also requires a GCP service account with the correct permissions in order to create the necessary cloud infrastructure for the environment being bootstrapped. The service account must have the following permissions:

- Cloud SQL Admin
- Compute Admin
- DNS Administrator
- Service Account Admin
- Service Account User
- Project IAM Admin
- Storage Admin
- Storage Object Admin

Download you service account key file and save it to some path within your user file-system and reference it via the `GOOGLE_CREDENTIALS` variable as shown in the `.envrc` environment file snippet below.

```
PATH_add <caps repository home>/bin

export GOOGLE_PROJECT=****
export GOOGLE_CREDENTIALS=<path to your service account key file>
export GOOGLE_REGION=europe-west1
export GOOGLE_ZONE=$GOOGLE_REGION-b

export GCS_STORAGE_ACCESS_KEY=****
export GCS_STORAGE_SECRET_KEY=****

#
# Token for downloading Pivotal products
#
export PIVNET_TOKEN=****

#
# SendGrid API Key`
#
export SENDGRID_API_KEY=****
```

Before you can apply the bootstrap configuration you will need to ensure a Google Cloud Storage bucket is created for the remote  Terraform state for the bootstrap configuration. The name of this bucket should be provided to CAPs via the `TF_VAR_terraform_state_bucket` environment control variable (in the examples below the name is assumed to be `tfstate-${GOOGLE_REGION}`).

#### `build-image`

Before you can bootstrap an environment for a particular IaaS you need to first build the bootstrap image. This is a multi-role image that is used to automate and secure access to the environment. To build the image run the following command.

```
USAGE: build-image -i|--iaas <IAAS_PROVIDER> [-r|--regions <REGIONS>]

    -i|--iaas <IAAS_PROVIDER>  The iaas provider for which images will be built.

    -r|--regions <REGIONS>     Comma separated list of the iaas provider's regions for which
                               images will be built. This does not apply to all providers and
                               will be ignored where appropriate.
```

All build logs will be written to the `<repository home>/log` folder.

#### `caps-init`

This utility sets the current environment context and will initialize a control file if one is not available. When switching context using this utility any active VPN sessions will be disconnected as the new context may require a different connection.

```
USAGE: caps-init <NAME> -d|--deployment <DEPLOYMENT_NAME> -i|--iaas <IAAS_PROVIDER>

    This utility will create a control file for a new environment in the repository root.
    This file will be named '.envrc-<NAME>'. Its format is compatible with the 'direnv'
    (https://github.com/direnv/direnv) utility which is recommend for managing profiles
    for multiple deployment environments. Running this script will terminate any
    connected VPN sessions.

    <NAME>                             The name of the environment. This will also be the name of your primary VPC.
    -d|--deployment <DEPLOYMENT_NAME>  The name of one of the deployment recipes.
    -i|--iaas <IAAS_PROVIDER>          The iaas provider that the deployment has been deployed to.
```

Control files are environment scripts and have the name format `.caps-env_<NAME>`. They will be placed within the root of this repository. You should keep all IAAS credentials out of this file and reference them as environment variables that have been exported via another mechanism such the [direnv](https://direnv.net/) utility. The control files contain all externalized variables that customize the Terraform templates for the bootstrap infrastructure as well as any configuration that needs to be passed to the operations automation pipelines.

Below is a sample control file for an environment named *pcf-demo-1* deployed to *GCP*.

```
#!/bin/bash

#
# Environment variables required by Terraform 
# to bootstrap and install the PCF environment
#

export TF_VAR_gcp_credentials=$GOOGLE_CREDENTIALS
export TF_VAR_gcp_region=$GOOGLE_REGION

export TF_VAR_gcp_storage_access_key=$GCS_STORAGE_ACCESS_KEY
export TF_VAR_gcp_storage_secret_key=$GCS_STORAGE_SECRET_KEY

export TF_VAR_smtp_relay_host=smtp.sendgrid.net
export TF_VAR_smtp_relay_port=2525
export TF_VAR_smtp_relay_api_key=$SENDGRID_API_KEY

# Email to send notifications to

export TF_VAR_notification_email=mevan.samaratunga@caps.io

#
# Cloud Automation Pipelines (CAPs) repository
#

export TF_VAR_automation_pipelines_branch=refactor_bootstrap

#
# Environment configuration repository
#

export TF_VAR_env_config_repo=https://github.com/mevansam/pcf-environments.git
export TF_VAR_env_config_repo_branch=master
export TF_VAR_env_config_path=pcf-demo-1/config

#
# Automation extensions git repository
#

export TF_VAR_automation_extensions_repo=https://github.com/mevansam/pcf-environments.git
export TF_VAR_automation_extensions_repo_branch=master

export TF_VAR_pcf_terraform_templates_path=pcf-demo-1/templates/terraform
export TF_VAR_pcf_tile_templates_path=pcf-demo-1/templates/tile

# Pivnet Token for downloading pivotal releases
export TF_VAR_pivnet_token=$PIVNET_TOKEN

# VPC configurations

export TF_VAR_vpc_name=pcf-demo-1
export TF_VAR_vpc_dns_zone=demo1.pocs.pcfs.io
export TF_VAR_vpc_parent_dns_zone_name=pocs-pcfs-io

export TF_VAR_terraform_state_bucket=tfstate-${GOOGLE_REGION}

export TF_VAR_bastion_instance_type=n1-standard-8
export TF_VAR_bastion_data_disk_size=300

export TF_VAR_bastion_admin_user=bastion-admin
export TF_VAR_bastion_setup_vpn=true
export TF_VAR_bastion_allow_public_ssh=true

# Network

export TF_VAR_pcf_environments='["sandbox"]'

export TF_VAR_pcf_networks='{
  sandbox = {
    service_networks    = "services,dynamic-services"
    subnet_config_order = "infrastructure,pas-1,services-1,dynamic-services-1,monitoring"
  }
}'

export TF_VAR_pcf_network_subnets='{
  sandbox = {
    infrastructure     = "192.168.101.0/26"
    pas-1              = "192.168.4.0/22"
    services-1         = "192.168.8.0/22"
    dynamic-services-1 = "192.168.12.0/22"
    monitoring         = "192.168.101.64/26"
  }
}'
```

#### `caps-tf`

Since the control plane for each environment is Terraform, this utility will be the tool you will use most often to apply changes to the bootstrap envrionment. Once an environment has been bootstrapped the internal automation will handle all upgrades and operational workflows via Concourse. Once you have set the context you can run a `plan` via this script to see what changes are pending. If the environment has already been set up then the `plan` should yield only an update to download the SSH keys for the environment. You will need to run `apply` to ensure keys have been downloaded before running any of the other utilities below.

```
USAGE: caps-tf plan|apply|destroy|recreate-bastion [-o|--options <TERRAFORM_OPTIONS>] [-i|--init] [-c|--clean]

    This utility will perform the given Terraform action on the deployment's bootstrap template.

    -o|--options  <TERRAFORM_OPTIONS>  Additional options to pass to terraform.
    -i|--init                          (Re)Initializes the terraform workspace.
    -c|--clean                         Ensures any rebuilds are clean (i.e. recreate-bastion with this
                                       option will ensure the persistent data volume is also recreated.
```

#### `caps-vpn`

If you configure the bootstrap infrastructure to setup VPN then the following utility can be used to download the vpn admin credentials. For Mac OS environments the credentials downloaded can be used with the [TunnelBlick](https://tunnelblick.net/) VPN client. The script will automatically import the credentials to [TunnelBlick](https://tunnelblick.net/) if it has been installed.

```
USAGE: caps-vpn

    This utility will download the VPN credentials required to access
    the environment's internal resources. The credentials will be
    download to the following folder.

       * <CAPS repository folder>/tmp
```

#### `caps-ci`

The bootstrap Concourse automation environment is configured to be exposed only locally to the automation instance. This means you cannot access it directly. Therefore, to access concourse you will need to use this utility. It creates an SSH tunnel to the automation instance so that Concourse can be accessed via a local port. 

Once the script has established the tunnel it will display the concourse basic-auth usermame and password required to login to the UI or via the `fly` CLI.

```
USAGE: caps-ci logout|login|info

    This utility will create an SSH tunnel to the Concourse environment that
    runs the automation pipelines. It will also initialize the 'fly' CLI and
    create a target to this concourse environment.
```

> If jobs in the deployment fail due to IaaS issues or timeouts simple restart the deployment by accessing concourse using the `caps-ci` utility.

#### `caps-ssh`

This helper script that can be used to create an SSH session to an instance within the cloud environment. It can also be used to login to the bastion instance using the admin credentials.

```
USAGE: caps-ssh <NAME> [-u|--user <SSH_USER>] [-x|--proxy]

    This utility will create launch an SSH session to an instance within the deployed
    environment.

    <NAME>                The name or IP of the instance to SSH to. If the name is 'bastion'
                          then an SSH session will be created to the bastion instance.
                          Otherwise it should be of the host prefix of the instance name.
                          For example <host prefix>.<vpc domain>.
    -u|--user <SSH_USER>  The SSH user to login as. This will be ignored when you SSH to the
                          bastion instance. For any other instance if this argument is not
                          provided the default SSH user will be 'ubuntu'.
    -x|--proxy            This will create a transparent proxy server that works as a poor
                          man's VPN. To install the sshuttle utility refer to the following
                          url: https://github.com/sshuttle/sshuttle. Use this only if you
                          have not setup or connected through a VPN in the bastion server
                          and require direct access to VPC's internal resources.
```

> The base image may implement [`sshguard`](https://www.sshguard.net/) or [`fail2ban`](https://www.fail2ban.org/wiki/index.php/Main_Page). Which means repeated failures to login will result in temporary block on your IP. If SSH is hanging then you will need re-try after some time or simply stop or disable the service as soon as you can SSH into the bastion instance.

#### `caps-info`

```
USAGE: caps-info

    This utility will display useful information about the current environment.
```

### Managing Access to an Environment

By default when you set the environment context you will have full administrative privileges to the environment, as long as you have the IaaS credentials with the appropriate role to access the bootstrap Terraform state. Access to the bastion instance using the bastion admin user and password is the highest level of access and it grants you access to all the bootstrap automation infrastructure as well as the keys to the access the IaaS. Hence, the bastion credentials should be considered highly sensitive. In the event the credentials need to be changed then the generated password can be tainted in the bootstrap Terraform state and the bastion instance rebuilt without affecting already deployed infrastructure.

If you need to grant non-admin access to the internal VPC network resources when VPN is configured and direct SSH has been disabled, you can create additional VPN credentials which can be shared by traditional means. To create a new VPN user.

1) SSH into the bastion instance as the admin and note down the password for `sudo`.

```
caps-ssh bastion
```

2) Create the user as follows one the SSH session has been established.

```
sudo create_vpn_user <USER> <PASSWORD>
```

3) The user can then download his/her credentials via the bastion HTTP server.

https://`BASTION PUBLIC DNS NAME]`/~`USER`

This link is secured using the user's VPN credentials which were set in 2). This user will not be able to SSH to the bastion instance or access any of the automation tooling, but will have access to any other deployed resource within VPC.

If the bastion was setup with `TF_VAR_bastion_allow_public_ssh=true` then you can tunnel to the VPC network using [sshuttle](https://github.com/sshuttle/sshuttle) and VPN access is not required. For non-admin access simply SSH to the bastion server as admin and create system users with limited priveleges that can establish the tunnel via the [sshuttle](https://github.com/sshuttle/sshuttle) utility.

### Advance Users

Advance users can extend the framework to override the default reference network as well as service configurations to create production ready environments.

## Bootstrapping Approach

Every environment needs to be bootstraped. The bootstrap step paves the IaaS with the necessary services required for secured access to a logical Virtual Data Center (VDC) created for the environment. Bootstrapping is achieved via Terraform templates. This initial template contains all the required parameters that setup the rest of the automation workflows. Bootstrapping is done by applying a Terraform template that launches an inception Virtual Private Cloud which also acts as the DMZ layer for the rest of the deployed infrastructure. More detail on the underlying automation services that enable bootstrapping an environment can be found in the [cloud-inceptor](https://github.com/mevansam/cloud-inceptor) project.

## Tearing down the environment

To tear down an environments first run the `destroy-env` job in all the `<ENVIRONMENT>_deployment` pipeline.

Once the PCF environments have been destroyed you can tear down the resources created via the bootstrapping process by running the `caps-tf destroy`. 
