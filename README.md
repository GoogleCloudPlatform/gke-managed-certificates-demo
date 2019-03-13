# Building Managed Certificates for your Kubernetes Engine Cluster

## Table of Contents

- [Building Managed Certificates for your Kubernetes Engine Cluster](#building-managed-certificates-for-your-kubernetes-engine-cluster)
  * [Table of Contents](#table-of-contents)
  * [Introduction](#introduction)
  * [Process](#process)
  * [Assumptions](#assumptions)
  * [Prerequisites](#prerequisites)
    + [Cloud Project](#cloud-project)
    + [Required GCP APIs](#required-gcp-apis)
    + [Install Cloud SDK](#install-cloud-sdk)
    + [Install kubectl CLI](#install-kubectl-cli)
    + [Install Kustomize](#install-kustomize)
    + [Install Terraform](#install-terraform)
    + [Configure Authentication](#configure-authentication)
  * [Deployment](#deployment)
    + [What are we deploying](#what-are-we-deploying)
    + [Terraform structure](#terraform-structure)
    + [Kustomize explained](#kustomize-explained)
    + [Deploying the scenario](#deploying-the-scenario)
  * [Validation](#validation)
  * [Teardown](#teardown)
  * [Troubleshooting](#troubleshooting)
  * [Relevant Material](#relevant-material)

## Introduction

A Kubernetes Ingress manages external access to your services in a cluster. It's an object which defines rules for routing external HTTP(S) traffic to applications running in a cluster. An Ingress object is associated with one or more Service objects, each of which is associated with a set of Pods. Ingress allows you to do path based and subdomain based routing to your backend services.

Additionally you can terminate TLS for your services through Ingress. While this usually requires you to create and manage your own certificates, GKE supports the use of Google managed certificates. This takes away the burden of manually requesting and managing SSL certificates to ensure secure connections to your services.

In this tutorial, we will go through how to use Google Cloud's new feature, Google managed certificates,to secure your Ingress in GKE.

## Process

The diagram below summarize the steps to deploy an ingress using a Google managed certificate.

![deployment process](images/IngressWithManagedCertDeployProcess.png)


## Assumptions

This guide assumes you own a domain name with a valid DNS managed zone so we can use it to add a DNS record for our Ingress. If you currently own a domain name without a DNS managed zone, follow these [instructions](https://cloud.google.com/dns/zones/) to create one in your project.

In this demo we will be using a managed zone called `fakedomain-zone` which contains all DNS records for the `fakedomain.com` domain. we chose the following url for our Ingress: `heyingress.fakedomain.com`. We will export those in environment variables later before we deploy the demo.

## Prerequisites

In order to complete the steps outlined below, several tools must be installed and have the proper configuration of authentication in order to access your GCP resources.

### Cloud Project

You will need access to a Google Cloud Project with billing enabled. See **Creating and Managing Projects** (https://cloud.google.com/resource-manager/docs/creating-managing-projects) for creating a new project. To make cleanup easier it's recommended to create a new project.

### Required GCP APIs

The following APIs will be enabled in the project:

* Kubernetes Engine API
* Cloud DNS API

### Install Cloud SDK

The Google Cloud SDK is used to interact with your GCP resources. [Installation instructions](https://cloud.google.com/sdk/downloads) for multiple platforms are available online.

### Install kubectl CLI

The kubectl CLI is used to interact with both Kubernetes Engine and kubernetes in general. [Installation instructions](https://kubernetes.io/docs/tasks/tools/install-kubectl/) for multiple platforms are available online.

### Install Kustomize

Kustomize is a tool for customization of kubernetes YAML files. Kustomize will take the original Kubernetes manifests YAML files and customize them while leaving the originals untouched. To install Kustomize on your OS, follow the instructions [here](https://github.com/kubernetes-sigs/kustomize/blob/master/docs/INSTALL.md).
we will be using the manifests under `demoApp/base_manifests` for our applications while customizing them later using Kustomize CLI

### Install Terraform

Terraform is used to automate the manipulation of cloud infrastructure. Its [installation instructions](https://www.terraform.io/intro/getting-started/install.html) are also available online.

### Configure Authentication

The Terraform configuration will execute against your personal account's GCP environment to create various resources. To set up the default account, run the following command to select the appropriate one:

`gcloud auth application-default login`

## Deployment

### What are we deploying

The end goal is to deploy a GKE Ingress that uses a Google managed certificate for ssl termination. In this example, we will create:

1. GKE cluster deployed with terraform
1. public static ip deployed with terraform and will be used as our Ingress IP
1. DNS record deployed pointing our domain name to our Ingress ip. It is also deployed with terraform
1. Google managed certificated for our domain deployed using gcloud since terraform has no support yet for this beta feature.
1. kubernetes application that contains a deployment, service and an Ingress which uses the certificate customized with Kustomize and deployed with kubectl


### Terraform structure

There are four Terraform files provided in this example. The first one, `main.tf`, is the starting point for Terraform. It describes the features that will be used and the resources that will be manipulated. The second file is `provider.tf`, which indicates which cloud provider and version will be the target of the Terraform commands--in this case GCP. The third file, is `outputs.tf` and has all of the outputs that will result from deploying those resources. The final file is `variables.tf`, which contains a list of variables that are used as inputs into Terraform. Any variables referenced in the `main.tf` file that do not have defaults configured in `variables.tf`, will result in prompts to the user at runtime.

### Kustomize explained

Kustomize lets you customize raw, template-free YAML files for multiple purposes, leaving the original YAML untouched and usable as is. The idea behind kustomize is taking a set of generic kubernetes manifests and describing how you want to customize them in a `kustomization.yaml` file. For our case, we used a generic application that uses Ingress from this [link](https://cloud.google.com/kubernetes-engine/docs/how-to/load-balance-ingress). You can find the YAML files for this App under `demoApp/base_manifests` folder. Later, we will customize them using kustomize to add some annotations to the Ingress resource.

A summary of the steps to create a customized Kubernetes manifest are listed below:

1. Create a kustomization.yaml file using `touch kustomization.yaml`
1. Declare generic resources YAML files you want to add to the file using the `kustomize edit add resource` command.
1. Create a patch file describing how you want to update those resources from the original ones and add it to kustomization.yaml file with the `kustomize edit add patch [filename]` command.
1. Finally, use `kustomize build` command to generate the final YAML manifest.

more documentation about kustomize and how you can use it can be found in their official [website](https://kustomize.io/)

### Deploying the scenario

To build out the environment, first we need to export two variables.

The first one contains the domain name we want to assign to our Ingress.
The second is the DNS managed zone name where we will create the DNS record for Ingress.

Open a terminal and export these variables according to your setup:
- `export DOMAIN="heyingress.fakedomain.com"`
- `export MANAGED_ZONE="fakedomain-zone"`

Now you can execute the following make command to run the demo:

```
$ make create
```

## Validation

To validate the scenario was successfull and our Ingress is properly configured run:

```
make validate
```

## Teardown

When you are finished with this example you will want to clean up the resources that were created to avoid accruing charges:

```
$ terraform teardown
```

Since Terraform tracks the resources it created it is able to tear them all down.

## Troubleshooting

when you create a google managed certificate, it takes approximately 30 to 60 minutes before the certificate is activated for the domain. If the certificate status is not set to `active` or `provisioning`, hop on [here](https://cloud.google.com/load-balancing/docs/ssl-certificates#certificate-resource-status) for more information on what went wrong.
Usually, it's either your dns is not properly configured or the Ingress did not create HTTP/s load balancer with the ip pointed to by the dns record you created.

## Relevant Material

* [Kubernetes Ingress](https://kubernetes.io/docs/concepts/services-networking/Ingress/)
* [Setting up HTTP Load Balancing with Ingress](https://cloud.google.com/kubernetes-engine/docs/tutorials/http-balancer)
* [HTTP(s) load balancing with Ingress](https://cloud.google.com/kubernetes-engine/docs/concepts/Ingress)
* [Ingress-gce](https://github.com/kubernetes/Ingress-gce)
* [Terraform Google Cloud Provider](https://www.terraform.io/docs/providers/google/index.html)

**This is not an officially supported Google product**
