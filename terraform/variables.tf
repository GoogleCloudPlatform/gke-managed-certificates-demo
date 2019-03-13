/*
Copyright 2018 Google LLC

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    https://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

variable "project" {
  description = "the GCP project to deploy this demo into"
  type        = "string"
}

variable "region" {
  description = "the region in which to create the Kubernetes cluster"
  type        = "string"
}

variable "cluster_name" {
  description = "the name to use when creating the GKE cluster"
  type        = "string"
}

variable "domain" {
  description = "the name to domain that will be used"
  type        = "string"
}

variable "managed_zone" {
  description = "managed zone to use to create domain name"
  type        = "string"
}
