#! /usr/bin/env bash

# Copyright 2018 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# "---------------------------------------------------------"
# "-                                                       -"
# "-  Creates cluster and deploys demo application         -"
# "-                                                       -"
# "---------------------------------------------------------"

set -o errexit
set -o nounset
set -o pipefail

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"

# source common.sh which checks for available commands and exports variables necessary for this demo
# shellcheck source=scripts/common.sh
source "$ROOT/scripts/common.sh"

# Generate the variables to be used by Terraform
# shellcheck source=scripts/generate-tfvars.sh
source "$ROOT/scripts/generate-tfvars.sh"

# Enable required GCP APIs
gcloud services enable container.googleapis.com dns.googleapis.com

# Initialize and run Terraform
echo "1. Building out environment"
(cd "$ROOT/terraform"; terraform init -input=false)
(cd "$ROOT/terraform"; terraform apply -input=false -auto-approve)

# Generate kubeconfig entry for newly generated certificate
echo "2. Generating Kubeconfig entry for the certificate"
# workaround for region issue. Region specified in your service account is not always the same for the certificate.
certificate_region=$(gcloud container clusters list | grep $CLUSTER_NAME | awk '{print $2}')
# Get actual region for cluster entrypoint. This is where the certificate lives regardless of your region/zone settings.
gcloud container clusters get-credentials "${CLUSTER_NAME}" --region "${certificate_region}"  --project "${PROJECT}"

# create the application that uses ingress with our created managed certificate
echo "4. deploy an application with an ingress to our gke cluster"

# create a separate folder for kustomize manifests and move to it
mkdir -p "$ROOT/demoApp/kustomized"
pushd "$ROOT/demoApp/kustomized"
# initialize the kustomization file.
# This file should declare all resources we want to deploy, and any customization to apply to them
touch kustomization.yaml

# add all resources of the demoApp base application to kustomization file
# these resources contains kubernetes manfiests for
# a deployment, a service and an ingress to expose the service.
kustomize edit add resource ../base_manifests/*

# create a patch file to add annotations to the ingress spec to use previously allocated ip
# and created certificate.
cat <<-EOF > add_ingress_annotations.yaml
	apiVersion: extensions/v1beta1
	kind: Ingress
	metadata:
	  name: demo-ing
	  annotations:
	    kubernetes.io/ingress.global-static-ip-name: "${DOMAIN%%.*}" # annotation to use our static ip
	    ingress.gcp.kubernetes.io/pre-shared-cert: "${DOMAIN%%.*}" # annotation to use our created certificate
	    kubernetes.io/ingress.allow-http: "false" # annotation to disable http from ingress
EOF

# add the patch file to the kustomization file
kustomize edit add patch add_ingress_annotations.yaml

# generate the final kubernetes manifests and apply them to kubectl to deploy our app
kustomize build . | kubectl apply -f -
popd
