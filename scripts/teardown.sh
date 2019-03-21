#! /usr/bin/env bash

# Copyright 2019 Google LLC
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
# "-  Delete uninstalls the demo application and deletes   -"
# "-  the GKE cluster                                      -"
# "-                                                       -"
# "---------------------------------------------------------"

# Do not set errexit as it makes partial deletes impossible
set -o nounset
set -o pipefail

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
# shellcheck source=scripts/common.sh
source "$ROOT/scripts/common.sh"

# teardown the ingress resource
pushd "$ROOT/demo-app/kustomized" || exit 1
# generate the kubernetes manifests and delete them with kubectl
kustomize build . | kubectl delete -f -
popd || exit 1

# Wait for Kubernetes resources to be deleted before deleting the cluster
# Also, filter out the resources to what would specifically be created for
# the GKE cluster
until [[ $(gcloud compute forwarding-rules list --filter "name ~ demo-ing") == "" ]]; do
  echo "Waiting for cluster to become ready for destruction..."
  sleep 10
done

until [[ $(gcloud compute target-https-proxies list --filter "name ~ demo-ing") == "" ]]; do
  echo "Waiting for cluster to become ready for destruction..."
  sleep 10
done

# Tear down Terraform-managed resources and remove generated tfvars
cd "$ROOT/terraform" || exit; terraform destroy -input=false -auto-approve
rm -f "$ROOT/terraform/terraform.tfvars"
rm -f "$ROOT/terraform/terraform.tfstate"
rm -f "$ROOT/terraform/terraform.tfstate.backup"

# remove kubectl context & cluster from config
CONTEXT=$(kubectl config get-contexts -o=name | grep "${CLUSTER_NAME}")
if [[ -n $CONTEXT ]]; then
  kubectl config delete-context "$CONTEXT"
  kubectl config delete-cluster "$CONTEXT"
  kubectl config unset "users.$CONTEXT"
  # unset current context if it's us
  CURRENT=$(kubectl config current-context)
  if [ "$CURRENT" == "$CONTEXT" ]; then
    kubectl config unset current-context
  fi
  echo "Removed demo from kubectl config."
else
  echo "No kubectl contexts to destroy."
fi

# remove kustomized folder
rm -rf "$ROOT/kube-manifests/kustomized"
