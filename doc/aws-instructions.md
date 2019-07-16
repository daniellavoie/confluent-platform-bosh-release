# AWS Bosh Deployment for Confluent Platform

## Preparing your IaaS

### Create a VPC

Example name : cp-bosh

Example CIDR : 10.0.10.0/16

### Create subnets

#### AZ 1

* Example subnet 1 name : cp-bosh-a
* Example subnet 1 CIDR : 10.0.11.0/24
* Example subnet 1 AZ : us-east-1a

#### AZ 2

* Example subnet 2 name : cp-bosh-b
* Example subnet 2 CIDR : 10.0.12.0/24
* Example subnet 2 AZ : us-east-1b

#### AZ 3

* Example subnet 3 name : cp-bosh-c
* Example subnet 3 CIDR : 10.0.13.0/24
* Example subnet 3 AZ : us-east-1c

### Create a Security Group for Bosh

Example name : bosh

Inbound rules :

| Type | Protocol | Port Range | Source | Description |
| ------------- | ------------- | ------------- | ------------- | ------------- |
| All traffic | All | All | Custom - <VPC-ID> | Management and data access |
| SSH | TCP | 22 | My IP | SSH access |

### Create a Security Group for Control Center

Example name : control-center

Inbound rules :

| Type | Protocol | Port Range | Source | Description |
| ------------- | ------------- | ------------- | ------------- | ------------- |
| Custom TCP Rule | TCP | 9021 | Anywhere | Http Access |

### Create a Security Group for Control Center Load Balancer

Example name : control-center-lb

Inbound rules :

| Type | Protocol | Port Range | Source | Description |
| ------------- | ------------- | ------------- | ------------- | ------------- |
| HTTP | TCP | 80 | Anywhere | Http Access |

### Create an Elastic IP

Create an elastic ip that can be assigned to the Bosh Director.

### Create a TCP Load Balancer for Confluent Server

TODO

### Create a Load Balancer for Control Center

<strong>Target Group</strong>
Type : Application Load Balancer
Scheme : internet-facing
IP address type : ipv4
Load Balancer Protocol : HTTP
VPC : Your newly created VPC
AZs : Check all AZ for your VPC.

<strong>Target Group</strong>
Target group route name : cp-control-center
Target group port: 9021

### Create a jumpbox to run Bosh CLI Commands

A standard Ubuntu Xenial 16.04 image on a `t2.micro` instance should be enough with 8GB disks.

## Install the bosh CLI from your Jumpbox

```
wget https://github.com/cloudfoundry/bosh-cli/releases/download/v5.5.1/bosh-cli-5.5.1-linux-amd64 && \
  chmod +x bosh-cli-* && \
  sudo mv bosh-cli-* /usr/local/bin/bosh && \
  sudo apt-get update && \
  sudo apt-get install -y build-essential zlibc zlib1g-dev ruby ruby-dev openssl libxslt-dev libxml2-dev libssl-dev libreadline6 libreadline6-dev libyaml-dev libsqlite3-dev sqlite3
```

## Create a Bosh Director

```
git clone https://github.com/cloudfoundry/bosh-deployment && \
  bosh create-env bosh-deployment/bosh.yml \
    --state=bosh-deployment/director-state.json \
    --vars-store=bosh-deployment/director-store.yml \
    -o bosh-deployment/aws/cpi.yml \
    -o bosh-deployment/uaa.yml \
    -o bosh-deployment/credhub.yml \
    -o bosh-deployment/jumpbox-user.yml \
    -o bosh-deployment/external-ip-with-registry-not-recommended.yml \
    -v director_name=aws-bosh-director \
    -v internal_cidr=<VPC-CIDR> \
    -v internal_gw=<VPC-GATEWAY> \
    -v internal_ip=<DIRECTOR-FIXED-IP> \
    -v access_key_id=<IAM-ACCESS-SECRET-ID> \
    -v secret_access_key=<IAM-SECRET-ACCESS-KEY> \
    -v region=<AWS-REGION> \
    -v az=<AWS-REGION-AZ> \
    -v default_key_name=cp-bosh \
    -v default_security_groups=[<SECURITY-GROUP>] \
    -v subnet_id=<VPC-SUBNET-ID> \
    -v external_ip=<ELASTIC-IP> \
    --var-file private_key=<KEY-PAIR-PEM-FILE>
```

## Configure the newly created Bosh Environment

```
export DIRECTOR_STORE=bosh-deployment/director-store.yml

export BOSH_ENVIRONMENT=<DIRECTOR-FIXED-IP>

export BOSH_CA_CERT=`bosh interpolate $DIRECTOR_STORE --path /director_ssl/ca`
export BOSH_CLIENT=admin
export BOSH_CLIENT_SECRET=`bosh interpolate $DIRECTOR_STORE --path /admin_password`

export CREDHUB_SERVER=$BOSH_ENVIRONMENT:8844
export CREDHUB_CA_CERT="$(bosh interpolate $DIRECTOR_STORE --path=/credhub_tls/ca )"$'\n'"$( bosh interpolate $DIRECTOR_STORE --path=/uaa_ssl/ca)"

export CREDHUB_CLIENT=credhub-admin
export CREDHUB_SECRET=`bosh interpolate $DIRECTOR_STORE --path /credhub_admin_client_secret`
```

## Upload a Xenial Stemcell

```
bosh upload-stemcell --sha1 86c7b832c4666cfb9e84e81d21c034d1f3858642 \
  https://bosh.io/d/stemcells/bosh-aws-xen-hvm-ubuntu-xenial-go_agent?v=315.64
```

## Update Cloud Config

Prepare a yml file with your own IaaS configuration. Here is an example (cloud-configs/aws.yml)[cloud-config.yml] for AWS.

The following properties should be sourced from your IaaS configuration.

| Yml Key | Example value | Config description |
| ------------- | ------------- | ------------- |
| azs[0].cloud_properties.availability_zone | us-east-1a | AZ name for AZ1 |
| azs[1].cloud_properties.availability_zone | us-east-1b | AZ name for AZ2 |
| azs[2].cloud_properties.availability_zone | us-east-1c | AZ name for AZ3 |
| vm_types[name=default].cloud_properties.security_groups | ["bosh"] | Security groups to be applies to created VMs |
| vm_extensions[name=control-center].cloud_properties.lb_target_groups | ["cp-control-center"] | Name of the Load Balancer for Control Center |
| vm_extensions[name=control-center].cloud_properties.security_groups | ["bosh", "control-center"] | Security groups to be applies to Control Center VM |
| networks[name=default].subnets[0].range | 10.0.11.0/24 | CIDR for subnet 1 |
| networks[name=default].subnets[0].gateway | 10.0.11.1 | CIDR for subnet 1 |
| networks[name=default].subnets[0].reserved | [10.0.11.1-10.0.11.19] | Prevents Bosh from assigning IP to this range for subnet 1 |
| networks[name=default].subnets[0].cloud_properties.subnet | subnet-0ca02f61ce8c72a04 | Subnet ID for subnet 1 |
| networks[name=default].subnets[1].range | 10.0.12.0/24 | CIDR for subnet 2 |
| networks[name=default].subnets[1].gateway | 10.0.12.1 | CIDR for subnet 2 |
| networks[name=default].subnets[1].reserved | [10.0.12.1-10.0.12.19] | Prevents Bosh from assigning IP to this range for subnet 2 |
| networks[name=default].subnets[1].cloud_properties.subnet | subnet-0403b06d5272d9856 | Subnet ID for subnet 2 |
| networks[name=default].subnets[2].range | 10.0.13.0/24 | CIDR for subnet 3 |
| networks[name=default].subnets[2].gateway | 10.0.13.1 | CIDR for subnet 3 |
| networks[name=default].subnets[2].reserved | [10.0.13.1-10.0.13.19] | Prevents Bosh from assigning IP to this range for subnet 3 |
| networks[name=default].subnets[2].cloud_properties.subnet | subnet-0f9412c7b708efa5a | Subnet ID for subnet 3 |

```
deploy update-cloud-config <PATH-TO-CLOUD-CONFIG-YML>
```

## Deployment Confluent Platform

```plain
bosh deploy manifests/confluent-platform-solo.yml
```

## Development

To iterate on this BOSH release, use the `create.yml` manifest when you deploy:

```plain
bosh deploy manifests/confluent-platform-solo.yml -o manifests/operators/create.yml
```