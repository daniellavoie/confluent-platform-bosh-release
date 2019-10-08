# GCP Bosh Deployment for Confluent Platform

## Preparing your IaaS

### Create a VPC

Example name : cp-bosh

Example CIDR : 10.0.10.0/16

### Create subnets

| Name | CIDR | Region |
|---|---|---|
| instrastructure | 10.0.10.0/24 | northamerica-northeast1 |
| confluent-platform | 10.0.20.0/24 | northamerica-northeast1 |

### Create Firewall rules

| Name | Targets | Filters | Protocols / ports | Network |
| ------------- | ------------- | ------------- | ------------- | ------------- |
| bosh-allow-ssh | allow-ssh | IP ranges: 0.0.0.0/0  | tcp:22 | cp-bosh |
| bosh-unrestricted | confluent-platform | Tags: confluent-platform  | all | cp-bosh |
| bosh-allow-control-center | allow-control-center | IP ranges: 0.0.0.0/0 | tcp:9021 | cp-bosh |
| bosh-allow-ksql | allow-ksql | IP ranges: 0.0.0.0/0 | tcp:8088 | cp-bosh |

### Create unmanaged instance groups for Control Center

| Number | Zone | Name | Network | Subnet |
|---|---|---|---|---|
| 1 | northamerica-northeast1-a | cp-control-center | cp-bosh | confluent-platform |
| 2 | northamerica-northeast1-b | cp-control-center | cp-bosh | confluent-platform |
| 3 | northamerica-northeast1-c | cp-control-center | cp-bosh | confluent-platform |

### Create unmanaged instance groups for KSQL

| Number | Zone | Name | Network | Subnet |
|---|---|---|---|---|
| 1 | northamerica-northeast1-a | cp-ksql | cp-bosh | confluent-platform |
| 2 | northamerica-northeast1-b | cp-ksql | cp-bosh | confluent-platform |
| 3 | northamerica-northeast1-c | cp-ksql | cp-bosh | confluent-platform |

### Create an Http Load Balancer for Control Center

#### Backend services

Instance Group : cp-control-center

Port number : 9021

Health check : HTTP on :9021/

Backend Services : cp-control-center

#### Frontend

protocol :  http

port : 80

ip : Reserved ipv4

### Create an Http Load Balancer for KSQL

#### Backend services

Instance Group : cp-ksql

Port number : 8088

Health check : HTTP on :8088/

Backend Services : cp-ksql

#### Frontend

protocol :  https

port : 443

ip : Reserved ipv4

### Create a jumpbox to run Bosh CLI Commands

A standard Ubuntu Xenial on a `f1-micro` instance should be enough.

Ensure define it's network to `cp-bosh` and add the `allow-ssh` and `confluent-platform` network tags. Last but non the least, ensure to add your SSH key from the `Security` tab. Otherwise you will only be able to connect from GCP web ssh console.

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
  -o bosh-deployment/gcp/cpi.yml \
  -o bosh-deployment/uaa.yml \
  -o bosh-deployment/credhub.yml \
  -o bosh-deployment/jumpbox-user.yml \
  -v director_name=gcp-bosh-director \
  -v internal_cidr=<VPC-INFRA-SUBNET-CIDR> \
  -v internal_gw=<VPC-INFRA-SUBNET-GW> \
  -v internal_ip=<DIRECTOR-FIXED-IP> \
  --var-file gcp_credentials_json=<GCP-CREDENTIALS-JSON-FILE> \
  -v project_id=<GCP-PROJECT-ID-IN-LOWERCASE> \
  -v zone=<GCP-ZONE> \
  -v tags=[confluent-platform] \
  -v network=<VPC-NAME> \
  -v subnetwork=<VPC-INFRA-SUBNET>
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
bosh upload-stemcell --sha1 4623028f7f7e7cb0b6ea04c9bddbe2aa837b6d73 \
  "https://bosh.io/d/stemcells/bosh-google-kvm-ubuntu-xenial-go_agent?v=315.64"
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