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
# "-  Validation script checks if demo application         -"
# "-  deployed successfully.                               -"
# "-                                                       -"
# "---------------------------------------------------------"

set -o nounset
set -o pipefail

# Define retry constants
MAX_COUNT=60
RETRY_COUNT=0
SLEEP=20

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
# source our demo variables
# shellcheck source=scripts/common.sh
source "$ROOT/scripts/common.sh"

# get application name from kubernetes
APP_NAME=$(kubectl get deployments -n default \
  -ojsonpath='{.items[0].metadata.name}')
APP_MESSAGE="deployment \"$APP_NAME\" successfully rolled out"

cd "$ROOT/terraform" || exit; CLUSTER_NAME=$(terraform output cluster_name) \
  ZONE=$(terraform output primary_zone)

# Get credentials for the k8s cluster
gcloud container clusters get-credentials "$CLUSTER_NAME" --zone="$ZONE"

# check our deployment status
SUCCESSFUL_ROLLOUT=false
for _ in {1..60}; do
  ROLLOUT=$(kubectl rollout status -n default \
    --watch=false deployment/"$APP_NAME") &> /dev/null
  if [[ $ROLLOUT = *"$APP_MESSAGE"* ]]; then
    SUCCESSFUL_ROLLOUT=true
    break
  fi
  sleep 2
  echo "Waiting for application deployment..."
done

if [ "${SUCCESSFUL_ROLLOUT}" = false ]; then
  echo "ERROR - $APP_NAME failed to deploy"
  exit 1
else
  echo "$APP_NAME successfully deployed"
fi

# Loop for up to 120 seconds waiting for ingress's IP address to become available
INGRESS_NAME=$(kubectl get ingress -n default \
  -ojsonpath='{.items[0].metadata.name}')
for _ in {1..60}; do
  # Get ingress's ip
  EXT_IP=$(kubectl get ing "$INGRESS_NAME" -n default \
    -ojsonpath='{.status.loadBalancer.ingress[0].ip}')
  [ -n "$EXT_IP" ] && break
  sleep 2
  echo "Waiting for Ingress availability..."
done

if [ -z "$EXT_IP" ]; then
  echo "ERROR - Timed out waiting for ingress"
  exit 1
else
  echo "Ingress is available on $EXT_IP"
fi

# Loop for up to 69 mins waiting for managed certificate to become active
# managed certificate takes between 30 to 60 mins to become active
for _ in {1..120}; do
  STATUS=$(gcloud beta compute ssl-certificates list --format='value(managed.status)')
  [ "$STATUS" == "ACTIVE" ] && break
  sleep 30
  echo "Waiting for certificate to be signed..."
done

if [ "$STATUS" != "ACTIVE" ]; then
  echo "ERROR - Timed out waiting for certificate to become valide"
  exit 1
else
  echo "ingress certificate is active"
fi

# check if certificate domain name is resolvable to the ingress ip
DOMAIN_IP="$(dig +short "${DOMAIN}")"
if [ "${DOMAIN_IP}" != "${EXT_IP}" ]; then
  echo "ERROR - $DOMAIN is not pointing to ingress IP ${EXT_IP}"
  exit 1
fi
echo "App is available at: https://${DOMAIN}"

# Curl for the service with retries untill you get a HTTP 200 response code back
# this makes sure our ingress ssl termination is working fine
STATUS_CODE=$(curl -s -o /dev/null -w "%{http_code}" https://"{$DOMAIN}")
until [[ "${STATUS_CODE}" -eq 200 ]]; do
  if [[ "${RETRY_COUNT}" -gt "${MAX_COUNT}" ]]; then
    # failed with retry, lets check whatz wrong and bail
    echo "Retry count exceeded. Exiting..."
    # Timed out?
    if [ -n "$STATUS_CODE" ]; then
      echo "ERROR - Timed out waiting for service"
      exit 1
    fi
    # HTTP status not okay?
    if [ "$STATUS_CODE" != "200" ]; then
      echo "ERROR - Service is returning error"
      exit 1
    fi
  fi
  NUM_SECONDS="$(( RETRY_COUNT * SLEEP ))"
  echo "Waiting for service availability..."
  echo "service / did not return an HTTP 200 response code after ${NUM_SECONDS} seconds"
  sleep "${SLEEP}"
  RETRY_COUNT="$(( RETRY_COUNT + 1 ))"
  STATUS_CODE=$(curl -s -o /dev/null -w "%{http_code}" https://"${DOMAIN}")
done

# succeeded, let's report it
echo "Application endpoint returns an HTTP 200 response code"
