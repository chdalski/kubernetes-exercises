#!/bin/bash

# shellcheck source=../../.scripts/verify.sh
source "$(git rev-parse --show-toplevel)/.scripts/verify.sh"

# shellcheck disable=SC2329
verify_task1() {
  TASK_NUMBER="1"

  # Define expected values
  local expected_rs_name="web-rs"
  local expected_namespace="default"
  local expected_replicas=3
  local expected_image="nginx:1.25"
  local expected_label_key="app"
  local expected_label_value="web"
  local expected_port=80

  # Get ReplicaSet JSON
  debug "Fetching ReplicaSet '${expected_rs_name}' in namespace '${expected_namespace}'."
  local rs_json
  rs_json="$(kubectl get rs "${expected_rs_name}" -n "${expected_namespace}" -o json 2>/dev/null)" || { debug "Failed to fetch ReplicaSet '${expected_rs_name}'."; failed; return; }

  # Check ReplicaSet name
  debug "Verifying ReplicaSet name."
  local rs_name
  rs_name="$(echo "${rs_json}" | jq -r '.metadata.name')" || { debug "Failed to extract ReplicaSet name."; failed; return; }
  [ "${rs_name}" = "${expected_rs_name}" ] || { debug "ReplicaSet name mismatch: expected '${expected_rs_name}', found '${rs_name}'."; failed; return; }

  # Check namespace
  debug "Verifying ReplicaSet namespace."
  local rs_namespace
  rs_namespace="$(echo "${rs_json}" | jq -r '.metadata.namespace')" || { debug "Failed to extract ReplicaSet namespace."; failed; return; }
  [ "${rs_namespace}" = "${expected_namespace}" ] || { debug "ReplicaSet namespace mismatch: expected '${expected_namespace}', found '${rs_namespace}'."; failed; return; }

  # Check replicas
  debug "Verifying ReplicaSet replicas."
  local rs_replicas
  rs_replicas="$(echo "${rs_json}" | jq -r '.spec.replicas')" || { debug "Failed to extract ReplicaSet replicas."; failed; return; }
  [ "${rs_replicas}" -eq "${expected_replicas}" ] || { debug "ReplicaSet replicas mismatch: expected '${expected_replicas}', found '${rs_replicas}'."; failed; return; }

  # Check selector label
  debug "Verifying ReplicaSet selector label."
  local rs_selector_label
  rs_selector_label="$(echo "${rs_json}" | jq -r ".spec.selector.matchLabels.${expected_label_key}")" || { debug "Failed to extract ReplicaSet selector label '${expected_label_key}'."; failed; return; }
  [ "${rs_selector_label}" = "${expected_label_value}" ] || { debug "ReplicaSet selector label mismatch: expected '${expected_label_value}', found '${rs_selector_label}'."; failed; return; }

  # Check pod template label
  debug "Verifying ReplicaSet pod template label."
  local rs_template_label
  rs_template_label="$(echo "${rs_json}" | jq -r ".spec.template.metadata.labels.${expected_label_key}")" || { debug "Failed to extract pod template label '${expected_label_key}'."; failed; return; }
  [ "${rs_template_label}" = "${expected_label_value}" ] || { debug "Pod template label mismatch: expected '${expected_label_value}', found '${rs_template_label}'."; failed; return; }

  # Check container image
  debug "Verifying ReplicaSet container image."
  local rs_container_image
  rs_container_image="$(echo "${rs_json}" | jq -r '.spec.template.spec.containers[0].image')" || { debug "Failed to extract container image."; failed; return; }
  [ "${rs_container_image}" = "${expected_image}" ] || { debug "Container image mismatch: expected '${expected_image}', found '${rs_container_image}'."; failed; return; }

  # Check container port
  debug "Verifying ReplicaSet container port."
  local rs_container_port
  rs_container_port="$(echo "${rs_json}" | jq -r '.spec.template.spec.containers[0].ports[0].containerPort')" || { debug "Failed to extract container port."; failed; return; }
  [ "${rs_container_port}" -eq "${expected_port}" ] || { debug "Container port mismatch: expected '${expected_port}', found '${rs_container_port}'."; failed; return; }

  # Get pods with correct label
  debug "Fetching pods with label '${expected_label_key}=${expected_label_value}' in namespace '${expected_namespace}'."
  local pods_json
  pods_json="$(kubectl get pods -n "${expected_namespace}" -l "${expected_label_key}=${expected_label_value}" -o json 2>/dev/null)" || { debug "Failed to fetch pods with label '${expected_label_key}=${expected_label_value}'."; failed; return; }

  # Check pod count
  debug "Verifying number of pods."
  local pod_count
  pod_count="$(echo "${pods_json}" | jq '.items | length')" || { debug "Failed to count pods."; failed; return; }
  [ "${pod_count}" -eq "${expected_replicas}" ] || { debug "Pod count mismatch: expected '${expected_replicas}', found '${pod_count}'."; failed; return; }

  # Check each pod's image and running status
  debug "Verifying each pod's image and running status."
  local i
  for ((i=0; i<expected_replicas; i++)); do
    local pod_image
    pod_image="$(echo "${pods_json}" | jq -r ".items[${i}].spec.containers[0].image")" || { debug "Failed to extract image for pod index ${i}."; failed; return; }
    if [ "${pod_image}" != "${expected_image}" ]; then
      debug "Pod index ${i} image mismatch: expected '${expected_image}', found '${pod_image}'."
      failed
      return
    fi
    local pod_phase
    pod_phase="$(echo "${pods_json}" | jq -r ".items[${i}].status.phase")" || { debug "Failed to extract status.phase for pod index ${i}."; failed; return; }
    if [ "${pod_phase}" != "Running" ]; then
      debug "Pod index ${i} is not running: expected 'Running', found '${pod_phase}'."
      failed
      return
    fi
  done

  debug "All verifications passed for task ${TASK_NUMBER}."
  solved
  return
}

# shellcheck disable=SC2329
verify_task2() {
  TASK_NUMBER="2"

  # Expected values
  local expected_namespace="affinity"
  local expected_rs_name="api-backend"
  local expected_replicas=2
  local expected_image="nginx:1.29"
  local expected_label_tier="backend"
  local expected_label_env="prod"
  local expected_port=8080
  local expected_affinity_label_key="service"
  local expected_affinity_label_value="cache-server"

  # Fetch the ReplicaSet JSON
  debug "Fetching ReplicaSet '$expected_rs_name' in namespace '$expected_namespace'."
  local rs_json
  rs_json="$(kubectl get rs "$expected_rs_name" -n "$expected_namespace" -o json 2>/dev/null)" || { debug "Failed to fetch ReplicaSet '$expected_rs_name' in namespace '$expected_namespace'."; failed; return; }

  # Check ReplicaSet exists
  local rs_name
  rs_name="$(echo "$rs_json" | jq -r '.metadata.name' 2>/dev/null)" || { debug "Failed to parse ReplicaSet name from JSON."; failed; return; }
  if [ "$rs_name" != "$expected_rs_name" ]; then
    debug "ReplicaSet name mismatch. Expected '$expected_rs_name', found '$rs_name'."
    failed
    return
  fi

  # Check ReplicaSet replicas
  local rs_replicas
  rs_replicas="$(echo "$rs_json" | jq '.spec.replicas' 2>/dev/null)" || { debug "Failed to parse ReplicaSet replicas from JSON."; failed; return; }
  if [ "$rs_replicas" -ne "$expected_replicas" ]; then
    debug "ReplicaSet replicas mismatch. Expected '$expected_replicas', found '$rs_replicas'."
    failed
    return
  fi

  # Check pod template labels
  local rs_label_tier
  rs_label_tier="$(echo "$rs_json" | jq -r '.spec.template.metadata.labels.tier' 2>/dev/null)" || { debug "Failed to parse pod template label 'tier'."; failed; return; }
  local rs_label_env
  rs_label_env="$(echo "$rs_json" | jq -r '.spec.template.metadata.labels.env' 2>/dev/null)" || { debug "Failed to parse pod template label 'env'."; failed; return; }
  if [ "$rs_label_tier" != "$expected_label_tier" ]; then
    debug "Pod template label 'tier' mismatch. Expected '$expected_label_tier', found '$rs_label_tier'."
    failed
    return
  fi
  if [ "$rs_label_env" != "$expected_label_env" ]; then
    debug "Pod template label 'env' mismatch. Expected '$expected_label_env', found '$rs_label_env'."
    failed
    return
  fi

  # Check pod template container image
  local rs_image
  rs_image="$(echo "$rs_json" | jq -r '.spec.template.spec.containers[0].image' 2>/dev/null)" || { debug "Failed to parse pod template container image."; failed; return; }
  if [ "$rs_image" != "$expected_image" ]; then
    debug "Pod template container image mismatch. Expected '$expected_image', found '$rs_image'."
    failed
    return
  fi

  # Check pod template container port
  local rs_port
  rs_port="$(echo "$rs_json" | jq '.spec.template.spec.containers[0].ports[0].containerPort' 2>/dev/null)" || { debug "Failed to parse pod template container port."; failed; return; }
  if [ "$rs_port" -ne "$expected_port" ]; then
    debug "Pod template container port mismatch. Expected '$expected_port', found '$rs_port'."
    failed
    return
  fi

  # Check pod affinity rules
  local rs_affinity
  rs_affinity="$(echo "$rs_json" | jq '.spec.template.spec.affinity.podAffinity.preferredDuringSchedulingIgnoredDuringExecution[0].podAffinityTerm.labelSelector.matchExpressions[0]' 2>/dev/null)" || { debug "Failed to parse pod affinity rules."; failed; return; }
  local rs_affinity_key
  rs_affinity_key="$(echo "$rs_affinity" | jq -r '.key' 2>/dev/null)" || { debug "Failed to parse affinity key."; failed; return; }
  local rs_affinity_values
  rs_affinity_values="$(echo "$rs_affinity" | jq -r '.values[]' 2>/dev/null)" || { debug "Failed to parse affinity values."; failed; return; }
  if [ "$rs_affinity_key" != "$expected_affinity_label_key" ] || ! echo "$rs_affinity_values" | grep -q "$expected_affinity_label_value"; then
    debug "Pod affinity rule mismatch. Expected key '$expected_affinity_label_key' with value '$expected_affinity_label_value', found key '$rs_affinity_key' with values '$rs_affinity_values'."
    failed
    return
  fi

  # Fetch pods managed by the ReplicaSet
  debug "Fetching pods managed by ReplicaSet '$expected_rs_name'."
  local pods_json
  pods_json="$(kubectl get pods -n "$expected_namespace" -l "tier=$expected_label_tier,env=$expected_label_env" -o json 2>/dev/null)" || { debug "Failed to fetch pods for ReplicaSet '$expected_rs_name'."; failed; return; }
  local pod_count
  pod_count="$(echo "$pods_json" | jq '.items | length' 2>/dev/null)" || { debug "Failed to parse pod count."; failed; return; }
  if [ "$pod_count" -ne "$expected_replicas" ]; then
    debug "Pod count mismatch. Expected '$expected_replicas', found '$pod_count'."
    failed
    return
  fi

  # Check each pod for correct labels and image
  local i
  for ((i=0; i<pod_count; i++)); do
    local pod_name
    pod_name="$(echo "$pods_json" | jq -r ".items[$i].metadata.name" 2>/dev/null)" || { debug "Failed to parse pod name at index $i."; failed; return; }
    local pod_image
    pod_image="$(echo "$pods_json" | jq -r ".items[$i].spec.containers[0].image" 2>/dev/null)" || { debug "Failed to parse pod image for pod '$pod_name'."; failed; return; }
    if [ "$pod_image" != "$expected_image" ]; then
      debug "Pod '$pod_name' image mismatch. Expected '$expected_image', found '$pod_image'."
      failed
      return
    fi
    local pod_label_tier
    pod_label_tier="$(echo "$pods_json" | jq -r ".items[$i].metadata.labels.tier" 2>/dev/null)" || { debug "Failed to parse pod label 'tier' for pod '$pod_name'."; failed; return; }
    local pod_label_env
    pod_label_env="$(echo "$pods_json" | jq -r ".items[$i].metadata.labels.env" 2>/dev/null)" || { debug "Failed to parse pod label 'env' for pod '$pod_name'."; failed; return; }
    if [ "$pod_label_tier" != "$expected_label_tier" ] || [ "$pod_label_env" != "$expected_label_env" ]; then
      debug "Pod '$pod_name' label mismatch. Expected 'tier=$expected_label_tier,env=$expected_label_env', found 'tier=$pod_label_tier,env=$pod_label_env'."
      failed
      return
    fi
    debug "Pod '$pod_name' passed image and label checks."
  done

  debug "All checks passed for Task 2. Verification successful."
  solved
  return
}

# shellcheck disable=SC2329
verify_task3() {
  TASK_NUMBER="3"

  # Expected values
  local expected_rs_name="redis-cache"
  local expected_namespace="default"
  local expected_replicas=4
  local expected_image="redis:7.2-alpine"
  local expected_selector_role="cache"
  local expected_label_role="cache"
  local expected_label_component="redis"
  local expected_container_port=6379

  # Fetch the ReplicaSet JSON
  # Checking if the ReplicaSet exists
  local rs_json
  rs_json="$(kubectl get rs "$expected_rs_name" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Failed to get ReplicaSet '$expected_rs_name' in namespace '$expected_namespace'."
    failed
    return
  }
  debug "Fetched ReplicaSet '$expected_rs_name' JSON."

  # Check the number of replicas
  local rs_replicas
  rs_replicas="$(echo "$rs_json" | jq '.spec.replicas')" || {
    debug "Failed to extract replicas from ReplicaSet JSON."
    failed
    return
  }
  if [ "$rs_replicas" -ne "$expected_replicas" ]; then
    debug "ReplicaSet has $rs_replicas replicas, expected $expected_replicas."
    failed
    return
  fi
  debug "ReplicaSet has correct number of replicas: $rs_replicas."

  # Check the selector
  local rs_selector_role
  rs_selector_role="$(echo "$rs_json" | jq -r '.spec.selector.matchLabels.role')" || {
    debug "Failed to extract selector.matchLabels.role from ReplicaSet JSON."
    failed
    return
  }
  if [ "$rs_selector_role" != "$expected_selector_role" ]; then
    debug "ReplicaSet selector.matchLabels.role is '$rs_selector_role', expected '$expected_selector_role'."
    failed
    return
  fi
  debug "ReplicaSet selector.matchLabels.role is correct: $rs_selector_role."

  # Check the pod template labels
  local rs_template_label_role
  rs_template_label_role="$(echo "$rs_json" | jq -r '.spec.template.metadata.labels.role')" || {
    debug "Failed to extract template.metadata.labels.role from ReplicaSet JSON."
    failed
    return
  }
  if [ "$rs_template_label_role" != "$expected_label_role" ]; then
    debug "Pod template label 'role' is '$rs_template_label_role', expected '$expected_label_role'."
    failed
    return
  fi

  local rs_template_label_component
  rs_template_label_component="$(echo "$rs_json" | jq -r '.spec.template.metadata.labels.component')" || {
    debug "Failed to extract template.metadata.labels.component from ReplicaSet JSON."
    failed
    return
  }
  if [ "$rs_template_label_component" != "$expected_label_component" ]; then
    debug "Pod template label 'component' is '$rs_template_label_component', expected '$expected_label_component'."
    failed
    return
  fi
  debug "Pod template labels are correct: role=$rs_template_label_role, component=$rs_template_label_component."

  # Check the container image and port
  local rs_container_image
  rs_container_image="$(echo "$rs_json" | jq -r '.spec.template.spec.containers[0].image')" || {
    debug "Failed to extract container image from ReplicaSet JSON."
    failed
    return
  }
  if [ "$rs_container_image" != "$expected_image" ]; then
    debug "Container image is '$rs_container_image', expected '$expected_image'."
    failed
    return
  fi

  local rs_container_port
  rs_container_port="$(echo "$rs_json" | jq '.spec.template.spec.containers[0].ports[0].containerPort')" || {
    debug "Failed to extract container port from ReplicaSet JSON."
    failed
    return
  }
  if [ "$rs_container_port" -ne "$expected_container_port" ]; then
    debug "Container port is '$rs_container_port', expected '$expected_container_port'."
    failed
    return
  fi
  debug "Container image and port are correct: image=$rs_container_image, port=$rs_container_port."

  # Check that all pods have the correct labels and are running
  # Fetch pods with the selector
  local pods_json
  pods_json="$(kubectl get pods -n "$expected_namespace" -l "role=$expected_label_role" -o json 2>/dev/null)" || {
    debug "Failed to get pods with label 'role=$expected_label_role' in namespace '$expected_namespace'."
    failed
    return
  }
  debug "Fetched pods with label 'role=$expected_label_role'."

  local pod_count
  pod_count="$(echo "$pods_json" | jq '.items | length')" || {
    debug "Failed to count pods from pods JSON."
    failed
    return
  }
  if [ "$pod_count" -ne "$expected_replicas" ]; then
    debug "Number of pods with label 'role=$expected_label_role' is $pod_count, expected $expected_replicas."
    failed
    return
  fi

  # Check each pod's labels and status
  local i
  for ((i=0; i<pod_count; i++)); do
    local pod_name
    pod_name="$(echo "$pods_json" | jq -r ".items[$i].metadata.name")"
    local pod_label_component
    pod_label_component="$(echo "$pods_json" | jq -r ".items[$i].metadata.labels.component")"
    local pod_status
    pod_status="$(echo "$pods_json" | jq -r ".items[$i].status.phase")"

    if [ "$pod_label_component" != "$expected_label_component" ]; then
      debug "Pod '$pod_name' label 'component' is '$pod_label_component', expected '$expected_label_component'."
      failed
      return
    fi
    if [ "$pod_status" != "Running" ]; then
      debug "Pod '$pod_name' status is '$pod_status', expected 'Running'."
      failed
      return
    fi
    debug "Pod '$pod_name' has correct label 'component' and is running."
  done

  debug "All verifications passed for ReplicaSet '$expected_rs_name'."
  solved
  return
}

# shellcheck disable=SC2329
verify_task4() {
  TASK_NUMBER="4"

  # Expected values
  local expected_rs_name="frontend-rs"
  local expected_namespace="default"
  local expected_replicas=2
  local expected_image="httpd:2.4"
  local expected_label_app="frontend"
  local expected_cpu_limit="200m"
  local expected_memory_limit="256Mi"
  local expected_container_port=3000

  # Fetch the ReplicaSet JSON
  local rs_json
  rs_json="$(kubectl get rs "$expected_rs_name" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Failed to get ReplicaSet '$expected_rs_name' in namespace '$expected_namespace'."
    failed
    return
  }
  debug "Fetched ReplicaSet '$expected_rs_name' JSON."

  # Check the number of replicas
  local rs_replicas
  rs_replicas="$(echo "$rs_json" | jq '.spec.replicas')" || {
    debug "Failed to extract replicas from ReplicaSet JSON."
    failed
    return
  }
  if [ "$rs_replicas" -ne "$expected_replicas" ]; then
    debug "ReplicaSet has $rs_replicas replicas, expected $expected_replicas."
    failed
    return
  fi
  debug "ReplicaSet has correct number of replicas: $rs_replicas."

  # Check the pod template labels
  local rs_template_label_app
  rs_template_label_app="$(echo "$rs_json" | jq -r '.spec.template.metadata.labels.app')" || {
    debug "Failed to extract template.metadata.labels.app from ReplicaSet JSON."
    failed
    return
  }
  if [ "$rs_template_label_app" != "$expected_label_app" ]; then
    debug "Pod template label 'app' is '$rs_template_label_app', expected '$expected_label_app'."
    failed
    return
  fi
  debug "Pod template label 'app' is correct: $rs_template_label_app."

  # Check the container image
  local rs_container_image
  rs_container_image="$(echo "$rs_json" | jq -r '.spec.template.spec.containers[0].image')" || {
    debug "Failed to extract container image from ReplicaSet JSON."
    failed
    return
  }
  if [ "$rs_container_image" != "$expected_image" ]; then
    debug "Container image is '$rs_container_image', expected '$expected_image'."
    failed
    return
  fi

  # Check the container port
  local rs_container_port
  rs_container_port="$(echo "$rs_json" | jq '.spec.template.spec.containers[0].ports[0].containerPort')" || {
    debug "Failed to extract container port from ReplicaSet JSON."
    failed
    return
  }
  if [ "$rs_container_port" -ne "$expected_container_port" ]; then
    debug "Container port is '$rs_container_port', expected '$expected_container_port'."
    failed
    return
  fi
  debug "Container image and port are correct: image=$rs_container_image, port=$rs_container_port."

  # Check the resource limits
  local rs_cpu_limit
  rs_cpu_limit="$(echo "$rs_json" | jq -r '.spec.template.spec.containers[0].resources.limits.cpu')" || {
    debug "Failed to extract CPU limit from ReplicaSet JSON."
    failed
    return
  }
  if [ "$rs_cpu_limit" != "$expected_cpu_limit" ]; then
    debug "CPU limit is '$rs_cpu_limit', expected '$expected_cpu_limit'."
    failed
    return
  fi

  local rs_memory_limit
  rs_memory_limit="$(echo "$rs_json" | jq -r '.spec.template.spec.containers[0].resources.limits.memory')" || {
    debug "Failed to extract memory limit from ReplicaSet JSON."
    failed
    return
  }
  if [ "$rs_memory_limit" != "$expected_memory_limit" ]; then
    debug "Memory limit is '$rs_memory_limit', expected '$expected_memory_limit'."
    failed
    return
  fi
  debug "Resource limits are correct: cpu=$rs_cpu_limit, memory=$rs_memory_limit."

  # Check that all pods have the correct label and are running
  local pods_json
  pods_json="$(kubectl get pods -n "$expected_namespace" -l "app=$expected_label_app" -o json 2>/dev/null)" || {
    debug "Failed to get pods with label 'app=$expected_label_app' in namespace '$expected_namespace'."
    failed
    return
  }
  debug "Fetched pods with label 'app=$expected_label_app'."

  local pod_count
  pod_count="$(echo "$pods_json" | jq '.items | length')" || {
    debug "Failed to count pods from pods JSON."
    failed
    return
  }
  if [ "$pod_count" -ne "$expected_replicas" ]; then
    debug "Number of pods with label 'app=$expected_label_app' is $pod_count, expected $expected_replicas."
    failed
    return
  fi

  # Check each pod's labels and status
  local i
  for ((i=0; i<pod_count; i++)); do
    local pod_name
    pod_name="$(echo "$pods_json" | jq -r ".items[$i].metadata.name")"
    local pod_label_app
    pod_label_app="$(echo "$pods_json" | jq -r ".items[$i].metadata.labels.app")"
    local pod_status
    pod_status="$(echo "$pods_json" | jq -r ".items[$i].status.phase")"

    if [ "$pod_label_app" != "$expected_label_app" ]; then
      debug "Pod '$pod_name' label 'app' is '$pod_label_app', expected '$expected_label_app'."
      failed
      return
    fi
    if [ "$pod_status" != "Running" ]; then
      debug "Pod '$pod_name' status is '$pod_status', expected 'Running'."
      failed
      return
    fi
    debug "Pod '$pod_name' has correct label 'app' and is running."
  done

  debug "All verifications passed for ReplicaSet '$expected_rs_name'."
  solved
  return
}

# shellcheck disable=SC2329
verify_task5() {
  TASK_NUMBER="5"

  # Expected values
  local expected_rs_name="logger-rs"
  local expected_namespace="logger"
  local expected_replicas=1
  local expected_image="busybox:1.36"
  local expected_label_app="logger"
  local expected_env_name="LOG_LEVEL"
  local expected_env_value="debug"
  local expected_command_0="sleep"
  local expected_command_1="28800"

  # Fetch the ReplicaSet JSON
  local rs_json
  rs_json="$(kubectl get rs "$expected_rs_name" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Failed to get ReplicaSet '$expected_rs_name' in namespace '$expected_namespace'."
    failed
    return
  }
  debug "Fetched ReplicaSet '$expected_rs_name' JSON."

  # Check the number of replicas
  local rs_replicas
  rs_replicas="$(echo "$rs_json" | jq '.spec.replicas')" || {
    debug "Failed to extract replicas from ReplicaSet JSON."
    failed
    return
  }
  if [ "$rs_replicas" -ne "$expected_replicas" ]; then
    debug "ReplicaSet has $rs_replicas replicas, expected $expected_replicas."
    failed
    return
  fi
  debug "ReplicaSet has correct number of replicas: $rs_replicas."

  # Check the pod template label
  local rs_template_label_app
  rs_template_label_app="$(echo "$rs_json" | jq -r '.spec.template.metadata.labels.app')" || {
    debug "Failed to extract template.metadata.labels.app from ReplicaSet JSON."
    failed
    return
  }
  if [ "$rs_template_label_app" != "$expected_label_app" ]; then
    debug "Pod template label 'app' is '$rs_template_label_app', expected '$expected_label_app'."
    failed
    return
  fi
  debug "Pod template label 'app' is correct: $rs_template_label_app."

  # Check the container image
  local rs_container_image
  rs_container_image="$(echo "$rs_json" | jq -r '.spec.template.spec.containers[0].image')" || {
    debug "Failed to extract container image from ReplicaSet JSON."
    failed
    return
  }
  if [ "$rs_container_image" != "$expected_image" ]; then
    debug "Container image is '$rs_container_image', expected '$expected_image'."
    failed
    return
  fi

  # Check the environment variable
  local env_count
  env_count="$(echo "$rs_json" | jq '.spec.template.spec.containers[0].env | length')" || {
    debug "Failed to extract environment variables from ReplicaSet JSON."
    failed
    return
  }
  local found_env="false"
  local i
  for ((i=0; i<env_count; i++)); do
    local env_name
    env_name="$(echo "$rs_json" | jq -r ".spec.template.spec.containers[0].env[$i].name")"
    local env_value
    env_value="$(echo "$rs_json" | jq -r ".spec.template.spec.containers[0].env[$i].value")"
    if [ "$env_name" = "$expected_env_name" ] && [ "$env_value" = "$expected_env_value" ]; then
      found_env="true"
      break
    fi
  done
  if [ "$found_env" != "true" ]; then
    debug "Environment variable '$expected_env_name=$expected_env_value' not found in container spec."
    failed
    return
  fi
  debug "Environment variable '$expected_env_name=$expected_env_value' is set correctly."

  # Check the command
  local rs_command_0
  rs_command_0="$(echo "$rs_json" | jq -r '.spec.template.spec.containers[0].command[0]')" || {
    debug "Failed to extract first command element from ReplicaSet JSON."
    failed
    return
  }
  local rs_command_1
  rs_command_1="$(echo "$rs_json" | jq -r '.spec.template.spec.containers[0].command[1]')" || {
    debug "Failed to extract second command element from ReplicaSet JSON."
    failed
    return
  }
  if [ "$rs_command_0" != "$expected_command_0" ] || [ "$rs_command_1" != "$expected_command_1" ]; then
    debug "Container command is ['$rs_command_0', '$rs_command_1'], expected ['$expected_command_0', '$expected_command_1']."
    failed
    return
  fi
  debug "Container command is correct: ['$rs_command_0', '$rs_command_1']."

  # Check that the pod is running and has the correct label
  local pods_json
  pods_json="$(kubectl get pods -n "$expected_namespace" -l "app=$expected_label_app" -o json 2>/dev/null)" || {
    debug "Failed to get pods with label 'app=$expected_label_app' in namespace '$expected_namespace'."
    failed
    return
  }
  debug "Fetched pods with label 'app=$expected_label_app'."

  local pod_count
  pod_count="$(echo "$pods_json" | jq '.items | length')" || {
    debug "Failed to count pods from pods JSON."
    failed
    return
  }
  if [ "$pod_count" -ne "$expected_replicas" ]; then
    debug "Number of pods with label 'app=$expected_label_app' is $pod_count, expected $expected_replicas."
    failed
    return
  fi

  for ((i=0; i<pod_count; i++)); do
    local pod_name
    pod_name="$(echo "$pods_json" | jq -r ".items[$i].metadata.name")"
    local pod_label_app
    pod_label_app="$(echo "$pods_json" | jq -r ".items[$i].metadata.labels.app")"
    local pod_status
    pod_status="$(echo "$pods_json" | jq -r ".items[$i].status.phase")"

    if [ "$pod_label_app" != "$expected_label_app" ]; then
      debug "Pod '$pod_name' label 'app' is '$pod_label_app', expected '$expected_label_app'."
      failed
      return
    fi
    if [ "$pod_status" != "Running" ]; then
      debug "Pod '$pod_name' status is '$pod_status', expected 'Running'."
      failed
      return
    fi
    debug "Pod '$pod_name' has correct label 'app' and is running."
  done

  debug "All verifications passed for ReplicaSet '$expected_rs_name'."
  solved
  return
}

# shellcheck disable=SC2329
verify_task6() {
  TASK_NUMBER="6"

  # Expected values
  local expected_rs_name="worker-rs"
  local expected_namespace="default"
  local expected_replicas=3
  local expected_image="alpine:3.20"
  local expected_label_role="worker"
  local expected_affinity_key="disk"
  local expected_affinity_value="ssd"
  local expected_command_0="sh"
  local expected_command_1="-c"
  local expected_command_2="echo Hello from worker; sleep 28800"

  # Fetch the ReplicaSet JSON
  local rs_json
  rs_json="$(kubectl get rs "$expected_rs_name" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Failed to get ReplicaSet '$expected_rs_name' in namespace '$expected_namespace'."
    failed
    return
  }
  debug "Fetched ReplicaSet '$expected_rs_name' JSON."

  # Check the number of replicas
  local rs_replicas
  rs_replicas="$(echo "$rs_json" | jq '.spec.replicas')" || {
    debug "Failed to extract replicas from ReplicaSet JSON."
    failed
    return
  }
  if [ "$rs_replicas" -ne "$expected_replicas" ]; then
    debug "ReplicaSet has $rs_replicas replicas, expected $expected_replicas."
    failed
    return
  fi
  debug "ReplicaSet has correct number of replicas: $rs_replicas."

  # Check the pod template label
  local rs_template_label_role
  rs_template_label_role="$(echo "$rs_json" | jq -r '.spec.template.metadata.labels.role')" || {
    debug "Failed to extract template.metadata.labels.role from ReplicaSet JSON."
    failed
    return
  }
  if [ "$rs_template_label_role" != "$expected_label_role" ]; then
    debug "Pod template label 'role' is '$rs_template_label_role', expected '$expected_label_role'."
    failed
    return
  fi
  debug "Pod template label 'role' is correct: $rs_template_label_role."

  # Check the container image
  local rs_container_image
  rs_container_image="$(echo "$rs_json" | jq -r '.spec.template.spec.containers[0].image')" || {
    debug "Failed to extract container image from ReplicaSet JSON."
    failed
    return
  }
  if [ "$rs_container_image" != "$expected_image" ]; then
    debug "Container image is '$rs_container_image', expected '$expected_image'."
    failed
    return
  fi

  # Check the command
  local rs_command_0
  rs_command_0="$(echo "$rs_json" | jq -r '.spec.template.spec.containers[0].command[0]')" || {
    debug "Failed to extract first command element from ReplicaSet JSON."
    failed
    return
  }
  local rs_command_1
  rs_command_1="$(echo "$rs_json" | jq -r '.spec.template.spec.containers[0].command[1]')" || {
    debug "Failed to extract second command element from ReplicaSet JSON."
    failed
    return
  }
  local rs_command_2
  rs_command_2="$(echo "$rs_json" | jq -r '.spec.template.spec.containers[0].command[2]')" || {
    debug "Failed to extract third command element from ReplicaSet JSON."
    failed
    return
  }
  if [ "$rs_command_0" != "$expected_command_0" ] || [ "$rs_command_1" != "$expected_command_1" ] || [ "$rs_command_2" != "$expected_command_2" ]; then
    debug "Container command is ['$rs_command_0', '$rs_command_1', '$rs_command_2'], expected ['$expected_command_0', '$expected_command_1', '$expected_command_2']."
    failed
    return
  fi
  debug "Container command is correct: ['$rs_command_0', '$rs_command_1', '$rs_command_2']."

  # Check node affinity
  local affinity_key
  affinity_key="$(echo "$rs_json" | jq -r '.spec.template.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].key')" || {
    debug "Failed to extract node affinity key from ReplicaSet JSON."
    failed
    return
  }
  local affinity_operator
  affinity_operator="$(echo "$rs_json" | jq -r '.spec.template.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].operator')" || {
    debug "Failed to extract node affinity operator from ReplicaSet JSON."
    failed
    return
  }
  local affinity_value
  affinity_value="$(echo "$rs_json" | jq -r '.spec.template.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].values[0]')" || {
    debug "Failed to extract node affinity value from ReplicaSet JSON."
    failed
    return
  }
  if [ "$affinity_key" != "$expected_affinity_key" ] || [ "$affinity_operator" != "In" ] || [ "$affinity_value" != "$expected_affinity_value" ]; then
    debug "Node affinity is key='$affinity_key', operator='$affinity_operator', value='$affinity_value'; expected key='$expected_affinity_key', operator='In', value='$expected_affinity_value'."
    failed
    return
  fi
  debug "Node affinity is correct: key='$affinity_key', operator='$affinity_operator', value='$affinity_value'."

  # Check that all pods have the correct label, are running, and are scheduled on nodes with the correct label
  local pods_json
  pods_json="$(kubectl get pods -n "$expected_namespace" -l "role=$expected_label_role" -o json 2>/dev/null)" || {
    debug "Failed to get pods with label 'role=$expected_label_role' in namespace '$expected_namespace'."
    failed
    return
  }
  debug "Fetched pods with label 'role=$expected_label_role'."

  local pod_count
  pod_count="$(echo "$pods_json" | jq '.items | length')" || {
    debug "Failed to count pods from pods JSON."
    failed
    return
  }
  if [ "$pod_count" -ne "$expected_replicas" ]; then
    debug "Number of pods with label 'role=$expected_label_role' is $pod_count, expected $expected_replicas."
    failed
    return
  fi

  local i
  for ((i=0; i<pod_count; i++)); do
    local pod_name
    pod_name="$(echo "$pods_json" | jq -r ".items[$i].metadata.name")"
    local pod_label_role
    pod_label_role="$(echo "$pods_json" | jq -r ".items[$i].metadata.labels.role")"
    local pod_status
    pod_status="$(echo "$pods_json" | jq -r ".items[$i].status.phase")"
    local pod_node
    pod_node="$(echo "$pods_json" | jq -r ".items[$i].spec.nodeName")"

    if [ "$pod_label_role" != "$expected_label_role" ]; then
      debug "Pod '$pod_name' label 'role' is '$pod_label_role', expected '$expected_label_role'."
      failed
      return
    fi
    if [ "$pod_status" != "Running" ]; then
      debug "Pod '$pod_name' status is '$pod_status', expected 'Running'."
      failed
      return
    fi

    # Check node label for affinity
    local node_json
    node_json="$(kubectl get node "$pod_node" -o json 2>/dev/null)" || {
      debug "Failed to get node '$pod_node' for pod '$pod_name'."
      failed
      return
    }
    local node_disk_label
    node_disk_label="$(echo "$node_json" | jq -r ".metadata.labels[\"$expected_affinity_key\"]")" || {
      debug "Failed to extract node label '$expected_affinity_key' from node '$pod_node'."
      failed
      return
    }
    if [ "$node_disk_label" != "$expected_affinity_value" ]; then
      debug "Pod '$pod_name' is scheduled on node '$pod_node' with label '$expected_affinity_key=$node_disk_label', expected '$expected_affinity_key=$expected_affinity_value'."
      failed
      return
    fi

    debug "Pod '$pod_name' has correct label 'role', is running, and is scheduled on node '$pod_node' with '$expected_affinity_key=$node_disk_label'."
  done

  debug "All verifications passed for ReplicaSet '$expected_rs_name'."
  solved
  return
}

# shellcheck disable=SC2329
verify_task7() {
  TASK_NUMBER="7"

  # Expected values
  local expected_rs_name="db-rs"
  local expected_namespace="default"
  local expected_replicas=2
  local expected_image="postgres:16.3"
  local expected_label_app="database"
  local expected_container_port=5432
  local expected_probe_port=5432

  # Fetch the ReplicaSet JSON
  local rs_json
  rs_json="$(kubectl get rs "$expected_rs_name" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Failed to get ReplicaSet '$expected_rs_name' in namespace '$expected_namespace'."
    failed
    return
  }
  debug "Fetched ReplicaSet '$expected_rs_name' JSON."

  # Check the number of replicas
  local rs_replicas
  rs_replicas="$(echo "$rs_json" | jq '.spec.replicas')" || {
    debug "Failed to extract replicas from ReplicaSet JSON."
    failed
    return
  }
  if [ "$rs_replicas" -ne "$expected_replicas" ]; then
    debug "ReplicaSet has $rs_replicas replicas, expected $expected_replicas."
    failed
    return
  fi
  debug "ReplicaSet has correct number of replicas: $rs_replicas."

  # Check the pod template label
  local rs_template_label_app
  rs_template_label_app="$(echo "$rs_json" | jq -r '.spec.template.metadata.labels.app')" || {
    debug "Failed to extract template.metadata.labels.app from ReplicaSet JSON."
    failed
    return
  }
  if [ "$rs_template_label_app" != "$expected_label_app" ]; then
    debug "Pod template label 'app' is '$rs_template_label_app', expected '$expected_label_app'."
    failed
    return
  fi
  debug "Pod template label 'app' is correct: $rs_template_label_app."

  # Check the container image
  local rs_container_image
  rs_container_image="$(echo "$rs_json" | jq -r '.spec.template.spec.containers[0].image')" || {
    debug "Failed to extract container image from ReplicaSet JSON."
    failed
    return
  }
  if [ "$rs_container_image" != "$expected_image" ]; then
    debug "Container image is '$rs_container_image', expected '$expected_image'."
    failed
    return
  fi

  # Check the container port
  local rs_container_port
  rs_container_port="$(echo "$rs_json" | jq '.spec.template.spec.containers[0].ports[0].containerPort')" || {
    debug "Failed to extract container port from ReplicaSet JSON."
    failed
    return
  }
  if [ "$rs_container_port" -ne "$expected_container_port" ]; then
    debug "Container port is '$rs_container_port', expected '$expected_container_port'."
    failed
    return
  fi
  debug "Container image and port are correct: image=$rs_container_image, port=$rs_container_port."

  # Check the readiness probe
  local probe_type
  probe_type="$(echo "$rs_json" | jq -r '.spec.template.spec.containers[0].readinessProbe.tcpSocket.port')" || {
    debug "Failed to extract readiness probe TCP socket port from ReplicaSet JSON."
    failed
    return
  }
  if [ "$probe_type" != "$expected_probe_port" ]; then
    debug "Readiness probe TCP socket port is '$probe_type', expected '$expected_probe_port'."
    failed
    return
  fi
  debug "Readiness probe TCP socket port is correct: $probe_type."

  # Check that all pods have the correct label and are running
  local pods_json
  pods_json="$(kubectl get pods -n "$expected_namespace" -l "app=$expected_label_app" -o json 2>/dev/null)" || {
    debug "Failed to get pods with label 'app=$expected_label_app' in namespace '$expected_namespace'."
    failed
    return
  }
  debug "Fetched pods with label 'app=$expected_label_app'."

  local pod_count
  pod_count="$(echo "$pods_json" | jq '.items | length')" || {
    debug "Failed to count pods from pods JSON."
    failed
    return
  }
  if [ "$pod_count" -ne "$expected_replicas" ]; then
    debug "Number of pods with label 'app=$expected_label_app' is $pod_count, expected $expected_replicas."
    failed
    return
  fi

  local i
  for ((i=0; i<pod_count; i++)); do
    local pod_name
    pod_name="$(echo "$pods_json" | jq -r ".items[$i].metadata.name")"
    local pod_label_app
    pod_label_app="$(echo "$pods_json" | jq -r ".items[$i].metadata.labels.app")"
    local pod_status
    pod_status="$(echo "$pods_json" | jq -r ".items[$i].status.phase")"

    if [ "$pod_label_app" != "$expected_label_app" ]; then
      debug "Pod '$pod_name' label 'app' is '$pod_label_app', expected '$expected_label_app'."
      failed
      return
    fi
    if [ "$pod_status" != "Running" ]; then
      debug "Pod '$pod_name' status is '$pod_status', expected 'Running'."
      failed
      return
    fi
    debug "Pod '$pod_name' has correct label 'app' and is running."
  done

  debug "All verifications passed for ReplicaSet '$expected_rs_name'."
  solved
  return
}

# shellcheck disable=SC2329
verify_task8() {
  TASK_NUMBER="8"

  # Expected values
  local expected_rs_name="job-runner"
  local expected_namespace="default"
  local expected_replicas="2"
  local expected_image="python:3.12-slim"
  local expected_label_key="app"
  local expected_label_value="job"
  local expected_command='["python","-m","http.server","8000"]'
  local expected_restart_policy="Always"

  # Fetch the ReplicaSet JSON
  # Checking if the ReplicaSet exists in the expected namespace
  debug "Fetching ReplicaSet '$expected_rs_name' in namespace '$expected_namespace'."
  local rs_json
  rs_json="$(kubectl get rs "$expected_rs_name" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Failed to fetch ReplicaSet '$expected_rs_name' in namespace '$expected_namespace'."
    failed
    return
  }

  # Check the number of replicas
  debug "Verifying that the ReplicaSet maintains $expected_replicas replicas."
  local rs_replicas
  rs_replicas="$(jq '.spec.replicas' <<<"$rs_json" 2>/dev/null)" || {
    debug "Failed to parse replicas from ReplicaSet JSON."
    failed
    return
  }
  if [ "$rs_replicas" != "$expected_replicas" ]; then
    debug "ReplicaSet has $rs_replicas replicas, expected $expected_replicas."
    failed
    return
  fi

  # Check the pod template image
  debug "Verifying that the pod template uses image '$expected_image'."
  local rs_image
  rs_image="$(jq -r '.spec.template.spec.containers[0].image' <<<"$rs_json" 2>/dev/null)" || {
    debug "Failed to parse image from ReplicaSet JSON."
    failed
    return
  }
  if [ "$rs_image" != "$expected_image" ]; then
    debug "ReplicaSet uses image '$rs_image', expected '$expected_image'."
    failed
    return
  fi

  # Check the pod template labels
  debug "Verifying that the pod template has label '$expected_label_key=$expected_label_value'."
  local rs_label
  rs_label="$(jq -r ".spec.template.metadata.labels.\"$expected_label_key\"" <<<"$rs_json" 2>/dev/null)" || {
    debug "Failed to parse label '$expected_label_key' from ReplicaSet JSON."
    failed
    return
  }
  if [ "$rs_label" != "$expected_label_value" ]; then
    debug "ReplicaSet pod template label '$expected_label_key' is '$rs_label', expected '$expected_label_value'."
    failed
    return
  fi

  # Check the pod template command
  debug "Verifying that the pod template command matches the expected command."
  local rs_command
  rs_command="$(jq -c '.spec.template.spec.containers[0].command' <<<"$rs_json" 2>/dev/null | tr -d '[:space:]')" || {
    debug "Failed to parse command from ReplicaSet JSON."
    failed
    return
  }
  local expected_command_no_space
  expected_command_no_space="$(echo "$expected_command" | tr -d '[:space:]')"
  if [ "$rs_command" != "$expected_command_no_space" ]; then
    debug "ReplicaSet pod template command is '$rs_command', expected '$expected_command_no_space'."
    failed
    return
  fi

  # Check the pod template restart policy
  debug "Verifying that the pod template restart policy is '$expected_restart_policy'."
  local rs_restart_policy
  rs_restart_policy="$(jq -r '.spec.template.spec.restartPolicy // "Always"' <<<"$rs_json" 2>/dev/null)" || {
    debug "Failed to parse restart policy from ReplicaSet JSON."
    failed
    return
  }
  if [ "$rs_restart_policy" != "$expected_restart_policy" ]; then
    debug "ReplicaSet pod template restart policy is '$rs_restart_policy', expected '$expected_restart_policy'."
    failed
    return
  fi

  # All checks passed
  debug "All verifications for ReplicaSet '$expected_rs_name' succeeded."
  solved
  return
}

# shellcheck disable=SC2329
verify_task9() {
  TASK_NUMBER="9"

  # Expected values
  local expected_rs_name="static-files"
  local expected_namespace="default"
  local expected_replicas="2"
  local expected_image="nginx:1.25"
  local expected_label_key="app"
  local expected_label_value="static"
  local expected_mount_path="/usr/share/nginx/html"
  local expected_volume_type="emptyDir"
  local expected_port="80"

  # Fetch the ReplicaSet JSON
  debug "Fetching ReplicaSet '$expected_rs_name' in namespace '$expected_namespace'."
  local rs_json
  rs_json="$(kubectl get rs "$expected_rs_name" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Failed to fetch ReplicaSet '$expected_rs_name' in namespace '$expected_namespace'."
    failed
    return
  }

  # Check the number of replicas
  debug "Verifying that the ReplicaSet maintains $expected_replicas replicas."
  local rs_replicas
  rs_replicas="$(jq '.spec.replicas' <<<"$rs_json" 2>/dev/null)" || {
    debug "Failed to parse replicas from ReplicaSet JSON."
    failed
    return
  }
  if [ "$rs_replicas" != "$expected_replicas" ]; then
    debug "ReplicaSet has $rs_replicas replicas, expected $expected_replicas."
    failed
    return
  fi

  # Check the pod template image
  debug "Verifying that the pod template uses image '$expected_image'."
  local rs_image
  rs_image="$(jq -r '.spec.template.spec.containers[0].image' <<<"$rs_json" 2>/dev/null)" || {
    debug "Failed to parse image from ReplicaSet JSON."
    failed
    return
  }
  if [ "$rs_image" != "$expected_image" ]; then
    debug "ReplicaSet uses image '$rs_image', expected '$expected_image'."
    failed
    return
  fi

  # Check the pod template labels
  debug "Verifying that the pod template has label '$expected_label_key=$expected_label_value'."
  local rs_label
  rs_label="$(jq -r ".spec.template.metadata.labels.\"$expected_label_key\"" <<<"$rs_json" 2>/dev/null)" || {
    debug "Failed to parse label '$expected_label_key' from ReplicaSet JSON."
    failed
    return
  }
  if [ "$rs_label" != "$expected_label_value" ]; then
    debug "ReplicaSet pod template label '$expected_label_key' is '$rs_label', expected '$expected_label_value'."
    failed
    return
  fi

  # Check the pod template volume mount and volume type robustly
  debug "Verifying that the pod template mounts an emptyDir volume at '$expected_mount_path'."
  # Find the volumeMount with the expected mountPath
  local rs_volume_mount_name
  rs_volume_mount_name="$(jq -r --arg path "$expected_mount_path" '.spec.template.spec.containers[0].volumeMounts[] | select(.mountPath == $path) | .name' <<<"$rs_json" 2>/dev/null)" || {
    debug "Failed to parse volumeMounts from ReplicaSet JSON."
    failed
    return
  }
  if [ -z "$rs_volume_mount_name" ]; then
    debug "No volumeMount found with mountPath '$expected_mount_path'."
    failed
    return
  fi

  # Find the volume with the name from the volumeMount
  local rs_volume_type
  rs_volume_type="$(jq -r --arg name "$rs_volume_mount_name" '.spec.template.spec.volumes[] | select(.name == $name) | if has("emptyDir") then "emptyDir" else "" end' <<<"$rs_json" 2>/dev/null)" || {
    debug "Failed to parse volumes from ReplicaSet JSON."
    failed
    return
  }
  if [ "$rs_volume_type" != "$expected_volume_type" ]; then
    debug "Volume named '$rs_volume_mount_name' is of type '$rs_volume_type', expected '$expected_volume_type'."
    failed
    return
  fi

  # Check the pod template container port
  debug "Verifying that the pod template exposes port $expected_port."
  local rs_port
  rs_port="$(jq '.spec.template.spec.containers[0].ports[0].containerPort' <<<"$rs_json" 2>/dev/null)" || {
    debug "Failed to parse container port from ReplicaSet JSON."
    failed
    return
  }
  if [ "$rs_port" != "$expected_port" ]; then
    debug "ReplicaSet pod template exposes port '$rs_port', expected '$expected_port'."
    failed
    return
  fi

  # All checks passed
  debug "All verifications for ReplicaSet '$expected_rs_name' succeeded."
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
