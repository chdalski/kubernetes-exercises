#!/bin/bash

# shellcheck source=../../.scripts/verify.sh
source "$(git rev-parse --show-toplevel)/.scripts/verify.sh"

# shellcheck disable=SC2329
verify_task1() {
  TASK_NUMBER="1"

  # Expected values
  local configmap_name="app-config"
  local app_mode="production"
  local app_version="1.0"
  local pod_name="app-pod"
  local expected_image="nginx:1.29.0"

  # Verify ConfigMap exists and has correct data
  debug "Checking if ConfigMap '$configmap_name' exists"
  local cm_json
  cm_json=$(kubectl get configmap "$configmap_name" -o json 2>/dev/null) || { debug "Failed to get ConfigMap '$configmap_name'"; failed; return; }

  debug "Verifying ConfigMap APP_MODE"
  local cm_app_mode
  cm_app_mode=$(echo "$cm_json" | jq -r '.data.APP_MODE' 2>/dev/null) || { debug "Failed to extract APP_MODE from ConfigMap"; failed; return; }
  [[ "$cm_app_mode" == "$app_mode" ]] || { debug "Expected APP_MODE: $app_mode, found: $cm_app_mode"; failed; return; }

  debug "Verifying ConfigMap APP_VERSION"
  local cm_app_version
  cm_app_version=$(echo "$cm_json" | jq -r '.data.APP_VERSION' 2>/dev/null) || { debug "Failed to extract APP_VERSION from ConfigMap"; failed; return; }
  [[ "$cm_app_version" == "$app_version" ]] || { debug "Expected APP_VERSION: $app_version, found: $cm_app_version"; failed; return; }

  # Verify Pod exists and has correct image
  debug "Checking if Pod '$pod_name' exists"
  local pod_json
  pod_json=$(kubectl get pod "$pod_name" -o json 2>/dev/null) || { debug "Failed to get Pod '$pod_name'"; failed; return; }

  debug "Verifying Pod image"
  local pod_image
  pod_image=$(echo "$pod_json" | jq -r '.spec.containers[0].image' 2>/dev/null) || { debug "Failed to extract image from Pod"; failed; return; }
  [[ "$pod_image" == "$expected_image" ]] || { debug "Expected image: $expected_image, found: $pod_image"; failed; return; }

  # Verify Environment Variables in Pod Execution
  debug "Checking environment variables in running pod"
  local pod_envs
  pod_envs=$(kubectl exec "$pod_name" -- env 2>/dev/null | grep APP_) || { debug "Failed to get environment variables from Pod"; failed; return; }

  echo "$pod_envs" | grep -q "^APP_MODE=$app_mode$" || { debug "APP_MODE environment variable not set to '$app_mode' in Pod"; failed; return; }
  echo "$pod_envs" | grep -q "^APP_VERSION=$app_version$" || { debug "APP_VERSION environment variable not set to '$app_version' in Pod"; failed; return; }

  debug "All verifications passed for task $TASK_NUMBER"
  solved
  return
}

# shellcheck disable=SC2329
verify_task2() {
  TASK_NUMBER="2"

  # Expected values
  local expected_cm_name="html-config"
  local expected_pod_name="web-pod"
  local expected_image="nginx:1.29.0"
  local expected_mount_path="/usr/share/nginx/html"
  local expected_index_file="index.html"
  local expected_error_file="error.html"
  local expected_index_content="<h1>Welcome to Kubernetes</h1>"
  local expected_error_content="<h1>Error Page</h1>"

  # Check ConfigMap exists and has correct data
  debug "Checking if ConfigMap '$expected_cm_name' exists"
  local cm_json
  cm_json=$(kubectl get configmap "$expected_cm_name" -o json 2>/dev/null) || { debug "Failed to get ConfigMap '$expected_cm_name'"; failed; return; }

  debug "Verifying ConfigMap contains correct '$expected_index_file' content"
  local file_content
  file_content=$(echo "$cm_json" | jq -r --arg f "$expected_index_file" '.data[$f]' 2>/dev/null) || { debug "Failed to extract '$expected_index_file' from ConfigMap"; failed; return; }
  [[ "$file_content" == "$expected_index_content" ]] || { debug "Expected '$expected_index_file' content: $expected_index_content, found: $file_content"; failed; return; }

  debug "Verifying ConfigMap contains correct '$expected_error_file' content"
  file_content=$(echo "$cm_json" | jq -r --arg f "$expected_error_file" '.data[$f]' 2>/dev/null) || { debug "Failed to extract '$expected_error_file' from ConfigMap"; failed; return; }
  [[ "$file_content" == "$expected_error_content" ]] || { debug "Expected '$expected_error_file' content: $expected_error_content, found: $file_content"; failed; return; }

  # Check Pod exists, uses correct image, and mounts ConfigMap at correct path
  debug "Checking if Pod '$expected_pod_name' exists"
  local pod_json
  pod_json=$(kubectl get pod "$expected_pod_name" -o json 2>/dev/null) || { debug "Failed to get Pod '$expected_pod_name'"; failed; return; }

  debug "Verifying Pod image"
  local pod_image
  pod_image=$(echo "$pod_json" | jq -r '.spec.containers[0].image' 2>/dev/null) || { debug "Failed to extract image from Pod"; failed; return; }
  [[ "$pod_image" == "$expected_image" ]] || { debug "Expected image: $expected_image, found: $pod_image"; failed; return; }

  debug "Verifying Pod mounts ConfigMap '$expected_cm_name' at correct path"
  local volume_name
  volume_name=$(echo "$pod_json" | jq -r --arg cm "$expected_cm_name" '.spec.volumes[] | select(.configMap.name==$cm) | .name' 2>/dev/null) || { debug "Failed to extract volume name for ConfigMap '$expected_cm_name'"; failed; return; }
  [[ -n "$volume_name" ]] || { debug "No volume found for ConfigMap '$expected_cm_name'"; failed; return; }

  local mount_path
  mount_path=$(echo "$pod_json" | jq -r --arg v "$volume_name" '.spec.containers[0].volumeMounts[] | select(.name==$v) | .mountPath' 2>/dev/null) || { debug "Failed to extract mountPath for volume '$volume_name'"; failed; return; }
  [[ "$mount_path" == "$expected_mount_path" ]] || { debug "Expected mountPath: $expected_mount_path, found: $mount_path"; failed; return; }

  # Check files are present in the running container with correct content
  debug "Checking for presence of '$expected_index_file' and '$expected_error_file' in pod"
  kubectl exec "$expected_pod_name" -- test -f "$expected_mount_path/$expected_index_file" 2>/dev/null || { debug "'$expected_index_file' not found in pod"; failed; return; }
  kubectl exec "$expected_pod_name" -- test -f "$expected_mount_path/$expected_error_file" 2>/dev/null || { debug "'$expected_error_file' not found in pod"; failed; return; }

  debug "Verifying content of '$expected_index_file' in pod"
  file_content=$(kubectl exec "$expected_pod_name" -- cat "$expected_mount_path/$expected_index_file" 2>/dev/null) || { debug "Failed to read '$expected_index_file' in pod"; failed; return; }
  [[ "$file_content" == "$expected_index_content" ]] || { debug "Expected content in '$expected_index_file': $expected_index_content, found: $file_content"; failed; return; }

  debug "Verifying content of '$expected_error_file' in pod"
  file_content=$(kubectl exec "$expected_pod_name" -- cat "$expected_mount_path/$expected_error_file" 2>/dev/null) || { debug "Failed to read '$expected_error_file' in pod"; failed; return; }
  [[ "$file_content" == "$expected_error_content" ]] || { debug "Expected content in '$expected_error_file': $expected_error_content, found: $file_content"; failed; return; }

  debug "All verifications passed for task $TASK_NUMBER"
  solved
  return
}

# shellcheck disable=SC2329
verify_task3() {
  TASK_NUMBER="3"

  # Expected values
  local expected_secret_name="db-credentials"
  local expected_username="admin"
  local expected_password="SuperSecretPassword"
  local expected_pod_name="db-pod"
  local expected_image="nginx:1.29.0"

  # Check if the Secret exists
  debug "Checking if Secret '$expected_secret_name' exists"
  local secret_exists
  secret_exists=$(kubectl get secret "$expected_secret_name" -o name 2>/dev/null) || { debug "Failed to get Secret '$expected_secret_name'"; failed; return; }
  [[ -n "$secret_exists" ]] || { debug "Secret '$expected_secret_name' does not exist"; failed; return; }

  # Check Secret data
  debug "Verifying Secret data for username and password"
  local actual_username
  actual_username=$(kubectl get secret "$expected_secret_name" -o jsonpath='{.data.username}' 2>/dev/null | base64 --decode) || { debug "Failed to decode username from Secret"; failed; return; }
  local actual_password
  actual_password=$(kubectl get secret "$expected_secret_name" -o jsonpath='{.data.password}' 2>/dev/null | base64 --decode) || { debug "Failed to decode password from Secret"; failed; return; }
  [[ "$actual_username" == "$expected_username" ]] || { debug "Expected username: $expected_username, found: $actual_username"; failed; return; }
  [[ "$actual_password" == "$expected_password" ]] || { debug "Expected password: $expected_password, found: $actual_password"; failed; return; }

  # Check if the Pod exists
  debug "Checking if Pod '$expected_pod_name' exists"
  local pod_exists
  pod_exists=$(kubectl get pod "$expected_pod_name" -o name 2>/dev/null) || { debug "Failed to get Pod '$expected_pod_name'"; failed; return; }
  [[ -n "$pod_exists" ]] || { debug "Pod '$expected_pod_name' does not exist"; failed; return; }

  # Check Pod image
  debug "Verifying Pod image"
  local actual_image
  actual_image=$(kubectl get pod "$expected_pod_name" -o jsonpath='{.spec.containers[0].image}' 2>/dev/null) || { debug "Failed to get image from Pod"; failed; return; }
  [[ "$actual_image" == "$expected_image" ]] || { debug "Expected image: $expected_image, found: $actual_image"; failed; return; }

  # Check Pod readiness
  debug "Checking if Pod is ready"
  local pod_ready
  pod_ready=$(kubectl get pod "$expected_pod_name" -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null) || { debug "Failed to get Pod readiness"; failed; return; }
  [[ "$pod_ready" == "true" ]] || { debug "Pod '$expected_pod_name' is not ready"; failed; return; }

  # Verify environment variables are set correctly
  debug "Verifying environment variables in Pod"
  local env_username
  env_username=$(kubectl exec "$expected_pod_name" -- env 2>/dev/null | grep "^username=" | cut -d= -f2) || { debug "Failed to get username env variable from Pod"; failed; return; }
  local env_password
  env_password=$(kubectl exec "$expected_pod_name" -- env 2>/dev/null | grep "^password=" | cut -d= -f2) || { debug "Failed to get password env variable from Pod"; failed; return; }
  [[ "$env_username" == "$expected_username" ]] || { debug "Expected env username: $expected_username, found: $env_username"; failed; return; }
  [[ "$env_password" == "$expected_password" ]] || { debug "Expected env password: $expected_password, found: $env_password"; failed; return; }

  debug "All verifications passed for task $TASK_NUMBER"
  solved
  return
}

# shellcheck disable=SC2329
verify_task4() {
  TASK_NUMBER="4"

  # Expected values
  local secret_name="tls-secret"
  local pod_name="secure-pod"
  local expected_image="redis:8.0.2"
  local expected_mount_path="/etc/tls"
  local local_crt_file="task4.crt"
  local local_key_file="task4.key"

  # Get secret as JSON
  debug "Fetching secret '$secret_name'"
  local secret_json
  secret_json=$(kubectl get secret "$secret_name" -o json 2>/dev/null) || { debug "Failed to get secret '$secret_name'"; failed; return; }

  # Verify secret contains expected data fields
  debug "Verifying secret contains 'tls.crt' and 'tls.key'"
  echo "$secret_json" | jq -e '.data["tls.crt"] and .data["tls.key"]' >/dev/null 2>&1 || { debug "Secret does not contain required fields"; failed; return; }

  # Get pod as JSON
  debug "Fetching pod '$pod_name'"
  local pod_json
  pod_json=$(kubectl get pod "$pod_name" -o json 2>/dev/null) || { debug "Failed to get pod '$pod_name'"; failed; return; }

  # Verify pod has only one container and uses the expected image
  debug "Verifying pod has only one container"
  echo "$pod_json" | jq -e '.spec.containers | length == 1' >/dev/null 2>&1 || { debug "Pod does not have exactly one container"; failed; return; }
  debug "Verifying pod uses expected image"
  echo "$pod_json" | jq -e --arg img "$expected_image" '.spec.containers[0].image == $img' >/dev/null 2>&1 || { debug "Pod image is not '$expected_image'"; failed; return; }

  # Verify pod contains a volume that uses the expected secret
  debug "Verifying pod contains a volume using secret '$secret_name'"
  local volume_name
  volume_name=$(echo "$pod_json" | jq -r --arg secret "$secret_name" '.spec.volumes[] | select(.secret.secretName == $secret) | .name' 2>/dev/null) || { debug "Failed to extract volume name for secret"; failed; return; }
  [[ -n "$volume_name" ]] || { debug "No volume found using secret '$secret_name'"; failed; return; }

  # Verify container has a volumeMount with the name of the volume and the expected mount path
  debug "Verifying container has correct volumeMount"
  echo "$pod_json" | jq -e --arg vol "$volume_name" --arg path "$expected_mount_path" \
    '.spec.containers[0].volumeMounts[] | select(.name == $vol and .mountPath == $path)' >/dev/null 2>&1 || { debug "No volumeMount with name '$volume_name' and path '$expected_mount_path'"; failed; return; }

  # Verify the files are mounted in the container and match the local files (base64 compare)
  debug "Comparing mounted tls.crt with local file"
  local local_crt_b64
  local_crt_b64=$(base64 -w0 < "$local_crt_file" 2>/dev/null) || { debug "Failed to base64 encode local crt file"; failed; return; }
  local pod_crt_b64
  pod_crt_b64=$(kubectl exec "$pod_name" -- sh -c "base64 -w0 < '$expected_mount_path/tls.crt'" 2>/dev/null) || { debug "Failed to base64 encode pod crt file"; failed; return; }
  [[ "$local_crt_b64" == "$pod_crt_b64" ]] || { debug "Mounted tls.crt does not match local file"; failed; return; }

  debug "Comparing mounted tls.key with local file"
  local local_key_b64
  local_key_b64=$(base64 -w0 < "$local_key_file" 2>/dev/null) || { debug "Failed to base64 encode local key file"; failed; return; }
  local pod_key_b64
  pod_key_b64=$(kubectl exec "$pod_name" -- sh -c "base64 -w0 < '$expected_mount_path/tls.key'" 2>/dev/null) || { debug "Failed to base64 encode pod key file"; failed; return; }
  [[ "$local_key_b64" == "$pod_key_b64" ]] || { debug "Mounted tls.key does not match local file"; failed; return; }

  debug "All verifications passed for task $TASK_NUMBER"
  solved
  return
}

# shellcheck disable=SC2329
verify_task5() {
  TASK_NUMBER="5"

  # Expected values
  local configmap_name="message-config"
  local configmap_key="message"
  local configmap_value="Hello, Kubernetes"
  local pod_name="message-pod"
  local expected_image="busybox:1.37.0"
  local expected_command="sh -c while true; do echo \"\$MESSAGE\"; sleep 5; done"
  local env_name="MESSAGE"
  local env_configmap_name="message-config"
  local env_configmap_key="message"

  # Verify ConfigMap exists and has correct data
  debug "Checking if ConfigMap '$configmap_name' exists and contains correct data"
  local cm_json
  cm_json=$(kubectl get configmap "$configmap_name" -o json 2>/dev/null) || { debug "Failed to get ConfigMap '$configmap_name'"; failed; return; }
  echo "$cm_json" | jq -e --arg key "$configmap_key" --arg val "$configmap_value" '.data[$key] == $val' >/dev/null 2>&1 || { debug "ConfigMap '$configmap_name' does not contain key '$configmap_key' with value '$configmap_value'"; failed; return; }

  # Verify Pod exists and has correct image
  debug "Checking if Pod '$pod_name' exists and uses correct image"
  local pod_json
  pod_json=$(kubectl get pod "$pod_name" -o json 2>/dev/null) || { debug "Failed to get Pod '$pod_name'"; failed; return; }
  echo "$pod_json" | jq -e --arg img "$expected_image" '.spec.containers[0].image == $img' >/dev/null 2>&1 || { debug "Pod does not use expected image '$expected_image'"; failed; return; }

  # Verify Pod command
  debug "Verifying Pod command"
  local pod_command
  pod_command=$(echo "$pod_json" | jq -r '.spec.containers[0].command | join(" ")' 2>/dev/null) || { debug "Failed to extract command from Pod"; failed; return; }
  [[ "$pod_command" == "$expected_command" ]] || { debug "Expected command: $expected_command, found: $pod_command"; failed; return; }

  # Verify environment variable is set from ConfigMap key
  debug "Verifying environment variable '$env_name' is set from ConfigMap '$env_configmap_name' key '$env_configmap_key'"
  echo "$pod_json" | jq -e --arg env "$env_name" --arg cm "$env_configmap_name" --arg key "$env_configmap_key" \
    '.spec.containers[0].env[] | select(.name == $env) | .valueFrom.configMapKeyRef.name == $cm and .valueFrom.configMapKeyRef.key == $key' >/dev/null 2>&1 || { debug "Pod does not have env '$env_name' set from ConfigMap '$env_configmap_name' key '$env_configmap_key'"; failed; return; }

  debug "All verifications passed for task $TASK_NUMBER"
  solved
  return
}

# shellcheck disable=SC2329
verify_task6() {
  TASK_NUMBER="6"

  # Expected values
  local secret_name="api-secret"
  local configmap1_name="frontend-config"
  local configmap2_name="backend-config"
  local pod_name="complex-pod"
  local expected_api_key="12345"
  local expected_title="Frontend"
  local expected_endpoint="http://backend.local"

  # Verify Secret exists and get as json
  debug "Checking if Secret '$secret_name' exists"
  local secret_json
  secret_json=$(kubectl get secret "$secret_name" -o json 2>/dev/null) || { debug "Failed to get Secret '$secret_name'"; failed; return; }

  # Verify Secret contains expected API_KEY value (base64 encoded)
  debug "Verifying Secret contains correct API_KEY value"
  local expected_api_key_b64
  expected_api_key_b64=$(echo -n "$expected_api_key" | base64 2>/dev/null) || { debug "Failed to base64 encode expected API_KEY"; failed; return; }
  echo "$secret_json" | jq -e --arg key "$expected_api_key_b64" '.data.API_KEY == $key' 2>/dev/null | grep -q true || { debug "Secret API_KEY does not match expected value"; failed; return; }

  # Verify ConfigMap frontend-config exists and get as json
  debug "Checking if ConfigMap '$configmap1_name' exists"
  local configmap1_json
  configmap1_json=$(kubectl get configmap "$configmap1_name" -o json 2>/dev/null) || { debug "Failed to get ConfigMap '$configmap1_name'"; failed; return; }

  # Verify ConfigMap contains expected TITLE value
  debug "Verifying ConfigMap '$configmap1_name' contains correct TITLE"
  echo "$configmap1_json" | jq -e --arg val "$expected_title" '.data.TITLE == $val' 2>/dev/null | grep -q true || { debug "ConfigMap TITLE does not match expected value"; failed; return; }

  # Verify ConfigMap backend-config exists and get as json
  debug "Checking if ConfigMap '$configmap2_name' exists"
  local configmap2_json
  configmap2_json=$(kubectl get configmap "$configmap2_name" -o json 2>/dev/null) || { debug "Failed to get ConfigMap '$configmap2_name'"; failed; return; }

  # Verify ConfigMap contains expected ENDPOINT value
  debug "Verifying ConfigMap '$configmap2_name' contains correct ENDPOINT"
  echo "$configmap2_json" | jq -e --arg val "$expected_endpoint" '.data.ENDPOINT == $val' 2>/dev/null | grep -q true || { debug "ConfigMap ENDPOINT does not match expected value"; failed; return; }

  # Verify Pod exists and get as json
  debug "Checking if Pod '$pod_name' exists"
  local pod_json
  pod_json=$(kubectl get pod "$pod_name" -o json 2>/dev/null) || { debug "Failed to get Pod '$pod_name'"; failed; return; }

  # Verify Pod uses nginx:1.29.0 image
  debug "Verifying Pod uses image 'nginx:1.29.0'"
  echo "$pod_json" | jq -e '.spec.containers[0].image == "nginx:1.29.0"' 2>/dev/null | grep -q true || { debug "Pod does not use image 'nginx:1.29.0'"; failed; return; }

  # Verify Pod is running and has expected env vars
  debug "Checking Pod environment variables"
  local pod_env
  pod_env=$(kubectl exec "$pod_name" -- env 2>/dev/null) || { debug "Failed to get environment variables from Pod"; failed; return; }
  echo "$pod_env" | grep -q "^TITLE=$expected_title$" || { debug "TITLE env var not set to '$expected_title'"; failed; return; }
  echo "$pod_env" | grep -q "^ENDPOINT=$expected_endpoint$" || { debug "ENDPOINT env var not set to '$expected_endpoint'"; failed; return; }
  echo "$pod_env" | grep -q "^API_KEY=$expected_api_key$" || { debug "API_KEY env var not set to '$expected_api_key'"; failed; return; }

  debug "All verifications passed for task $TASK_NUMBER"
  solved
  return
}

# shellcheck disable=SC2329
verify_task7() {
  TASK_NUMBER="7"

  # Expected values
  local namespace="volume"
  local cm_name="app-config"
  local secret_name="app-secret"
  local pod_name="volume-pod"
  local expected_container_image="redis:8.0.2"
  local expected_cm_key="config.yml"
  local expected_cm_value="application: setting1"
  local expected_secret_key="password"
  local expected_secret_value_base64
  expected_secret_value_base64=$(echo -n "awesome_and_secure" | base64 2>/dev/null)
  local expected_config_mount_path="/etc/config"
  local expected_secret_mount_path="/etc/secret"

  # Verify ConfigMap exists and get its json
  debug "Checking if ConfigMap '$cm_name' exists in namespace '$namespace'"
  local cm_json
  cm_json=$(kubectl get configmap "$cm_name" -n "$namespace" -o json 2>/dev/null) || { debug "Failed to get ConfigMap '$cm_name'"; failed; return; }

  # Verify ConfigMap contains expected data
  debug "Verifying ConfigMap contains key '$expected_cm_key' with correct value"
  echo "$cm_json" | jq -e --arg key "$expected_cm_key" --arg val "$expected_cm_value" '.data[$key] == $val' >/dev/null 2>&1 || { debug "ConfigMap '$cm_name' does not contain key '$expected_cm_key' with value '$expected_cm_value'"; failed; return; }

  # Verify Secret exists and get its json
  debug "Checking if Secret '$secret_name' exists in namespace '$namespace'"
  local secret_json
  secret_json=$(kubectl get secret "$secret_name" -n "$namespace" -o json 2>/dev/null) || { debug "Failed to get Secret '$secret_name'"; failed; return; }

  # Verify Secret contains expected data (base64 encoded)
  debug "Verifying Secret contains key '$expected_secret_key' with correct base64 value"
  echo "$secret_json" | jq -e --arg key "$expected_secret_key" --arg val "$expected_secret_value_base64" '.data[$key] == $val' >/dev/null 2>&1 || { debug "Secret '$secret_name' does not contain key '$expected_secret_key' with expected value"; failed; return; }

  # Verify Pod exists and get its json
  debug "Checking if Pod '$pod_name' exists in namespace '$namespace'"
  local pod_json
  pod_json=$(kubectl get pod "$pod_name" -n "$namespace" -o json 2>/dev/null) || { debug "Failed to get Pod '$pod_name'"; failed; return; }

  # Verify Pod uses the expected image
  debug "Verifying Pod uses expected image"
  echo "$pod_json" | jq -e --arg image "$expected_container_image" '.spec.containers[0].image == $image' >/dev/null 2>&1 || { debug "Pod does not use expected image '$expected_container_image'"; failed; return; }

  # Get volumeMounts and volumes
  debug "Extracting volumeMount names for config and secret"
  local config_mount_name
  config_mount_name=$(echo "$pod_json" | jq -r --arg path "$expected_config_mount_path" '.spec.containers[0].volumeMounts[] | select(.mountPath == $path) | .name' 2>/dev/null) || { debug "Failed to extract config volumeMount name"; failed; return; }
  local secret_mount_name
  secret_mount_name=$(echo "$pod_json" | jq -r --arg path "$expected_secret_mount_path" '.spec.containers[0].volumeMounts[] | select(.mountPath == $path) | .name' 2>/dev/null) || { debug "Failed to extract secret volumeMount name"; failed; return; }

  # Check that mount names are not empty
  [[ -n "$config_mount_name" ]] || { debug "Config volumeMount name is empty"; failed; return; }
  [[ -n "$secret_mount_name" ]] || { debug "Secret volumeMount name is empty"; failed; return; }

  # Verify config volumeMount points to the expected ConfigMap
  debug "Verifying config volumeMount points to ConfigMap '$cm_name'"
  echo "$pod_json" | jq -e --arg name "$config_mount_name" --arg cm "$cm_name" '.spec.volumes[] | select(.name == $name) | .configMap.name == $cm' >/dev/null 2>&1 || { debug "Config volumeMount does not point to ConfigMap '$cm_name'"; failed; return; }

  # Verify secret volumeMount points to the expected Secret
  debug "Verifying secret volumeMount points to Secret '$secret_name'"
  echo "$pod_json" | jq -e --arg name "$secret_mount_name" --arg secret "$secret_name" '.spec.volumes[] | select(.name == $name) | .secret.secretName == $secret' >/dev/null 2>&1 || { debug "Secret volumeMount does not point to Secret '$secret_name'"; failed; return; }

  debug "All verifications passed for task $TASK_NUMBER"
  solved
  return
}

# shellcheck disable=SC2329
verify_task8() {
  TASK_NUMBER="8"

  # Expected values and file-derived values
  local namespace="files"
  local env_configmap_name="config-env"
  local env_secret_name="secret-env"
  local file_configmap_name="config-file"
  local file_secret_name="secret-file"
  local pod_name="app-pod"
  local image="httpd:2.4"
  local config_env_file="t8config.env"
  local env_key1="environment"
  local env_key2="title"
  local secret_env_file="t8secret.env"
  local secret_key1="user"
  local secret_key2="password"
  local config_file_key="t8config.database"
  local secret_file_key="t8secret.database"
  local config_mount_path="/etc/database/config.properties"
  local secret_mount_path="/etc/database/secret.properties"

  # Read expected values from files
  local expected_env_environment expected_env_title
  expected_env_environment=$(grep "^${env_key1}=" "./$config_env_file" | cut -d '=' -f2-) || { debug "Failed to read $env_key1 from $config_env_file"; failed; return; }
  expected_env_title=$(grep "^${env_key2}=" "./$config_env_file" | cut -d '=' -f2-) || { debug "Failed to read $env_key2 from $config_env_file"; failed; return; }

  local expected_secret_user expected_secret_password
  expected_secret_user=$(grep "^${secret_key1}=" "./$secret_env_file" | cut -d '=' -f2-) || { debug "Failed to read $secret_key1 from $secret_env_file"; failed; return; }
  expected_secret_password=$(grep "^${secret_key2}=" "./$secret_env_file" | cut -d '=' -f2-) || { debug "Failed to read $secret_key2 from $secret_env_file"; failed; return; }

  # 1. Verify configmap config-env
  debug "Verifying ConfigMap '$env_configmap_name' in namespace '$namespace'"
  local cm_env_json
  cm_env_json=$(kubectl get configmap "$env_configmap_name" -n "$namespace" -o json 2>/dev/null) || { debug "Failed to get ConfigMap '$env_configmap_name'"; failed; return; }
  jq -e --arg k "$env_key1" --arg v "$expected_env_environment" '.data[$k] == $v' <<<"$cm_env_json" >/dev/null 2>&1 || { debug "ConfigMap '$env_configmap_name' does not contain $env_key1=$expected_env_environment"; failed; return; }
  jq -e --arg k "$env_key2" --arg v "$expected_env_title" '.data[$k] == $v' <<<"$cm_env_json" >/dev/null 2>&1 || { debug "ConfigMap '$env_configmap_name' does not contain $env_key2=$expected_env_title"; failed; return; }

  # 2. Verify configmap config-file
  debug "Verifying ConfigMap '$file_configmap_name' file key"
  local cm_file_json
  cm_file_json=$(kubectl get configmap "$file_configmap_name" -n "$namespace" -o jsonpath='{.data.t8config\.database}' 2>/dev/null) || { debug "Failed to get ConfigMap '$file_configmap_name' file key"; failed; return; }
  diff "./$config_file_key" <(echo "$cm_file_json") 2>/dev/null || { debug "ConfigMap file key does not match local file"; failed; return; }

  # 3. Verify secret secret-env
  debug "Verifying Secret '$env_secret_name' in namespace '$namespace'"
  local secret_env_json
  secret_env_json=$(kubectl get secret "$env_secret_name" -n "$namespace" -o json 2>/dev/null) || { debug "Failed to get Secret '$env_secret_name'"; failed; return; }
  local user_decoded
  user_decoded=$(jq -r --arg k "$secret_key1" '.data[$k]' <<<"$secret_env_json" | base64 -d 2>/dev/null) || { debug "Failed to decode user from Secret"; failed; return; }
  [[ "$user_decoded" == "$expected_secret_user" ]] || { debug "Secret user does not match expected value"; failed; return; }
  local password_decoded
  password_decoded=$(jq -r --arg k "$secret_key2" '.data[$k]' <<<"$secret_env_json" | base64 -d 2>/dev/null) || { debug "Failed to decode password from Secret"; failed; return; }
  [[ "$password_decoded" == "$expected_secret_password" ]] || { debug "Secret password does not match expected value"; failed; return; }

  # 4. Verify secret secret-file
  debug "Verifying Secret '$file_secret_name' file key"
  local secret_file_json
  secret_file_json=$(kubectl get secret "$file_secret_name" -n "$namespace" -o jsonpath='{.data.t8secret\.database}' 2>/dev/null) || { debug "Failed to get Secret '$file_secret_name' file key"; failed; return; }
  local secret_file_decoded
  secret_file_decoded=$(echo "$secret_file_json" | base64 -d 2>/dev/null) || { debug "Failed to decode secret file key"; failed; return; }
  diff "./$secret_file_key" <(echo "$secret_file_decoded") 2>/dev/null || { debug "Secret file key does not match local file"; failed; return; }

  # 5. Verify pod exists and get as json
  debug "Verifying Pod '$pod_name' exists in namespace '$namespace'"
  local pod_json
  pod_json=$(kubectl get pod "$pod_name" -n "$namespace" -o json 2>/dev/null) || { debug "Failed to get Pod '$pod_name'"; failed; return; }

  # 6. Verify pod image
  debug "Verifying Pod uses image '$image'"
  jq -e --arg img "$image" '.spec.containers[0].image == $img' <<<"$pod_json" >/dev/null 2>&1 || { debug "Pod does not use image '$image'"; failed; return; }

  # 7. Verify env variables from configmap and secret
  debug "Verifying Pod environment variables from ConfigMap and Secret"
  jq -e --arg name "APP_ENV" --arg cm "$env_configmap_name" --arg key "$env_key1" \
    '.spec.containers[0].env[] | select(.name == $name and .valueFrom.configMapKeyRef.name == $cm and .valueFrom.configMapKeyRef.key == $key)' <<<"$pod_json" >/dev/null 2>&1 || { debug "Pod does not have APP_ENV from ConfigMap"; failed; return; }
  jq -e --arg name "APP_TITLE" --arg cm "$env_configmap_name" --arg key "$env_key2" \
    '.spec.containers[0].env[] | select(.name == $name and .valueFrom.configMapKeyRef.name == $cm and .valueFrom.configMapKeyRef.key == $key)' <<<"$pod_json" >/dev/null 2>&1 || { debug "Pod does not have APP_TITLE from ConfigMap"; failed; return; }
  jq -e --arg name "APP_USER" --arg sec "$env_secret_name" --arg key "$secret_key1" \
    '.spec.containers[0].env[] | select(.name == $name and .valueFrom.secretKeyRef.name == $sec and .valueFrom.secretKeyRef.key == $key)' <<<"$pod_json" >/dev/null 2>&1 || { debug "Pod does not have APP_USER from Secret"; failed; return; }
  jq -e --arg name "APP_PASSWORD" --arg sec "$env_secret_name" --arg key "$secret_key2" \
    '.spec.containers[0].env[] | select(.name == $name and .valueFrom.secretKeyRef.name == $sec and .valueFrom.secretKeyRef.key == $key)' <<<"$pod_json" >/dev/null 2>&1 || { debug "Pod does not have APP_PASSWORD from Secret"; failed; return; }

  # 8. Verify volumeMounts and volumes for configmap and secret
  debug "Verifying Pod volumeMounts and volumes for ConfigMap and Secret"
  local config_volume
  config_volume=$(jq -r '.spec.containers[0].volumeMounts[] | select(.mountPath == "/etc/database/config.properties") | .name' <<<"$pod_json") || { debug "Failed to extract config volumeMount name"; failed; return; }
  jq -e --arg vol "$config_volume" --arg cm "$file_configmap_name" --arg key "$config_file_key" \
    '.spec.volumes[] | select(.name == $vol and .configMap.name == $cm)' <<<"$pod_json" >/dev/null 2>&1 || { debug "Pod config volume does not point to ConfigMap"; failed; return; }

  local secret_volume
  secret_volume=$(jq -r '.spec.containers[0].volumeMounts[] | select(.mountPath == "/etc/database/secret.properties") | .name' <<<"$pod_json") || { debug "Failed to extract secret volumeMount name"; failed; return; }
  jq -e --arg vol "$secret_volume" --arg sec "$file_secret_name" --arg key "$secret_file_key" \
    '.spec.volumes[] | select(.name == $vol and .secret.secretName == $sec)' <<<"$pod_json" >/dev/null 2>&1 || { debug "Pod secret volume does not point to Secret"; failed; return; }

  # 9. Verify in-container env and files (exec into pod)
  debug "Verifying in-container environment variables and files"
  local env_val
  env_val=$(kubectl exec -n "$namespace" "$pod_name" -- printenv APP_ENV 2>/dev/null) || { debug "Failed to get APP_ENV from pod"; failed; return; }
  [[ "$env_val" == "$expected_env_environment" ]] || { debug "APP_ENV in pod does not match expected value"; failed; return; }
  env_val=$(kubectl exec -n "$namespace" "$pod_name" -- printenv APP_TITLE 2>/dev/null) || { debug "Failed to get APP_TITLE from pod"; failed; return; }
  [[ "$env_val" == "$expected_env_title" ]] || { debug "APP_TITLE in pod does not match expected value"; failed; return; }
  env_val=$(kubectl exec -n "$namespace" "$pod_name" -- printenv APP_USER 2>/dev/null) || { debug "Failed to get APP_USER from pod"; failed; return; }
  [[ "$env_val" == "$expected_secret_user" ]] || { debug "APP_USER in pod does not match expected value"; failed; return; }
  env_val=$(kubectl exec -n "$namespace" "$pod_name" -- printenv APP_PASSWORD 2>/dev/null) || { debug "Failed to get APP_PASSWORD from pod"; failed; return; }
  [[ "$env_val" == "$expected_secret_password" ]] || { debug "APP_PASSWORD in pod does not match expected value"; failed; return; }

  local file_content
  file_content=$(kubectl exec -n "$namespace" "$pod_name" -- cat "$config_mount_path" 2>/dev/null) || { debug "Failed to read config.properties in pod"; failed; return; }
  [[ "$file_content" == $(cat "./${config_file_key}") ]] || { debug "config.properties in pod does not match expected file"; failed; return; }
  file_content=$(kubectl exec -n "$namespace" "$pod_name" -- cat "$secret_mount_path" 2>/dev/null) || { debug "Failed to read secret.properties in pod"; failed; return; }
  [[ "$file_content" == $(cat "./${secret_file_key}") ]] || { debug "secret.properties in pod does not match expected file"; failed; return; }

  debug "All verifications passed for task $TASK_NUMBER"
  solved
  return
}

# shellcheck disable=SC2329
verify_task9() {
  TASK_NUMBER="9"

  # Expected values
  local namespace="default"
  local cm_name="immutable-config"
  local expected_cm_key="APP_ENV"
  local expected_cm_value="staging"

  # Verify ConfigMap exists and get its json
  debug "Checking if ConfigMap '$cm_name' exists in namespace '$namespace'"
  local cm_json
  cm_json=$(kubectl get configmap "$cm_name" -n "$namespace" -o json 2>/dev/null) || { debug "Failed to get ConfigMap '$cm_name'"; failed; return; }

  # Verify ConfigMap contains expected data
  debug "Verifying ConfigMap contains key '$expected_cm_key' with value '$expected_cm_value'"
  echo "$cm_json" | jq -e --arg key "$expected_cm_key" --arg val "$expected_cm_value" '.data[$key] == $val' >/dev/null 2>&1 || { debug "ConfigMap does not contain $expected_cm_key=$expected_cm_value"; failed; return; }

  # Verify ConfigMap is immutable
  debug "Verifying ConfigMap is immutable"
  echo "$cm_json" | jq -e '.immutable == true' >/dev/null 2>&1 || { debug "ConfigMap is not immutable"; failed; return; }

  debug "All verifications passed for task $TASK_NUMBER"
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
)
run_verification VERIFY_TASK_FUNCTIONS "$@"

exit 0
