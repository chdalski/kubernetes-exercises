#!/bin/bash

# shellcheck source=../../.scripts/verify.sh
source "$(git rev-parse --show-toplevel)/.scripts/verify.sh"

# shellcheck disable=SC2329
verify_task1() {
  TASK_NUMBER="1"
  local expected_repo_name="bitnami"
  local expected_repo_url="https://charts.bitnami.com/bitnami"

  # Check if the bitnami repo is present and has the correct URL
  debug "Checking if helm repo '$expected_repo_name' exists with correct URL."
  local repo_url
  repo_url="$(helm repo list -o json 2>/dev/null | jq -r '.[] | select(.name=="'"$expected_repo_name"'") | .url')" || {
    debug "Failed to query helm repositories."
    failed
    return
  }
  if [ -z "$repo_url" ]; then
    debug "Helm repo '$expected_repo_name' not found."
    failed
    return
  fi
  if [ "$repo_url" != "$expected_repo_url" ]; then
    debug "Helm repo '$expected_repo_name' URL is '$repo_url', expected '$expected_repo_url'."
    failed
    return
  fi

  debug "All checks passed for Task 1. Verification successful."
  solved
  return
}

# shellcheck disable=SC2329
verify_task2() {
  TASK_NUMBER="2"
  local expected_release="custom-apache"
  local expected_namespace="web"
  local expected_image_tag="2.4.58-debian-11-r0"
  local expected_service_type="NodePort"
  local expected_replica_count="3"

  # Check if the release exists in the correct namespace
  debug "Checking if Helm release '$expected_release' exists in namespace '$expected_namespace'."
  local release_json
  release_json="$(helm list -n "$expected_namespace" -o json 2>/dev/null | jq '.[] | select(.name=="'"$expected_release"'")')" || {
    debug "Failed to query Helm releases."
    failed
    return
  }
  if [ -z "$release_json" ]; then
    debug "Helm release '$expected_release' not found in namespace '$expected_namespace'."
    failed
    return
  fi

  # Check chart name
  local chart_name
  chart_name="$(echo "$release_json" | jq -r '.chart' | cut -d'-' -f1)" || {
    debug "Failed to extract chart name from Helm release."
    failed
    return
  }
  if [ "$chart_name" != "apache" ]; then
    debug "Helm release chart is '$chart_name', expected 'apache'."
    failed
    return
  fi

  # Check image tag in deployment
  debug "Checking if Deployment uses correct image tag."
  local deploy_json
  deploy_json="$(kubectl get deployment -n "$expected_namespace" -l app.kubernetes.io/instance="$expected_release" -o json 2>/dev/null)" || {
    debug "Failed to get deployment for Helm release '$expected_release'."
    failed
    return
  }
  local image_tag
  image_tag="$(echo "$deploy_json" | jq -r '.items[0].spec.template.spec.containers[0].image' | awk -F: '{print $2}')" || {
    debug "Failed to extract image tag from deployment."
    failed
    return
  }
  if [ "$image_tag" != "$expected_image_tag" ]; then
    debug "Deployment image tag is '$image_tag', expected '$expected_image_tag'."
    failed
    return
  fi

  # Check service type
  debug "Checking if Service uses correct type."
  local svc_json
  svc_json="$(kubectl get svc -n "$expected_namespace" -l app.kubernetes.io/instance="$expected_release" -o json 2>/dev/null)" || {
    debug "Failed to get service for Helm release '$expected_release'."
    failed
    return
  }
  local svc_type
  svc_type="$(echo "$svc_json" | jq -r '.items[0].spec.type')" || {
    debug "Failed to extract service type."
    failed
    return
  }
  if [ "$svc_type" != "$expected_service_type" ]; then
    debug "Service type is '$svc_type', expected '$expected_service_type'."
    failed
    return
  fi

  # Check replica count
  debug "Checking if Deployment has correct replica count."
  local replicas
  replicas="$(echo "$deploy_json" | jq -r '.items[0].spec.replicas')" || {
    debug "Failed to extract replica count from deployment."
    failed
    return
  }
  if [ "$replicas" != "$expected_replica_count" ]; then
    debug "Deployment replica count is '$replicas', expected '$expected_replica_count'."
    failed
    return
  fi

  debug "All checks passed for Task 2. Verification successful."
  solved
  return
}

# shellcheck disable=SC2329
verify_task3() {
  TASK_NUMBER="3"
  local expected_release="vault"
  local expected_namespace="fort-knox"
  local expected_chart_version="0.30.1"

  # Check if the release exists in the correct namespace
  debug "Checking if Helm release '$expected_release' exists in namespace '$expected_namespace'."
  local release_json
  release_json="$(helm list -n "$expected_namespace" -o json 2>/dev/null | jq '.[] | select(.name=="'"$expected_release"'")')" || {
    debug "Failed to query Helm releases."
    failed
    return
  }
  if [ -z "$release_json" ]; then
    debug "Helm release '$expected_release' not found in namespace '$expected_namespace'."
    failed
    return
  fi

  # Check chart version
  debug "Checking if Helm release '$expected_release' is at chart version '$expected_chart_version'."
  local chart_version
  chart_version="$(echo "$release_json" | jq -r '.chart' | awk -F- '{print $NF}')" || {
    debug "Failed to extract chart version from Helm release."
    failed
    return
  }
  if [ "$chart_version" != "$expected_chart_version" ]; then
    debug "Helm release chart version is '$chart_version', expected '$expected_chart_version'."
    failed
    return
  fi

  debug "All checks passed for Task 3. Verification successful."
  solved
  return
}

# shellcheck disable=SC2329
verify_task4() {
  TASK_NUMBER="4"
  local expected_image_tag="7.2.0-debian-11-r0"
  local expected_output_file="redis-manifests.yaml"

  # Check if output file exists
  debug "Checking if output file '$expected_output_file' exists."
  [ -f "$expected_output_file" ] || {
    debug "Output file '$expected_output_file' not found."
    failed
    return
  }

  # Check if the output file contains the correct image tag for Redis
  debug "Checking if output file contains the correct Redis image tag."
  grep "image:.*redis.*:$expected_image_tag" "$expected_output_file" >/dev/null 2>&1 || {
    debug "Output file does not contain the expected Redis image tag '$expected_image_tag'."
    failed
    return
  }

  # Check if the output file contains a reference to the Bitnami Redis chart
  debug "Checking if output file contains a reference to the Bitnami Redis chart."
  grep "bitnami/redis" "$expected_output_file" >/dev/null 2>&1 || {
    debug "Output file does not contain a reference to the Bitnami Redis chart."
    failed
    return
  }

  debug "All checks passed for Task 4. Verification successful."
  solved
  return
}

# shellcheck disable=SC2329
verify_task5() {
  TASK_NUMBER="5"
  local expected_release="qdrant-db"
  local expected_namespace="ai"

  # Check that the Helm release no longer exists
  debug "Checking that Helm release '$expected_release' does not exist in namespace '$expected_namespace'."
  helm list -n "$expected_namespace" -o json 2>/dev/null | jq -e '.[] | select(.name=="'"$expected_release"'")' >/dev/null 2>&1 && {
    debug "Helm release '$expected_release' still exists in namespace '$expected_namespace'."
    failed
    return
  }

  # Check that no resources with the release label remain in the namespace
  debug "Checking that no resources with label 'app.kubernetes.io/instance=$expected_release' remain in namespace '$expected_namespace'."
  local resource_count
  resource_count="$(kubectl get all -n "$expected_namespace" -l app.kubernetes.io/instance="$expected_release" --no-headers 2>/dev/null | wc -l | tr -d ' ')" || {
    debug "Failed to query for resources with label 'app.kubernetes.io/instance=$expected_release'."
    failed
    return
  }
  if [ "$resource_count" -ne 0 ]; then
    debug "There are still $resource_count resources with label 'app.kubernetes.io/instance=$expected_release' in namespace '$expected_namespace'."
    failed
    return
  fi

  debug "All checks passed for Task 5. Verification successful."
  solved
  return
}

# shellcheck disable=SC2329
verify_task6() {
  TASK_NUMBER="6"
  local expected_release="terraform"
  local expected_namespace="deployment"
  local rollback_source_revision="1"

  # Check that the Helm release exists in the correct namespace
  debug "Checking if Helm release '$expected_release' exists in namespace '$expected_namespace'."
  helm list -n "$expected_namespace" -o json 2>/dev/null | jq -e '.[] | select(.name=="'"$expected_release"'")' >/dev/null 2>&1 || {
    debug "Helm release '$expected_release' not found in namespace '$expected_namespace'."
    failed
    return
  }

  # Get the latest deployed revision (the rollback target)
  debug "Getting the latest deployed revision for Helm release '$expected_release'."
  local latest_deployed_json
  latest_deployed_json="$(helm history "$expected_release" -n "$expected_namespace" -o json 2>/dev/null | jq 'map(select(.status == "deployed")) | last')" || {
    debug "Failed to get Helm release history for '$expected_release'."
    failed
    return
  }
  local latest_chart
  latest_chart="$(echo "$latest_deployed_json" | jq -r '.chart')" || {
    debug "Failed to extract chart from latest deployed revision."
    failed
    return
  }
  local latest_app_version
  latest_app_version="$(echo "$latest_deployed_json" | jq -r '.app_version // empty')" || {
    debug "Failed to extract app_version from latest deployed revision."
    failed
    return
  }

  # Get the rollback source revision (revision 1)
  debug "Getting the source (revision $rollback_source_revision) for comparison."
  local source_json
  source_json="$(helm history "$expected_release" -n "$expected_namespace" -o json 2>/dev/null | jq 'map(select(.revision == '"$rollback_source_revision"')) | .[0]')" || {
    debug "Failed to get source revision $rollback_source_revision for '$expected_release'."
    failed
    return
  }
  local source_chart
  source_chart="$(echo "$source_json" | jq -r '.chart')" || {
    debug "Failed to extract chart from source revision."
    failed
    return
  }
  local source_app_version
  source_app_version="$(echo "$source_json" | jq -r '.app_version // empty')" || {
    debug "Failed to extract app_version from source revision."
    failed
    return
  }

  # Compare chart and app_version between latest deployed and source revision
  if [ "$latest_chart" != "$source_chart" ]; then
    debug "Latest deployed chart ('$latest_chart') does not match source revision chart ('$source_chart')."
    failed
    return
  fi
  if [ "$latest_app_version" != "$source_app_version" ]; then
    debug "Latest deployed app_version ('$latest_app_version') does not match source revision app_version ('$source_app_version')."
    failed
    return
  fi

  debug "All checks passed for Task 6. Verification successful."
  solved
  return
}

# shellcheck disable=SC2329
verify_task7() {
  TASK_NUMBER="7"
  local expected_chart="hello-world"
  local expected_repo_url="https://helm.github.io/examples"
  local expected_version="0.1.0"
  local expected_chart_dir="hello-world"

  # Check if the chart directory exists and contains Chart.yaml
  debug "Checking if chart directory '$expected_chart_dir' exists and contains Chart.yaml."
  [ -d "$expected_chart_dir" ] || {
    debug "Chart directory '$expected_chart_dir' not found."
    failed
    return
  }
  [ -f "$expected_chart_dir/Chart.yaml" ] || {
    debug "Chart.yaml not found in '$expected_chart_dir'."
    failed
    return
  }

  # Check Chart.yaml for correct name and version
  debug "Checking Chart.yaml for correct chart name and version."
  local chart_name
  chart_name="$(grep '^name:' "$expected_chart_dir/Chart.yaml" | awk '{print $2}')" || {
    debug "Failed to extract chart name from Chart.yaml."
    failed
    return
  }
  if [ "$chart_name" != "$expected_chart" ]; then
    debug "Chart name in Chart.yaml is '$chart_name', expected '$expected_chart'."
    failed
    return
  fi

  local chart_version
  chart_version="$(grep '^version:' "$expected_chart_dir/Chart.yaml" | awk '{print $2}')" || {
    debug "Failed to extract chart version from Chart.yaml."
    failed
    return
  }
  if [ "$chart_version" != "$expected_version" ]; then
    debug "Chart version in Chart.yaml is '$chart_version', expected '$expected_version'."
    failed
    return
  fi

  debug "All checks passed for Task 7. Verification successful."
  solved
  return
}

# shellcheck disable=SC2034
VERIFY_TASK_FUNCTIONS=(
  verify_task1
  verify_task2
  verify_task3
  verify_task4
  verify_task5
  verify_task6
  verify_task7
)
run_verification VERIFY_TASK_FUNCTIONS "$@"

exit 0
