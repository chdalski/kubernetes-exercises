#!/bin/bash

# shellcheck source=../../.scripts/verify.sh
source "$(git rev-parse --show-toplevel)/.scripts/verify.sh"

# shellcheck disable=SC2329
verify_task1() {
  TASK_NUMBER="1"
  local namespace="task1"
  local pod_name="nginx"
  local expected_status="Running"
  local expected_image="nginx:1.21"

  # Retrieve the pod JSON once
  debug "Retrieving JSON for pod '$pod_name' in namespace '$namespace'."
  local pod_json
  pod_json="$(kubectl get pod "$pod_name" -n "$namespace" -o json 2>/dev/null)" || {
    debug "Failed to retrieve pod '$pod_name' in namespace '$namespace'."
    failed
    return
  }

  # Check if the pod is running
  debug "Checking if pod '$pod_name' is in status '$expected_status'."
  local rs_status_phase
  rs_status_phase="$(echo "$pod_json" | jq -r '.status.phase // empty' 2>/dev/null)" || {
    debug "Failed to extract status.phase from pod JSON."
    failed
    return
  }
  if [ "$rs_status_phase" != "$expected_status" ]; then
    debug "Pod status mismatch. Expected '$expected_status', found '$rs_status_phase'."
    failed
    return
  fi

  # Check the image of the container
  debug "Checking if pod '$pod_name' uses image '$expected_image'."
  local rs_image
  rs_image="$(echo "$pod_json" | jq -r '.spec.containers[0].image // empty' 2>/dev/null)" || {
    debug "Failed to extract container image from pod JSON."
    failed
    return
  }
  if [ "$rs_image" != "$expected_image" ]; then
    debug "Pod image mismatch. Expected '$expected_image', found '$rs_image'."
    failed
    return
  fi

  debug "Pod '$pod_name' is running and uses the correct image. Verification successful."
  solved
  return
}

# shellcheck disable=SC2329
verify_task2() {
  TASK_NUMBER="2"
  local namespace="task2"
  local pod_name="nginx"
  local expected_image="nginx:1.21"
  local label_key="exposed"
  local expected_label_value="true"
  local expected_port="80"
  local service_name="nginx"

  # Retrieve the Pod JSON once
  debug "Retrieving JSON for pod '$pod_name' in namespace '$namespace'."
  local pod_json
  pod_json="$(kubectl get pod "$pod_name" -n "$namespace" -o json 2>/dev/null)" || {
    debug "Failed to retrieve pod '$pod_name' in namespace '$namespace'."
    failed
    return
  }

  # Check the Pod status (should be "Running")
  debug "Checking if pod '$pod_name' is in status 'Running'."
  local rs_pod_status
  rs_pod_status="$(echo "$pod_json" | jq -r '.status.phase // empty' 2>/dev/null)" || {
    debug "Failed to extract status.phase from pod JSON."
    failed
    return
  }
  if [[ "$rs_pod_status" != "Running" ]]; then
    debug "Pod status mismatch. Expected 'Running', found '$rs_pod_status'."
    failed
    return
  fi

  # Check the image of the container
  debug "Checking if pod '$pod_name' uses image '$expected_image'."
  local rs_pod_image
  rs_pod_image="$(echo "$pod_json" | jq -r '.spec.containers[0].image // empty' 2>/dev/null)" || {
    debug "Failed to extract container image from pod JSON."
    failed
    return
  }
  if [[ "$rs_pod_image" != "$expected_image" ]]; then
    debug "Pod image mismatch. Expected '$expected_image', found '$rs_pod_image'."
    failed
    return
  fi

  # Check if the Pod has the correct label
  debug "Checking if pod '$pod_name' has label '$label_key' with value '$expected_label_value'."
  local rs_pod_label
  rs_pod_label="$(echo "$pod_json" | jq -r --arg key "$label_key" '.metadata.labels[$key] // empty' 2>/dev/null)" || {
    debug "Failed to extract label '$label_key' from pod JSON."
    failed
    return
  }
  if [[ "$rs_pod_label" != "$expected_label_value" ]]; then
    debug "Pod label mismatch. Expected '$expected_label_value', found '$rs_pod_label'."
    failed
    return
  fi

  # Check if the Pod exposes the correct container port
  debug "Checking if pod '$pod_name' exposes container port '$expected_port'."
  local rs_container_port
  rs_container_port="$(echo "$pod_json" | jq -r '.spec.containers[0].ports[0].containerPort // empty' 2>/dev/null)" || {
    debug "Failed to extract container port from pod JSON."
    failed
    return
  }
  if [[ "$rs_container_port" != "$expected_port" ]]; then
    debug "Pod container port mismatch. Expected '$expected_port', found '$rs_container_port'."
    failed
    return
  fi

  # Retrieve the Service JSON once
  debug "Retrieving JSON for service '$service_name' in namespace '$namespace'."
  local svc_json
  svc_json="$(kubectl get svc "$service_name" -n "$namespace" -o json 2>/dev/null)" || {
    debug "Failed to retrieve service '$service_name' in namespace '$namespace'."
    failed
    return
  }

  # Check if the Service targets the correct Pod by the same label (selector)
  debug "Checking if service '$service_name' selector '$label_key' matches value '$expected_label_value'."
  local rs_service_selector
  rs_service_selector="$(echo "$svc_json" | jq -r --arg key "$label_key" '.spec.selector[$key] // empty' 2>/dev/null)" || {
    debug "Failed to extract selector '$label_key' from service JSON."
    failed
    return
  }
  if [[ "$rs_service_selector" != "$expected_label_value" ]]; then
    debug "Service selector mismatch. Expected '$expected_label_value', found '$rs_service_selector'."
    failed
    return
  fi

  # Check if the Service exposes the correct port
  debug "Checking if service '$service_name' exposes port '$expected_port'."
  local rs_service_port
  rs_service_port="$(echo "$svc_json" | jq -r '.spec.ports[0].port // empty' 2>/dev/null)" || {
    debug "Failed to extract service port from service JSON."
    failed
    return
  }
  if [[ "$rs_service_port" != "$expected_port" ]]; then
    debug "Service port mismatch. Expected '$expected_port', found '$rs_service_port'."
    failed
    return
  fi

  debug "Pod and service verification successful."
  solved
  return
}

# shellcheck disable=SC2329
verify_task3() {
  TASK_NUMBER="3"
  local file="busybox-env.txt"
  local expected_pod_name="pod/busybox"
  local expected_image='image "busybox:1.37.0"'
  local expected_deletion='pod "busybox" deleted'

  # Check if the expected file exists
  debug "Checking if file '$file' exists."
  [ -f "$file" ] || {
    debug "File '$file' does not exist. Expected file to be present."
    failed
    return
  }

  # Retrieve events from the default namespace
  debug "Retrieving events from namespace 'default'."
  local events
  events="$(kubectl get events -n default 2>/dev/null)" || {
    debug "Failed to retrieve events from namespace 'default'."
    failed
    return
  }

  # Check for the pod name in events
  debug "Checking if events contain pod name '$expected_pod_name'."
  echo "$events" | grep -q "$expected_pod_name" || {
    debug "Event for pod name '$expected_pod_name' not found in events."
    failed
    return
  }

  # Check for the image in events
  debug "Checking if events contain image '$expected_image'."
  echo "$events" | grep -q "$expected_image" || {
    debug "Event for image '$expected_image' not found in events."
    failed
    return
  }

  # Check for the deletion message in the file
  debug "Checking if the last line of '$file' indicates pod deletion."
  local last_line
  last_line="$(tail -1 < "$file" 2>/dev/null)" || {
    debug "Failed to read last line from file '$file'."
    failed
    return
  }
  if [[ "$last_line" != "$expected_deletion" ]]; then
    debug "Pod deletion message mismatch. Expected '$expected_deletion', found '$last_line'."
    failed
    return
  fi

  debug "All checks for pod events and deletion message passed. Verification successful."
  solved
  return
}

# shellcheck disable=SC2329
verify_task4() {
  TASK_NUMBER="4"
  local namespace="default"
  local pod_name="envpod"
  local expected_container_name="ckadenv"
  local expected_image="nginx"
  local expected_env_name="CKAD"
  local expected_env_value="task4"

  # Retrieve the pod JSON once
  debug "Retrieving JSON for pod '$pod_name' in namespace '$namespace'."
  local pod_json
  pod_json="$(kubectl get pod "$pod_name" -n "$namespace" -o json 2>/dev/null)" || {
    debug "Failed to retrieve pod '$pod_name' in namespace '$namespace'."
    failed
    return
  }

  # Check container name
  debug "Checking if the container name is '$expected_container_name'."
  local rs_container_name
  rs_container_name="$(echo "$pod_json" | jq -r '.spec.containers[0].name // empty' 2>/dev/null)" || {
    debug "Failed to extract container name from pod JSON."
    failed
    return
  }
  if [[ "$rs_container_name" != "$expected_container_name" ]]; then
    debug "Container name mismatch. Expected '$expected_container_name', found '$rs_container_name'."
    failed
    return
  fi

  # Check container image
  debug "Checking if the container image is '$expected_image'."
  local rs_image
  rs_image="$(echo "$pod_json" | jq -r '.spec.containers[0].image // empty' 2>/dev/null)" || {
    debug "Failed to extract container image from pod JSON."
    failed
    return
  }
  if [[ "$rs_image" != "$expected_image" ]]; then
    debug "Container image mismatch. Expected '$expected_image', found '$rs_image'."
    failed
    return
  fi

  # Check environment variable
  debug "Checking if the environment variable '$expected_env_name' is set to '$expected_env_value'."
  local rs_env_value
  rs_env_value="$(echo "$pod_json" | jq -r --arg name "$expected_env_name" '.spec.containers[0].env[] | select(.name == $name) | .value // empty' 2>/dev/null)" || {
    debug "Failed to extract environment variable '$expected_env_name' from pod JSON."
    failed
    return
  }
  if [[ "$rs_env_value" != "$expected_env_value" ]]; then
    debug "Environment variable '$expected_env_name' mismatch. Expected '$expected_env_value', found '$rs_env_value'."
    failed
    return
  fi

  debug "Pod '$pod_name' has the correct container name, image, and environment variable. Verification successful."
  solved
  return
}

# shellcheck disable=SC2329
verify_task5() {
  TASK_NUMBER="5"
  local pod_name="task5-app"
  local expected_container_name="busybox"
  local expected_image="busybox"
  local expected_config_map="app-config"
  local expected_restart_policy="Always"
  local expected_command='["/bin/sh","-c","sleep 7200"]'

  # Retrieve the pod JSON once
  debug "Retrieving JSON for pod '$pod_name'."
  local pod_json
  pod_json="$(kubectl get pod "$pod_name" -o json 2>/dev/null)" || {
    debug "Failed to retrieve pod '$pod_name'."
    failed
    return
  }

  # Check the container name
  debug "Checking if the container name is '$expected_container_name'."
  local rs_container_name
  rs_container_name="$(echo "$pod_json" | jq -r '.spec.containers[0].name // empty' 2>/dev/null)" || {
    debug "Failed to extract container name from pod JSON."
    failed
    return
  }
  if [ "$rs_container_name" != "$expected_container_name" ]; then
    debug "Container name mismatch. Expected '$expected_container_name', found '$rs_container_name'."
    failed
    return
  fi

  # Check the container image
  debug "Checking if the container image is '$expected_image'."
  local rs_image
  rs_image="$(echo "$pod_json" | jq -r '.spec.containers[0].image // empty' 2>/dev/null)" || {
    debug "Failed to extract container image from pod JSON."
    failed
    return
  }
  if [ "$rs_image" != "$expected_image" ]; then
    debug "Container image mismatch. Expected '$expected_image', found '$rs_image'."
    failed
    return
  fi

  # Verify the environment variables are loaded from the ConfigMap
  debug "Checking if environment variables are loaded from ConfigMap '$expected_config_map'."
  local rs_env_source
  rs_env_source="$(echo "$pod_json" | jq -r '.spec.containers[0].envFrom[0].configMapRef.name // empty' 2>/dev/null)" || {
    debug "Failed to extract envFrom configMapRef from pod JSON."
    failed
    return
  }
  if [ "$rs_env_source" != "$expected_config_map" ]; then
    debug "ConfigMap reference mismatch. Expected '$expected_config_map', found '$rs_env_source'."
    failed
    return
  fi

  # Verify the restart policy
  debug "Checking if restart policy is '$expected_restart_policy'."
  local rs_policy
  rs_policy="$(echo "$pod_json" | jq -r '.spec.restartPolicy // empty' 2>/dev/null)" || {
    debug "Failed to extract restart policy from pod JSON."
    failed
    return
  }
  if [ "$rs_policy" != "$expected_restart_policy" ]; then
    debug "Restart policy mismatch. Expected '$expected_restart_policy', found '$rs_policy'."
    failed
    return
  fi

  # Verify the command
  debug "Checking if the command is '$expected_command'."
  local rs_command
  rs_command="$(echo "$pod_json" | jq -c '.spec.containers[0].command // empty' 2>/dev/null)" || {
    debug "Failed to extract command from pod JSON."
    failed
    return
  }
  if [[ "$rs_command" != "$expected_command" ]]; then
    debug "Command mismatch. Expected '$expected_command', found '$rs_command'."
    failed
    return
  fi

  debug "Pod '$pod_name' has the correct container name, image, envFrom, restart policy, and command. Verification successful."
  solved
  return
}

# shellcheck disable=SC2329
verify_task6() {
  TASK_NUMBER="6"
  local namespace="task6"
  local pod_name="nginx-init"
  local init_container="busy-init"
  local main_container="nginx"
  local expected_init_image="busybox:1.37.0"
  local expected_main_image="nginx:1.21"
  local shared_volume="shared"
  local expected_init_mount="/data"
  local expected_main_mount="/usr/share/nginx/html"
  local expected_text="hello ckad"

  # Retrieve the pod JSON once
  debug "Retrieving JSON for pod '$pod_name' in namespace '$namespace'."
  local pod_json
  pod_json="$(kubectl get pod "$pod_name" -n "$namespace" -o json 2>/dev/null)" || {
    debug "Failed to retrieve pod '$pod_name' in namespace '$namespace'."
    failed
    return
  }

  # Check if init container exists with the correct image
  debug "Checking if init container '$init_container' exists with image '$expected_init_image'."
  local rs_init_image
  rs_init_image="$(echo "$pod_json" | jq -r --arg name "$init_container" '.spec.initContainers[] | select(.name == $name) | .image // empty' 2>/dev/null)" || {
    debug "Failed to extract init container image from pod JSON."
    failed
    return
  }
  if [[ "$rs_init_image" != "$expected_init_image" ]]; then
    debug "Init container image mismatch. Expected '$expected_init_image', found '$rs_init_image'."
    failed
    return
  fi

  # Check if main container exists with the correct image
  debug "Checking if main container '$main_container' exists with image '$expected_main_image'."
  local rs_main_image
  rs_main_image="$(echo "$pod_json" | jq -r --arg name "$main_container" '.spec.containers[] | select(.name == $name) | .image // empty' 2>/dev/null)" || {
    debug "Failed to extract main container image from pod JSON."
    failed
    return
  }
  if [[ "$rs_main_image" != "$expected_main_image" ]]; then
    debug "Main container image mismatch. Expected '$expected_main_image', found '$rs_main_image'."
    failed
    return
  fi

  # Check if the shared volume is mounted in the init container
  debug "Checking if shared volume '$shared_volume' is mounted at '$expected_init_mount' in init container."
  local rs_init_mount
  rs_init_mount="$(echo "$pod_json" | jq -r --arg name "$init_container" --arg vol "$shared_volume" '.spec.initContainers[] | select(.name == $name) | .volumeMounts[] | select(.name == $vol) | .mountPath // empty' 2>/dev/null)" || {
    debug "Failed to extract init container volume mount from pod JSON."
    failed
    return
  }
  if [[ "$rs_init_mount" != "$expected_init_mount" ]]; then
    debug "Init container volume mount mismatch. Expected '$expected_init_mount', found '$rs_init_mount'."
    failed
    return
  fi

  # Check if the shared volume is mounted in the main container
  debug "Checking if shared volume '$shared_volume' is mounted at '$expected_main_mount' in main container."
  local rs_main_mount
  rs_main_mount="$(echo "$pod_json" | jq -r --arg name "$main_container" --arg vol "$shared_volume" '.spec.containers[] | select(.name == $name) | .volumeMounts[] | select(.name == $vol) | .mountPath // empty' 2>/dev/null)" || {
    debug "Failed to extract main container volume mount from pod JSON."
    failed
    return
  }
  if [[ "$rs_main_mount" != "$expected_main_mount" ]]; then
    debug "Main container volume mount mismatch. Expected '$expected_main_mount', found '$rs_main_mount'."
    failed
    return
  fi

  # Check if the expected content is written to shared volume by the init container
  debug "Checking if the expected content is present in the shared volume."
  local actual_text
  actual_text="$(kubectl exec -n "$namespace" "$pod_name" -c "$main_container" -- cat "$expected_main_mount/index.html" 2>/dev/null)" || {
    debug "Failed to read content from '$expected_main_mount/index.html' in main container."
    failed
    return
  }
  if [[ "$actual_text" != "$expected_text" ]]; then
    debug "Content mismatch in shared volume. Expected '$expected_text', found '$actual_text'."
    failed
    return
  fi

  debug "Pod '$pod_name' has correct init/main containers, images, volume mounts, and shared content. Verification successful."
  solved
  return
}

# shellcheck disable=SC2329
verify_task7() {
  TASK_NUMBER="7"
  local namespace="default"
  local pod_name="log-processor"
  local sidecar_name="log-forwarder"
  local main_container_name="app"
  local expected_restart_policy="Always"

  # Retrieve the pod JSON once
  debug "Retrieving JSON for pod '$pod_name' in namespace '$namespace'."
  local pod_json
  pod_json="$(kubectl get pod "$pod_name" -n "$namespace" -o json 2>/dev/null)" || {
    debug "Failed to retrieve pod '$pod_name' in namespace '$namespace'."
    failed
    return
  }

  # Verify the initContainer is defined
  debug "Checking if initContainer '$sidecar_name' is defined."
  local rs_init_defined
  rs_init_defined="$(echo "$pod_json" | jq -r --arg name "$sidecar_name" '.spec.initContainers[]? | select(.name == $name) | .name' 2>/dev/null)" || {
    debug "Failed to extract initContainer '$sidecar_name' from pod JSON."
    failed
    return
  }
  if [[ "$rs_init_defined" != "$sidecar_name" ]]; then
    debug "InitContainer '$sidecar_name' not found in pod spec."
    failed
    return
  fi

  # Verify the initContainer has restartPolicy: Always
  debug "Checking if initContainer '$sidecar_name' has restartPolicy '$expected_restart_policy'."
  local rs_restart_policy
  rs_restart_policy="$(echo "$pod_json" | jq -r --arg name "$sidecar_name" '.spec.initContainers[]? | select(.name == $name) | .restartPolicy // empty' 2>/dev/null)" || {
    debug "Failed to extract restartPolicy for initContainer '$sidecar_name' from pod JSON."
    failed
    return
  }
  if [[ "$rs_restart_policy" != "$expected_restart_policy" ]]; then
    debug "InitContainer '$sidecar_name' restartPolicy mismatch. Expected '$expected_restart_policy', found '$rs_restart_policy'."
    failed
    return
  fi

  # Verify the initContainer is running
  debug "Checking if initContainer '$sidecar_name' is running."
  local rs_init_running
  rs_init_running="$(echo "$pod_json" | jq -r --arg name "$sidecar_name" '.status.initContainerStatuses[]? | select(.name == $name) | .state.running' 2>/dev/null)" || {
    debug "Failed to extract running state for initContainer '$sidecar_name' from pod JSON."
    failed
    return
  }
  if [[ -z "$rs_init_running" || "$rs_init_running" == "null" ]]; then
    debug "InitContainer '$sidecar_name' is not running."
    failed
    return
  fi

  # Verify the main container is running
  debug "Checking if main container '$main_container_name' is running."
  local rs_main_running
  rs_main_running="$(echo "$pod_json" | jq -r --arg name "$main_container_name" '.status.containerStatuses[]? | select(.name == $name) | .state.running' 2>/dev/null)" || {
    debug "Failed to extract running state for main container '$main_container_name' from pod JSON."
    failed
    return
  }
  if [[ -z "$rs_main_running" || "$rs_main_running" == "null" ]]; then
    debug "Main container '$main_container_name' is not running."
    failed
    return
  fi

  # Validate logs from the main container
  debug "Validating logs from main container '$main_container_name'."
  kubectl logs "$pod_name" -n "$namespace" -c "$main_container_name" --tail=5 > /dev/null 2>&1 || {
    debug "Failed to retrieve logs from main container '$main_container_name'."
    failed
    return
  }

  # Validate logs from the initContainer (sidecar)
  debug "Validating logs from initContainer '$sidecar_name'."
  kubectl logs "$pod_name" -n "$namespace" -c "$sidecar_name" --tail=5 > /dev/null 2>&1 || {
    debug "Failed to retrieve logs from initContainer '$sidecar_name'."
    failed
    return
  }

  debug "Pod '$pod_name' has initContainer sidecar with restartPolicy: Always, both containers running, and logs accessible. Verification successful."
  solved
  return
}

# shellcheck disable=SC2329
verify_task8() {
  TASK_NUMBER="8"
  local namespace="task8"
  local pod_name="liveness-exec"
  local expected_cmd="/bin/sh -c rm -rf /tmp/healthy; sleep 15; touch /tmp/healthy; sleep 7200"
  local pod_age_threshold=15
  local initial_default=5
  local period_default=5
  local failure_threshold_default=1

  # Retrieve the pod JSON once
  debug "Retrieving JSON for pod '$pod_name' in namespace '$namespace'."
  local pod_json
  pod_json="$(kubectl get pod "$pod_name" -n "$namespace" -o=json 2>/dev/null)" || {
    debug "Failed to retrieve pod '$pod_name' in namespace '$namespace'."
    failed
    return
  }

  # Verify Restart Count is Zero
  debug "Checking if container restart count is zero."
  local rs_restart_count
  rs_restart_count="$(echo "$pod_json" | jq -r '.status.containerStatuses[0].restartCount // empty' 2>/dev/null)" || {
    debug "Failed to extract restart count from pod JSON."
    failed
    return
  }
  if [[ "$rs_restart_count" -ne 0 ]]; then
    debug "Restart count is not zero. Found '$rs_restart_count'."
    failed
    return
  fi

  # Check Pod Age
  debug "Checking if pod age is at least '$pod_age_threshold' seconds."
  local rs_pod_start_time
  rs_pod_start_time="$(echo "$pod_json" | jq -r '.status.startTime // empty' 2>/dev/null)" || {
    debug "Failed to extract pod startTime from pod JSON."
    failed
    return
  }
  local rs_pod_age
  rs_pod_age=$(( $(date +%s) - $(date -d "$rs_pod_start_time" +%s) ))
  if [[ "$rs_pod_age" -lt "$pod_age_threshold" ]]; then
    debug "Pod age is less than threshold. Age: '$rs_pod_age', Threshold: '$pod_age_threshold'."
    failed
    return
  fi

  # Verify Pod Command
  debug "Checking if pod command match expected."
  local rs_cmd_actual
  rs_cmd_actual="$(echo "$pod_json" | jq -r '.spec.containers[0].command | join(" ")' 2>/dev/null)" || {
    debug "Failed to extract pod command from pod JSON."
    failed
    return
  }
  if [[ "$rs_cmd_actual" != "$expected_cmd" ]]; then
    debug "Pod command mismatch. Expected: '$expected_cmd', Found: '$rs_cmd_actual'"
    failed
    return
  fi

  # Verify Liveness Probe Configuration Has Been Changed
  debug "Checking if livenessProbe configuration has been changed from defaults."
  local rs_initial_delay
  local rs_period
  local rs_failure_threshold
  rs_initial_delay="$(echo "$pod_json" | jq -r '.spec.containers[0].livenessProbe.initialDelaySeconds // empty' 2>/dev/null)" || {
    debug "Failed to extract livenessProbe.initialDelaySeconds from pod JSON."
    failed
    return
  }
  rs_period="$(echo "$pod_json" | jq -r '.spec.containers[0].livenessProbe.periodSeconds // empty' 2>/dev/null)" || {
    debug "Failed to extract livenessProbe.periodSeconds from pod JSON."
    failed
    return
  }
  rs_failure_threshold="$(echo "$pod_json" | jq -r '.spec.containers[0].livenessProbe.failureThreshold // empty' 2>/dev/null)" || {
    debug "Failed to extract livenessProbe.failureThreshold from pod JSON."
    failed
    return
  }
  if [[ "$rs_initial_delay" -eq "$initial_default" && "$rs_period" -eq "$period_default" && "$rs_failure_threshold" -eq "$failure_threshold_default" ]]; then
    debug "Liveness probe configuration has not been changed from defaults."
    failed
    return
  fi

  debug "Pod '$pod_name' in namespace '$namespace' meets all verification criteria. Verification successful."
  solved
  return
}

# shellcheck disable=SC2329
verify_task9() {
  TASK_NUMBER="9"
  local pod_name="nginx-health"
  local namespace="default"
  local expected_image="nginx:1.21"
  local expected_configmap="nginx-health"
  local expected_readiness_path="/healthz"
  local expected_readiness_port="80"
  local expected_initial_delay="3"
  local expected_period="5"

  # Check if the Pod exists and retrieve its JSON
  debug "Retrieving JSON for pod '$pod_name' in namespace '$namespace'."
  local pod_json
  pod_json="$(kubectl get pod "$pod_name" -n "$namespace" -o json 2>/dev/null)" || {
    debug "Failed to retrieve pod '$pod_name' in namespace '$namespace'."
    failed
    return
  }

  # Verify the container image
  debug "Checking if container image is '$expected_image'."
  local rs_container_image
  rs_container_image="$(echo "$pod_json" | jq -r '.spec.containers[0].image // empty' 2>/dev/null)" || {
    debug "Failed to extract container image from pod JSON."
    failed
    return
  }
  if [[ "$rs_container_image" != "$expected_image" ]]; then
    debug "Container image mismatch. Expected '$expected_image', found '$rs_container_image'."
    failed
    return
  fi

  # Verify the mounted ConfigMap
  debug "Checking if ConfigMap '$expected_configmap' is mounted."
  local rs_mounted_config
  rs_mounted_config="$(echo "$pod_json" | jq -r --arg name "$expected_configmap" '.spec.volumes[]? | select(.configMap.name == $name) | .configMap.name' 2>/dev/null)" || {
    debug "Failed to extract mounted ConfigMap from pod JSON."
    failed
    return
  }
  if [[ "$rs_mounted_config" != "$expected_configmap" ]]; then
    debug "Mounted ConfigMap mismatch. Expected '$expected_configmap', found '$rs_mounted_config'."
    failed
    return
  fi

  # Verify the readiness probe path, port, and timing
  debug "Checking readiness probe configuration."
  local rs_readiness_path
  rs_readiness_path="$(echo "$pod_json" | jq -r '.spec.containers[0].readinessProbe.httpGet.path // empty' 2>/dev/null)" || {
    debug "Failed to extract readinessProbe.httpGet.path from pod JSON."
    failed
    return
  }
  local rs_readiness_port
  rs_readiness_port="$(echo "$pod_json" | jq -r '.spec.containers[0].readinessProbe.httpGet.port // empty' 2>/dev/null)" || {
    debug "Failed to extract readinessProbe.httpGet.port from pod JSON."
    failed
    return
  }
  local rs_readiness_initial_delay
  rs_readiness_initial_delay="$(echo "$pod_json" | jq -r '.spec.containers[0].readinessProbe.initialDelaySeconds // empty' 2>/dev/null)" || {
    debug "Failed to extract readinessProbe.initialDelaySeconds from pod JSON."
    failed
    return
  }
  local rs_readiness_period
  rs_readiness_period="$(echo "$pod_json" | jq -r '.spec.containers[0].readinessProbe.periodSeconds // empty' 2>/dev/null)" || {
    debug "Failed to extract readinessProbe.periodSeconds from pod JSON."
    failed
    return
  }

  if [[ "$rs_readiness_path" != "$expected_readiness_path" ]]; then
    debug "Readiness probe path mismatch. Expected '$expected_readiness_path', found '$rs_readiness_path'."
    failed
    return
  fi
  if [[ "$rs_readiness_port" != "$expected_readiness_port" ]]; then
    debug "Readiness probe port mismatch. Expected '$expected_readiness_port', found '$rs_readiness_port'."
    failed
    return
  fi
  if [[ "$rs_readiness_initial_delay" != "$expected_initial_delay" ]]; then
    debug "Readiness probe initialDelaySeconds mismatch. Expected '$expected_initial_delay', found '$rs_readiness_initial_delay'."
    failed
    return
  fi
  if [[ "$rs_readiness_period" != "$expected_period" ]]; then
    debug "Readiness probe periodSeconds mismatch. Expected '$expected_period', found '$rs_readiness_period'."
    failed
    return
  fi

  debug "Pod '$pod_name' in namespace '$namespace' meets all verification criteria. Verification successful."
  solved
  return
}

# shellcheck disable=SC2329
verify_task10() {
  TASK_NUMBER="10"
  local namespace="task10"
  local pod_name="help-me"
  local expected_status="Running"
  local expected_image_prefix="nginx:"

  # Retrieve the pod JSON once
  debug "Retrieving JSON for pod '$pod_name' in namespace '$namespace'."
  local pod_json
  pod_json="$(kubectl get pod "$pod_name" -n "$namespace" -o json 2>/dev/null)" || {
    debug "Failed to retrieve pod '$pod_name' in namespace '$namespace'."
    failed
    return
  }

  # Check the pod status
  debug "Checking if pod status is '$expected_status'."
  local rs_pod_status
  rs_pod_status="$(echo "$pod_json" | jq -r '.status.phase // empty' 2>/dev/null)" || {
    debug "Failed to extract pod status from pod JSON."
    failed
    return
  }
  if [[ "$rs_pod_status" != "$expected_status" ]]; then
    debug "Pod status mismatch. Expected '$expected_status', found '$rs_pod_status'."
    failed
    return
  fi

  # Check the image
  debug "Checking if container image starts with '$expected_image_prefix'."
  local rs_image
  rs_image="$(echo "$pod_json" | jq -r '.spec.containers[0].image // empty' 2>/dev/null)" || {
    debug "Failed to extract container image from pod JSON."
    failed
    return
  }
  if [[ "$rs_image" != $expected_image_prefix* ]]; then
    debug "Container image mismatch. Expected prefix '$expected_image_prefix', found '$rs_image'."
    failed
    return
  fi

  debug "Pod '$pod_name' in namespace '$namespace' is running and uses an image with prefix '$expected_image_prefix'. Verification successful."
  solved
  return
}

# shellcheck disable=SC2329
verify_task11() {
  TASK_NUMBER="11"
  local namespace="limits"
  local pod_name="resource-pod"
  local expected_image="nginx:1.29.0"
  local expected_restart_policy="Never"
  local expected_request_cpu="100m"
  local expected_request_memory="128Mi"
  local expected_limit_cpu="200m"
  local expected_limit_memory="256Mi"

  # Check if the pod exists and retrieve its JSON
  debug "Retrieving JSON for pod '$pod_name' in namespace '$namespace'."
  local pod_json
  pod_json="$(kubectl get pod "$pod_name" -n "$namespace" -o json 2>/dev/null)" || {
    debug "Pod '$pod_name' does not exist in namespace '$namespace'."
    failed
    return
  }

  # Check image
  debug "Checking if container image is '$expected_image'."
  local rs_image
  rs_image="$(echo "$pod_json" | jq -r '.spec.containers[0].image // empty' 2>/dev/null)" || {
    debug "Failed to extract container image from pod JSON."
    failed
    return
  }
  if [ "$rs_image" != "$expected_image" ]; then
    debug "Container image mismatch. Expected '$expected_image', found '$rs_image'."
    failed
    return
  fi

  # Check restart policy
  debug "Checking if restart policy is '$expected_restart_policy'."
  local rs_restart_policy
  rs_restart_policy="$(echo "$pod_json" | jq -r '.spec.restartPolicy // empty' 2>/dev/null)" || {
    debug "Failed to extract restart policy from pod JSON."
    failed
    return
  }
  if [ "$rs_restart_policy" != "$expected_restart_policy" ]; then
    debug "Restart policy mismatch. Expected '$expected_restart_policy', found '$rs_restart_policy'."
    failed
    return
  fi

  # Check resource requests
  debug "Checking resource requests for CPU and memory."
  local rs_request_cpu
  local rs_request_memory
  rs_request_cpu="$(echo "$pod_json" | jq -r '.spec.containers[0].resources.requests.cpu // empty' 2>/dev/null)" || {
    debug "Failed to extract CPU request from pod JSON."
    failed
    return
  }
  rs_request_memory="$(echo "$pod_json" | jq -r '.spec.containers[0].resources.requests.memory // empty' 2>/dev/null)" || {
    debug "Failed to extract memory request from pod JSON."
    failed
    return
  }
  if [ "$rs_request_cpu" != "$expected_request_cpu" ]; then
    debug "CPU request mismatch. Expected '$expected_request_cpu', found '$rs_request_cpu'."
    failed
    return
  fi
  if [ "$rs_request_memory" != "$expected_request_memory" ]; then
    debug "Memory request mismatch. Expected '$expected_request_memory', found '$rs_request_memory'."
    failed
    return
  fi

  # Check resource limits
  debug "Checking resource limits for CPU and memory."
  local rs_limit_cpu
  local rs_limit_memory
  rs_limit_cpu="$(echo "$pod_json" | jq -r '.spec.containers[0].resources.limits.cpu // empty' 2>/dev/null)" || {
    debug "Failed to extract CPU limit from pod JSON."
    failed
    return
  }
  rs_limit_memory="$(echo "$pod_json" | jq -r '.spec.containers[0].resources.limits.memory // empty' 2>/dev/null)" || {
    debug "Failed to extract memory limit from pod JSON."
    failed
    return
  }
  if [ "$rs_limit_cpu" != "$expected_limit_cpu" ]; then
    debug "CPU limit mismatch. Expected '$expected_limit_cpu', found '$rs_limit_cpu'."
    failed
    return
  fi
  if [ "$rs_limit_memory" != "$expected_limit_memory" ]; then
    debug "Memory limit mismatch. Expected '$expected_limit_memory', found '$rs_limit_memory'."
    failed
    return
  fi

  debug "Pod '$pod_name' in namespace '$namespace' meets all verification criteria. Verification successful."
  solved
  return
}

# shellcheck disable=SC2329
verify_task12() {
  TASK_NUMBER="12"
  local namespace="limits"
  local limit_range_name="cpu-limit"
  local pod_name="resource-pod2"

  # Check if there is exactly one LimitRange in the namespace
  debug "Checking if there is exactly one LimitRange in namespace '$namespace'."
  local limit_ranges_count
  limit_ranges_count="$(kubectl get limitranges -n "$namespace" --no-headers 2>/dev/null | wc -l)" || {
    debug "Failed to count LimitRanges in namespace '$namespace'."
    failed
    return
  }
  if [ "$limit_ranges_count" -ne 1 ]; then
    debug "Expected exactly one LimitRange in namespace '$namespace', found '$limit_ranges_count'."
    failed
    return
  fi

  # Get the LimitRange JSON
  debug "Retrieving LimitRange '$limit_range_name' in namespace '$namespace'."
  local lr_json
  lr_json="$(kubectl get limitranges -n "$namespace" "$limit_range_name" -o json 2>/dev/null)" || {
    debug "Failed to retrieve LimitRange '$limit_range_name' in namespace '$namespace'."
    failed
    return
  }

  # Extract min/max CPU and memory
  debug "Extracting min/max CPU and memory from LimitRange."
  local max_cpu max_memory min_cpu min_memory
  max_cpu="$(echo "$lr_json" | jq -r '.spec.limits[0].max.cpu // empty' 2>/dev/null)" || {
    debug "Failed to extract max.cpu from LimitRange JSON."
    failed
    return
  }
  max_memory="$(echo "$lr_json" | jq -r '.spec.limits[0].max.memory // empty' 2>/dev/null)" || {
    debug "Failed to extract max.memory from LimitRange JSON."
    failed
    return
  }
  min_cpu="$(echo "$lr_json" | jq -r '.spec.limits[0].min.cpu // empty' 2>/dev/null)" || {
    debug "Failed to extract min.cpu from LimitRange JSON."
    failed
    return
  }
  min_memory="$(echo "$lr_json" | jq -r '.spec.limits[0].min.memory // empty' 2>/dev/null)" || {
    debug "Failed to extract min.memory from LimitRange JSON."
    failed
    return
  }

  # Retrieve the pod JSON once
  debug "Retrieving JSON for pod '$pod_name' in namespace '$namespace'."
  local pod_json
  pod_json="$(kubectl get pod "$pod_name" -n "$namespace" -o json 2>/dev/null)" || {
    debug "Pod '$pod_name' does not exist in namespace '$namespace'."
    failed
    return
  }

  # Extract pod's resource limits
  debug "Extracting pod's resource limits."
  local pod_cpu pod_memory
  pod_cpu="$(echo "$pod_json" | jq -r '.spec.containers[0].resources.limits.cpu // empty' 2>/dev/null)" || {
    debug "Failed to extract pod CPU limit from pod JSON."
    failed
    return
  }
  pod_memory="$(echo "$pod_json" | jq -r '.spec.containers[0].resources.limits.memory // empty' 2>/dev/null)" || {
    debug "Failed to extract pod memory limit from pod JSON."
    failed
    return
  }

  # Verify CPU limits
  debug "Verifying pod CPU limits against LimitRange."
  if [[ -n "$max_cpu" && "$pod_cpu" > "$max_cpu" ]]; then
    debug "Pod CPU limit '$pod_cpu' exceeds LimitRange max '$max_cpu'."
    failed
    return
  fi
  if [[ -n "$min_cpu" && "$pod_cpu" < "$min_cpu" ]]; then
    debug "Pod CPU limit '$pod_cpu' is below LimitRange min '$min_cpu'."
    failed
    return
  fi

  # Verify Memory limits
  debug "Verifying pod memory limits against LimitRange."
  if [[ -n "$max_memory" && "$pod_memory" > "$max_memory" ]]; then
    debug "Pod memory limit '$pod_memory' exceeds LimitRange max '$max_memory'."
    failed
    return
  fi
  if [[ -n "$min_memory" && "$pod_memory" < "$min_memory" ]]; then
    debug "Pod memory limit '$pod_memory' is below LimitRange min '$min_memory'."
    failed
    return
  fi

  # Check the pod status
  debug "Checking if pod '$pod_name' is running."
  local pod_status
  pod_status="$(echo "$pod_json" | jq -r '.status.phase // empty' 2>/dev/null)" || {
    debug "Failed to extract pod status from pod JSON."
    failed
    return
  }
  if [[ "$pod_status" != "Running" ]]; then
    debug "Pod status mismatch. Expected 'Running', found '$pod_status'."
    failed
    return
  fi

  debug "Pod '$pod_name' in namespace '$namespace' meets all LimitRange and status criteria. Verification successful."
  solved
  return
}

# shellcheck disable=SC2329
verify_task13() {
  TASK_NUMBER="13"
  local namespace="default"
  local pod_name="secret-logger"
  local expected_value="good job"
  local secret_name="task13-secret"

  # Check if the pod exists and retrieve its JSON
  debug "Retrieving JSON for pod '$pod_name' in namespace '$namespace'."
  local pod_json
  pod_json="$(kubectl get pod "$pod_name" -n "$namespace" -o json 2>/dev/null)" || {
    debug "Pod '$pod_name' does not exist in namespace '$namespace'."
    failed
    return
  }

  # Check if env or envFrom was used with the correct secret
  debug "Checking if env or envFrom is set to secret '$secret_name'."
  local rs_envfrom_secret
  rs_envfrom_secret="$(echo "$pod_json" | jq -r '.spec.containers[0].envFrom[0].secretRef.name // empty' 2>/dev/null)" || {
    debug "Failed to extract envFrom secretRef from pod JSON."
    failed
    return
  }
  local rs_env_secret
  rs_env_secret="$(echo "$pod_json" | jq -r '.spec.containers[0].env[0].valueFrom.secretKeyRef.name // empty' 2>/dev/null)" || {
    debug "Failed to extract env secretKeyRef from pod JSON."
    failed
    return
  }
  if [[ "$rs_envfrom_secret" != "$secret_name" && "$rs_env_secret" != "$secret_name" ]]; then
    debug "Neither envFrom nor env is set correctly to '$secret_name'. Found envFrom: '$rs_envfrom_secret', env: '$rs_env_secret'."
    failed
    return
  fi

  # Check the pod status
  debug "Checking if pod status is 'Succeeded'."
  local rs_pod_status
  rs_pod_status="$(echo "$pod_json" | jq -r '.status.phase // empty' 2>/dev/null)" || {
    debug "Failed to extract pod status from pod JSON."
    failed
    return
  }
  if [[ "$rs_pod_status" != "Succeeded" ]]; then
    debug "Pod status mismatch. Expected 'Succeeded', found '$rs_pod_status'."
    failed
    return
  fi

  # Fetch the pod logs and verify output
  debug "Fetching pod logs and verifying output."
  local pod_logs
  pod_logs="$(kubectl logs "$pod_name" -n "$namespace" 2>/dev/null)" || {
    debug "Failed to retrieve logs from pod '$pod_name'."
    failed
    return
  }
  if [[ "$pod_logs" != "$expected_value" ]]; then
    debug "Pod logs mismatch. Expected '$expected_value', found '$pod_logs'."
    failed
    return
  fi

  debug "Pod '$pod_name' in namespace '$namespace' meets all verification criteria. Verification successful."
  solved
  return
}

# shellcheck disable=SC2329
verify_task14() {
  TASK_NUMBER="14"
  local namespace="task14"
  local pod_name="selector"
  local label_key="tier"
  local label_value="backend"

  # Retrieve the pod JSON once
  debug "Retrieving JSON for pod '$pod_name' in namespace '$namespace'."
  local pod_json
  pod_json="$(kubectl get pod "$pod_name" -n "$namespace" -o json 2>/dev/null)" || {
    debug "Pod '$pod_name' does not exist in namespace '$namespace'."
    failed
    return
  }

  # Verify that the pod spec includes the correct nodeSelector
  debug "Checking if pod spec includes nodeSelector '$label_key: $label_value'."
  local rs_node_selector
  rs_node_selector="$(echo "$pod_json" | jq -r --arg key "$label_key" '.spec.nodeSelector[$key] // empty' 2>/dev/null)" || {
    debug "Failed to extract nodeSelector from pod JSON."
    failed
    return
  }
  if [[ "$rs_node_selector" != "$label_value" ]]; then
    debug "Pod nodeSelector mismatch. Expected '$label_value', found '$rs_node_selector'."
    failed
    return
  fi

  # Verify that the pod is properly scheduled to a node
  debug "Checking if pod is scheduled to a node."
  local rs_node_name
  rs_node_name="$(echo "$pod_json" | jq -r '.spec.nodeName // empty' 2>/dev/null)" || {
    debug "Failed to extract nodeName from pod JSON."
    failed
    return
  }
  if [[ -z "$rs_node_name" ]]; then
    debug "Pod is not scheduled to any node."
    failed
    return
  fi

  # Ensure the node has the correct label
  debug "Checking if node '$rs_node_name' has label '$label_key: $label_value'."
  local node_json
  node_json="$(kubectl get node "$rs_node_name" -o json 2>/dev/null)" || {
    debug "Failed to retrieve node '$rs_node_name'."
    failed
    return
  }
  local rs_node_label_value
  rs_node_label_value="$(echo "$node_json" | jq -r --arg key "$label_key" '.metadata.labels[$key] // empty' 2>/dev/null)" || {
    debug "Failed to extract label '$label_key' from node JSON."
    failed
    return
  }
  if [[ "$rs_node_label_value" != "$label_value" ]]; then
    debug "Node label mismatch. Expected '$label_value', found '$rs_node_label_value'."
    failed
    return
  fi

  # Ensure the pod is in running state
  debug "Checking if pod is in 'Running' state."
  local rs_pod_phase
  rs_pod_phase="$(echo "$pod_json" | jq -r '.status.phase // empty' 2>/dev/null)" || {
    debug "Failed to extract pod phase from pod JSON."
    failed
    return
  }
  if [[ "$rs_pod_phase" != "Running" ]]; then
    debug "Pod phase mismatch. Expected 'Running', found '$rs_pod_phase'."
    failed
    return
  fi

  debug "Pod '$pod_name' in namespace '$namespace' is scheduled to a node with correct label and is running. Verification successful."
  solved
  return
}

# shellcheck disable=SC2329
verify_task15() {
  TASK_NUMBER="15"
  local namespace="task15"
  local pod_name="affinity"
  local node_label_key="tier"
  local node_label_value="frontend"

  # Check if the namespace exists
  debug "Checking if namespace '$namespace' exists."
  kubectl get namespace "$namespace" > /dev/null 2>&1 || {
    debug "Namespace '$namespace' does not exist."
    failed
    return
  }

  # Retrieve the pod JSON once
  debug "Retrieving JSON for pod '$pod_name' in namespace '$namespace'."
  local pod_json
  pod_json="$(kubectl get pod "$pod_name" -n "$namespace" -o json 2>/dev/null)" || {
    debug "Pod '$pod_name' does not exist in namespace '$namespace'."
    failed
    return
  }

  # Check if the pod has the correct nodeAffinity configured
  debug "Checking nodeAffinity configuration for pod '$pod_name'."
  local affinity_config
  affinity_config="$(echo "$pod_json" | jq '.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution')" || {
    debug "Failed to extract nodeAffinity from pod JSON."
    failed
    return
  }
  if [[ -z "$affinity_config" ]] || [[ $(echo "$affinity_config" | jq -r '.nodeSelectorTerms | length') -eq 0 ]]; then
    debug "No nodeSelectorTerms found in nodeAffinity."
    failed
    return
  fi

  local match_key
  match_key="$(echo "$affinity_config" | jq -r '.nodeSelectorTerms[0].matchExpressions[0].key // empty')" || {
    debug "Failed to extract matchExpressions key from nodeAffinity."
    failed
    return
  }
  local match_operator
  match_operator="$(echo "$affinity_config" | jq -r '.nodeSelectorTerms[0].matchExpressions[0].operator // empty')" || {
    debug "Failed to extract matchExpressions operator from nodeAffinity."
    failed
    return
  }
  local match_value
  match_value="$(echo "$affinity_config" | jq -r '.nodeSelectorTerms[0].matchExpressions[0].values[0] // empty')" || {
    debug "Failed to extract matchExpressions value from nodeAffinity."
    failed
    return
  }

  if [[ "$match_key" != "$node_label_key" ]]; then
    debug "NodeAffinity key mismatch. Expected '$node_label_key', found '$match_key'."
    failed
    return
  fi
  if [[ "$match_operator" != "In" ]]; then
    debug "NodeAffinity operator mismatch. Expected 'In', found '$match_operator'."
    failed
    return
  fi
  if [[ "$match_value" != "$node_label_value" ]]; then
    debug "NodeAffinity value mismatch. Expected '$node_label_value', found '$match_value'."
    failed
    return
  fi

  # Retrieve the node where the pod is running
  debug "Retrieving node name where pod '$pod_name' is scheduled."
  local node_name
  node_name="$(echo "$pod_json" | jq -r '.spec.nodeName // empty')" || {
    debug "Failed to extract nodeName from pod JSON."
    failed
    return
  }
  if [[ -z "$node_name" ]]; then
    debug "Pod '$pod_name' is not scheduled to any node."
    failed
    return
  fi

  # Verify that the node has the expected label
  debug "Checking if node '$node_name' has label '$node_label_key: $node_label_value'."
  local node_json
  node_json="$(kubectl get node "$node_name" -o json 2>/dev/null)" || {
    debug "Failed to retrieve node '$node_name'."
    failed
    return
  }
  local node_label
  node_label="$(echo "$node_json" | jq -r --arg key "$node_label_key" '.metadata.labels[$key] // empty')" || {
    debug "Failed to extract label '$node_label_key' from node JSON."
    failed
    return
  }
  if [[ "$node_label" != "$node_label_value" ]]; then
    debug "Node label mismatch. Expected '$node_label_value', found '$node_label'."
    failed
    return
  fi

  debug "Pod '$pod_name' in namespace '$namespace' has correct nodeAffinity and is scheduled to a node with the correct label. Verification successful."
  solved
  return
}

# shellcheck disable=SC2329
verify_task16() {
  TASK_NUMBER="16"
  local pod_name="tolerant"
  local control_plane_label="node-role.kubernetes.io/control-plane"
  local tier_key="tier"
  local forbidden_tiers=("frontend" "backend")
  local expected_message="I'm tolerant!"
  local namespace="default"

  # Retrieve the pod JSON once
  debug "Retrieving JSON for pod '$pod_name' in namespace '$namespace'."
  local pod_json
  pod_json="$(kubectl get pod "$pod_name" -n "$namespace" -o json 2>/dev/null)" || {
    debug "Pod '$pod_name' does not exist in namespace '$namespace'."
    failed
    return
  }

  # Verify the pod's node affinity
  debug "Checking node affinity for key '$tier_key' with operator 'NotIn' and forbidden tiers."
  local affinity
  affinity="$(echo "$pod_json" | jq -r '.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0]' 2>/dev/null)" || {
    debug "Failed to extract node affinity from pod JSON."
    failed
    return
  }
  local affinity_key
  affinity_key="$(echo "$affinity" | jq -r '.key // empty' 2>/dev/null)"
  local affinity_operator
  affinity_operator="$(echo "$affinity" | jq -r '.operator // empty' 2>/dev/null)"
  if [[ "$affinity_key" != "$tier_key" ]]; then
    debug "Node affinity key mismatch. Expected '$tier_key', found '$affinity_key'."
    failed
    return
  fi
  if [[ "$affinity_operator" != "NotIn" ]]; then
    debug "Node affinity operator mismatch. Expected 'NotIn', found '$affinity_operator'."
    failed
    return
  fi

  # Verify forbidden tiers
  debug "Checking forbidden tiers in node affinity values."
  local affinity_values
  affinity_values="$(echo "$affinity" | jq -r '.values[]' 2>/dev/null)" || {
    debug "Failed to extract node affinity values from pod JSON."
    failed
    return
  }
  for forbidden in "${forbidden_tiers[@]}"; do
    if ! grep -qx "$forbidden" <<< "$affinity_values"; then
      debug "Forbidden tier '$forbidden' not found in node affinity values."
      failed
      return
    fi
  done

  # Verify the toleration for control-plane
  debug "Checking toleration for key '$control_plane_label' with operator 'Exists' and effect 'NoSchedule'."
  local toleration
  toleration="$(echo "$pod_json" | jq -r --arg key "$control_plane_label" '.spec.tolerations[] | select(.key==$key)' 2>/dev/null)" || {
    debug "Failed to extract toleration for key '$control_plane_label' from pod JSON."
    failed
    return
  }
  local toleration_operator
  toleration_operator="$(echo "$toleration" | jq -r '.operator // empty' 2>/dev/null)"
  local toleration_effect
  toleration_effect="$(echo "$toleration" | jq -r '.effect // empty' 2>/dev/null)"
  if [[ "$toleration_operator" != "Exists" ]]; then
    debug "Toleration operator mismatch. Expected 'Exists', found '$toleration_operator'."
    failed
    return
  fi
  if [[ "$toleration_effect" != "NoSchedule" ]]; then
    debug "Toleration effect mismatch. Expected 'NoSchedule', found '$toleration_effect'."
    failed
    return
  fi

  # Check the restart policy is "Never"
  debug "Checking if restart policy is 'Never'."
  local restart_policy
  restart_policy="$(echo "$pod_json" | jq -r '.spec.restartPolicy // empty' 2>/dev/null)" || {
    debug "Failed to extract restart policy from pod JSON."
    failed
    return
  }
  if [[ "$restart_policy" != "Never" ]]; then
    debug "Restart policy mismatch. Expected 'Never', found '$restart_policy'."
    failed
    return
  fi

  # Check the pod's status to ensure it has completed successfully
  debug "Checking if pod phase is 'Succeeded'."
  local pod_phase
  pod_phase="$(echo "$pod_json" | jq -r '.status.phase // empty' 2>/dev/null)" || {
    debug "Failed to extract pod phase from pod JSON."
    failed
    return
  }
  if [[ "$pod_phase" != "Succeeded" ]]; then
    debug "Pod phase mismatch. Expected 'Succeeded', found '$pod_phase'."
    failed
    return
  fi

  # Check the pod logs for the expected message
  debug "Checking pod logs for expected message."
  local pod_logs
  pod_logs="$(kubectl logs "$pod_name" -n "$namespace" 2>/dev/null)" || {
    debug "Failed to retrieve logs from pod '$pod_name'."
    failed
    return
  }
  if [[ "$pod_logs" != *"$expected_message"* ]]; then
    debug "Pod logs do not contain expected message. Expected to find '$expected_message', found '$pod_logs'."
    failed
    return
  fi

  debug "Pod '$pod_name' in namespace '$namespace' meets all verification criteria. Verification successful."
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
)
run_verification VERIFY_TASK_FUNCTIONS "$@"

exit 0
