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
# "-  Common commands for all scripts                      -"
# "-                                                       -"
# "---------------------------------------------------------"

# common variables needed for demo
# gke cluster name
export CLUSTER_NAME="gke-managed-certificates-demo"

# gcloud, kubectl, kustomize and terraform are required for this POC
command -v gcloud >/dev/null 2>&1 || { \
 echo >&2 "I require gcloud but it's not installed.  Aborting."; exit 1; }

command -v kubectl >/dev/null 2>&1 || { \
 echo >&2 "I require kubectl but it's not installed.  Aborting."; exit 1; }

command -v kustomize >/dev/null 2>&1 || { \
 echo >&2 "I require kustomize but it's not installed.";
 echo >&2 "Check this link for instructions on how to install:";
 echo >&2 "https://github.com/kubernetes-sigs/kustomize/blob/master/docs/INSTALL.md   Aborting."; exit 1; }

command -v terraform >/dev/null 2>&1 || { \
 echo >&2 "I require terraform but it's not installed.  Aborting."; exit 1; }
