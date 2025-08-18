#!/bin/bash

# shellcheck source=../../.scripts/verify.sh
source "$(git rev-parse --show-toplevel)/.scripts/verify.sh"

# shellcheck disable=SC2329
verify_task1() {
  TASK_NUMBER="1"

  # Expected values
  local pv_name="data-pv"
  local pvc_name="data-pvc"
  local pod_name="data-pod"
  local image_name="nginx:1.29.0"
  local pv_storage="1Gi"
  local pvc_request="500Mi"
  local access_mode="ReadWriteOnce"
  local pv_path="/mnt/data"
  local pvc_mount_path="/data"

  # Verify PersistentVolume exists and matches the spec
  debug "Checking if PersistentVolume '$pv_name' exists and matches the expected spec"
  local pv_json
  pv_json=$(kubectl get pv "$pv_name" -o json 2>/dev/null) || { debug "Failed to get PersistentVolume '$pv_name'"; failed; return; }
  local pv_actual_name
  pv_actual_name=$(echo "$pv_json" | jq -r '.metadata.name') || { debug "Failed to extract PV name"; failed; return; }
  [[ "$pv_actual_name" == "$pv_name" ]] || { debug "Expected PV name: $pv_name, found: $pv_actual_name"; failed; return; }
  local pv_actual_storage
  pv_actual_storage=$(echo "$pv_json" | jq -r '.spec.capacity.storage') || { debug "Failed to extract PV storage"; failed; return; }
  [[ "$pv_actual_storage" == "$pv_storage" ]] || { debug "Expected PV storage: $pv_storage, found: $pv_actual_storage"; failed; return; }
  local pv_actual_access_mode
  pv_actual_access_mode=$(echo "$pv_json" | jq -r '.spec.accessModes[0]') || { debug "Failed to extract PV access mode"; failed; return; }
  [[ "$pv_actual_access_mode" == "$access_mode" ]] || { debug "Expected PV access mode: $access_mode, found: $pv_actual_access_mode"; failed; return; }
  local pv_actual_path
  pv_actual_path=$(echo "$pv_json" | jq -r '.spec.hostPath.path') || { debug "Failed to extract PV hostPath"; failed; return; }
  [[ "$pv_actual_path" == "$pv_path" ]] || { debug "Expected PV hostPath: $pv_path, found: $pv_actual_path"; failed; return; }

  # Verify PersistentVolumeClaim exists and matches the spec
  debug "Checking if PersistentVolumeClaim '$pvc_name' exists and matches the expected spec"
  local pvc_json
  pvc_json=$(kubectl get pvc "$pvc_name" -o json 2>/dev/null) || { debug "Failed to get PersistentVolumeClaim '$pvc_name'"; failed; return; }
  local pvc_actual_name
  pvc_actual_name=$(echo "$pvc_json" | jq -r '.metadata.name') || { debug "Failed to extract PVC name"; failed; return; }
  [[ "$pvc_actual_name" == "$pvc_name" ]] || { debug "Expected PVC name: $pvc_name, found: $pvc_actual_name"; failed; return; }
  local pvc_actual_volume_name
  pvc_actual_volume_name=$(echo "$pvc_json" | jq -r '.spec.volumeName') || { debug "Failed to extract PVC volumeName"; failed; return; }
  [[ "$pvc_actual_volume_name" == "$pv_name" ]] || { debug "Expected PVC volumeName: $pv_name, found: $pvc_actual_volume_name"; failed; return; }
  local pvc_actual_access_mode
  pvc_actual_access_mode=$(echo "$pvc_json" | jq -r '.spec.accessModes[0]') || { debug "Failed to extract PVC access mode"; failed; return; }
  [[ "$pvc_actual_access_mode" == "$access_mode" ]] || { debug "Expected PVC access mode: $access_mode, found: $pvc_actual_access_mode"; failed; return; }
  local pvc_actual_request
  pvc_actual_request=$(echo "$pvc_json" | jq -r '.spec.resources.requests.storage') || { debug "Failed to extract PVC storage request"; failed; return; }
  [[ "$pvc_actual_request" == "$pvc_request" ]] || { debug "Expected PVC storage request: $pvc_request, found: $pvc_actual_request"; failed; return; }

  # Verify Pod exists and matches the spec
  debug "Checking if Pod '$pod_name' exists and matches the expected spec"
  local pod_json
  pod_json=$(kubectl get pod "$pod_name" -o json 2>/dev/null) || { debug "Failed to get Pod '$pod_name'"; failed; return; }
  local pod_actual_name
  pod_actual_name=$(echo "$pod_json" | jq -r '.metadata.name') || { debug "Failed to extract Pod name"; failed; return; }
  [[ "$pod_actual_name" == "$pod_name" ]] || { debug "Expected Pod name: $pod_name, found: $pod_actual_name"; failed; return; }
  local pod_actual_image
  pod_actual_image=$(echo "$pod_json" | jq -r '.spec.containers[0].image') || { debug "Failed to extract Pod image"; failed; return; }
  [[ "$pod_actual_image" == "$image_name" ]] || { debug "Expected Pod image: $image_name, found: $pod_actual_image"; failed; return; }
  local pod_actual_mount_path
  pod_actual_mount_path=$(echo "$pod_json" | jq -r '.spec.containers[0].volumeMounts[0].mountPath') || { debug "Failed to extract Pod volumeMount path"; failed; return; }
  [[ "$pod_actual_mount_path" == "$pvc_mount_path" ]] || { debug "Expected Pod mountPath: $pvc_mount_path, found: $pod_actual_mount_path"; failed; return; }
  local pod_actual_claim_name
  pod_actual_claim_name=$(echo "$pod_json" | jq -r '.spec.volumes[0].persistentVolumeClaim.claimName') || { debug "Failed to extract Pod PVC claimName"; failed; return; }
  [[ "$pod_actual_claim_name" == "$pvc_name" ]] || { debug "Expected Pod PVC claimName: $pvc_name, found: $pod_actual_claim_name"; failed; return; }

  debug "All verifications passed for task $TASK_NUMBER"
  solved
  return
}

# shellcheck disable=SC2329
verify_task2() {
  TASK_NUMBER="2"

  # Expected values
  local pod_name="init-cache"
  local namespace="default"
  local init_container_mount_path="/cache"
  local app_container_name="app"
  local app_container_image="nginx:1.29.0"
  local app_html_mount_path="/usr/share/nginx/html"
  local app_config_mount_path="/etc/nginx/conf.d"
  local expected_config_map_name="app-config"

  # Step 1: Get the pod as JSON by its name
  debug "Fetching pod '$pod_name' in namespace '$namespace'"
  local pod_json
  pod_json=$(kubectl get pod "$pod_name" -n "$namespace" -o json 2>/dev/null) || { debug "Failed to get pod '$pod_name'"; failed; return; }

  # Step 2: Verify initContainer[0] has a volumeMount[0] with the expected mountPath
  debug "Checking initContainer[0] volumeMount[0] mountPath"
  local init_container_mount_path_actual
  init_container_mount_path_actual=$(echo "$pod_json" | jq -r '.spec.initContainers[0].volumeMounts[0].mountPath' 2>/dev/null) || { debug "Failed to extract initContainer mountPath"; failed; return; }
  [[ "$init_container_mount_path_actual" == "$init_container_mount_path" ]] || { debug "Expected initContainer mountPath: $init_container_mount_path, found: $init_container_mount_path_actual"; failed; return; }

  # Step 3: Get the name of the volumeMount[0] from the initContainer
  debug "Extracting initContainer[0] volumeMount[0] name"
  local init_container_volume_name
  init_container_volume_name=$(echo "$pod_json" | jq -r '.spec.initContainers[0].volumeMounts[0].name' 2>/dev/null) || { debug "Failed to extract initContainer volume name"; failed; return; }
  [[ -n "$init_container_volume_name" ]] || { debug "initContainer volume name is empty"; failed; return; }

  # Step 4: Verify the volume is an emptyDir
  debug "Verifying that volume '$init_container_volume_name' is an emptyDir"
  local empty_dir_check
  empty_dir_check=$(echo "$pod_json" | jq -r ".spec.volumes[] | select(.name == \"$init_container_volume_name\").emptyDir" 2>/dev/null) || { debug "Failed to check emptyDir for volume '$init_container_volume_name'"; failed; return; }
  [[ "$empty_dir_check" != "null" ]] || { debug "Volume '$init_container_volume_name' is not an emptyDir"; failed; return; }

  # Step 5: Verify containers[0] has the expected name
  debug "Checking app container name"
  local app_container_name_actual
  app_container_name_actual=$(echo "$pod_json" | jq -r '.spec.containers[0].name' 2>/dev/null) || { debug "Failed to extract app container name"; failed; return; }
  [[ "$app_container_name_actual" == "$app_container_name" ]] || { debug "Expected app container name: $app_container_name, found: $app_container_name_actual"; failed; return; }

  # Step 6: Verify containers[0] has the expected image
  debug "Checking app container image"
  local app_container_image_actual
  app_container_image_actual=$(echo "$pod_json" | jq -r '.spec.containers[0].image' 2>/dev/null) || { debug "Failed to extract app container image"; failed; return; }
  [[ "$app_container_image_actual" == "$app_container_image" ]] || { debug "Expected app container image: $app_container_image, found: $app_container_image_actual"; failed; return; }

  # Step 7: Verify the app container has a volumeMount with the same volume as in step 3, mounted to the expected path
  debug "Checking app container html volumeMount"
  local app_container_html_mount
  app_container_html_mount=$(echo "$pod_json" | jq -r ".spec.containers[0].volumeMounts[] | select(.name == \"$init_container_volume_name\" and .mountPath == \"$app_html_mount_path\")" 2>/dev/null) || { debug "Failed to extract app container html volumeMount"; failed; return; }
  [[ -n "$app_container_html_mount" ]] || { debug "App container does not have expected html volumeMount"; failed; return; }

  # Step 8: Verify the app container has another volume mounted to the expected path
  debug "Checking app container config volumeMount"
  local config_volume_mount
  config_volume_mount=$(echo "$pod_json" | jq -r ".spec.containers[0].volumeMounts[] | select(.mountPath == \"$app_config_mount_path\").name" 2>/dev/null) || { debug "Failed to extract config volumeMount"; failed; return; }
  [[ -n "$config_volume_mount" ]] || { debug "App container does not have config volumeMount at $app_config_mount_path"; failed; return; }

  # Step 9: Verify the corresponding volume points to the configMap with the expected name
  debug "Checking configMap name for config volume"
  local config_map_name_actual
  config_map_name_actual=$(echo "$pod_json" | jq -r ".spec.volumes[] | select(.name == \"$config_volume_mount\").configMap.name" 2>/dev/null) || { debug "Failed to extract configMap name for config volume"; failed; return; }
  [[ "$config_map_name_actual" == "$expected_config_map_name" ]] || { debug "Expected configMap name: $expected_config_map_name, found: $config_map_name_actual"; failed; return; }

  # Step 10: Verify curl execution by checking nginx access log
  debug "Checking nginx access log for curl execution"
  local nginx_access_log
  nginx_access_log=$(kubectl exec -it "$pod_name" -c "$app_container_name" -- cat /var/log/nginx/host.access.log 2>/dev/null) || { debug "Failed to get nginx access log"; failed; return; }
  [[ "$nginx_access_log" == *"127.0.0.1"* && "$nginx_access_log" == *"GET"* && "$nginx_access_log" == *"200"* && "$nginx_access_log" == *"curl"* ]] || { debug "nginx access log does not show expected curl request"; failed; return; }

  debug "All verifications passed for task $TASK_NUMBER"
  solved
  return
}

# shellcheck disable=SC2329
verify_task3() {
  TASK_NUMBER="3"

  # Expected values
  local pod_name="task3-app"
  local pvc_name="task3-pvc"
  local pv_name="task3-pv"
  local task_file_name="task3.txt"
  local expected_text="nginx version: nginx/1.29.0"

  # Check if the pod is deleted
  debug "Verifying that pod '$pod_name' is deleted"
  local pod_status
  pod_status=$(kubectl get pod "$pod_name" -o json --ignore-not-found 2>/dev/null | jq -r '.metadata.name' 2>/dev/null) || { debug "Failed to get pod '$pod_name'"; failed; return; }
  [[ -z "$pod_status" ]] || { debug "Pod '$pod_name' still exists"; failed; return; }

  # Check if the PVC is deleted
  debug "Verifying that PVC '$pvc_name' is deleted"
  local pvc_status
  pvc_status=$(kubectl get pvc "$pvc_name" -o json --ignore-not-found 2>/dev/null | jq -r '.metadata.name' 2>/dev/null) || { debug "Failed to get PVC '$pvc_name'"; failed; return; }
  [[ -z "$pvc_status" ]] || { debug "PVC '$pvc_name' still exists"; failed; return; }

  # Check if the PV is deleted
  debug "Verifying that PV '$pv_name' is deleted"
  local pv_status
  pv_status=$(kubectl get pv "$pv_name" -o json --ignore-not-found 2>/dev/null | jq -r '.metadata.name' 2>/dev/null) || { debug "Failed to get PV '$pv_name'"; failed; return; }
  [[ -z "$pv_status" ]] || { debug "PV '$pv_name' still exists"; failed; return; }

  # Check if the task3.txt file exists
  debug "Verifying that file '$task_file_name' exists in the expected storage path"
  local local_storage_path
  local_storage_path="$(git rev-parse --show-toplevel)/.cluster/mounts/storage"
  [[ -f "$local_storage_path/$task_file_name" ]] || { debug "File '$task_file_name' does not exist at '$local_storage_path'"; failed; return; }

  # Check the content of task3.txt
  debug "Verifying the content of '$task_file_name'"
  local file_content
  file_content=$(cat "$local_storage_path/$task_file_name" 2>/dev/null) || { debug "Failed to read file '$task_file_name'"; failed; return; }
  [[ "$file_content" == "$expected_text" ]] || { debug "Expected file content: '$expected_text', found: '$file_content'"; failed; return; }

  debug "All verifications passed for task $TASK_NUMBER"
  solved
  return
}

# shellcheck disable=SC2329
verify_task4() {
  TASK_NUMBER="4"

  # Expected values
  local namespace="config"
  local pod_name="app"
  local expected_image="nginx:1.29.0"
  local mount_path="/etc/app"
  local configmap_name="app-config"
  local config_key="config"
  local expected_file_path="${mount_path}/config.json"

  # Get the pod as JSON by its name
  debug "Fetching pod '$pod_name' in namespace '$namespace'"
  local pod_json
  pod_json=$(kubectl get pod "$pod_name" -n "$namespace" -o json 2>/dev/null) || { debug "Failed to get pod '$pod_name' in namespace '$namespace'"; failed; return; }

  # Verify the pod is running
  debug "Verifying pod status is 'Running'"
  local pod_status
  pod_status=$(echo "$pod_json" | jq -r '.status.phase' 2>/dev/null) || { debug "Failed to extract pod status"; failed; return; }
  [[ "$pod_status" == "Running" ]] || { debug "Expected pod status: Running, found: $pod_status"; failed; return; }

  # Verify the pod's image is as expected
  debug "Verifying pod image"
  local pod_image
  pod_image=$(echo "$pod_json" | jq -r '.spec.containers[0].image' 2>/dev/null) || { debug "Failed to extract pod image"; failed; return; }
  [[ "$pod_image" == "$expected_image" ]] || { debug "Expected pod image: $expected_image, found: $pod_image"; failed; return; }

  # Verify there's a volumeMount to path /etc/app
  debug "Checking for volumeMount at '$mount_path'"
  local mount_check
  mount_check=$(echo "$pod_json" | jq -r --arg path "$mount_path" '.spec.containers[0].volumeMounts[] | select(.mountPath == $path)' 2>/dev/null) || { debug "Failed to check volumeMount at $mount_path"; failed; return; }
  [[ -n "$mount_check" ]] || { debug "No volumeMount found at $mount_path"; failed; return; }

  # Use the volumeMounts name to get the volume name
  debug "Extracting volume name for mount path '$mount_path'"
  local volume_name
  volume_name=$(echo "$pod_json" | jq -r --arg path "$mount_path" '.spec.containers[0].volumeMounts[] | select(.mountPath == $path) | .name' 2>/dev/null) || { debug "Failed to extract volume name for mount path $mount_path"; failed; return; }
  [[ -n "$volume_name" ]] || { debug "Volume name for mount path $mount_path is empty"; failed; return; }

  # Verify the volume mounts the right config map and has the items configured as expected
  debug "Verifying volume '$volume_name' mounts configMap '$configmap_name' with correct items"
  local cm_check
  cm_check=$(echo "$pod_json" | jq -r --arg vol "$volume_name" --arg cm "$configmap_name" --arg key "$config_key" \
    '.spec.volumes[] | select(.name == $vol) | (.configMap.name == $cm and .configMap.items[0].key == $key and .configMap.items[0].path == "config.json")' 2>/dev/null) || { debug "Failed to check configMap mount for volume $volume_name"; failed; return; }
  [[ "$cm_check" == "true" ]] || { debug "ConfigMap mount for volume $volume_name is not as expected"; failed; return; }

  # Get the value of the key from the ConfigMap
  debug "Fetching value for key '$config_key' from ConfigMap '$configmap_name'"
  local key_value
  key_value=$(kubectl get configmap "$configmap_name" -n "$namespace" -o json 2>/dev/null | jq -r --arg key "$config_key" '.data[$key]' 2>/dev/null) || { debug "Failed to get key '$config_key' from ConfigMap '$configmap_name'"; failed; return; }
  [[ -n "$key_value" ]] || { debug "Key '$config_key' in ConfigMap '$configmap_name' is empty"; failed; return; }

  # Verify the content of the file inside the container
  debug "Verifying content of file '$expected_file_path' inside pod"
  local file_content
  file_content=$(kubectl exec -n "$namespace" "$pod_name" -- cat "$expected_file_path" 2>/dev/null) || { debug "Failed to read file '$expected_file_path' inside pod"; failed; return; }
  [[ "$file_content" == "$key_value" ]] || { debug "Expected file content: '$key_value', found: '$file_content'"; failed; return; }

  debug "All verifications passed for task $TASK_NUMBER"
  solved
  return
}

# shellcheck disable=SC2329
verify_task5() {
  TASK_NUMBER="5"

  # Expected values
  local namespace="database"
  local pod_name="app"
  local expected_image="redis:8.0.2"
  local secret_name="db-credentials"
  local mount_path="/etc/credentials"
  local volume_name="secret-vol"

  # Get the pod definition in JSON format
  debug "Fetching pod '$pod_name' in namespace '$namespace'"
  local pod_json
  pod_json=$(kubectl get pod "$pod_name" -n "$namespace" -o json 2>/dev/null) || { debug "Failed to get pod '$pod_name' in namespace '$namespace'"; failed; return; }

  # Verify the pod is using the correct image
  debug "Verifying pod image"
  local pod_image
  pod_image=$(echo "$pod_json" | jq -r '.spec.containers[0].image' 2>/dev/null) || { debug "Failed to extract pod image"; failed; return; }
  [[ "$pod_image" == "$expected_image" ]] || { debug "Expected image: $expected_image, found: $pod_image"; failed; return; }

  # Verify the pod has the correct volumeMount
  debug "Checking for correct volumeMount"
  local volume_mount_path
  volume_mount_path=$(echo "$pod_json" | jq -r --arg vol "$volume_name" '.spec.containers[0].volumeMounts[] | select(.name==$vol) | .mountPath' 2>/dev/null) || { debug "Failed to extract volumeMount path"; failed; return; }
  [[ "$volume_mount_path" == "$mount_path" ]] || { debug "Expected volumeMount path: $mount_path, found: $volume_mount_path"; failed; return; }

  # Verify the volume is backed by the correct Secret
  debug "Verifying volume '$volume_name' is backed by Secret '$secret_name'"
  local secret_ref
  secret_ref=$(echo "$pod_json" | jq -r --arg vol "$volume_name" '.spec.volumes[] | select(.name==$vol) | .secret.secretName' 2>/dev/null) || { debug "Failed to extract secret reference for volume $volume_name"; failed; return; }
  [[ "$secret_ref" == "$secret_name" ]] || { debug "Expected secret name: $secret_name, found: $secret_ref"; failed; return; }

  # Get the list of files in the container's mounted directory
  debug "Listing files in mounted directory '$mount_path' inside pod"
  local mounted_files
  mounted_files=$(kubectl exec -n "$namespace" "$pod_name" -- ls "$mount_path" 2>/dev/null) || { debug "Failed to list files in $mount_path inside pod"; failed; return; }

  # Verify all keys from the Secret are mounted (fetching Secret data keys)
  debug "Fetching keys from Secret '$secret_name'"
  local secret_keys
  secret_keys=$(kubectl get secret "$secret_name" -n "$namespace" -o json 2>/dev/null | jq -r '.data | keys | .[]' 2>/dev/null) || { debug "Failed to get keys from Secret '$secret_name'"; failed; return; }

  # Check that each key is present in the container's mounted directory as a file
  debug "Verifying each secret key is present as a file in the mounted directory"
  local key
  for key in $secret_keys; do
    echo "$mounted_files" | tr ' ' '\n' | grep -Fwq "$key" || { debug "Secret key '$key' not found in mounted directory '$mount_path'"; failed; return; }
  done

  debug "All verifications passed for task $TASK_NUMBER"
  solved
  return
}

# shellcheck disable=SC2329
verify_task6() {
  TASK_NUMBER="6"

  # Expected values
  local namespace="storage-limited"
  local pv_name="quota"
  local pvc_count=2
  local expected_request_storage="2Gi"
  local expected_pvc_limit=2
  local expected_pv_capacity="3Gi"
  local pv_path="/tmp/backend"
  local node_affinity_key="tier"
  local node_affinity_value="backend"

  # Verify the namespace exists
  debug "Checking if namespace '$namespace' exists"
  kubectl get ns "$namespace" &>/dev/null || { debug "Namespace '$namespace' does not exist"; failed; return; }

  # Get the list of quotas in the namespace
  debug "Fetching resource quotas in namespace '$namespace'"
  local quota_list
  quota_list=$(kubectl get quota -n "$namespace" -o json 2>/dev/null) || { debug "Failed to get resource quotas in namespace '$namespace'"; failed; return; }

  # Verify that one quota exists in the namespace
  debug "Verifying there is exactly one resource quota"
  local quota_count
  quota_count=$(echo "$quota_list" | jq '.items | length' 2>/dev/null) || { debug "Failed to count resource quotas"; failed; return; }
  [[ "$quota_count" -eq 1 ]] || { debug "Expected 1 resource quota, found: $quota_count"; failed; return; }

  # Verify the quota's definition
  debug "Verifying resource quota's storage and PVC limits"
  local quota_json
  quota_json=$(echo "$quota_list" | jq '.items[0]' 2>/dev/null) || { debug "Failed to extract resource quota JSON"; failed; return; }
  local quota_storage
  quota_storage=$(echo "$quota_json" | jq -r '.spec.hard["requests.storage"]' 2>/dev/null) || { debug "Failed to extract requests.storage from quota"; failed; return; }
  [[ "$quota_storage" == "$expected_request_storage" ]] || { debug "Expected requests.storage: $expected_request_storage, found: $quota_storage"; failed; return; }
  local quota_pvc_limit
  quota_pvc_limit=$(echo "$quota_json" | jq -r '.spec.hard["persistentvolumeclaims"]' 2>/dev/null) || { debug "Failed to extract persistentvolumeclaims from quota"; failed; return; }
  [[ "$quota_pvc_limit" == "$expected_pvc_limit" ]] || { debug "Expected persistentvolumeclaims: $expected_pvc_limit, found: $quota_pvc_limit"; failed; return; }

  # Verify the persistent volume's definition
  debug "Fetching and verifying PersistentVolume '$pv_name'"
  local pv_json
  pv_json=$(kubectl get pv "$pv_name" -o json 2>/dev/null) || { debug "Failed to get PersistentVolume '$pv_name'"; failed; return; }
  local pv_capacity
  pv_capacity=$(echo "$pv_json" | jq -r '.spec.capacity.storage' 2>/dev/null) || { debug "Failed to extract PV capacity"; failed; return; }
  [[ "$pv_capacity" == "$expected_pv_capacity" ]] || { debug "Expected PV capacity: $expected_pv_capacity, found: $pv_capacity"; failed; return; }
  local pv_local_path
  pv_local_path=$(echo "$pv_json" | jq -r '.spec.local.path' 2>/dev/null) || { debug "Failed to extract PV local path"; failed; return; }
  [[ "$pv_local_path" == "$pv_path" ]] || { debug "Expected PV local path: $pv_path, found: $pv_local_path"; failed; return; }
  local pv_affinity_key
  pv_affinity_key=$(echo "$pv_json" | jq -r '.spec.nodeAffinity.required.nodeSelectorTerms[0].matchExpressions[0].key' 2>/dev/null) || { debug "Failed to extract PV node affinity key"; failed; return; }
  [[ "$pv_affinity_key" == "$node_affinity_key" ]] || { debug "Expected PV node affinity key: $node_affinity_key, found: $pv_affinity_key"; failed; return; }
  local pv_affinity_value
  pv_affinity_value=$(echo "$pv_json" | jq -r '.spec.nodeAffinity.required.nodeSelectorTerms[0].matchExpressions[0].values[0]' 2>/dev/null) || { debug "Failed to extract PV node affinity value"; failed; return; }
  [[ "$pv_affinity_value" == "$node_affinity_value" ]] || { debug "Expected PV node affinity value: $node_affinity_value, found: $pv_affinity_value"; failed; return; }

  # Verify the correct number of PVCs exist in the namespace
  debug "Verifying the number of PVCs in namespace '$namespace'"
  local pvc_count_actual
  pvc_count_actual=$(kubectl get pvc -n "$namespace" -o json 2>/dev/null | jq '.items | length' 2>/dev/null) || { debug "Failed to count PVCs in namespace '$namespace'"; failed; return; }
  [[ "$pvc_count_actual" -eq "$pvc_count" ]] || { debug "Expected $pvc_count PVCs, found: $pvc_count_actual"; failed; return; }

  debug "All verifications passed for task $TASK_NUMBER"
  solved
  return
}

# shellcheck disable=SC2329
verify_task7() {
  TASK_NUMBER="7"

  # Expected values
  local expected_host_path="/mnt/projects"
  local expected_requested_storage="2Gi"
  local expected_sub_path="project1"
  local expected_mount_path="/projects"
  local expected_image_prefix="nginx"

  # Step 1: Verify there is a PV that mounts /mnt/projects as hostPath path
  debug "Searching for PV with hostPath '$expected_host_path'"
  local pv_name
  pv_name=$(kubectl get pv -o json 2>/dev/null | jq -r --arg path "$expected_host_path" '.items[] | select(.spec.hostPath.path == $path) | .metadata.name') || { debug "Failed to get PV with hostPath '$expected_host_path'"; failed; return; }
  [[ -n "$pv_name" ]] || { debug "No PV found with hostPath '$expected_host_path'"; failed; return; }

  local hostpath
  hostpath=$(kubectl get pv "$pv_name" -o json 2>/dev/null | jq -r '.spec.hostPath.path' 2>/dev/null) || { debug "Failed to get hostPath for PV '$pv_name'"; failed; return; }
  [[ "$hostpath" == "$expected_host_path" ]] || { debug "Expected hostPath: $expected_host_path, found: $hostpath"; failed; return; }

  # Step 2: Verify if there is a PVC that uses that PV and requests 2Gi of storage
  debug "Searching for PVC using PV '$pv_name' and requesting '$expected_requested_storage'"
  local pvc_name
  pvc_name=$(kubectl get pvc -o json 2>/dev/null | jq -r --arg pv_name "$pv_name" --arg requested_storage "$expected_requested_storage" '.items[] | select(.spec.volumeName == $pv_name and .spec.resources.requests.storage == $requested_storage) | .metadata.name') || { debug "Failed to get PVC using PV '$pv_name'"; failed; return; }
  [[ -n "$pvc_name" ]] || { debug "No PVC found using PV '$pv_name' with requested storage '$expected_requested_storage'"; failed; return; }

  local requested_storage
  requested_storage=$(kubectl get pvc "$pvc_name" -o json 2>/dev/null | jq -r '.spec.resources.requests.storage' 2>/dev/null) || { debug "Failed to get requested storage for PVC '$pvc_name'"; failed; return; }
  [[ "$requested_storage" == "$expected_requested_storage" ]] || { debug "Expected PVC requested storage: $expected_requested_storage, found: $requested_storage"; failed; return; }

  # Step 3: Verify if there's a pod using that PVC and fulfills the requirements
  debug "Searching for pod using PVC '$pvc_name'"
  local pod_name
  pod_name=$(kubectl get pod -o json 2>/dev/null | jq -r --arg pvc_name "$pvc_name" '.items[] | select(.spec.volumes[]?.persistentVolumeClaim?.claimName == $pvc_name) | .metadata.name') || { debug "Failed to get pod using PVC '$pvc_name'"; failed; return; }
  [[ -n "$pod_name" ]] || { debug "No pod found using PVC '$pvc_name'"; failed; return; }

  debug "Verifying subPath and mountPath in pod '$pod_name'"
  local subpath
  subpath=$(kubectl get pod "$pod_name" -o json 2>/dev/null | jq -r --arg mount_path "$expected_mount_path" '.spec.containers[0].volumeMounts[] | select(.mountPath == $mount_path) | .subPath' 2>/dev/null) || { debug "Failed to get subPath for mountPath '$expected_mount_path' in pod '$pod_name'"; failed; return; }
  [[ "$subpath" == "$expected_sub_path" ]] || { debug "Expected subPath: $expected_sub_path, found: $subpath"; failed; return; }

  debug "Verifying container image in pod '$pod_name'"
  local image
  image=$(kubectl get pod "$pod_name" -o json 2>/dev/null | jq -r '.spec.containers[0].image' 2>/dev/null) || { debug "Failed to get image for pod '$pod_name'"; failed; return; }
  [[ "$image" == "$expected_image_prefix"* ]] || { debug "Expected image prefix: $expected_image_prefix, found: $image"; failed; return; }

  # Step 4: Verify there are files created inside the /mnt/projects folder in the container
  debug "Checking for files in '$expected_mount_path' inside pod '$pod_name'"
  local created_files
  created_files=$(kubectl exec "$pod_name" -- bash -c "ls $expected_mount_path" 2>/dev/null) || { debug "Failed to list files in '$expected_mount_path' inside pod '$pod_name'"; failed; return; }
  [[ -n "$created_files" ]] || { debug "No files found in '$expected_mount_path' inside pod '$pod_name'"; failed; return; }

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
)
run_verification VERIFY_TASK_FUNCTIONS "$@"

exit 0
