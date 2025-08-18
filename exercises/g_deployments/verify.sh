#!/bin/bash

# shellcheck source=../../.scripts/verify.sh
source "$(git rev-parse --show-toplevel)/.scripts/verify.sh"

# shellcheck disable=SC2329
verify_task1() {
  TASK_NUMBER="1"

  # Define expected values
  local expected_deploy_name="webapp-deploy"
  local expected_image="nginx:1.25"
  local expected_replicas=3
  local expected_port=80

  # Get deployment JSON from Kubernetes API
  local rs_deploy_json
  rs_deploy_json=$(kubectl get deployment "$expected_deploy_name" -o json 2>/dev/null) || { debug "Failed to get deployment '$expected_deploy_name' from Kubernetes API."; failed; return; }

  # Check deployment name
  local rs_deploy_name
  rs_deploy_name=$(echo "$rs_deploy_json" | jq -r '.metadata.name' 2>/dev/null) || { debug "Failed to extract deployment name using jq."; failed; return; }
  if [ "$rs_deploy_name" != "$expected_deploy_name" ]; then
    debug "Deployment name mismatch: expected '$expected_deploy_name', found '$rs_deploy_name'."
    failed
    return
  fi

  # Check replicas
  local rs_replicas
  rs_replicas=$(echo "$rs_deploy_json" | jq '.spec.replicas' 2>/dev/null) || { debug "Failed to extract replicas using jq."; failed; return; }
  if [ "$rs_replicas" -ne "$expected_replicas" ]; then
    debug "Replica count mismatch: expected '$expected_replicas', found '$rs_replicas'."
    failed
    return
  fi

  # Check container image
  local rs_image
  rs_image=$(echo "$rs_deploy_json" | jq -r '.spec.template.spec.containers[0].image' 2>/dev/null) || { debug "Failed to extract container image using jq."; failed; return; }
  if [ "$rs_image" != "$expected_image" ]; then
    debug "Container image mismatch: expected '$expected_image', found '$rs_image'."
    failed
    return
  fi

  # Check container port
  local rs_port
  rs_port=$(echo "$rs_deploy_json" | jq '.spec.template.spec.containers[0].ports[0].containerPort' 2>/dev/null) || { debug "Failed to extract container port using jq."; failed; return; }
  if [ "$rs_port" -ne "$expected_port" ]; then
    debug "Container port mismatch: expected '$expected_port', found '$rs_port'."
    failed
    return
  fi

  debug "All deployment verifications passed successfully."
  solved
  return
}

# shellcheck disable=SC2329
verify_task2() {
  TASK_NUMBER="2"

  # Define expected values
  local expected_deployment_name="api-deploy"
  local expected_namespace="task2"
  local expected_image="nginx:1.29"
  local expected_replicas="2"
  local expected_strategy="RollingUpdate"

  # Get deployment as JSON from Kubernetes API
  local rs_deploy_json
  rs_deploy_json=$(kubectl get deployment "$expected_deployment_name" -n "$expected_namespace" -o json 2>/dev/null) || { debug "Failed to get deployment '$expected_deployment_name' in namespace '$expected_namespace'."; failed; return; }

  # Check replicas
  local rs_replicas
  rs_replicas=$(echo "$rs_deploy_json" | jq -r '.spec.replicas' 2>/dev/null) || { debug "Failed to extract replicas using jq."; failed; return; }
  if [ "$rs_replicas" != "$expected_replicas" ]; then
    debug "Replica count mismatch: expected '$expected_replicas', found '$rs_replicas'."
    failed
    return
  fi

  # Check container image
  local rs_image
  rs_image=$(echo "$rs_deploy_json" | jq -r '.spec.template.spec.containers[0].image' 2>/dev/null) || { debug "Failed to extract container image using jq."; failed; return; }
  if [ "$rs_image" != "$expected_image" ]; then
    debug "Container image mismatch: expected '$expected_image', found '$rs_image'."
    failed
    return
  fi

  # Check strategy is RollingUpdate
  local rs_strategy
  rs_strategy=$(echo "$rs_deploy_json" | jq -r '.spec.strategy.type' 2>/dev/null) || { debug "Failed to extract deployment strategy using jq."; failed; return; }
  if [ "$rs_strategy" != "$expected_strategy" ]; then
    debug "Deployment strategy mismatch: expected '$expected_strategy', found '$rs_strategy'."
    failed
    return
  fi

  # Check that all pods are running and ready with the correct image
  local rs_ready_replicas
  rs_ready_replicas=$(echo "$rs_deploy_json" | jq -r '.status.readyReplicas' 2>/dev/null) || { debug "Failed to extract readyReplicas using jq."; failed; return; }
  if [ "$rs_ready_replicas" != "$expected_replicas" ]; then
    debug "Ready replicas mismatch: expected '$expected_replicas', found '$rs_ready_replicas'."
    failed
    return
  fi

  local rs_updated_replicas
  rs_updated_replicas=$(echo "$rs_deploy_json" | jq -r '.status.updatedReplicas' 2>/dev/null) || { debug "Failed to extract updatedReplicas using jq."; failed; return; }
  if [ "$rs_updated_replicas" != "$expected_replicas" ]; then
    debug "Updated replicas mismatch: expected '$expected_replicas', found '$rs_updated_replicas'."
    failed
    return
  fi

  debug "All deployment verifications passed successfully."
  solved
  return
}

# shellcheck disable=SC2329
verify_task3() {
  TASK_NUMBER="3"

  # Define expected values
  local expected_deployment_name="cache-deploy"
  local expected_image="redis:8.0.2"
  local expected_replicas=4

  # Get deployment JSON from Kubernetes API
  local rs_deploy_json
  rs_deploy_json=$(kubectl get deployment "$expected_deployment_name" -o json 2>/dev/null) || { debug "Failed to get deployment '$expected_deployment_name' from Kubernetes API."; failed; return; }

  # Check number of replicas
  local rs_replicas
  rs_replicas=$(echo "$rs_deploy_json" | jq '.spec.replicas' 2>/dev/null) || { debug "Failed to extract replicas using jq."; failed; return; }
  if [ "$rs_replicas" -ne "$expected_replicas" ]; then
    debug "Replica count mismatch: expected '$expected_replicas', found '$rs_replicas'."
    failed
    return
  fi

  # Check image of the first container in the deployment
  local rs_image
  rs_image=$(echo "$rs_deploy_json" | jq -r '.spec.template.spec.containers[0].image' 2>/dev/null) || { debug "Failed to extract container image using jq."; failed; return; }
  if [ "$rs_image" != "$expected_image" ]; then
    debug "Container image mismatch: expected '$expected_image', found '$rs_image'."
    failed
    return
  fi

  debug "All deployment verifications passed successfully."
  solved
  return
}

# shellcheck disable=SC2329
verify_task4() {
  TASK_NUMBER="4"

  # Define expected values
  local expected_deploy_name="worker-deploy"
  local expected_replicas_up=5
  local expected_replicas_down=2

  # Get deployment JSON from Kubernetes API
  local rs_deploy_json
  rs_deploy_json=$(kubectl get deployment "$expected_deploy_name" -o json 2>/dev/null) || { debug "Failed to get deployment '$expected_deploy_name' from Kubernetes API."; failed; return; }

  # Check if deployment exists and is currently scaled to 2
  local rs_replicas
  rs_replicas=$(echo "$rs_deploy_json" | jq '.spec.replicas' 2>/dev/null) || { debug "Failed to extract replicas using jq."; failed; return; }
  if [ "$rs_replicas" -ne "$expected_replicas_down" ]; then
    debug "Replica count mismatch: expected '$expected_replicas_down', found '$rs_replicas'."
    failed
    return
  fi

  # Get events for the deployment (only once)
  local rs_events_json
  rs_events_json=$(kubectl get event --field-selector involvedObject.kind=Deployment,involvedObject.name="$expected_deploy_name" -o json 2>/dev/null) || { debug "Failed to get events for deployment '$expected_deploy_name'."; failed; return; }

  # Check for scale up event to 5
  local rs_scaled_up
  rs_scaled_up=$(echo "$rs_events_json" | jq -r --arg up_msg "Scaled up replica set" --argjson up_replicas "$expected_replicas_up" \
    '.items[] | select(.message | test($up_msg)) | select(.message | test("to " + ($up_replicas|tostring))) | .message' 2>/dev/null | wc -l)
  if [ "$rs_scaled_up" -eq 0 ]; then
    debug "No scale up event found to $expected_replicas_up replicas."
    failed
    return
  fi

  # Check for scale down event to 2
  local rs_scaled_down
  rs_scaled_down=$(echo "$rs_events_json" | jq -r --arg down_msg "Scaled down replica set" --argjson down_replicas "$expected_replicas_down" \
    '.items[] | select(.message | test($down_msg)) | select(.message | test("to " + ($down_replicas|tostring))) | .message' 2>/dev/null | wc -l)
  if [ "$rs_scaled_down" -eq 0 ]; then
    debug "No scale down event found to $expected_replicas_down replicas."
    failed
    return
  fi

  debug "All deployment and event verifications passed successfully."
  solved
  return
}

# shellcheck disable=SC2329
verify_task5() {
  TASK_NUMBER="5"

  # Define expected values
  local expected_deploy_name="analytics-deploy"
  local expected_image="python:3.12"
  local expected_command='["python","-c","import time; time.sleep(99999999)"]'
  local expected_cpu_req="100m"
  local expected_cpu_lim="500m"
  local expected_mem_req="128Mi"
  local expected_mem_lim="512Mi"
  local expected_replicas="1"

  # Get deployment JSON from Kubernetes API
  local rs_deploy_json
  rs_deploy_json=$(kubectl get deployment "$expected_deploy_name" -o json 2>/dev/null) || { debug "Failed to get deployment '$expected_deploy_name' from Kubernetes API."; failed; return; }

  # Check replicas
  local rs_replicas
  rs_replicas=$(echo "$rs_deploy_json" | jq -r '.spec.replicas' 2>/dev/null) || { debug "Failed to extract replicas using jq."; failed; return; }
  if [ "$rs_replicas" != "$expected_replicas" ]; then
    debug "Replica count mismatch: expected '$expected_replicas', found '$rs_replicas'."
    failed
    return
  fi

  # Check image
  local rs_image
  rs_image=$(echo "$rs_deploy_json" | jq -r '.spec.template.spec.containers[0].image' 2>/dev/null) || { debug "Failed to extract container image using jq."; failed; return; }
  if [ "$rs_image" != "$expected_image" ]; then
    debug "Container image mismatch: expected '$expected_image', found '$rs_image'."
    failed
    return
  fi

  # Check command
  local rs_command
  rs_command=$(echo "$rs_deploy_json" | jq -c '.spec.template.spec.containers[0].command' 2>/dev/null) || { debug "Failed to extract container command using jq."; failed; return; }
  if [ "$rs_command" != "$expected_command" ]; then
    debug "Container command mismatch: expected '$expected_command', found '$rs_command'."
    failed
    return
  fi

  # Check CPU request
  local rs_cpu_req
  rs_cpu_req=$(echo "$rs_deploy_json" | jq -r '.spec.template.spec.containers[0].resources.requests.cpu' 2>/dev/null) || { debug "Failed to extract CPU request using jq."; failed; return; }
  if [ "$rs_cpu_req" != "$expected_cpu_req" ]; then
    debug "CPU request mismatch: expected '$expected_cpu_req', found '$rs_cpu_req'."
    failed
    return
  fi

  # Check CPU limit
  local rs_cpu_lim
  rs_cpu_lim=$(echo "$rs_deploy_json" | jq -r '.spec.template.spec.containers[0].resources.limits.cpu' 2>/dev/null) || { debug "Failed to extract CPU limit using jq."; failed; return; }
  if [ "$rs_cpu_lim" != "$expected_cpu_lim" ]; then
    debug "CPU limit mismatch: expected '$expected_cpu_lim', found '$rs_cpu_lim'."
    failed
    return
  fi

  # Check memory request
  local rs_mem_req
  rs_mem_req=$(echo "$rs_deploy_json" | jq -r '.spec.template.spec.containers[0].resources.requests.memory' 2>/dev/null) || { debug "Failed to extract memory request using jq."; failed; return; }
  if [ "$rs_mem_req" != "$expected_mem_req" ]; then
    debug "Memory request mismatch: expected '$expected_mem_req', found '$rs_mem_req'."
    failed
    return
  fi

  # Check memory limit
  local rs_mem_lim
  rs_mem_lim=$(echo "$rs_deploy_json" | jq -r '.spec.template.spec.containers[0].resources.limits.memory' 2>/dev/null) || { debug "Failed to extract memory limit using jq."; failed; return; }
  if [ "$rs_mem_lim" != "$expected_mem_lim" ]; then
    debug "Memory limit mismatch: expected '$expected_mem_lim', found '$rs_mem_lim'."
    failed
    return
  fi

  debug "All deployment resource and configuration verifications passed successfully."
  solved
  return
}

# shellcheck disable=SC2329
verify_task6() {
  TASK_NUMBER="6"

  # Define expected values
  local expected_deploy_name="envtest-deploy"
  local expected_image="nginx:1.29"
  local expected_replicas=2
  local expected_env0_name="ENV"
  local expected_env0_value="production"
  local expected_env1_name="DEBUG"
  local expected_env1_value="false"

  # Get deployment JSON from Kubernetes API
  local rs_deploy_json
  rs_deploy_json=$(kubectl get deployment "$expected_deploy_name" -o json 2>/dev/null) || { debug "Failed to get deployment '$expected_deploy_name' from Kubernetes API."; failed; return; }

  # Check deployment name
  local rs_name
  rs_name=$(echo "$rs_deploy_json" | jq -r '.metadata.name' 2>/dev/null) || { debug "Failed to extract deployment name using jq."; failed; return; }
  if [ "$rs_name" != "$expected_deploy_name" ]; then
    debug "Deployment name mismatch: expected '$expected_deploy_name', found '$rs_name'."
    failed
    return
  fi

  # Check replicas
  local rs_replicas
  rs_replicas=$(echo "$rs_deploy_json" | jq '.spec.replicas' 2>/dev/null) || { debug "Failed to extract replicas using jq."; failed; return; }
  if [ "$rs_replicas" -ne "$expected_replicas" ]; then
    debug "Replica count mismatch: expected '$expected_replicas', found '$rs_replicas'."
    failed
    return
  fi

  # Check container image
  local rs_image
  rs_image=$(echo "$rs_deploy_json" | jq -r '.spec.template.spec.containers[0].image' 2>/dev/null) || { debug "Failed to extract container image using jq."; failed; return; }
  if [ "$rs_image" != "$expected_image" ]; then
    debug "Container image mismatch: expected '$expected_image', found '$rs_image'."
    failed
    return
  fi

  # Check environment variables count
  local rs_env_count
  rs_env_count=$(echo "$rs_deploy_json" | jq '.spec.template.spec.containers[0].env | length' 2>/dev/null) || { debug "Failed to extract environment variable count using jq."; failed; return; }
  if [ "$rs_env_count" -lt 2 ]; then
    debug "Environment variable count mismatch: expected at least 2, found '$rs_env_count'."
    failed
    return
  fi

  # Check environment variable 0
  local rs_env0_name
  rs_env0_name=$(echo "$rs_deploy_json" | jq -r '.spec.template.spec.containers[0].env[0].name' 2>/dev/null) || { debug "Failed to extract env[0] name using jq."; failed; return; }
  if [ "$rs_env0_name" != "$expected_env0_name" ]; then
    debug "env[0] name mismatch: expected '$expected_env0_name', found '$rs_env0_name'."
    failed
    return
  fi

  local rs_env0_value
  rs_env0_value=$(echo "$rs_deploy_json" | jq -r '.spec.template.spec.containers[0].env[0].value' 2>/dev/null) || { debug "Failed to extract env[0] value using jq."; failed; return; }
  if [ "$rs_env0_value" != "$expected_env0_value" ]; then
    debug "env[0] value mismatch: expected '$expected_env0_value', found '$rs_env0_value'."
    failed
    return
  fi

  # Check environment variable 1
  local rs_env1_name
  rs_env1_name=$(echo "$rs_deploy_json" | jq -r '.spec.template.spec.containers[0].env[1].name' 2>/dev/null) || { debug "Failed to extract env[1] name using jq."; failed; return; }
  if [ "$rs_env1_name" != "$expected_env1_name" ]; then
    debug "env[1] name mismatch: expected '$expected_env1_name', found '$rs_env1_name'."
    failed
    return
  fi

  local rs_env1_value
  rs_env1_value=$(echo "$rs_deploy_json" | jq -r '.spec.template.spec.containers[0].env[1].value' 2>/dev/null) || { debug "Failed to extract env[1] value using jq."; failed; return; }
  if [ "$rs_env1_value" != "$expected_env1_value" ]; then
    debug "env[1] value mismatch: expected '$expected_env1_value', found '$rs_env1_value'."
    failed
    return
  fi

  debug "All deployment environment variable and configuration verifications passed successfully."
  solved
  return
}

# shellcheck disable=SC2329
verify_task7() {
  TASK_NUMBER="7"

  # Define expected values
  local expected_configmap_name="app-config"
  local expected_configmap_key="APP_MODE"
  local expected_configmap_value="debug"
  local expected_deployment_name="configmap-deploy"
  local expected_image="nginx:1.29.0"
  local expected_replicas="1"

  # Get ConfigMap as JSON from Kubernetes API
  local rs_configmap_json
  rs_configmap_json=$(kubectl get configmap "$expected_configmap_name" -o json 2>/dev/null) || { debug "Failed to get ConfigMap '$expected_configmap_name' from Kubernetes API."; failed; return; }

  # Verify ConfigMap key and value
  local rs_actual_value
  rs_actual_value=$(echo "$rs_configmap_json" | jq -r ".data.${expected_configmap_key}" 2>/dev/null) || { debug "Failed to extract key '$expected_configmap_key' from ConfigMap using jq."; failed; return; }
  if [ "$rs_actual_value" != "$expected_configmap_value" ]; then
    debug "ConfigMap key '$expected_configmap_key' value mismatch: expected '$expected_configmap_value', found '$rs_actual_value'."
    failed
    return
  fi

  # Get Deployment as JSON from Kubernetes API
  local rs_deploy_json
  rs_deploy_json=$(kubectl get deployment "$expected_deployment_name" -o json 2>/dev/null) || { debug "Failed to get deployment '$expected_deployment_name' from Kubernetes API."; failed; return; }

  # Verify replicas
  local rs_actual_replicas
  rs_actual_replicas=$(echo "$rs_deploy_json" | jq -r ".spec.replicas" 2>/dev/null) || { debug "Failed to extract replicas from deployment using jq."; failed; return; }
  if [ "$rs_actual_replicas" != "$expected_replicas" ]; then
    debug "Deployment replica count mismatch: expected '$expected_replicas', found '$rs_actual_replicas'."
    failed
    return
  fi

  # Verify image
  local rs_actual_image
  rs_actual_image=$(echo "$rs_deploy_json" | jq -r '.spec.template.spec.containers[0].image' 2>/dev/null) || { debug "Failed to extract container image from deployment using jq."; failed; return; }
  if [ "$rs_actual_image" != "$expected_image" ]; then
    debug "Deployment container image mismatch: expected '$expected_image', found '$rs_actual_image'."
    failed
    return
  fi

  # Verify envFrom references the ConfigMap
  local rs_envfrom_configmap
  rs_envfrom_configmap=$(echo "$rs_deploy_json" | jq -r '.spec.template.spec.containers[0].envFrom[]? | select(.configMapRef.name=="'"$expected_configmap_name"'") | .configMapRef.name' 2>/dev/null) || { debug "Failed to extract envFrom ConfigMap reference using jq."; failed; return; }
  if [ "$rs_envfrom_configmap" != "$expected_configmap_name" ]; then
    debug "Deployment envFrom ConfigMap reference mismatch: expected '$expected_configmap_name', found '$rs_envfrom_configmap'."
    failed
    return
  fi

  debug "All ConfigMap and deployment verifications passed successfully."
  solved
  return
}


# shellcheck disable=SC2329
verify_task8() {
  TASK_NUMBER="8"

  # Define expected values
  local expected_secret_name="db-secret"
  local expected_secret_key="DB_PASSWORD"
  local expected_secret_value="supersecret"
  local expected_deploy_name="secret-deploy"
  local expected_image_name="mysql:8.4"
  local expected_env_name="MYSQL_ROOT_PASSWORD"
  local expected_replicas="1"

  # Get Secret as JSON from Kubernetes API
  local rs_secret_json
  rs_secret_json=$(kubectl get secret "$expected_secret_name" -o json 2>/dev/null) || { debug "Failed to get secret '$expected_secret_name' from Kubernetes API."; failed; return; }

  # Check if secret contains the expected key
  local rs_secret_key_found
  rs_secret_key_found=$(echo "$rs_secret_json" | jq -r ".data | has(\"$expected_secret_key\")" 2>/dev/null) || { debug "Failed to check for key '$expected_secret_key' in secret using jq."; failed; return; }
  if [ "$rs_secret_key_found" != "true" ]; then
    debug "Secret '$expected_secret_name' does not contain key '$expected_secret_key'."
    failed
    return
  fi

  # Check if secret value matches expected (after base64 decoding)
  local rs_secret_value
  rs_secret_value=$(echo "$rs_secret_json" | jq -r ".data[\"$expected_secret_key\"]" 2>/dev/null | base64 -d 2>/dev/null) || { debug "Failed to decode secret value for key '$expected_secret_key'."; failed; return; }
  if [ "$rs_secret_value" != "$expected_secret_value" ]; then
    debug "Secret value mismatch for key '$expected_secret_key': expected '$expected_secret_value', found '$rs_secret_value'."
    failed
    return
  fi

  # Get Deployment as JSON from Kubernetes API
  local rs_deploy_json
  rs_deploy_json=$(kubectl get deployment "$expected_deploy_name" -o json 2>/dev/null) || { debug "Failed to get deployment '$expected_deploy_name' from Kubernetes API."; failed; return; }

  # Check replicas
  local rs_replicas
  rs_replicas=$(echo "$rs_deploy_json" | jq -r ".spec.replicas" 2>/dev/null) || { debug "Failed to extract replicas from deployment using jq."; failed; return; }
  if [ "$rs_replicas" != "$expected_replicas" ]; then
    debug "Deployment replica count mismatch: expected '$expected_replicas', found '$rs_replicas'."
    failed
    return
  fi

  # Check image
  local rs_image
  rs_image=$(echo "$rs_deploy_json" | jq -r ".spec.template.spec.containers[0].image" 2>/dev/null) || { debug "Failed to extract container image from deployment using jq."; failed; return; }
  if [ "$rs_image" != "$expected_image_name" ]; then
    debug "Deployment container image mismatch: expected '$expected_image_name', found '$rs_image'."
    failed
    return
  fi

  # Check env variable references the secret name
  local rs_env_secret_name
  rs_env_secret_name=$(echo "$rs_deploy_json" | jq -r ".spec.template.spec.containers[0].env[] | select(.name==\"$expected_env_name\") | .valueFrom.secretKeyRef.name" 2>/dev/null) || { debug "Failed to extract env secret name from deployment using jq."; failed; return; }
  if [ "$rs_env_secret_name" != "$expected_secret_name" ]; then
    debug "Deployment env variable '$expected_env_name' secret name mismatch: expected '$expected_secret_name', found '$rs_env_secret_name'."
    failed
    return
  fi

  # Check env variable references the secret key
  local rs_env_secret_key
  rs_env_secret_key=$(echo "$rs_deploy_json" | jq -r ".spec.template.spec.containers[0].env[] | select(.name==\"$expected_env_name\") | .valueFrom.secretKeyRef.key" 2>/dev/null) || { debug "Failed to extract env secret key from deployment using jq."; failed; return; }
  if [ "$rs_env_secret_key" != "$expected_secret_key" ]; then
    debug "Deployment env variable '$expected_env_name' secret key mismatch: expected '$expected_secret_key', found '$rs_env_secret_key'."
    failed
    return
  fi

  debug "All secret and deployment verifications passed successfully."
  solved
  return
}

# shellcheck disable=SC2329
verify_task9() {
  TASK_NUMBER="9"

  # Define expected values
  local expected_deploy_name="probe-deploy"
  local expected_image="httpd:2.4"
  local expected_replicas=2
  local expected_probe_path="/"
  local expected_probe_port=80

  # Get deployment JSON from Kubernetes API
  local rs_deploy_json
  rs_deploy_json=$(kubectl get deployment "$expected_deploy_name" -o json 2>/dev/null) || { debug "Failed to get deployment '$expected_deploy_name' from Kubernetes API."; failed; return; }

  # Check deployment name
  local rs_name
  rs_name=$(echo "$rs_deploy_json" | jq -r '.metadata.name' 2>/dev/null) || { debug "Failed to extract deployment name using jq."; failed; return; }
  if [ "$rs_name" != "$expected_deploy_name" ]; then
    debug "Deployment name mismatch: expected '$expected_deploy_name', found '$rs_name'."
    failed
    return
  fi

  # Check replicas
  local rs_replicas
  rs_replicas=$(echo "$rs_deploy_json" | jq '.spec.replicas' 2>/dev/null) || { debug "Failed to extract replicas using jq."; failed; return; }
  if [ "$rs_replicas" -ne "$expected_replicas" ]; then
    debug "Replica count mismatch: expected '$expected_replicas', found '$rs_replicas'."
    failed
    return
  fi

  # Check container image
  local rs_image
  rs_image=$(echo "$rs_deploy_json" | jq -r '.spec.template.spec.containers[0].image' 2>/dev/null) || { debug "Failed to extract container image using jq."; failed; return; }
  if [ "$rs_image" != "$expected_image" ]; then
    debug "Container image mismatch: expected '$expected_image', found '$rs_image'."
    failed
    return
  fi

  # Check readiness probe path
  local rs_probe_path
  rs_probe_path=$(echo "$rs_deploy_json" | jq -r '.spec.template.spec.containers[0].readinessProbe.httpGet.path' 2>/dev/null) || { debug "Failed to extract readiness probe path using jq."; failed; return; }
  if [ "$rs_probe_path" != "$expected_probe_path" ]; then
    debug "Readiness probe path mismatch: expected '$expected_probe_path', found '$rs_probe_path'."
    failed
    return
  fi

  # Check readiness probe port
  local rs_probe_port
  rs_probe_port=$(echo "$rs_deploy_json" | jq '.spec.template.spec.containers[0].readinessProbe.httpGet.port' 2>/dev/null) || { debug "Failed to extract readiness probe port using jq."; failed; return; }
  if [ "$rs_probe_port" -ne "$expected_probe_port" ]; then
    debug "Readiness probe port mismatch: expected '$expected_probe_port', found '$rs_probe_port'."
    failed
    return
  fi

  debug "All deployment and readiness probe verifications passed successfully."
  solved
  return
}

# shellcheck disable=SC2329
verify_task10() {
  TASK_NUMBER="10"

  # Define expected values
  local expected_deployment_name="liveness-deploy"
  local expected_image="redis:7.2"
  local expected_replicas=1
  local expected_probe_command='["redis-cli","ping"]'
  local expected_probe_period=11

  # Get deployment JSON from Kubernetes API
  local rs_deploy_json
  rs_deploy_json=$(kubectl get deployment "$expected_deployment_name" -o json 2>/dev/null) || { debug "Failed to get deployment '$expected_deployment_name' from Kubernetes API."; failed; return; }

  # Check deployment name
  local rs_name
  rs_name=$(echo "$rs_deploy_json" | jq -r '.metadata.name' 2>/dev/null) || { debug "Failed to extract deployment name using jq."; failed; return; }
  if [ "$rs_name" != "$expected_deployment_name" ]; then
    debug "Deployment name mismatch: expected '$expected_deployment_name', found '$rs_name'."
    failed
    return
  fi

  # Check replicas
  local rs_replicas
  rs_replicas=$(echo "$rs_deploy_json" | jq '.spec.replicas' 2>/dev/null) || { debug "Failed to extract replicas using jq."; failed; return; }
  if [ "$rs_replicas" -ne "$expected_replicas" ]; then
    debug "Replica count mismatch: expected '$expected_replicas', found '$rs_replicas'."
    failed
    return
  fi

  # Check container image
  local rs_image
  rs_image=$(echo "$rs_deploy_json" | jq -r '.spec.template.spec.containers[0].image' 2>/dev/null) || { debug "Failed to extract container image using jq."; failed; return; }
  if [ "$rs_image" != "$expected_image" ]; then
    debug "Container image mismatch: expected '$expected_image', found '$rs_image'."
    failed
    return
  fi

  # Check liveness probe exists
  local rs_liveness_probe
  rs_liveness_probe=$(echo "$rs_deploy_json" | jq '.spec.template.spec.containers[0].livenessProbe' 2>/dev/null) || { debug "Failed to extract livenessProbe using jq."; failed; return; }
  if [ "$rs_liveness_probe" = "null" ]; then
    debug "Liveness probe is not defined in the deployment."
    failed
    return
  fi

  # Check liveness probe command
  local rs_probe_command
  rs_probe_command=$(echo "$rs_deploy_json" | jq -c '.spec.template.spec.containers[0].livenessProbe.exec.command' 2>/dev/null) || { debug "Failed to extract liveness probe command using jq."; failed; return; }
  if [ "$rs_probe_command" != "$expected_probe_command" ]; then
    debug "Liveness probe command mismatch: expected '$expected_probe_command', found '$rs_probe_command'."
    failed
    return
  fi

  # Check liveness probe periodSeconds
  local rs_probe_period
  rs_probe_period=$(echo "$rs_deploy_json" | jq '.spec.template.spec.containers[0].livenessProbe.periodSeconds' 2>/dev/null) || { debug "Failed to extract liveness probe periodSeconds using jq."; failed; return; }
  if [ "$rs_probe_period" -ne "$expected_probe_period" ]; then
    debug "Liveness probe periodSeconds mismatch: expected '$expected_probe_period', found '$rs_probe_period'."
    failed
    return
  fi

  debug "All deployment and liveness probe verifications passed successfully."
  solved
  return
}

# shellcheck disable=SC2329
verify_task11() {
  TASK_NUMBER="11"

  # Define expected values
  local expected_deployment_name="label-deploy"
  local expected_image="nginx:1.25"
  local expected_label_key="tier"
  local expected_label_value="backend"
  local expected_replicas=3

  # Get deployment JSON from Kubernetes API
  local rs_deployment_json
  rs_deployment_json=$(kubectl get deployment "$expected_deployment_name" -o json 2>/dev/null) || { debug "Failed to get deployment '$expected_deployment_name' from Kubernetes API."; failed; return; }

  # Check replicas
  local rs_replicas
  rs_replicas=$(echo "$rs_deployment_json" | jq '.spec.replicas' 2>/dev/null) || { debug "Failed to extract replicas using jq."; failed; return; }
  if [ "$rs_replicas" -ne "$expected_replicas" ]; then
    debug "Replica count mismatch: expected '$expected_replicas', found '$rs_replicas'."
    failed
    return
  fi

  # Check selector.matchLabels
  local rs_selector_match_labels
  rs_selector_match_labels=$(echo "$rs_deployment_json" | jq -r '.spec.selector.matchLabels' 2>/dev/null) || { debug "Failed to extract selector.matchLabels using jq."; failed; return; }
  local rs_selector_label_value
  rs_selector_label_value=$(echo "$rs_selector_match_labels" | jq -r --arg key "$expected_label_key" '.[$key]' 2>/dev/null) || { debug "Failed to extract selector label value for key '$expected_label_key'."; failed; return; }
  if [ "$rs_selector_label_value" != "$expected_label_value" ]; then
    debug "Selector label mismatch: expected '$expected_label_key: $expected_label_value', found '$expected_label_key: $rs_selector_label_value'."
    failed
    return
  fi

  # Check pod template labels
  local rs_pod_template_labels
  rs_pod_template_labels=$(echo "$rs_deployment_json" | jq -r '.spec.template.metadata.labels' 2>/dev/null) || { debug "Failed to extract pod template labels using jq."; failed; return; }
  local rs_pod_template_label_value
  rs_pod_template_label_value=$(echo "$rs_pod_template_labels" | jq -r --arg key "$expected_label_key" '.[$key]' 2>/dev/null) || { debug "Failed to extract pod template label value for key '$expected_label_key'."; failed; return; }
  if [ "$rs_pod_template_label_value" != "$expected_label_value" ]; then
    debug "Pod template label mismatch: expected '$expected_label_key: $expected_label_value', found '$expected_label_key: $rs_pod_template_label_value'."
    failed
    return
  fi

  # Check container image
  local rs_image
  rs_image=$(echo "$rs_deployment_json" | jq -r '.spec.template.spec.containers[0].image' 2>/dev/null) || { debug "Failed to extract container image using jq."; failed; return; }
  if [ "$rs_image" != "$expected_image" ]; then
    debug "Container image mismatch: expected '$expected_image', found '$rs_image'."
    failed
    return
  fi

  debug "All deployment label and configuration verifications passed successfully."
  solved
  return
}

# shellcheck disable=SC2329
verify_task12() {
  TASK_NUMBER="12"

  # Define expected values
  local expected_deployment_name="recreate-deploy"
  local expected_namespace="recreate"
  local expected_image="mongo:7.0"
  local expected_strategy="Recreate"
  local expected_replicas=4

  # Get deployment JSON from Kubernetes API
  local rs_deployment_json
  rs_deployment_json=$(kubectl get deployment "$expected_deployment_name" -n "$expected_namespace" -o json 2>/dev/null) || { debug "Failed to get deployment '$expected_deployment_name' in namespace '$expected_namespace' from Kubernetes API."; failed; return; }

  # Check container image
  local rs_image
  rs_image=$(echo "$rs_deployment_json" | jq -r '.spec.template.spec.containers[0].image' 2>/dev/null) || { debug "Failed to extract container image using jq."; failed; return; }
  if [ "$rs_image" != "$expected_image" ]; then
    debug "Container image mismatch: expected '$expected_image', found '$rs_image'."
    failed
    return
  fi

  # Check deployment strategy
  local rs_strategy
  rs_strategy=$(echo "$rs_deployment_json" | jq -r '.spec.strategy.type' 2>/dev/null) || { debug "Failed to extract deployment strategy using jq."; failed; return; }
  if [ "$rs_strategy" != "$expected_strategy" ]; then
    debug "Deployment strategy mismatch: expected '$expected_strategy', found '$rs_strategy'."
    failed
    return
  fi

  # Check replicas
  local rs_replicas
  rs_replicas=$(echo "$rs_deployment_json" | jq -r '.spec.replicas' 2>/dev/null) || { debug "Failed to extract replicas using jq."; failed; return; }
  if [ "$rs_replicas" -ne "$expected_replicas" ]; then
    debug "Replica count mismatch: expected '$expected_replicas', found '$rs_replicas'."
    failed
    return
  fi

  debug "All deployment strategy and configuration verifications passed successfully."
  solved
  return
}

# shellcheck disable=SC2329
verify_task13() {
  TASK_NUMBER="13"

  # Expected values
  local expected_deployment_name="pause-deploy"
  local expected_image="httpd:2.4"
  local expected_env_name="TEST"
  local expected_env_value="true"

  # Retrieve deployment JSON
  local rs_deploy_json
  debug "Fetching deployment '$expected_deployment_name' as JSON"
  rs_deploy_json=$(kubectl get deployment "$expected_deployment_name" -o json 2>/dev/null) || { debug "Failed to get deployment '$expected_deployment_name' from Kubernetes API."; failed; return; }

  # Verify deployment has correct image
  debug "Checking if deployment has container with image '$expected_image'"
  jq -e --arg img "$expected_image" '.spec.template.spec.containers[] | select(.image == $img)' 2>/dev/null <<<"$rs_deploy_json" >/dev/null \
    || { debug "Deployment does not have container with image '$expected_image'."; failed; return; }

  # Verify deployment is paused
  debug "Checking if deployment is paused"
  jq -e '.spec.paused == true' 2>/dev/null <<<"$rs_deploy_json" >/dev/null \
    || { debug "Deployment is not paused."; failed; return; }

  # Verify the environment variable is set in the deployment spec
  debug "Checking if deployment spec has env '$expected_env_name' with value '$expected_env_value'"
  jq -e --arg name "$expected_env_name" --arg value "$expected_env_value" \
    '.spec.template.spec.containers[].env[]? | select(.name == $name and .value == $value)' 2>/dev/null <<<"$rs_deploy_json" >/dev/null \
    || { debug "Deployment does not have env '$expected_env_name' with value '$expected_env_value'."; failed; return; }

  # Get the name of a pod belonging to the deployment
  debug "Fetching pod name for deployment '$expected_deployment_name'"
  local rs_pod_name
  rs_pod_name=$(kubectl get pods -l app="$expected_deployment_name" -o json 2>/dev/null | jq -r '.items[0].metadata.name' 2>/dev/null)
  if [ -z "$rs_pod_name" ] || [ "$rs_pod_name" = "null" ]; then
    debug "No pod found for deployment '$expected_deployment_name'."
    failed
    return
  fi

  # Get the pod as JSON
  debug "Fetching pod '$rs_pod_name' as JSON"
  local rs_pod_json
  rs_pod_json=$(kubectl get pod "$rs_pod_name" -o json 2>/dev/null) || { debug "Failed to get pod '$rs_pod_name' as JSON."; failed; return; }

  # Verify the pod does NOT have the environment variable set
  debug "Checking that pod '$rs_pod_name' does NOT have env '$expected_env_name' set"
  jq -e --arg name "$expected_env_name" '[ .spec.containers[].env[]? | select(.name == $name) ] | length == 0' 2>/dev/null <<<"$rs_pod_json" >/dev/null \
    || { debug "Pod '$rs_pod_name' has env '$expected_env_name' set, but it should not."; failed; return; }

  debug "All deployment pause and environment variable verifications passed successfully."
  solved
  return
}

# shellcheck disable=SC2329
verify_task14() {
  TASK_NUMBER="14"

  # Expected values
  local deployment_name="history-deploy"
  local expected_image="nginx:1.25"
  local expected_revision_limit=2
  local expected_replicas=2

  # Get deployment JSON
  local deploy_json
  debug "Fetching deployment '${deployment_name}' as JSON"
  deploy_json="$(kubectl get deployment "${deployment_name}" -o json 2>/dev/null)" || { debug "Failed to fetch deployment '${deployment_name}'"; failed; return; }

  # Check image
  debug "Checking container image"
  local rs_image
  rs_image="$(echo "${deploy_json}" | jq -r '.spec.template.spec.containers[0].image' 2>/dev/null)" || { debug "Failed to extract image from deployment JSON"; failed; return; }
  if [ "${rs_image}" != "${expected_image}" ]; then
    debug "Image mismatch: expected '${expected_image}', found '${rs_image}'"
    failed
    return
  fi

  # Check revision history limit
  debug "Checking revisionHistoryLimit"
  local rs_revision_limit
  rs_revision_limit="$(echo "${deploy_json}" | jq -r '.spec.revisionHistoryLimit' 2>/dev/null)" || { debug "Failed to extract revisionHistoryLimit from deployment JSON"; failed; return; }
  if [ "${rs_revision_limit}" != "${expected_revision_limit}" ]; then
    debug "revisionHistoryLimit mismatch: expected '${expected_revision_limit}', found '${rs_revision_limit}'"
    failed
    return
  fi

  # Check replicas
  debug "Checking replicas count"
  local rs_replicas
  rs_replicas="$(echo "${deploy_json}" | jq -r '.spec.replicas' 2>/dev/null)" || { debug "Failed to extract replicas from deployment JSON"; failed; return; }
  if [ "${rs_replicas}" != "${expected_replicas}" ]; then
    debug "Replicas mismatch: expected '${expected_replicas}', found '${rs_replicas}'"
    failed
    return
  fi

  debug "All verifications passed successfully"
  solved
  return
}

# shellcheck disable=SC2329
verify_task15() {
  TASK_NUMBER="15"

  # Expected values
  local deployment_name="init-deploy"
  local expected_main_image="httpd:2.4"
  local expected_init_image="busybox:1.36"
  local expected_init_command="echo Init done"
  local expected_replicas=1

  # Fetch deployment JSON
  debug "Fetching deployment '${deployment_name}' as JSON"
  local deployment_json
  deployment_json="$(kubectl get deployment "${deployment_name}" -o json 2>/dev/null)" || { debug "Failed to fetch deployment '${deployment_name}'"; failed; return; }

  # Check replicas
  debug "Verifying replicas count is '${expected_replicas}'"
  local replicas
  replicas="$(echo "${deployment_json}" | jq '.spec.replicas' 2>/dev/null)" || { debug "Failed to extract replicas from deployment JSON"; failed; return; }
  [ "${replicas}" -eq "${expected_replicas}" ] || { debug "Replicas mismatch: expected '${expected_replicas}', found '${replicas}'"; failed; return; }

  # Check main container image
  debug "Verifying main container image is '${expected_main_image}'"
  local main_image
  main_image="$(echo "${deployment_json}" | jq -r '.spec.template.spec.containers[0].image' 2>/dev/null)" || { debug "Failed to extract main container image from deployment JSON"; failed; return; }
  [ "${main_image}" = "${expected_main_image}" ] || { debug "Main container image mismatch: expected '${expected_main_image}', found '${main_image}'"; failed; return; }

  # Check init container image
  debug "Verifying init container image is '${expected_init_image}'"
  local init_image
  init_image="$(echo "${deployment_json}" | jq -r '.spec.template.spec.initContainers[0].image' 2>/dev/null)" || { debug "Failed to extract init container image from deployment JSON"; failed; return; }
  [ "${init_image}" = "${expected_init_image}" ] || { debug "Init container image mismatch: expected '${expected_init_image}', found '${init_image}'"; failed; return; }

  # Check init container command
  debug "Verifying init container command includes '${expected_init_command}'"
  local init_command
  init_command="$(echo "${deployment_json}" | jq -r '.spec.template.spec.initContainers[0].command | join(" ")' 2>/dev/null)" || { debug "Failed to extract init container command from deployment JSON"; failed; return; }
  case "${init_command}" in
    *"${expected_init_command}") ;;
    *) debug "Init container command mismatch: expected to include '${expected_init_command}', found '${init_command}'"; failed; return ;;
  esac

  debug "All verifications for task ${TASK_NUMBER} passed successfully"
  solved
  return
}

# shellcheck disable=SC2329
verify_task16() {
  TASK_NUMBER="16"

  # Expected values
  local deployment_name="affinity-deploy"
  local expected_image="nginx:1.25"
  local expected_label_key="disktype"
  local expected_label_value="ssd"
  local expected_replicas=2

  # Fetch deployment JSON
  debug "Fetching deployment '${deployment_name}' as JSON"
  local deployment_json
  deployment_json="$(kubectl get deployment "${deployment_name}" -o json 2>/dev/null)" || { debug "Failed to fetch deployment '${deployment_name}'"; failed; return; }

  # Check replicas
  debug "Verifying replicas count is '${expected_replicas}'"
  local replicas
  replicas="$(echo "${deployment_json}" | jq '.spec.replicas' 2>/dev/null)" || { debug "Failed to extract replicas from deployment JSON"; failed; return; }
  [ "${replicas}" -eq "${expected_replicas}" ] || { debug "Replicas mismatch: expected '${expected_replicas}', found '${replicas}'"; failed; return; }

  # Check container image
  debug "Verifying container image is '${expected_image}'"
  local image
  image="$(echo "${deployment_json}" | jq -r '.spec.template.spec.containers[0].image' 2>/dev/null)" || { debug "Failed to extract container image from deployment JSON"; failed; return; }
  [ "${image}" = "${expected_image}" ] || { debug "Container image mismatch: expected '${expected_image}', found '${image}'"; failed; return; }

  # Check node affinity
  debug "Verifying node affinity is set"
  local node_affinity_json
  node_affinity_json="$(echo "${deployment_json}" | jq '.spec.template.spec.affinity.nodeAffinity' 2>/dev/null)" || { debug "Failed to extract nodeAffinity from deployment JSON"; failed; return; }

  # Check requiredDuringSchedulingIgnoredDuringExecution exists
  debug "Checking if requiredDuringSchedulingIgnoredDuringExecution exists in node affinity"
  echo "${node_affinity_json}" | jq '.requiredDuringSchedulingIgnoredDuringExecution' 2>/dev/null | grep -qv null || { debug "requiredDuringSchedulingIgnoredDuringExecution not found in node affinity"; failed; return; }

  # Check for the correct label selector
  debug "Verifying node affinity label selector for key '${expected_label_key}' and value '${expected_label_value}'"
  local node_affinity
  node_affinity="$(echo "${node_affinity_json}" | jq -r '.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[] | select(.key=="'"${expected_label_key}"'" and .operator=="In") | .values[]' 2>/dev/null)" || { debug "Failed to extract node affinity label selector from nodeAffinity JSON"; failed; return; }
  [ "${node_affinity}" = "${expected_label_value}" ] || { debug "Node affinity label value mismatch: expected '${expected_label_value}', found '${node_affinity}'"; failed; return; }

  debug "All verifications for task ${TASK_NUMBER} passed successfully"
  solved
  return
}

# shellcheck disable=SC2329
verify_task17() {
  TASK_NUMBER="17"

  # Expected values
  local expected_deploy="hostpath-deploy"
  local expected_image="nginx:1.29"
  local expected_host_path="/mnt/data"
  local expected_mount_path="/mnt/logs"
  local expected_replicas="1"

  # Fetch deployment JSON
  debug "Fetching deployment '${expected_deploy}' as JSON"
  local deploy_json
  deploy_json="$(kubectl get deployment "${expected_deploy}" -o json 2>/dev/null)" || { debug "Failed to fetch deployment '${expected_deploy}'"; failed; return; }

  # Check replicas
  debug "Verifying replicas count is '${expected_replicas}'"
  local replicas
  replicas="$(echo "${deploy_json}" | jq -r '.spec.replicas' 2>/dev/null)" || { debug "Failed to extract replicas from deployment JSON"; failed; return; }
  [ "${replicas}" = "${expected_replicas}" ] || { debug "Replicas mismatch: expected '${expected_replicas}', found '${replicas}'"; failed; return; }

  # Check container image
  debug "Verifying container image is '${expected_image}'"
  local image
  image="$(echo "${deploy_json}" | jq -r '.spec.template.spec.containers[0].image' 2>/dev/null)" || { debug "Failed to extract container image from deployment JSON"; failed; return; }
  [ "${image}" = "${expected_image}" ] || { debug "Container image mismatch: expected '${expected_image}', found '${image}'"; failed; return; }

  # Check volumeMounts and volumes
  debug "Extracting volumeMounts and volumes from deployment"
  local volume_mounts_json
  volume_mounts_json="$(echo "${deploy_json}" | jq '.spec.template.spec.containers[0].volumeMounts' 2>/dev/null)" || { debug "Failed to extract volumeMounts from deployment JSON"; failed; return; }
  local volumes_json
  volumes_json="$(echo "${deploy_json}" | jq '.spec.template.spec.volumes' 2>/dev/null)" || { debug "Failed to extract volumes from deployment JSON"; failed; return; }

  # Find the volumeMount with the expected mountPath
  debug "Verifying volumeMount exists at mountPath '${expected_mount_path}'"
  local mount_path
  mount_path="$(echo "${volume_mounts_json}" | jq -r '.[] | select(.mountPath=="'"${expected_mount_path}"'") | .mountPath' 2>/dev/null)" || { debug "Failed to extract mountPath from volumeMounts JSON"; failed; return; }
  [ "${mount_path}" = "${expected_mount_path}" ] || { debug "MountPath mismatch: expected '${expected_mount_path}', found '${mount_path}'"; failed; return; }

  # Get the name of the volume mounted at the expected path
  debug "Extracting volume name for mountPath '${expected_mount_path}'"
  local volume_name
  volume_name="$(echo "${volume_mounts_json}" | jq -r '.[] | select(.mountPath=="'"${expected_mount_path}"'") | .name' 2>/dev/null)" || { debug "Failed to extract volume name from volumeMounts JSON"; failed; return; }

  # Get the volume definition for that name
  debug "Extracting PVC claim name for volume '${volume_name}'"
  local claim_name
  claim_name="$(echo "${volumes_json}" | jq -r '.[] | select(.name=="'"${volume_name}"'") | .persistentVolumeClaim.claimName' 2>/dev/null)" || { debug "Failed to extract claimName from volumes JSON"; failed; return; }
  [ -n "${claim_name}" ] || { debug "No claimName found for volume '${volume_name}'"; failed; return; }

  # Get the PVC as JSON
  debug "Fetching PVC '${claim_name}' as JSON"
  local pvc_json
  pvc_json="$(kubectl get pvc "${claim_name}" -o json 2>/dev/null)" || { debug "Failed to fetch PVC '${claim_name}'"; failed; return; }

  # Check PVC status is Bound
  debug "Verifying PVC '${claim_name}' status is 'Bound'"
  local pvc_status
  pvc_status="$(echo "${pvc_json}" | jq -r '.status.phase' 2>/dev/null)" || { debug "Failed to extract PVC status from PVC JSON"; failed; return; }
  [ "${pvc_status}" = "Bound" ] || { debug "PVC status mismatch: expected 'Bound', found '${pvc_status}'"; failed; return; }

  # Get the PV name from the PVC
  debug "Extracting PV name from PVC '${claim_name}'"
  local pv_name
  pv_name="$(echo "${pvc_json}" | jq -r '.spec.volumeName' 2>/dev/null)" || { debug "Failed to extract PV name from PVC JSON"; failed; return; }
  [ -n "${pv_name}" ] || { debug "No PV name found in PVC '${claim_name}'"; failed; return; }

  # Get the PV as JSON
  debug "Fetching PV '${pv_name}' as JSON"
  local pv_json
  pv_json="$(kubectl get pv "${pv_name}" -o json 2>/dev/null)" || { debug "Failed to fetch PV '${pv_name}'"; failed; return; }

  # Check the hostPath.path in the PV
  debug "Verifying PV '${pv_name}' hostPath.path is '${expected_host_path}'"
  local host_path
  host_path="$(echo "${pv_json}" | jq -r '.spec.hostPath.path' 2>/dev/null)" || { debug "Failed to extract hostPath.path from PV JSON"; failed; return; }
  [ "${host_path}" = "${expected_host_path}" ] || { debug "hostPath.path mismatch: expected '${expected_host_path}', found '${host_path}'"; failed; return; }

  # Check all pods for the deployment are running
  debug "Fetching pods for deployment '${expected_deploy}' and verifying they are running"
  local pod_json
  pod_json=$(kubectl get pods -l app="${expected_deploy}" -o json 2>/dev/null) || { debug "Failed to fetch pods for deployment '${expected_deploy}'"; failed; return; }
  local pod_count
  pod_count="$(echo "${pod_json}" | jq '.items | length' 2>/dev/null)" || { debug "Failed to count pods in pod JSON"; failed; return; }
  [ "${pod_count}" = "${expected_replicas}" ] || { debug "Pod count mismatch: expected '${expected_replicas}', found '${pod_count}'"; failed; return; }
  local pod_running_count
  pod_running_count="$(echo "${pod_json}" | jq '[.items[] | select(.status.phase=="Running")] | length' 2>/dev/null)" || { debug "Failed to count running pods in pod JSON"; failed; return; }
  [ "${pod_running_count}" = "${expected_replicas}" ] || { debug "Running pod count mismatch: expected '${expected_replicas}', found '${pod_running_count}'"; failed; return; }

  debug "All verifications for task ${TASK_NUMBER} passed successfully"
  solved
  return
}

# shellcheck disable=SC2329
verify_task18() {
  TASK_NUMBER="18"

  # Expected values
  local expected_name="minready-deploy"
  local expected_image="nginx:1.25"
  local expected_minReadySeconds=10
  local expected_replicas=2

  # Retrieve deployment JSON
  local deploy_json
  debug "Fetching deployment '$expected_name' as JSON"
  deploy_json=$(kubectl get deployment "$expected_name" -o json 2>/dev/null) || { debug "Failed to fetch deployment '$expected_name'"; failed; return; }

  # Check deployment name
  local rs_name
  debug "Checking deployment name"
  rs_name=$(echo "$deploy_json" | jq -r '.metadata.name' 2>/dev/null) || { debug "Failed to extract deployment name with jq"; failed; return; }
  [ "$rs_name" = "$expected_name" ] || { debug "Deployment name mismatch: expected '$expected_name', found '$rs_name'"; failed; return; }

  # Check replicas
  local rs_replicas
  debug "Checking deployment replicas"
  rs_replicas=$(echo "$deploy_json" | jq '.spec.replicas' 2>/dev/null) || { debug "Failed to extract replicas with jq"; failed; return; }
  [ "$rs_replicas" -eq "$expected_replicas" ] || { debug "Replica count mismatch: expected '$expected_replicas', found '$rs_replicas'"; failed; return; }

  # Check minReadySeconds
  local rs_minReadySeconds
  debug "Checking minReadySeconds"
  rs_minReadySeconds=$(echo "$deploy_json" | jq '.spec.minReadySeconds' 2>/dev/null) || { debug "Failed to extract minReadySeconds with jq"; failed; return; }
  [ "$rs_minReadySeconds" -eq "$expected_minReadySeconds" ] || { debug "minReadySeconds mismatch: expected '$expected_minReadySeconds', found '$rs_minReadySeconds'"; failed; return; }

  # Check container image
  local rs_image
  debug "Checking container image"
  rs_image=$(echo "$deploy_json" | jq -r '.spec.template.spec.containers[0].image' 2>/dev/null) || { debug "Failed to extract container image with jq"; failed; return; }
  [ "$rs_image" = "$expected_image" ] || { debug "Container image mismatch: expected '$expected_image', found '$rs_image'"; failed; return; }

  debug "All deployment checks passed successfully"
  solved
  return
}

# shellcheck disable=SC2329
verify_task19() {
  TASK_NUMBER="19"

  # Expected values
  local expected_name="deadline-deploy"
  local expected_image="httpd:2.4"
  local expected_progress_deadline=60
  local expected_replicas=1

  # Retrieve deployment JSON
  local deploy_json
  debug "Fetching deployment '$expected_name' as JSON"
  deploy_json="$(kubectl get deployment "$expected_name" -o json 2>/dev/null)" || { debug "Failed to fetch deployment '$expected_name'"; failed; return; }

  # Check deployment name
  local rs_name
  debug "Checking deployment name"
  rs_name="$(echo "$deploy_json" | jq -r '.metadata.name' 2>/dev/null)" || { debug "Failed to extract deployment name with jq"; failed; return; }
  [ "$rs_name" = "$expected_name" ] || { debug "Deployment name mismatch: expected '$expected_name', found '$rs_name'"; failed; return; }

  # Check container image
  local rs_image
  debug "Checking container image"
  rs_image="$(echo "$deploy_json" | jq -r '.spec.template.spec.containers[0].image' 2>/dev/null)" || { debug "Failed to extract container image with jq"; failed; return; }
  [ "$rs_image" = "$expected_image" ] || { debug "Container image mismatch: expected '$expected_image', found '$rs_image'"; failed; return; }

  # Check progressDeadlineSeconds
  local rs_progress_deadline
  debug "Checking progressDeadlineSeconds"
  rs_progress_deadline="$(echo "$deploy_json" | jq -r '.spec.progressDeadlineSeconds' 2>/dev/null)" || { debug "Failed to extract progressDeadlineSeconds with jq"; failed; return; }
  [ "$rs_progress_deadline" -eq "$expected_progress_deadline" ] || { debug "progressDeadlineSeconds mismatch: expected '$expected_progress_deadline', found '$rs_progress_deadline'"; failed; return; }

  # Check replicas
  local rs_replicas
  debug "Checking deployment replicas"
  rs_replicas="$(echo "$deploy_json" | jq -r '.spec.replicas' 2>/dev/null)" || { debug "Failed to extract replicas with jq"; failed; return; }
  [ "$rs_replicas" -eq "$expected_replicas" ] || { debug "Replica count mismatch: expected '$expected_replicas', found '$rs_replicas'"; failed; return; }

  debug "All deployment checks passed successfully"
  solved
  return
}

# shellcheck disable=SC2329
verify_task20() {
  TASK_NUMBER="20"

  # Expected values
  local expected_name="rollingupdate-deploy"
  local expected_image="nginx:1.25"
  local expected_replicas=4
  local expected_maxSurge="2"
  local expected_maxUnavailable="1"

  # Retrieve deployment JSON
  local deploy_json
  debug "Fetching deployment '$expected_name' as JSON"
  deploy_json=$(kubectl get deployment "$expected_name" -o json 2>/dev/null) || { debug "Failed to fetch deployment '$expected_name'"; failed; return; }

  # Check deployment name
  local rs_name
  debug "Checking deployment name"
  rs_name=$(echo "$deploy_json" | jq -r '.metadata.name' 2>/dev/null) || { debug "Failed to extract deployment name with jq"; failed; return; }
  [ "$rs_name" = "$expected_name" ] || { debug "Deployment name mismatch: expected '$expected_name', found '$rs_name'"; failed; return; }

  # Check replicas
  local rs_replicas
  debug "Checking deployment replicas"
  rs_replicas=$(echo "$deploy_json" | jq '.spec.replicas' 2>/dev/null) || { debug "Failed to extract replicas with jq"; failed; return; }
  [ "$rs_replicas" -eq "$expected_replicas" ] || { debug "Replica count mismatch: expected '$expected_replicas', found '$rs_replicas'"; failed; return; }

  # Check container image
  local rs_image
  debug "Checking container image"
  rs_image=$(echo "$deploy_json" | jq -r '.spec.template.spec.containers[0].image' 2>/dev/null) || { debug "Failed to extract container image with jq"; failed; return; }
  [ "$rs_image" = "$expected_image" ] || { debug "Container image mismatch: expected '$expected_image', found '$rs_image'"; failed; return; }

  # Check strategy type
  local rs_strategy_type
  debug "Checking deployment strategy type"
  rs_strategy_type=$(echo "$deploy_json" | jq -r '.spec.strategy.type' 2>/dev/null) || { debug "Failed to extract strategy type with jq"; failed; return; }
  [ "$rs_strategy_type" = "RollingUpdate" ] || { debug "Strategy type mismatch: expected 'RollingUpdate', found '$rs_strategy_type'"; failed; return; }

  # Check maxSurge
  local rs_maxSurge
  debug "Checking maxSurge value"
  rs_maxSurge=$(echo "$deploy_json" | jq -r '.spec.strategy.rollingUpdate.maxSurge' 2>/dev/null) || { debug "Failed to extract maxSurge with jq"; failed; return; }
  [ "$rs_maxSurge" = "$expected_maxSurge" ] || { debug "maxSurge mismatch: expected '$expected_maxSurge', found '$rs_maxSurge'"; failed; return; }

  # Check maxUnavailable
  local rs_maxUnavailable
  debug "Checking maxUnavailable value"
  rs_maxUnavailable=$(echo "$deploy_json" | jq -r '.spec.strategy.rollingUpdate.maxUnavailable' 2>/dev/null) || { debug "Failed to extract maxUnavailable with jq"; failed; return; }
  [ "$rs_maxUnavailable" = "$expected_maxUnavailable" ] || { debug "maxUnavailable mismatch: expected '$expected_maxUnavailable', found '$rs_maxUnavailable'"; failed; return; }

  debug "All deployment checks passed successfully"
  solved
  return
}

# shellcheck disable=SC2329
verify_task21() {
  TASK_NUMBER="21"

  # Expected values
  local expected_namespace="rollout-demo"
  local expected_deployment="rolling-update-demo"
  local expected_image="nginx:1.29"
  local expected_replicas=6
  local expected_max_surge="2"
  local expected_max_unavailable="50%"

  # Retrieve deployment JSON
  local deploy_json
  debug "Fetching deployment '$expected_deployment' in namespace '$expected_namespace' as JSON"
  deploy_json="$(kubectl get deployment "$expected_deployment" -n "$expected_namespace" -o json 2>/dev/null)" || { debug "Failed to fetch deployment '$expected_deployment' in namespace '$expected_namespace'"; failed; return; }

  # Check container image
  local rs_image
  debug "Checking container image"
  rs_image="$(echo "$deploy_json" | jq -r '.spec.template.spec.containers[0].image' 2>/dev/null)" || { debug "Failed to extract container image with jq"; failed; return; }
  [ "$rs_image" = "$expected_image" ] || { debug "Container image mismatch: expected '$expected_image', found '$rs_image'"; failed; return; }

  # Check replicas
  local rs_replicas
  debug "Checking deployment replicas"
  rs_replicas="$(echo "$deploy_json" | jq '.spec.replicas' 2>/dev/null)" || { debug "Failed to extract replicas with jq"; failed; return; }
  [ "$rs_replicas" -eq "$expected_replicas" ] || { debug "Replica count mismatch: expected '$expected_replicas', found '$rs_replicas'"; failed; return; }

  # Check strategy type (should be RollingUpdate or default)
  local rs_strategy_type
  debug "Checking deployment strategy type"
  rs_strategy_type="$(echo "$deploy_json" | jq -r '.spec.strategy.type // "RollingUpdate"' 2>/dev/null)" || { debug "Failed to extract strategy type with jq"; failed; return; }
  [ "$rs_strategy_type" = "RollingUpdate" ] || { debug "Strategy type mismatch: expected 'RollingUpdate', found '$rs_strategy_type'"; failed; return; }

  # Check maxSurge
  local rs_max_surge
  debug "Checking maxSurge value"
  rs_max_surge="$(echo "$deploy_json" | jq -r '.spec.strategy.rollingUpdate.maxSurge // "25%"' 2>/dev/null)" || { debug "Failed to extract maxSurge with jq"; failed; return; }
  if [ "$rs_max_surge" != "$expected_max_surge" ]; then
    if ! [[ "$rs_max_surge" =~ ^[0-9]+$ && "$rs_max_surge" -eq 2 ]]; then
      debug "maxSurge mismatch: expected '$expected_max_surge' or 2, found '$rs_max_surge'"
      failed
      return
    fi
  fi

  # Check maxUnavailable
  local rs_max_unavailable
  debug "Checking maxUnavailable value"
  rs_max_unavailable="$(echo "$deploy_json" | jq -r '.spec.strategy.rollingUpdate.maxUnavailable // "25%"' 2>/dev/null)" || { debug "Failed to extract maxUnavailable with jq"; failed; return; }
  if [ "$rs_max_unavailable" != "$expected_max_unavailable" ]; then
    if ! [[ "$rs_max_unavailable" =~ ^[0-9]+$ && "$rs_max_unavailable" -eq 3 ]]; then
      debug "maxUnavailable mismatch: expected '$expected_max_unavailable' or 3, found '$rs_max_unavailable'"
      failed
      return
    fi
  fi

  # Check rollout status
  debug "Checking rollout status"
  kubectl rollout status deployment "$expected_deployment" -n "$expected_namespace" --timeout=5s >/dev/null 2>/dev/null || { debug "Rollout status check failed for deployment '$expected_deployment' in namespace '$expected_namespace'"; failed; return; }

  debug "All deployment checks passed successfully"
  solved
  return
}

# shellcheck disable=SC2329
verify_task22() {
  TASK_NUMBER="22"

  # Expected values
  local namespace="blue-green"
  local deployment_green="blue-green-demo-green"
  local deployment_blue="blue-green-demo-blue"
  local service_name="blue-green-demo-svc"
  local expected_image_green="nginx:1.29"
  local expected_image_blue="nginx:1.25"
  local expected_selector_app="blue-green-demo"
  local expected_selector_version="green"

  # Check green deployment
  local rs_deployment_green_json
  debug "Fetching green deployment '$deployment_green' in namespace '$namespace'"
  rs_deployment_green_json="$(kubectl get deployment "$deployment_green" -n "$namespace" -o json 2>/dev/null)" || { debug "Failed to fetch green deployment '$deployment_green'"; failed; return; }

  # Check green deployment name
  debug "Checking green deployment name"
  local rs_green_name
  rs_green_name="$(echo "$rs_deployment_green_json" | jq -r '.metadata.name' 2>/dev/null)" || { debug "Failed to extract green deployment name"; failed; return; }
  [ "$rs_green_name" = "$deployment_green" ] || { debug "Green deployment name mismatch: expected '$deployment_green', found '$rs_green_name'"; failed; return; }

  # Check green deployment image
  debug "Checking green deployment image"
  local rs_green_image
  rs_green_image="$(echo "$rs_deployment_green_json" | jq -r '.spec.template.spec.containers[0].image' 2>/dev/null)" || { debug "Failed to extract green deployment image"; failed; return; }
  [ "$rs_green_image" = "$expected_image_green" ] || { debug "Green deployment image mismatch: expected '$expected_image_green', found '$rs_green_image'"; failed; return; }

  # Check green deployment selector labels
  debug "Checking green deployment selector labels"
  local rs_green_selector_app
  rs_green_selector_app="$(echo "$rs_deployment_green_json" | jq -r '.spec.selector.matchLabels.app' 2>/dev/null)" || { debug "Failed to extract green deployment selector app label"; failed; return; }
  [ "$rs_green_selector_app" = "$expected_selector_app" ] || { debug "Green deployment selector app label mismatch: expected '$expected_selector_app', found '$rs_green_selector_app'"; failed; return; }

  local rs_green_selector_version
  rs_green_selector_version="$(echo "$rs_deployment_green_json" | jq -r '.spec.selector.matchLabels.version' 2>/dev/null)" || { debug "Failed to extract green deployment selector version label"; failed; return; }
  [ "$rs_green_selector_version" = "green" ] || { debug "Green deployment selector version label mismatch: expected 'green', found '$rs_green_selector_version'"; failed; return; }

  # Check green deployment template labels
  debug "Checking green deployment template labels"
  local rs_green_template_app
  rs_green_template_app="$(echo "$rs_deployment_green_json" | jq -r '.spec.template.metadata.labels.app' 2>/dev/null)" || { debug "Failed to extract green deployment template app label"; failed; return; }
  [ "$rs_green_template_app" = "$expected_selector_app" ] || { debug "Green deployment template app label mismatch: expected '$expected_selector_app', found '$rs_green_template_app'"; failed; return; }

  local rs_green_template_version
  rs_green_template_version="$(echo "$rs_deployment_green_json" | jq -r '.spec.template.metadata.labels.version' 2>/dev/null)" || { debug "Failed to extract green deployment template version label"; failed; return; }
  [ "$rs_green_template_version" = "green" ] || { debug "Green deployment template version label mismatch: expected 'green', found '$rs_green_template_version'"; failed; return; }

  # Check blue deployment
  local rs_deployment_blue_json
  debug "Fetching blue deployment '$deployment_blue' in namespace '$namespace'"
  rs_deployment_blue_json="$(kubectl get deployment "$deployment_blue" -n "$namespace" -o json 2>/dev/null)" || { debug "Failed to fetch blue deployment '$deployment_blue'"; failed; return; }

  # Check blue deployment name
  debug "Checking blue deployment name"
  local rs_blue_name
  rs_blue_name="$(echo "$rs_deployment_blue_json" | jq -r '.metadata.name' 2>/dev/null)" || { debug "Failed to extract blue deployment name"; failed; return; }
  [ "$rs_blue_name" = "$deployment_blue" ] || { debug "Blue deployment name mismatch: expected '$deployment_blue', found '$rs_blue_name'"; failed; return; }

  # Check blue deployment image
  debug "Checking blue deployment image"
  local rs_blue_image
  rs_blue_image="$(echo "$rs_deployment_blue_json" | jq -r '.spec.template.spec.containers[0].image' 2>/dev/null)" || { debug "Failed to extract blue deployment image"; failed; return; }
  [ "$rs_blue_image" = "$expected_image_blue" ] || { debug "Blue deployment image mismatch: expected '$expected_image_blue', found '$rs_blue_image'"; failed; return; }

  # Check blue deployment selector labels
  debug "Checking blue deployment selector labels"
  local rs_blue_selector_app
  rs_blue_selector_app="$(echo "$rs_deployment_blue_json" | jq -r '.spec.selector.matchLabels.app' 2>/dev/null)" || { debug "Failed to extract blue deployment selector app label"; failed; return; }
  [ "$rs_blue_selector_app" = "$expected_selector_app" ] || { debug "Blue deployment selector app label mismatch: expected '$expected_selector_app', found '$rs_blue_selector_app'"; failed; return; }

  local rs_blue_selector_version
  rs_blue_selector_version="$(echo "$rs_deployment_blue_json" | jq -r '.spec.selector.matchLabels.version' 2>/dev/null)" || { debug "Failed to extract blue deployment selector version label"; failed; return; }
  [ "$rs_blue_selector_version" = "blue" ] || { debug "Blue deployment selector version label mismatch: expected 'blue', found '$rs_blue_selector_version'"; failed; return; }

  # Check blue deployment template labels
  debug "Checking blue deployment template labels"
  local rs_blue_template_app
  rs_blue_template_app="$(echo "$rs_deployment_blue_json" | jq -r '.spec.template.metadata.labels.app' 2>/dev/null)" || { debug "Failed to extract blue deployment template app label"; failed; return; }
  [ "$rs_blue_template_app" = "$expected_selector_app" ] || { debug "Blue deployment template app label mismatch: expected '$expected_selector_app', found '$rs_blue_template_app'"; failed; return; }

  local rs_blue_template_version
  rs_blue_template_version="$(echo "$rs_deployment_blue_json" | jq -r '.spec.template.metadata.labels.version' 2>/dev/null)" || { debug "Failed to extract blue deployment template version label"; failed; return; }
  [ "$rs_blue_template_version" = "blue" ] || { debug "Blue deployment template version label mismatch: expected 'blue', found '$rs_blue_template_version'"; failed; return; }

  # Check service selector
  local rs_service_json
  debug "Fetching service '$service_name' in namespace '$namespace'"
  rs_service_json="$(kubectl get service "$service_name" -n "$namespace" -o json 2>/dev/null)" || { debug "Failed to fetch service '$service_name'"; failed; return; }

  debug "Checking service selector app label"
  local rs_service_selector_app
  rs_service_selector_app="$(echo "$rs_service_json" | jq -r '.spec.selector.app' 2>/dev/null)" || { debug "Failed to extract service selector app label"; failed; return; }
  [ "$rs_service_selector_app" = "$expected_selector_app" ] || { debug "Service selector app label mismatch: expected '$expected_selector_app', found '$rs_service_selector_app'"; failed; return; }

  debug "Checking service selector version label"
  local rs_service_selector_version
  rs_service_selector_version="$(echo "$rs_service_json" | jq -r '.spec.selector.version' 2>/dev/null)" || { debug "Failed to extract service selector version label"; failed; return; }
  [ "$rs_service_selector_version" = "$expected_selector_version" ] || { debug "Service selector version label mismatch: expected '$expected_selector_version', found '$rs_service_selector_version'"; failed; return; }

  debug "All blue-green deployment and service checks passed successfully"
  solved
  return
}

# shellcheck disable=SC2329
verify_task23() {
  TASK_NUMBER="23"

  # Expected values
  local namespace="canary-demo"
  local canary_deployment="canary-demo-canary"
  local stable_deployment="canary-demo-stable"
  local service_name="canary-demo-svc"
  local canary_image="nginx:1.25"
  local stable_image="nginx:1.21"
  local canary_replicas=3
  local service_port=80
  local service_target_port=80

  # Retrieve all deployments as JSON
  local deployments_json
  debug "Fetching all deployments in namespace '$namespace'"
  deployments_json=$(kubectl get deployments -n "$namespace" -o json 2>/dev/null) || { debug "Failed to fetch deployments in namespace '$namespace'"; failed; return; }

  # Check canary deployment exists and has correct spec
  local rs_canary_json
  debug "Checking canary deployment '$canary_deployment'"
  rs_canary_json=$(echo "$deployments_json" | jq -e --arg name "$canary_deployment" '.items[] | select(.metadata.name == $name)' 2>/dev/null) || { debug "Canary deployment '$canary_deployment' not found"; failed; return; }

  debug "Checking canary deployment image and replicas"
  local rs_canary_image
  rs_canary_image=$(echo "$rs_canary_json" | jq -r '.spec.template.spec.containers[0].image' 2>/dev/null) || { debug "Failed to extract canary deployment image"; failed; return; }
  [ "$rs_canary_image" = "$canary_image" ] || { debug "Canary deployment image mismatch: expected '$canary_image', found '$rs_canary_image'"; failed; return; }

  local rs_canary_replicas
  rs_canary_replicas=$(echo "$rs_canary_json" | jq '.spec.replicas' 2>/dev/null) || { debug "Failed to extract canary deployment replicas"; failed; return; }
  [ "$rs_canary_replicas" -eq "$canary_replicas" ] || { debug "Canary deployment replicas mismatch: expected '$canary_replicas', found '$rs_canary_replicas'"; failed; return; }

  debug "Checking canary deployment labels"
  local rs_canary_label_app
  rs_canary_label_app=$(echo "$rs_canary_json" | jq -r '.spec.template.metadata.labels.app' 2>/dev/null) || { debug "Failed to extract canary deployment app label"; failed; return; }
  [ "$rs_canary_label_app" = "canary-demo" ] || { debug "Canary deployment app label mismatch: expected 'canary-demo', found '$rs_canary_label_app'"; failed; return; }

  local rs_canary_label_track
  rs_canary_label_track=$(echo "$rs_canary_json" | jq -r '.spec.template.metadata.labels.track' 2>/dev/null) || { debug "Failed to extract canary deployment track label"; failed; return; }
  [ "$rs_canary_label_track" = "canary" ] || { debug "Canary deployment track label mismatch: expected 'canary', found '$rs_canary_label_track'"; failed; return; }

  # Check stable deployment: either deleted or has 0 replicas and correct image/labels
  debug "Checking stable deployment '$stable_deployment'"
  local rs_stable_json
  rs_stable_json=$(echo "$deployments_json" | jq -e --arg name "$stable_deployment" '.items[] | select(.metadata.name == $name)' 2>/dev/null)
  if [ -n "$rs_stable_json" ]; then
    local rs_stable_replicas
    rs_stable_replicas=$(echo "$rs_stable_json" | jq '.spec.replicas' 2>/dev/null) || { debug "Failed to extract stable deployment replicas"; failed; return; }
    local rs_stable_image
    rs_stable_image=$(echo "$rs_stable_json" | jq -r '.spec.template.spec.containers[0].image' 2>/dev/null) || { debug "Failed to extract stable deployment image"; failed; return; }
    [ "$rs_stable_replicas" -eq 0 ] || { debug "Stable deployment replicas mismatch: expected 0, found '$rs_stable_replicas'"; failed; return; }
    [ "$rs_stable_image" = "$stable_image" ] || { debug "Stable deployment image mismatch: expected '$stable_image', found '$rs_stable_image'"; failed; return; }

    local rs_stable_label_app
    rs_stable_label_app=$(echo "$rs_stable_json" | jq -r '.spec.template.metadata.labels.app' 2>/dev/null) || { debug "Failed to extract stable deployment app label"; failed; return; }
    [ "$rs_stable_label_app" = "canary-demo" ] || { debug "Stable deployment app label mismatch: expected 'canary-demo', found '$rs_stable_label_app'"; failed; return; }

    local rs_stable_label_track
    rs_stable_label_track=$(echo "$rs_stable_json" | jq -r '.spec.template.metadata.labels.track' 2>/dev/null) || { debug "Failed to extract stable deployment track label"; failed; return; }
    [ "$rs_stable_label_track" = "stable" ] || { debug "Stable deployment track label mismatch: expected 'stable', found '$rs_stable_label_track'"; failed; return; }
  else
    debug "Stable deployment '$stable_deployment' not found (acceptable if deleted)"
  fi

  # Get Service JSON
  local rs_service_json
  debug "Fetching service '$service_name' in namespace '$namespace'"
  rs_service_json=$(kubectl get service "$service_name" -n "$namespace" -o json 2>/dev/null) || { debug "Failed to fetch service '$service_name'"; failed; return; }

  # Check service ports
  debug "Checking service ports"
  local rs_service_port
  rs_service_port=$(echo "$rs_service_json" | jq '.spec.ports[0].port' 2>/dev/null) || { debug "Failed to extract service port"; failed; return; }
  [ "$rs_service_port" -eq "$service_port" ] || { debug "Service port mismatch: expected '$service_port', found '$rs_service_port'"; failed; return; }

  local rs_service_target_port
  rs_service_target_port=$(echo "$rs_service_json" | jq '.spec.ports[0].targetPort' 2>/dev/null) || { debug "Failed to extract service targetPort"; failed; return; }
  [ "$rs_service_target_port" -eq "$service_target_port" ] || { debug "Service targetPort mismatch: expected '$service_target_port', found '$rs_service_target_port'"; failed; return; }

  # Check service selector
  debug "Checking service selector"
  local rs_selector_json
  rs_selector_json=$(echo "$rs_service_json" | jq '.spec.selector' 2>/dev/null) || { debug "Failed to extract service selector"; failed; return; }

  local rs_canary_matchlabels_json
  rs_canary_matchlabels_json=$(echo "$rs_canary_json" | jq '.spec.selector.matchLabels' 2>/dev/null) || { debug "Failed to extract canary deployment matchLabels"; failed; return; }

  # Acceptable if selector is only {"app":"canary-demo"}
  local only_app_selector
  only_app_selector=$(echo "$rs_selector_json" | jq -e 'keys == ["app"] and .app == "canary-demo"' 2>/dev/null)

  # Acceptable if selector matches canary deployment's matchLabels
  local matches_canary_labels
  matches_canary_labels=$(jq --argjson s "$rs_selector_json" --argjson m "$rs_canary_matchlabels_json" -n '$s == $m' 2>/dev/null)

  if [ "$only_app_selector" != "true" ] && [ "$matches_canary_labels" != "true" ]; then
    debug "Service selector does not match expected values"
    failed
    return
  fi

  debug "All canary deployment, stable deployment, and service checks passed successfully"
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
  verify_task8
  verify_task9
  verify_task10
  verify_task11
  verify_task12
  verify_task13
  verify_task14
  verify_task15
  verify_task16
  verify_task17
  verify_task18
  verify_task19
  verify_task20
  verify_task21
  verify_task22
  verify_task23
)
run_verification VERIFY_TASK_FUNCTIONS "$@"

exit 0
