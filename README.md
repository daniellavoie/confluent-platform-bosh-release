# BOSH release for Confluent Platform

This is a BOSH release and deployment manifest deploy the Confluent Platform on major cloud (including vSphere).

## Motivation

Containers are fun, but getting stateful workloads in them can get a bit arkward. The abstraction layers it brins only add more complexity to the primitives they require only in the name of cloud independance.

What if a cloud agnostic resource orchestrator existed and that was closer to the underlying cloud native resources. Enters [Bosh](https://bosh.io). As stated by the project presentation : 

> BOSH is a project that unifies release engineering, deployment, and lifecycle management of small and large-scale cloud software. BOSH can provision and deploy software over hundreds of VMs. It also performs monitoring, failure recovery, and software updates with zero-to-minimal downtime.

Long story short, Bosh let you declare a desired state of your software and the underlying physical infrastructure (disk, vm instance, networks, OS, etc) and ensures that it meets the actual state. It was inspired by Google Borg. OS upgrade? Bosh will update on a rolling deployment. Same for software or resource change. A VM stops responding?  Bosh will detach disk, trash the VM and recreate a new one before re-attaching persistent disks and restarting the processes. Think of it as a Kubernetes for your IaaS resources.

## Getting started on Bosh

[Stark and Wayne](https://starkandwayne.com) provides an incredible [Bosh tutorial](http://ultimateguidetobosh.com/). That is a recommeded first step to enter the world of Bosh.

## TL;DR - I just want to deploy

* [AWS deployment instructions](doc/aws-instructions.md)
* [GCP Deployment instructions](gcp-instructions.md)
* vSphere Deployment instructions - sooooon
* Virtual Box deployment instructions - sooooon

## Current limitations

** THIS IS FAR FROM BEING PRODUCTION READY **

* End to end security is half way implemented.

## State of security

A lot of security features are to be implemented. For a complete state of the bits that still requires implement, refers to the [state of security](doc/state-of-security.md) doc section.

## Tested IaaS

This current iteration was successully tested on AWS and GCP cpis.

## Deploy Confluent Platform Cluster

```
bosh deploy confluent-platform-bosh-release/manifests/confluent-platform.yml -o confluent-platform-bosh-release/manifests/operators/create.yml
```

## Updates

When new versions of `confluent-platform-bosh-release` are released the `manifests/confluent-platform-solo.yml` file will be updated. This means you can easily `git pull` and `bosh deploy` to upgrade.

```plain
export BOSH_ENVIRONMENT=<bosh-alias>
export BOSH_DEPLOYMENT=confluent-platform-dev
cd confluent-platform-bosh-release
git pull
cd -
bosh deploy confluent-platform-bosh-release/manifests/confluent-platform-solo.yml
```

## Development

To iterate on this BOSH release, use the `create.yml` manifest when you deploy:

```plain
bosh deploy manifests/confluent-platform-solo.yml -o manifests/operators/create.yml
```

## Acknowledgement

Big shout out to [Stark and Wayne](https://starkandwayne.com) for their inspiration with their [Kafka Bosh Release](https://github.com/cloudfoundry-community/kafka-boshrelease). The openjdk package used by release is provided by them.
