#!/bin/bash

# shellcheck source=../../.scripts/verify.sh
source "$(git rev-parse --show-toplevel)/.scripts/verify.sh"

# shellcheck disable=SC2329
verify_task1() {
  TASK_NUMBER="1"
  local expected_deploy_name="internal-api"
  local expected_namespace="internal"
  local expected_image="nginx:1.25"
  local expected_container_port=80
  local expected_service_name="internal-api-svc"
  local expected_service_type="ClusterIP"
  local expected_service_port=8080
  local expected_service_target_port=80
  local expected_np_name="allow-from-admin"
  local expected_np_label_value="admin"
  local expected_ns_selector_key="kubernetes.io/metadata.name"
  local expected_ns_selector_value="internal"

  # Check if the deployment exists and uses the correct image
  debug "Checking if deployment \"$expected_deploy_name\" exists in namespace \"$expected_namespace\" and uses image \"$expected_image\"."
  local deploy_json
  deploy_json="$(kubectl get deployment "$expected_deploy_name" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Failed to get deployment \"$expected_deploy_name\" in namespace \"$expected_namespace\"."
    failed
    return
  }
  local deploy_image
  deploy_image="$(echo "$deploy_json" | jq -r '.spec.template.spec.containers[0].image' 2>/dev/null)" || {
    debug "Failed to extract image from deployment JSON."
    failed
    return
  }
  if [ "$deploy_image" != "$expected_image" ]; then
    debug "Deployment image mismatch: expected \"$expected_image\", found \"$deploy_image\"."
    failed
    return
  fi

  # Check if the container exposes the correct port
  debug "Checking if deployment container exposes port $expected_container_port."
  local deploy_container_port
  deploy_container_port="$(echo "$deploy_json" | jq -r '.spec.template.spec.containers[0].ports[0].containerPort' 2>/dev/null)" || {
    debug "Failed to extract containerPort from deployment JSON."
    failed
    return
  }
  if [ "$deploy_container_port" != "$expected_container_port" ]; then
    debug "Deployment containerPort mismatch: expected \"$expected_container_port\", found \"$deploy_container_port\"."
    failed
    return
  fi

  # Extract deployment pod template labels
  debug "Extracting deployment pod template labels."
  local deploy_labels_json
  deploy_labels_json="$(echo "$deploy_json" | jq -c '.spec.template.metadata.labels' 2>/dev/null)" || {
    debug "Failed to extract deployment pod template labels."
    failed
    return
  }

  # Check if the service exists and is of correct type
  debug "Checking if service \"$expected_service_name\" exists in namespace \"$expected_namespace\" and is of type \"$expected_service_type\"."
  local svc_json
  svc_json="$(kubectl get service "$expected_service_name" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Failed to get service \"$expected_service_name\" in namespace \"$expected_namespace\"."
    failed
    return
  }
  local svc_type
  svc_type="$(echo "$svc_json" | jq -r '.spec.type' 2>/dev/null)" || {
    debug "Failed to extract service type from service JSON."
    failed
    return
  }
  if [ "$svc_type" != "$expected_service_type" ]; then
    debug "Service type mismatch: expected \"$expected_service_type\", found \"$svc_type\"."
    failed
    return
  fi

  # Check if the service exposes the correct port and targetPort
  debug "Checking if service \"$expected_service_name\" exposes port $expected_service_port and targetPort $expected_service_target_port."
  local svc_port
  svc_port="$(echo "$svc_json" | jq -r '.spec.ports[0].port' 2>/dev/null)" || {
    debug "Failed to extract service port from service JSON."
    failed
    return
  }
  local svc_target_port
  svc_target_port="$(echo "$svc_json" | jq -r '.spec.ports[0].targetPort' 2>/dev/null)" || {
    debug "Failed to extract service targetPort from service JSON."
    failed
    return
  }
  if [ "$svc_port" != "$expected_service_port" ]; then
    debug "Service port mismatch: expected \"$expected_service_port\", found \"$svc_port\"."
    failed
    return
  fi
  if [ "$svc_target_port" != "$expected_service_target_port" ]; then
    debug "Service targetPort mismatch: expected \"$expected_service_target_port\", found \"$svc_target_port\"."
    failed
    return
  fi

  # Check if the service selector matches the deployment pod template labels
  debug "Checking if service selector matches deployment pod template labels."
  local svc_selector_json
  svc_selector_json="$(echo "$svc_json" | jq -c '.spec.selector' 2>/dev/null)" || {
    debug "Failed to extract service selector from service JSON."
    failed
    return
  }
  if [ "$svc_selector_json" != "$deploy_labels_json" ]; then
    debug "Service selector does not match deployment pod template labels. Expected: $deploy_labels_json, Found: $svc_selector_json"
    failed
    return
  fi

  # Check if the NetworkPolicy exists
  debug "Checking if NetworkPolicy \"$expected_np_name\" exists in namespace \"$expected_namespace\"."
  local np_json
  np_json="$(kubectl get networkpolicy "$expected_np_name" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Failed to get NetworkPolicy \"$expected_np_name\" in namespace \"$expected_namespace\"."
    failed
    return
  }

  # Check if the NetworkPolicy selects the correct pods (using the same selector as the service/deployment)
  debug "Checking if NetworkPolicy podSelector matches deployment pod template labels."
  local np_pod_selector_json
  np_pod_selector_json="$(echo "$np_json" | jq -c '.spec.podSelector.matchLabels' 2>/dev/null)" || {
    debug "Failed to extract podSelector.matchLabels from NetworkPolicy JSON."
    failed
    return
  }
  if [ "$np_pod_selector_json" != "$deploy_labels_json" ]; then
    debug "NetworkPolicy podSelector does not match deployment pod template labels. Expected: $deploy_labels_json, Found: $np_pod_selector_json"
    failed
    return
  fi

  # Check that there is exactly one entry in .spec.ingress[0].from
  debug "Checking that there is exactly one entry in NetworkPolicy ingress.from."
  local from_entries_count
  from_entries_count="$(echo "$np_json" | jq '.spec.ingress[0].from | length' 2>/dev/null)" || {
    debug "Failed to count ingress.from entries in NetworkPolicy JSON."
    failed
    return
  }
  if [ "$from_entries_count" -ne 1 ]; then
    debug "NetworkPolicy ingress.from should have exactly one entry, found $from_entries_count."
    failed
    return
  fi

  # Check the single entry for correct podSelector and optional namespaceSelector
  debug "Checking the single ingress.from entry for correct podSelector and optional namespaceSelector."
  local entry
  entry="$(echo "$np_json" | jq '.spec.ingress[0].from[0]' 2>/dev/null)" || {
    debug "Failed to extract the single ingress.from entry."
    failed
    return
  }
  local has_pod_selector
  has_pod_selector="$(echo "$entry" | jq 'has("podSelector")' 2>/dev/null)"
  if [ "$has_pod_selector" != "true" ]; then
    debug "The single ingress.from entry must have a podSelector."
    failed
    return
  fi
  local role_value
  role_value="$(echo "$entry" | jq -r '.podSelector.matchLabels.role // empty' 2>/dev/null)"
  if [ "$role_value" != "$expected_np_label_value" ]; then
    debug "podSelector.matchLabels.role mismatch: expected \"$expected_np_label_value\", found \"$role_value\"."
    failed
    return
  fi
  local has_ns_selector
  has_ns_selector="$(echo "$entry" | jq 'has("namespaceSelector")' 2>/dev/null)"
  if [ "$has_ns_selector" = "true" ]; then
    local ns_value
    ns_value="$(echo "$entry" | jq -r ".namespaceSelector.matchLabels[\"$expected_ns_selector_key\"] // empty" 2>/dev/null)"
    if [ "$ns_value" != "$expected_ns_selector_value" ]; then
      debug "namespaceSelector.matchLabels.$expected_ns_selector_key mismatch: expected \"$expected_ns_selector_value\", found \"$ns_value\"."
      failed
      return
    fi
  fi

  debug "All checks passed for Task $TASK_NUMBER. Service and NetworkPolicy are strictly and correctly configured for IP whitelisting."
  solved
  return
}

# shellcheck disable=SC2329
verify_task2() {
  TASK_NUMBER="2"
  local expected_namespace="net-policy"
  local expected_frontend_pod="frontend"
  local expected_frontend_image="nginx:1.25"
  local expected_backend_pod="backend"
  local expected_backend_image="hashicorp/http-echo:1.0"
  local expected_backend_args='["-text=backend"]'
  local expected_backend_port=5678
  local expected_service_name="backend-svc"
  local expected_service_port=8080
  local expected_np_name="deny-all"

  # Check if the namespace exists
  debug "Checking if namespace \"$expected_namespace\" exists."
  kubectl get namespace "$expected_namespace" -o json >/dev/null 2>&1 || {
    debug "Namespace \"$expected_namespace\" does not exist."
    failed
    return
  }

  # Check if the frontend pod exists and uses the correct image
  debug "Checking if frontend pod \"$expected_frontend_pod\" exists and uses image \"$expected_frontend_image\"."
  local frontend_pod_json
  frontend_pod_json="$(kubectl get pod "$expected_frontend_pod" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Failed to get frontend pod \"$expected_frontend_pod\" in namespace \"$expected_namespace\"."
    failed
    return
  }
  local frontend_image
  frontend_image="$(echo "$frontend_pod_json" | jq -r '.spec.containers[0].image' 2>/dev/null)" || {
    debug "Failed to extract image from frontend pod JSON."
    failed
    return
  }
  if [ "$frontend_image" != "$expected_frontend_image" ]; then
    debug "Frontend pod image mismatch: expected \"$expected_frontend_image\", found \"$frontend_image\"."
    failed
    return
  fi

  # Check if the backend pod exists and uses the correct image, args, and port
  debug "Checking if backend pod \"$expected_backend_pod\" exists and uses image \"$expected_backend_image\"."
  local backend_pod_json
  backend_pod_json="$(kubectl get pod "$expected_backend_pod" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Failed to get backend pod \"$expected_backend_pod\" in namespace \"$expected_namespace\"."
    failed
    return
  }
  local backend_image
  backend_image="$(echo "$backend_pod_json" | jq -r '.spec.containers[0].image' 2>/dev/null)" || {
    debug "Failed to extract image from backend pod JSON."
    failed
    return
  }
  if [ "$backend_image" != "$expected_backend_image" ]; then
    debug "Backend pod image mismatch: expected \"$expected_backend_image\", found \"$backend_image\"."
    failed
    return
  fi

  debug "Checking backend pod args."
  local backend_args
  backend_args="$(echo "$backend_pod_json" | jq -c '.spec.containers[0].args' 2>/dev/null)" || {
    debug "Failed to extract args from backend pod JSON."
    failed
    return
  }
  if [ "$backend_args" != "$expected_backend_args" ]; then
    debug "Backend pod args mismatch: expected $expected_backend_args, found $backend_args."
    failed
    return
  fi

  debug "Checking backend pod containerPort."
  local backend_port
  backend_port="$(echo "$backend_pod_json" | jq -r '.spec.containers[0].ports[0].containerPort' 2>/dev/null)" || {
    debug "Failed to extract containerPort from backend pod JSON."
    failed
    return
  }
  if [ "$backend_port" != "$expected_backend_port" ]; then
    debug "Backend pod containerPort mismatch: expected $expected_backend_port, found $backend_port."
    failed
    return
  fi

  # Check if the backend service exists and is of correct type and port
  debug "Checking if service \"$expected_service_name\" exists and exposes port $expected_service_port."
  local svc_json
  svc_json="$(kubectl get service "$expected_service_name" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Failed to get service \"$expected_service_name\" in namespace \"$expected_namespace\"."
    failed
    return
  }
  local svc_port
  svc_port="$(echo "$svc_json" | jq -r '.spec.ports[0].port' 2>/dev/null)" || {
    debug "Failed to extract service port from service JSON."
    failed
    return
  }
  if [ "$svc_port" != "$expected_service_port" ]; then
    debug "Service port mismatch: expected $expected_service_port, found $svc_port."
    failed
    return
  fi

  # Check if the NetworkPolicy exists
  debug "Checking if NetworkPolicy \"$expected_np_name\" exists."
  local np_json
  np_json="$(kubectl get networkpolicy "$expected_np_name" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Failed to get NetworkPolicy \"$expected_np_name\" in namespace \"$expected_namespace\"."
    failed
    return
  }

  # Check that the NetworkPolicy targets the backend pod
  debug "Checking if NetworkPolicy podSelector matches backend pod labels."
  local backend_labels_json
  backend_labels_json="$(echo "$backend_pod_json" | jq -c '.metadata.labels' 2>/dev/null)" || {
    debug "Failed to extract backend pod labels."
    failed
    return
  }
  local np_pod_selector_json
  np_pod_selector_json="$(echo "$np_json" | jq -c '.spec.podSelector.matchLabels' 2>/dev/null)" || {
    debug "Failed to extract podSelector.matchLabels from NetworkPolicy JSON."
    failed
    return
  }
  # The backend pod must match the podSelector
  local selector_match
  selector_match="$(echo "$backend_labels_json" | jq --argjson sel "$np_pod_selector_json" 'to_entries | map(select($sel[.key] == .value)) | length == ($sel | length)' 2>/dev/null)" || {
    debug "Failed to compare backend pod labels with NetworkPolicy podSelector."
    failed
    return
  }
  if [ "$selector_match" != "true" ]; then
    debug "NetworkPolicy podSelector does not match backend pod labels. Selector: $np_pod_selector_json, Pod labels: $backend_labels_json"
    failed
    return
  fi

  # Check that the NetworkPolicy denies all ingress except from frontend
  debug "Checking that NetworkPolicy denies all ingress except from frontend."
  local ingress_count
  ingress_count="$(echo "$np_json" | jq '.spec.ingress | length' 2>/dev/null)" || {
    debug "Failed to count ingress rules in NetworkPolicy."
    failed
    return
  }
  if [ "$ingress_count" -ne 1 ]; then
    debug "NetworkPolicy should have exactly one ingress rule, found $ingress_count."
    failed
    return
  fi

  local from_count
  from_count="$(echo "$np_json" | jq '.spec.ingress[0].from | length' 2>/dev/null)" || {
    debug "Failed to count from entries in NetworkPolicy ingress rule."
    failed
    return
  }
  if [ "$from_count" -ne 1 ]; then
    debug "NetworkPolicy ingress rule should have exactly one from entry, found $from_count."
    failed
    return
  fi

  local from_entry
  from_entry="$(echo "$np_json" | jq '.spec.ingress[0].from[0]' 2>/dev/null)" || {
    debug "Failed to extract from entry from NetworkPolicy ingress rule."
    failed
    return
  }
  local has_pod_selector
  has_pod_selector="$(echo "$from_entry" | jq 'has("podSelector")' 2>/dev/null)"
  if [ "$has_pod_selector" != "true" ]; then
    debug "NetworkPolicy ingress.from entry must have a podSelector."
    failed
    return
  fi

  # The podSelector must match the frontend pod's labels
  local frontend_labels_json
  frontend_labels_json="$(echo "$frontend_pod_json" | jq -c '.metadata.labels' 2>/dev/null)" || {
    debug "Failed to extract frontend pod labels."
    failed
    return
  }
  local from_pod_selector_json
  from_pod_selector_json="$(echo "$from_entry" | jq -c '.podSelector.matchLabels' 2>/dev/null)" || {
    debug "Failed to extract podSelector.matchLabels from NetworkPolicy ingress.from entry."
    failed
    return
  }
  local frontend_selector_match
  frontend_selector_match="$(echo "$frontend_labels_json" | jq --argjson sel "$from_pod_selector_json" 'to_entries | map(select($sel[.key] == .value)) | length == ($sel | length)' 2>/dev/null)" || {
    debug "Failed to compare frontend pod labels with NetworkPolicy ingress.from podSelector."
    failed
    return
  }
  if [ "$frontend_selector_match" != "true" ]; then
    debug "NetworkPolicy ingress.from podSelector does not match frontend pod labels. Selector: $from_pod_selector_json, Pod labels: $frontend_labels_json"
    failed
    return
  fi

  debug "All checks passed for Task $TASK_NUMBER. NetworkPolicy correctly restricts ingress to backend pod from frontend pod only."
  solved
  return
}

# shellcheck disable=SC2329
verify_task3() {
  TASK_NUMBER="3"
  local expected_namespace="netpol-demo1"
  local expected_backend_pod="backend"
  local expected_backend_label_key="app"
  local expected_backend_label_value="backend"
  local expected_backend_port=80
  local expected_frontend_pod="frontend"
  local expected_frontend_label_key="role"
  local expected_frontend_label_value="frontend"
  local expected_np_name="allow-frontend"

  # Check if the namespace exists
  debug "Checking if namespace \"$expected_namespace\" exists."
  kubectl get namespace "$expected_namespace" >/dev/null 2>&1 || {
    debug "Namespace \"$expected_namespace\" does not exist."
    failed
    return
  }

  # Check if the backend pod exists and has the correct label
  debug "Checking if backend pod \"$expected_backend_pod\" exists and has label \"$expected_backend_label_key: $expected_backend_label_value\"."
  local backend_pod_json
  backend_pod_json="$(kubectl get pod "$expected_backend_pod" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Failed to get backend pod \"$expected_backend_pod\" in namespace \"$expected_namespace\"."
    failed
    return
  }
  local backend_label_value
  backend_label_value="$(echo "$backend_pod_json" | jq -r ".metadata.labels[\"$expected_backend_label_key\"]" 2>/dev/null)" || {
    debug "Failed to extract backend pod label \"$expected_backend_label_key\"."
    failed
    return
  }
  if [ "$backend_label_value" != "$expected_backend_label_value" ]; then
    debug "Backend pod label mismatch: expected \"$expected_backend_label_key: $expected_backend_label_value\", found \"$expected_backend_label_key: $backend_label_value\"."
    failed
    return
  fi

  # Check if the backend pod exposes the correct port
  debug "Checking if backend pod exposes containerPort $expected_backend_port."
  local backend_port
  backend_port="$(echo "$backend_pod_json" | jq -r '.spec.containers[0].ports[0].containerPort' 2>/dev/null)" || {
    debug "Failed to extract backend pod containerPort."
    failed
    return
  }
  if [ "$backend_port" != "$expected_backend_port" ]; then
    debug "Backend pod containerPort mismatch: expected $expected_backend_port, found $backend_port."
    failed
    return
  fi

  # Check if the frontend pod exists and has the correct label
  debug "Checking if frontend pod \"$expected_frontend_pod\" exists and has label \"$expected_frontend_label_key: $expected_frontend_label_value\"."
  local frontend_pod_json
  frontend_pod_json="$(kubectl get pod "$expected_frontend_pod" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Failed to get frontend pod \"$expected_frontend_pod\" in namespace \"$expected_namespace\"."
    failed
    return
  }
  local frontend_label_value
  frontend_label_value="$(echo "$frontend_pod_json" | jq -r ".metadata.labels[\"$expected_frontend_label_key\"]" 2>/dev/null)" || {
    debug "Failed to extract frontend pod label \"$expected_frontend_label_key\"."
    failed
    return
  }
  if [ "$frontend_label_value" != "$expected_frontend_label_value" ]; then
    debug "Frontend pod label mismatch: expected \"$expected_frontend_label_key: $expected_frontend_label_value\", found \"$expected_frontend_label_key: $frontend_label_value\"."
    failed
    return
  fi

  # Check if the NetworkPolicy exists
  debug "Checking if NetworkPolicy \"$expected_np_name\" exists."
  local np_json
  np_json="$(kubectl get networkpolicy "$expected_np_name" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Failed to get NetworkPolicy \"$expected_np_name\" in namespace \"$expected_namespace\"."
    failed
    return
  }

  # Check that the NetworkPolicy targets the backend pod
  debug "Checking if NetworkPolicy podSelector matches backend pod labels."
  local backend_labels_json
  backend_labels_json="$(echo "$backend_pod_json" | jq -c '.metadata.labels' 2>/dev/null)" || {
    debug "Failed to extract backend pod labels."
    failed
    return
  }
  local np_pod_selector_json
  np_pod_selector_json="$(echo "$np_json" | jq -c '.spec.podSelector.matchLabels' 2>/dev/null)" || {
    debug "Failed to extract podSelector.matchLabels from NetworkPolicy JSON."
    failed
    return
  }
  local selector_match
  selector_match="$(echo "$backend_labels_json" | jq --argjson sel "$np_pod_selector_json" 'to_entries | map(select($sel[.key] == .value)) | length == ($sel | length)' 2>/dev/null)" || {
    debug "Failed to compare backend pod labels with NetworkPolicy podSelector."
    failed
    return
  }
  if [ "$selector_match" != "true" ]; then
    debug "NetworkPolicy podSelector does not match backend pod labels. Selector: $np_pod_selector_json, Pod labels: $backend_labels_json"
    failed
    return
  fi

  # Check that the NetworkPolicy allows ingress only from pods with label role=frontend on port 80
  debug "Checking that NetworkPolicy allows ingress only from pods with label \"$expected_frontend_label_key: $expected_frontend_label_value\" on port $expected_backend_port."
  local ingress_count
  ingress_count="$(echo "$np_json" | jq '.spec.ingress | length' 2>/dev/null)" || {
    debug "Failed to count ingress rules in NetworkPolicy."
    failed
    return
  }
  if [ "$ingress_count" -ne 1 ]; then
    debug "NetworkPolicy should have exactly one ingress rule, found $ingress_count."
    failed
    return
  fi

  local from_count
  from_count="$(echo "$np_json" | jq '.spec.ingress[0].from | length' 2>/dev/null)" || {
    debug "Failed to count from entries in NetworkPolicy ingress rule."
    failed
    return
  }
  if [ "$from_count" -ne 1 ]; then
    debug "NetworkPolicy ingress rule should have exactly one from entry, found $from_count."
    failed
    return
  fi

  local from_entry
  from_entry="$(echo "$np_json" | jq '.spec.ingress[0].from[0]' 2>/dev/null)" || {
    debug "Failed to extract from entry from NetworkPolicy ingress rule."
    failed
    return
  }
  local has_pod_selector
  has_pod_selector="$(echo "$from_entry" | jq 'has("podSelector")' 2>/dev/null)"
  if [ "$has_pod_selector" != "true" ]; then
    debug "NetworkPolicy ingress.from entry must have a podSelector."
    failed
    return
  fi

  # The podSelector must match the frontend pod's labels
  local frontend_labels_json
  frontend_labels_json="$(echo "$frontend_pod_json" | jq -c '.metadata.labels' 2>/dev/null)" || {
    debug "Failed to extract frontend pod labels."
    failed
    return
  }
  local from_pod_selector_json
  from_pod_selector_json="$(echo "$from_entry" | jq -c '.podSelector.matchLabels' 2>/dev/null)" || {
    debug "Failed to extract podSelector.matchLabels from NetworkPolicy ingress.from entry."
    failed
    return
  }
  local frontend_selector_match
  frontend_selector_match="$(echo "$frontend_labels_json" | jq --argjson sel "$from_pod_selector_json" 'to_entries | map(select($sel[.key] == .value)) | length == ($sel | length)' 2>/dev/null)" || {
    debug "Failed to compare frontend pod labels with NetworkPolicy ingress.from podSelector."
    failed
    return
  }
  if [ "$frontend_selector_match" != "true" ]; then
    debug "NetworkPolicy ingress.from podSelector does not match frontend pod labels. Selector: $from_pod_selector_json, Pod labels: $frontend_labels_json"
    failed
    return
  fi

  # Check that the NetworkPolicy only allows port 80
  debug "Checking that NetworkPolicy only allows port $expected_backend_port."
  local ports_count
  ports_count="$(echo "$np_json" | jq '.spec.ingress[0].ports | length' 2>/dev/null)" || {
    debug "Failed to count ports in NetworkPolicy ingress rule."
    failed
    return
  }
  if [ "$ports_count" -ne 1 ]; then
    debug "NetworkPolicy ingress rule should have exactly one port entry, found $ports_count."
    failed
    return
  fi
  local port_value
  port_value="$(echo "$np_json" | jq -r '.spec.ingress[0].ports[0].port' 2>/dev/null)" || {
    debug "Failed to extract port from NetworkPolicy ingress rule."
    failed
    return
  }
  if [ "$port_value" != "$expected_backend_port" ]; then
    debug "NetworkPolicy ingress rule port mismatch: expected $expected_backend_port, found $port_value."
    failed
    return
  fi

  debug "All checks passed for Task $TASK_NUMBER. NetworkPolicy correctly restricts backend access to pods with label \"$expected_frontend_label_key: $expected_frontend_label_value\" on port $expected_backend_port."
  solved
  return
}

# shellcheck disable=SC2329
verify_task4() {
  TASK_NUMBER="4"
  local expected_namespace="netpol-demo2"
  local expected_pod_name="isolated"
  local expected_np_name="deny-all-except-dns"
  local expected_dns_port=53
  local expected_dns_protocol="UDP"

  # Check if the namespace exists
  debug "Checking if namespace \"$expected_namespace\" exists."
  kubectl get namespace "$expected_namespace" >/dev/null 2>&1 || {
    debug "Namespace \"$expected_namespace\" does not exist."
    failed
    return
  }

  # Check if the isolated pod exists
  debug "Checking if pod \"$expected_pod_name\" exists."
  local pod_json
  pod_json="$(kubectl get pod "$expected_pod_name" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Failed to get pod \"$expected_pod_name\" in namespace \"$expected_namespace\"."
    failed
    return
  }

  # Check if the NetworkPolicy exists
  debug "Checking if NetworkPolicy \"$expected_np_name\" exists."
  local np_json
  np_json="$(kubectl get networkpolicy "$expected_np_name" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Failed to get NetworkPolicy \"$expected_np_name\" in namespace \"$expected_namespace\"."
    failed
    return
  }

  # Check that the NetworkPolicy targets the isolated pod or all pods (podSelector: {})
  debug "Checking if NetworkPolicy podSelector targets the isolated pod or all pods."
  local np_pod_selector
  np_pod_selector="$(echo "$np_json" | jq '.spec.podSelector' 2>/dev/null)" || {
    debug "Failed to extract podSelector from NetworkPolicy JSON."
    failed
    return
  }
  local np_pod_selector_matchlabels
  np_pod_selector_matchlabels="$(echo "$np_json" | jq '.spec.podSelector.matchLabels' 2>/dev/null)" || {
    debug "Failed to extract podSelector.matchLabels from NetworkPolicy JSON."
    failed
    return
  }
  local pod_labels_json
  pod_labels_json="$(echo "$pod_json" | jq '.metadata.labels' 2>/dev/null)" || {
    debug "Failed to extract isolated pod labels."
    failed
    return
  }
  # Accept if podSelector is {} or podSelector.matchLabels is {} or matches pod's labels
  local selector_ok="false"
  if [ "$np_pod_selector" = "{}" ] || [ "$np_pod_selector_matchlabels" = "{}" ]; then
    selector_ok="true"
  else
    # Compare matchLabels with pod labels
    local selector_match
    selector_match="$(echo "$pod_labels_json" | jq --argjson sel "$np_pod_selector_matchlabels" 'to_entries | map(select($sel[.key] == .value)) | length == ($sel | length)' 2>/dev/null)" || {
      debug "Failed to compare isolated pod labels with NetworkPolicy podSelector."
      failed
      return
    }
    if [ "$selector_match" = "true" ]; then
      selector_ok="true"
    fi
  fi
  if [ "$selector_ok" != "true" ]; then
    debug "NetworkPolicy podSelector does not target the isolated pod or all pods. podSelector: $np_pod_selector, pod labels: $pod_labels_json"
    failed
    return
  fi

  # Check that the NetworkPolicy denies all ingress (no ingress rules)
  debug "Checking that NetworkPolicy denies all ingress."
  local ingress_exists
  ingress_exists="$(echo "$np_json" | jq '.spec | has("ingress")' 2>/dev/null)" || {
    debug "Failed to check for ingress rules in NetworkPolicy."
    failed
    return
  }
  if [ "$ingress_exists" = "true" ]; then
    local ingress_length
    ingress_length="$(echo "$np_json" | jq '.spec.ingress | length' 2>/dev/null)"
    if [ "$ingress_length" -ne 0 ]; then
      debug "NetworkPolicy should deny all ingress (no ingress rules), but found $ingress_length ingress rule(s)."
      failed
      return
    fi
  fi

  # Check that the NetworkPolicy allows only egress to DNS (UDP port 53)
  debug "Checking that NetworkPolicy allows only egress to DNS (UDP port 53)."
  local egress_exists
  egress_exists="$(echo "$np_json" | jq '.spec | has("egress")' 2>/dev/null)" || {
    debug "Failed to check for egress rules in NetworkPolicy."
    failed
    return
  }
  if [ "$egress_exists" != "true" ]; then
    debug "NetworkPolicy must have an egress rule allowing DNS."
    failed
    return
  fi
  local egress_length
  egress_length="$(echo "$np_json" | jq '.spec.egress | length' 2>/dev/null)" || {
    debug "Failed to count egress rules in NetworkPolicy."
    failed
    return
  }
  if [ "$egress_length" -ne 1 ]; then
    debug "NetworkPolicy should have exactly one egress rule, found $egress_length."
    failed
    return
  fi

  local egress_ports_length
  egress_ports_length="$(echo "$np_json" | jq '.spec.egress[0].ports | length' 2>/dev/null)" || {
    debug "Failed to count ports in NetworkPolicy egress rule."
    failed
    return
  }
  if [ "$egress_ports_length" -ne 1 ]; then
    debug "NetworkPolicy egress rule should have exactly one port entry, found $egress_ports_length."
    failed
    return
  fi

  local egress_port
  egress_port="$(echo "$np_json" | jq -r '.spec.egress[0].ports[0].port' 2>/dev/null)" || {
    debug "Failed to extract port from NetworkPolicy egress rule."
    failed
    return
  }
  if [ "$egress_port" != "$expected_dns_port" ]; then
    debug "NetworkPolicy egress rule port mismatch: expected $expected_dns_port, found $egress_port."
    failed
    return
  fi

  local egress_protocol
  egress_protocol="$(echo "$np_json" | jq -r '.spec.egress[0].ports[0].protocol' 2>/dev/null)" || {
    debug "Failed to extract protocol from NetworkPolicy egress rule."
    failed
    return
  }
  if [ "$egress_protocol" != "$expected_dns_protocol" ]; then
    debug "NetworkPolicy egress rule protocol mismatch: expected $expected_dns_protocol, found $egress_protocol."
    failed
    return
  fi

  # Check that policyTypes includes both Ingress and Egress
  debug "Checking that NetworkPolicy policyTypes includes both Ingress and Egress."
  local policy_types
  policy_types="$(echo "$np_json" | jq -c '.spec.policyTypes' 2>/dev/null)" || {
    debug "Failed to extract policyTypes from NetworkPolicy."
    failed
    return
  }
  local has_ingress
  has_ingress="$(echo "$policy_types" | jq 'index("Ingress")' 2>/dev/null)"
  local has_egress
  has_egress="$(echo "$policy_types" | jq 'index("Egress")' 2>/dev/null)"
  if [ "$has_ingress" = "null" ] || [ "$has_egress" = "null" ]; then
    debug "NetworkPolicy policyTypes must include both \"Ingress\" and \"Egress\". Found: $policy_types"
    failed
    return
  fi

  debug "All checks passed for Task $TASK_NUMBER. NetworkPolicy correctly denies all ingress and egress except DNS."
  solved
  return
}

# shellcheck disable=SC2329
verify_task5() {
  TASK_NUMBER="5"
  local expected_namespace="netpol-demo3"
  local expected_pod_name="api-server"
  local expected_pod_label_key="app"
  local expected_pod_label_value="api-server"
  local expected_np_name="allow-from-trusted-ns"
  local expected_trusted_ns="trusted-ns"
  local expected_ns_selector_key="kubernetes.io/metadata.name"

  # Check if the namespace exists
  debug "Checking if namespace \"$expected_namespace\" exists."
  kubectl get namespace "$expected_namespace" >/dev/null 2>&1 || {
    debug "Namespace \"$expected_namespace\" does not exist."
    failed
    return
  }

  # Check if the api-server pod exists and has the correct label
  debug "Checking if pod \"$expected_pod_name\" exists and has label \"$expected_pod_label_key: $expected_pod_label_value\"."
  local pod_json
  pod_json="$(kubectl get pod "$expected_pod_name" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Failed to get pod \"$expected_pod_name\" in namespace \"$expected_namespace\"."
    failed
    return
  }
  local pod_label_value
  pod_label_value="$(echo "$pod_json" | jq -r ".metadata.labels[\"$expected_pod_label_key\"]" 2>/dev/null)" || {
    debug "Failed to extract pod label \"$expected_pod_label_key\"."
    failed
    return
  }
  if [ "$pod_label_value" != "$expected_pod_label_value" ]; then
    debug "Pod label mismatch: expected \"$expected_pod_label_key: $expected_pod_label_value\", found \"$expected_pod_label_key: $pod_label_value\"."
    failed
    return
  fi

  # Check if the NetworkPolicy exists
  debug "Checking if NetworkPolicy \"$expected_np_name\" exists."
  local np_json
  np_json="$(kubectl get networkpolicy "$expected_np_name" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Failed to get NetworkPolicy \"$expected_np_name\" in namespace \"$expected_namespace\"."
    failed
    return
  }

  # Check that the NetworkPolicy targets the api-server pod
  debug "Checking if NetworkPolicy podSelector matches api-server pod labels."
  local pod_labels_json
  pod_labels_json="$(echo "$pod_json" | jq -c '.metadata.labels' 2>/dev/null)" || {
    debug "Failed to extract api-server pod labels."
    failed
    return
  }
  local np_pod_selector_json
  np_pod_selector_json="$(echo "$np_json" | jq -c '.spec.podSelector.matchLabels' 2>/dev/null)" || {
    debug "Failed to extract podSelector.matchLabels from NetworkPolicy JSON."
    failed
    return
  }
  local selector_match
  selector_match="$(echo "$pod_labels_json" | jq --argjson sel "$np_pod_selector_json" 'to_entries | map(select($sel[.key] == .value)) | length == ($sel | length)' 2>/dev/null)" || {
    debug "Failed to compare api-server pod labels with NetworkPolicy podSelector."
    failed
    return
  }
  if [ "$selector_match" != "true" ]; then
    debug "NetworkPolicy podSelector does not match api-server pod labels. Selector: $np_pod_selector_json, Pod labels: $pod_labels_json"
    failed
    return
  fi

  # Check that the NetworkPolicy allows ingress only from pods in the trusted-ns namespace
  debug "Checking that NetworkPolicy allows ingress only from pods in namespace \"$expected_trusted_ns\"."
  local ingress_count
  ingress_count="$(echo "$np_json" | jq '.spec.ingress | length' 2>/dev/null)" || {
    debug "Failed to count ingress rules in NetworkPolicy."
    failed
    return
  }
  if [ "$ingress_count" -ne 1 ]; then
    debug "NetworkPolicy should have exactly one ingress rule, found $ingress_count."
    failed
    return
  fi

  local from_count
  from_count="$(echo "$np_json" | jq '.spec.ingress[0].from | length' 2>/dev/null)" || {
    debug "Failed to count from entries in NetworkPolicy ingress rule."
    failed
    return
  }
  if [ "$from_count" -ne 1 ]; then
    debug "NetworkPolicy ingress rule should have exactly one from entry, found $from_count."
    failed
    return
  fi

  local from_entry
  from_entry="$(echo "$np_json" | jq '.spec.ingress[0].from[0]' 2>/dev/null)" || {
    debug "Failed to extract from entry from NetworkPolicy ingress rule."
    failed
    return
  }
  local has_ns_selector
  has_ns_selector="$(echo "$from_entry" | jq 'has("namespaceSelector")' 2>/dev/null)"
  if [ "$has_ns_selector" != "true" ]; then
    debug "NetworkPolicy ingress.from entry must have a namespaceSelector."
    failed
    return
  fi

  local ns_selector_value
  ns_selector_value="$(echo "$from_entry" | jq -r ".namespaceSelector.matchLabels[\"$expected_ns_selector_key\"] // empty" 2>/dev/null)"
  if [ "$ns_selector_value" != "$expected_trusted_ns" ]; then
    debug "namespaceSelector.matchLabels.$expected_ns_selector_key mismatch: expected \"$expected_trusted_ns\", found \"$ns_selector_value\"."
    failed
    return
  fi

  debug "All checks passed for Task $TASK_NUMBER. NetworkPolicy correctly allows ingress only from pods in namespace \"$expected_trusted_ns\"."
  solved
  return
}

# shellcheck disable=SC2329
verify_task6() {
  TASK_NUMBER="6"
  local expected_namespace="netpol-demo4"
  local expected_web_pod="web"
  local expected_web_label_key="app"
  local expected_web_label_value="web"
  local expected_client_pod="client"
  local expected_client_label_key="access"
  local expected_client_label_value="web"
  local expected_np_name="http-only-from-client"
  local expected_port=80

  # Check if the namespace exists
  debug "Checking if namespace \"$expected_namespace\" exists."
  kubectl get namespace "$expected_namespace" >/dev/null 2>&1 || {
    debug "Namespace \"$expected_namespace\" does not exist."
    failed
    return
  }

  # Check if the web pod exists and has the correct label
  debug "Checking if web pod \"$expected_web_pod\" exists and has label \"$expected_web_label_key: $expected_web_label_value\"."
  local web_pod_json
  web_pod_json="$(kubectl get pod "$expected_web_pod" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Failed to get web pod \"$expected_web_pod\" in namespace \"$expected_namespace\"."
    failed
    return
  }
  local web_label_value
  web_label_value="$(echo "$web_pod_json" | jq -r ".metadata.labels[\"$expected_web_label_key\"]" 2>/dev/null)" || {
    debug "Failed to extract web pod label \"$expected_web_label_key\"."
    failed
    return
  }
  if [ "$web_label_value" != "$expected_web_label_value" ]; then
    debug "Web pod label mismatch: expected \"$expected_web_label_key: $expected_web_label_value\", found \"$expected_web_label_key: $web_label_value\"."
    failed
    return
  fi

  # Check if the client pod exists and has the correct label
  debug "Checking if client pod \"$expected_client_pod\" exists and has label \"$expected_client_label_key: $expected_client_label_value\"."
  local client_pod_json
  client_pod_json="$(kubectl get pod "$expected_client_pod" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Failed to get client pod \"$expected_client_pod\" in namespace \"$expected_namespace\"."
    failed
    return
  }
  local client_label_value
  client_label_value="$(echo "$client_pod_json" | jq -r ".metadata.labels[\"$expected_client_label_key\"]" 2>/dev/null)" || {
    debug "Failed to extract client pod label \"$expected_client_label_key\"."
    failed
    return
  }
  if [ "$client_label_value" != "$expected_client_label_value" ]; then
    debug "Client pod label mismatch: expected \"$expected_client_label_key: $expected_client_label_value\", found \"$expected_client_label_key: $client_label_value\"."
    failed
    return
  fi

  # Check if the NetworkPolicy exists
  debug "Checking if NetworkPolicy \"$expected_np_name\" exists."
  local np_json
  np_json="$(kubectl get networkpolicy "$expected_np_name" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Failed to get NetworkPolicy \"$expected_np_name\" in namespace \"$expected_namespace\"."
    failed
    return
  }

  # Check that the NetworkPolicy targets the web pod
  debug "Checking if NetworkPolicy podSelector matches web pod labels."
  local web_labels_json
  web_labels_json="$(echo "$web_pod_json" | jq -c '.metadata.labels' 2>/dev/null)" || {
    debug "Failed to extract web pod labels."
    failed
    return
  }
  local np_pod_selector_json
  np_pod_selector_json="$(echo "$np_json" | jq -c '.spec.podSelector.matchLabels' 2>/dev/null)" || {
    debug "Failed to extract podSelector.matchLabels from NetworkPolicy JSON."
    failed
    return
  }
  local selector_match
  selector_match="$(echo "$web_labels_json" | jq --argjson sel "$np_pod_selector_json" 'to_entries | map(select($sel[.key] == .value)) | length == ($sel | length)' 2>/dev/null)" || {
    debug "Failed to compare web pod labels with NetworkPolicy podSelector."
    failed
    return
  }
  if [ "$selector_match" != "true" ]; then
    debug "NetworkPolicy podSelector does not match web pod labels. Selector: $np_pod_selector_json, Pod labels: $web_labels_json"
    failed
    return
  fi

  # Check that the NetworkPolicy allows ingress only from pods with label access=web on port 80
  debug "Checking that NetworkPolicy allows ingress only from pods with label \"$expected_client_label_key: $expected_client_label_value\" on port $expected_port."
  local ingress_count
  ingress_count="$(echo "$np_json" | jq '.spec.ingress | length' 2>/dev/null)" || {
    debug "Failed to count ingress rules in NetworkPolicy."
    failed
    return
  }
  if [ "$ingress_count" -ne 1 ]; then
    debug "NetworkPolicy should have exactly one ingress rule, found $ingress_count."
    failed
    return
  fi

  local from_count
  from_count="$(echo "$np_json" | jq '.spec.ingress[0].from | length' 2>/dev/null)" || {
    debug "Failed to count from entries in NetworkPolicy ingress rule."
    failed
    return
  }
  if [ "$from_count" -ne 1 ]; then
    debug "NetworkPolicy ingress rule should have exactly one from entry, found $from_count."
    failed
    return
  fi

  local from_entry
  from_entry="$(echo "$np_json" | jq '.spec.ingress[0].from[0]' 2>/dev/null)" || {
    debug "Failed to extract from entry from NetworkPolicy ingress rule."
    failed
    return
  }
  local has_pod_selector
  has_pod_selector="$(echo "$from_entry" | jq 'has("podSelector")' 2>/dev/null)"
  if [ "$has_pod_selector" != "true" ]; then
    debug "NetworkPolicy ingress.from entry must have a podSelector."
    failed
    return
  fi

  # The podSelector must match the client pod's labels
  local client_labels_json
  client_labels_json="$(echo "$client_pod_json" | jq -c '.metadata.labels' 2>/dev/null)" || {
    debug "Failed to extract client pod labels."
    failed
    return
  }
  local from_pod_selector_json
  from_pod_selector_json="$(echo "$from_entry" | jq -c '.podSelector.matchLabels' 2>/dev/null)" || {
    debug "Failed to extract podSelector.matchLabels from NetworkPolicy ingress.from entry."
    failed
    return
  }
  local client_selector_match
  client_selector_match="$(echo "$client_labels_json" | jq --argjson sel "$from_pod_selector_json" 'to_entries | map(select($sel[.key] == .value)) | length == ($sel | length)' 2>/dev/null)" || {
    debug "Failed to compare client pod labels with NetworkPolicy ingress.from podSelector."
    failed
    return
  }
  if [ "$client_selector_match" != "true" ]; then
    debug "NetworkPolicy ingress.from podSelector does not match client pod labels. Selector: $from_pod_selector_json, Pod labels: $client_labels_json"
    failed
    return
  fi

  # Check that the NetworkPolicy only allows port 80
  debug "Checking that NetworkPolicy only allows port $expected_port."
  local ports_count
  ports_count="$(echo "$np_json" | jq '.spec.ingress[0].ports | length' 2>/dev/null)" || {
    debug "Failed to count ports in NetworkPolicy ingress rule."
    failed
    return
  }
  if [ "$ports_count" -ne 1 ]; then
    debug "NetworkPolicy ingress rule should have exactly one port entry, found $ports_count."
    failed
    return
  fi
  local port_value
  port_value="$(echo "$np_json" | jq -r '.spec.ingress[0].ports[0].port' 2>/dev/null)" || {
    debug "Failed to extract port from NetworkPolicy ingress rule."
    failed
    return
  }
  if [ "$port_value" != "$expected_port" ]; then
    debug "NetworkPolicy ingress rule port mismatch: expected $expected_port, found $port_value."
    failed
    return
  fi

  debug "All checks passed for Task $TASK_NUMBER. NetworkPolicy correctly allows only HTTP traffic from pods with label \"$expected_client_label_key: $expected_client_label_value\"."
  solved
  return
}

# shellcheck disable=SC2329
verify_task7() {
  TASK_NUMBER="7"
  local expected_namespace="netpol-demo5"
  local expected_pod_name="egress-pod"
  local expected_np_name="allow-egress-external"
  local expected_ip_block="8.8.8.8/32"
  local expected_port=53
  local expected_protocol="TCP"

  # Check if the namespace exists
  debug "Checking if namespace \"$expected_namespace\" exists."
  kubectl get namespace "$expected_namespace" >/dev/null 2>&1 || {
    debug "Namespace \"$expected_namespace\" does not exist."
    failed
    return
  }

  # Check if the egress-pod exists
  debug "Checking if pod \"$expected_pod_name\" exists."
  local pod_json
  pod_json="$(kubectl get pod "$expected_pod_name" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Failed to get pod \"$expected_pod_name\" in namespace \"$expected_namespace\"."
    failed
    return
  }

  # Check if the NetworkPolicy exists
  debug "Checking if NetworkPolicy \"$expected_np_name\" exists."
  local np_json
  np_json="$(kubectl get networkpolicy "$expected_np_name" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Failed to get NetworkPolicy \"$expected_np_name\" in namespace \"$expected_namespace\"."
    failed
    return
  }

  # Check that the NetworkPolicy targets the egress-pod or all pods (podSelector: {})
  debug "Checking if NetworkPolicy podSelector targets the egress-pod or all pods."
  local np_pod_selector
  np_pod_selector="$(echo "$np_json" | jq '.spec.podSelector' 2>/dev/null)" || {
    debug "Failed to extract podSelector from NetworkPolicy JSON."
    failed
    return
  }
  local np_pod_selector_matchlabels
  np_pod_selector_matchlabels="$(echo "$np_json" | jq '.spec.podSelector.matchLabels' 2>/dev/null)" || {
    debug "Failed to extract podSelector.matchLabels from NetworkPolicy JSON."
    failed
    return
  }
  local pod_labels_json
  pod_labels_json="$(echo "$pod_json" | jq '.metadata.labels' 2>/dev/null)" || {
    debug "Failed to extract egress-pod labels."
    failed
    return
  }
  local selector_ok="false"
  if [ "$np_pod_selector" = "{}" ] || [ "$np_pod_selector_matchlabels" = "{}" ]; then
    selector_ok="true"
  else
    local selector_match
    selector_match="$(echo "$pod_labels_json" | jq --argjson sel "$np_pod_selector_matchlabels" 'to_entries | map(select($sel[.key] == .value)) | length == ($sel | length)' 2>/dev/null)" || {
      debug "Failed to compare egress-pod labels with NetworkPolicy podSelector."
      failed
      return
    }
    if [ "$selector_match" = "true" ]; then
      selector_ok="true"
    fi
  fi
  if [ "$selector_ok" != "true" ]; then
    debug "NetworkPolicy podSelector does not target the egress-pod or all pods. podSelector: $np_pod_selector, pod labels: $pod_labels_json"
    failed
    return
  fi

  # Check that the NetworkPolicy allows only egress to 8.8.8.8/32 on TCP port 53
  debug "Checking that NetworkPolicy allows only egress to $expected_ip_block on $expected_protocol port $expected_port."
  local egress_exists
  egress_exists="$(echo "$np_json" | jq '.spec | has("egress")' 2>/dev/null)" || {
    debug "Failed to check for egress rules in NetworkPolicy."
    failed
    return
  }
  if [ "$egress_exists" != "true" ]; then
    debug "NetworkPolicy must have an egress rule."
    failed
    return
  fi
  local egress_length
  egress_length="$(echo "$np_json" | jq '.spec.egress | length' 2>/dev/null)" || {
    debug "Failed to count egress rules in NetworkPolicy."
    failed
    return
  }
  if [ "$egress_length" -ne 1 ]; then
    debug "NetworkPolicy should have exactly one egress rule, found $egress_length."
    failed
    return
  fi

  local to_count
  to_count="$(echo "$np_json" | jq '.spec.egress[0].to | length' 2>/dev/null)" || {
    debug "Failed to count to entries in NetworkPolicy egress rule."
    failed
    return
  }
  if [ "$to_count" -ne 1 ]; then
    debug "NetworkPolicy egress rule should have exactly one to entry, found $to_count."
    failed
    return
  fi

  local to_entry
  to_entry="$(echo "$np_json" | jq '.spec.egress[0].to[0]' 2>/dev/null)" || {
    debug "Failed to extract to entry from NetworkPolicy egress rule."
    failed
    return
  }
  local has_ip_block
  has_ip_block="$(echo "$to_entry" | jq 'has("ipBlock")' 2>/dev/null)"
  if [ "$has_ip_block" != "true" ]; then
    debug "NetworkPolicy egress.to entry must have an ipBlock."
    failed
    return
  fi

  local ip_block_cidr
  ip_block_cidr="$(echo "$to_entry" | jq -r '.ipBlock.cidr' 2>/dev/null)" || {
    debug "Failed to extract ipBlock.cidr from NetworkPolicy egress.to entry."
    failed
    return
  }
  if [ "$ip_block_cidr" != "$expected_ip_block" ]; then
    debug "NetworkPolicy egress.to ipBlock.cidr mismatch: expected $expected_ip_block, found $ip_block_cidr."
    failed
    return
  fi

  local egress_ports_length
  egress_ports_length="$(echo "$np_json" | jq '.spec.egress[0].ports | length' 2>/dev/null)" || {
    debug "Failed to count ports in NetworkPolicy egress rule."
    failed
    return
  }
  if [ "$egress_ports_length" -ne 1 ]; then
    debug "NetworkPolicy egress rule should have exactly one port entry, found $egress_ports_length."
    failed
    return
  fi

  local egress_port
  egress_port="$(echo "$np_json" | jq -r '.spec.egress[0].ports[0].port' 2>/dev/null)" || {
    debug "Failed to extract port from NetworkPolicy egress rule."
    failed
    return
  }
  if [ "$egress_port" != "$expected_port" ]; then
    debug "NetworkPolicy egress rule port mismatch: expected $expected_port, found $egress_port."
    failed
    return
  fi

  local egress_protocol
  egress_protocol="$(echo "$np_json" | jq -r '.spec.egress[0].ports[0].protocol' 2>/dev/null)" || {
    debug "Failed to extract protocol from NetworkPolicy egress rule."
    failed
    return
  }
  if [ "$egress_protocol" != "$expected_protocol" ]; then
    debug "NetworkPolicy egress rule protocol mismatch: expected $expected_protocol, found $egress_protocol."
    failed
    return
  fi

  # Check that policyTypes includes Egress
  debug "Checking that NetworkPolicy policyTypes includes Egress."
  local policy_types
  policy_types="$(echo "$np_json" | jq -c '.spec.policyTypes' 2>/dev/null)" || {
    debug "Failed to extract policyTypes from NetworkPolicy."
    failed
    return
  }
  local has_egress
  has_egress="$(echo "$policy_types" | jq 'index("Egress")' 2>/dev/null)"
  if [ "$has_egress" = "null" ]; then
    debug "NetworkPolicy policyTypes must include \"Egress\". Found: $policy_types"
    failed
    return
  fi

  debug "All checks passed for Task $TASK_NUMBER. NetworkPolicy correctly allows egress only to $expected_ip_block on $expected_protocol port $expected_port."
  solved
  return
}

# shellcheck disable=SC2329
verify_task8() {
  # Non-local variable for task number
  TASK_NUMBER="8"

  # Local variables with predefined expected values
  local EXPECTED_NAMESPACE="netpol-demo6"
  local EXPECTED_POD_A_NAME="pod-a"
  local EXPECTED_POD_B_NAME="pod-b"
  local EXPECTED_NETWORK_POLICY_NAME="internal-only"
  local EXPECTED_NAMESPACE_LABEL_KEY="kubernetes.io/metadata.name"
  local EXPECTED_NAMESPACE_LABEL_VALUE="${EXPECTED_NAMESPACE}"

  debug "Starting verification for Task ${TASK_NUMBER}."

  # Step 1: Verify Namespace existence
  debug "Checking if namespace '${EXPECTED_NAMESPACE}' exists."
  kubectl get namespace "${EXPECTED_NAMESPACE}" -o json >/dev/null 2>&1 || {
    debug "Namespace '${EXPECTED_NAMESPACE}' not found."
    failed
    return
  }
  debug "Namespace '${EXPECTED_NAMESPACE}' found."

  # Step 2: Verify Pod-A existence and status
  debug "Checking if pod '${EXPECTED_POD_A_NAME}' exists in namespace '${EXPECTED_NAMESPACE}' and is in a ready state."
  local pod_a_json
  pod_a_json=$(kubectl get pod "${EXPECTED_POD_A_NAME}" -n "${EXPECTED_NAMESPACE}" -o json 2>/dev/null) || {
    debug "Pod '${EXPECTED_POD_A_NAME}' not found in namespace '${EXPECTED_NAMESPACE}'."
    failed
    return
  }
  local pod_a_status
  pod_a_status=$(echo "${pod_a_json}" | jq -r '.status.phase' 2>/dev/null) || {
    debug "Failed to extract status for pod '${EXPECTED_POD_A_NAME}'."
    failed
    return
  }
  if [[ "${pod_a_status}" != "Running" && "${pod_a_status}" != "Pending" && "${pod_a_status}" != "Succeeded" ]]; then
    debug "Pod '${EXPECTED_POD_A_NAME}' is not in a ready state. Current status: ${pod_a_status}."
    failed
    return
  fi
  debug "Pod '${EXPECTED_POD_A_NAME}' found and its status is '${pod_a_status}'."

  # Step 3: Verify Pod-B existence and status
  debug "Checking if pod '${EXPECTED_POD_B_NAME}' exists in namespace '${EXPECTED_NAMESPACE}' and is in a ready state."
  local pod_b_json
  pod_b_json=$(kubectl get pod "${EXPECTED_POD_B_NAME}" -n "${EXPECTED_NAMESPACE}" -o json 2>/dev/null) || {
    debug "Pod '${EXPECTED_POD_B_NAME}' not found in namespace '${EXPECTED_NAMESPACE}'."
    failed
    return
  }
  local pod_b_status
  pod_b_status=$(echo "${pod_b_json}" | jq -r '.status.phase' 2>/dev/null) || {
    debug "Failed to extract status for pod '${EXPECTED_POD_B_NAME}'."
    failed
    return
  }
  if [[ "${pod_b_status}" != "Running" && "${pod_b_status}" != "Pending" && "${pod_b_status}" != "Succeeded" ]]; then
    debug "Pod '${EXPECTED_POD_B_NAME}' is not in a ready state. Current status: ${pod_b_status}."
    failed
    return
  fi
  debug "Pod '${EXPECTED_POD_B_NAME}' found and its status is '${pod_b_status}'."

  # Step 4: Verify NetworkPolicy existence
  debug "Checking if NetworkPolicy '${EXPECTED_NETWORK_POLICY_NAME}' exists in namespace '${EXPECTED_NAMESPACE}'."
  local netpol_json
  netpol_json=$(kubectl get networkpolicy "${EXPECTED_NETWORK_POLICY_NAME}" -n "${EXPECTED_NAMESPACE}" -o json 2>/dev/null) || {
    debug "NetworkPolicy '${EXPECTED_NETWORK_POLICY_NAME}' not found in namespace '${EXPECTED_NAMESPACE}'."
    failed
    return
  }
  debug "NetworkPolicy '${EXPECTED_NETWORK_POLICY_NAME}' found."

  # Step 5: Verify NetworkPolicy podSelector is empty
  debug "Checking if NetworkPolicy '${EXPECTED_NETWORK_POLICY_NAME}' has an empty podSelector."
  local np_pod_selector_length
  np_pod_selector_length=$(echo "${netpol_json}" | jq -r '.spec.podSelector | to_entries | length' 2>/dev/null) || {
    debug "Failed to extract podSelector from NetworkPolicy JSON."
    failed
    return
  }
  if [[ "${np_pod_selector_length}" -ne 0 ]]; then
    debug "NetworkPolicy '${EXPECTED_NETWORK_POLICY_NAME}' podSelector is not empty. Found: $(echo "${netpol_json}" | jq -c '.spec.podSelector' 2>/dev/null)."
    failed
    return
  fi
  debug "NetworkPolicy '${EXPECTED_NETWORK_POLICY_NAME}' has an empty podSelector."

  # Step 6: Verify NetworkPolicy policyTypes includes Ingress
  debug "Checking if NetworkPolicy '${EXPECTED_NETWORK_POLICY_NAME}' policyTypes includes 'Ingress'."
  local np_policy_types_ingress_count
  np_policy_types_ingress_count=$(echo "${netpol_json}" | jq -r '.spec.policyTypes[]' 2>/dev/null | grep -c "Ingress") || {
    debug "Failed to extract policyTypes from NetworkPolicy JSON."
    failed
    return
  }
  if [[ "${np_policy_types_ingress_count}" -eq 0 ]]; then
    debug "NetworkPolicy '${EXPECTED_NETWORK_POLICY_NAME}' policyTypes does not include 'Ingress'. Found: $(echo "${netpol_json}" | jq -c '.spec.policyTypes' 2>/dev/null)."
    failed
    return
  fi
  debug "NetworkPolicy '${EXPECTED_NETWORK_POLICY_NAME}' policyTypes includes 'Ingress'."

  # Step 7: Verify NetworkPolicy ingress rules for internal communication
  debug "Checking NetworkPolicy '${EXPECTED_NETWORK_POLICY_NAME}' ingress rules."
  local np_ingress_rules_count
  np_ingress_rules_count=$(echo "${netpol_json}" | jq -r '.spec.ingress | length' 2>/dev/null) || {
    debug "Failed to count ingress rules from NetworkPolicy JSON."
    failed
    return
  }
  if [[ "${np_ingress_rules_count}" -ne 1 ]]; then
    debug "NetworkPolicy '${EXPECTED_NETWORK_POLICY_NAME}' has an incorrect number of ingress rules. Expected: 1, Found: ${np_ingress_rules_count}."
    failed
    return
  fi
  debug "NetworkPolicy '${EXPECTED_NETWORK_POLICY_NAME}' has 1 ingress rule."

  local np_ingress_from_array
  np_ingress_from_array=$(echo "${netpol_json}" | jq -c '.spec.ingress[0].from' 2>/dev/null) || {
    debug "Failed to extract 'from' array from ingress rule."
    failed
    return
  }

  local np_ingress_from_count
  np_ingress_from_count=$(echo "${np_ingress_from_array}" | jq -r 'length' 2>/dev/null) || {
    debug "Failed to count entries in 'from' array."
    failed
    return
  }

  # The 'from' array should contain exactly one entry.
  if [[ "${np_ingress_from_count}" -ne 1 ]]; then
    debug "NetworkPolicy '${EXPECTED_NETWORK_POLICY_NAME}' ingress rule has an incorrect number of 'from' entries. Expected: 1, Found: ${np_ingress_from_count}."
    failed
    return
  fi
  debug "NetworkPolicy '${EXPECTED_NETWORK_POLICY_NAME}' ingress rule has 1 'from' entry."

  local from_entry
  from_entry=$(echo "${np_ingress_from_array}" | jq -c '.[0]' 2>/dev/null) || {
    debug "Failed to extract the single 'from' entry."
    failed
    return
  }

  local is_pod_selector_empty="false"
  if echo "${from_entry}" | jq -e '.podSelector == {}' &>/dev/null; then
    is_pod_selector_empty="true"
    debug "Found 'from' entry with empty podSelector."
  fi

  local is_namespace_selector_matching="false"
  local ns_selector_match_label_value
  ns_selector_match_label_value=$(echo "${from_entry}" | jq -r ".namespaceSelector.matchLabels.\"${EXPECTED_NAMESPACE_LABEL_KEY}\"" 2>/dev/null)
  if [[ "${ns_selector_match_label_value}" == "${EXPECTED_NAMESPACE_LABEL_VALUE}" ]]; then
    is_namespace_selector_matching="true"
    debug "Found 'from' entry with namespaceSelector matching '${EXPECTED_NAMESPACE_LABEL_KEY}: ${EXPECTED_NAMESPACE_LABEL_VALUE}'."
  fi

  # Verify that at least one of the conditions is met within the single 'from' entry
  if [[ "${is_pod_selector_empty}" != "true" && "${is_namespace_selector_matching}" != "true" ]]; then
    debug "NetworkPolicy '${EXPECTED_NETWORK_POLICY_NAME}' ingress rule's 'from' entry does not correctly specify internal communication."
    debug "Expected either an empty podSelector or a namespaceSelector matching '${EXPECTED_NAMESPACE}'."
    debug "Found: ${from_entry}"
    failed
    return
  fi
  debug "NetworkPolicy '${EXPECTED_NETWORK_POLICY_NAME}' ingress rule's 'from' entry correctly specifies internal communication."

  # Final success message
  debug "All checks passed for Task ${TASK_NUMBER}."
  solved
  return
}

# shellcheck disable=SC2329
verify_task9() {
  TASK_NUMBER="9"
  local namespace="netpol-demo7"
  local pod_name="restricted-pod"
  local np_name="allow-specific-ipblock"
  local expected_ip_block="10.10.0.0/16"

  # Check if the NetworkPolicy exists and retrieve its JSON representation.
  debug "Checking for NetworkPolicy '$np_name' in namespace '$namespace'."
  local np_json
  np_json=$(kubectl get networkpolicy "$np_name" -n "$namespace" -o json 2>/dev/null) || {
    debug "NetworkPolicy '$np_name' not found in namespace '$namespace'."
    failed
    return
  }

  # Verify that the NetworkPolicy correctly targets the 'restricted-pod'.
  debug "Verifying NetworkPolicy podSelector targets pod '$pod_name'."
  local np_pod_selector_json
  np_pod_selector_json=$(echo "$np_json" | jq '.spec.podSelector' 2>/dev/null) || {
    debug "Failed to parse .spec.podSelector from NetworkPolicy '$np_name'."
    failed
    return
  }

  # An empty podSelector (`{}`) selects all pods in the namespace.
  # This is a valid solution as it includes the target pod.
  local is_empty_selector
  is_empty_selector=$(echo "$np_pod_selector_json" | jq 'if . == {} or . == null or . == {"matchLabels":{}} then "true" else "false" end' 2>/dev/null)

  if [ "$is_empty_selector" = "true" ]; then
    debug "podSelector is empty, which targets all pods in the namespace. Verifying '$pod_name' exists."
    kubectl get pod "$pod_name" -n "$namespace" >/dev/null 2>&1 || {
      debug "The target pod '$pod_name' does not exist in namespace '$namespace'. An empty podSelector is therefore insufficient."
      failed
      return
    }
    debug "Empty podSelector is valid as it affects the target pod '$pod_name'."
  else
    # If the selector is not empty, verify it specifically selects the pod.
    debug "podSelector is not empty. Verifying it selects pod '$pod_name'."
    local np_selector_labels
    np_selector_labels=$(echo "$np_pod_selector_json" | jq -r '.matchLabels | to_entries | .[] | "\(.key)=\(.value)"' 2>/dev/null | tr '\n' ',' | sed 's/,$//') || {
      debug "Failed to parse podSelector labels from NetworkPolicy '$np_name'."
      failed
      return
    }

    # Ensure the selector is not malformed (e.g., using matchExpressions without matchLabels)
    if [ -z "$np_selector_labels" ]; then
        debug "The podSelector is not empty but could not be resolved to labels. It might be missing 'matchLabels' or be malformed."
        failed
        return
    fi

    local selected_pod_name
    selected_pod_name=$(kubectl get pods -n "$namespace" -l "$np_selector_labels" --field-selector=metadata.name="$pod_name" -o=jsonpath='{.items[0].metadata.name}' 2>/dev/null) || {
      debug "Command to verify pod selection failed. Selector '$np_selector_labels' may be invalid."
      failed
      return
    }

    if [ "$selected_pod_name" != "$pod_name" ]; then
      debug "NetworkPolicy selector '$np_selector_labels' does not select the pod '$pod_name'."
      failed
      return
    fi
    debug "NetworkPolicy podSelector correctly targets pod '$pod_name'."
  fi

  # Verify that the policy type is 'Ingress'.
  debug "Verifying policy applies to Ingress."
  if ! echo "$np_json" | jq -e '.spec.policyTypes | index("Ingress")' >/dev/null 2>&1; then
    debug "NetworkPolicy '$np_name' does not have 'Ingress' in its policyTypes."
    failed
    return
  fi
  debug "Policy correctly applies to Ingress."

  # Verify the ingress rules. There must be exactly one rule.
  debug "Verifying ingress rules."
  local ingress_rules_count
  ingress_rules_count=$(echo "$np_json" | jq '.spec.ingress | length' 2>/dev/null) || {
    debug "Failed to parse ingress rules from NetworkPolicy '$np_name'."
    failed
    return
  }

  if [ "$ingress_rules_count" -ne 1 ]; then
    debug "Expected exactly 1 ingress rule, but found '$ingress_rules_count'."
    failed
    return
  fi

  # The single ingress rule must have exactly one 'from' source.
  local from_count
  from_count=$(echo "$np_json" | jq '.spec.ingress[0].from | length' 2>/dev/null) || {
    debug "Failed to parse 'from' array in the ingress rule."
    failed
    return
  }

  if [ "$from_count" -ne 1 ]; then
    debug "Expected exactly 1 entry in the 'from' array, but found '$from_count'."
    failed
    return
  fi

  # The 'from' source must be an 'ipBlock' with the correct CIDR.
  debug "Verifying ingress rule is from IP block '$expected_ip_block'."
  local np_ip_block_cidr
  np_ip_block_cidr=$(echo "$np_json" | jq -r '.spec.ingress[0].from[0].ipBlock.cidr' 2>/dev/null) || {
    debug "Failed to parse ipBlock.cidr from the ingress rule."
    failed
    return
  }

  if [ "$np_ip_block_cidr" != "$expected_ip_block" ]; then
    debug "Incorrect IP block CIDR. Expected '$expected_ip_block', but found '$np_ip_block_cidr'."
    failed
    return
  fi

  # Ensure the 'from' source ONLY contains 'ipBlock' and no other selectors.
  local from_rule_key_count
  from_rule_key_count=$(echo "$np_json" | jq '.spec.ingress[0].from[0] | keys | length' 2>/dev/null) || {
    debug "Failed to parse keys from the 'from' rule."
    failed
    return
  }

  if [ "$from_rule_key_count" -ne 1 ]; then
    debug "The ingress 'from' rule should only contain 'ipBlock', but it contains other selectors."
    failed
    return
  fi

  debug "NetworkPolicy '$np_name' is correctly configured to allow ingress only from '$expected_ip_block'."
  solved
  return
}

# shellcheck disable=SC2329
verify_task10() {
  TASK_NUMBER="10"
  local namespace="netpol-demo8"
  local np_name="allow-frontend-and-admin"
  local target_pod_name="multi-port-pod"
  local target_pod_label_key="app"
  local target_pod_label_value="multi-port"
  local frontend_label_value="frontend"
  local admin_label_value="admin"
  local frontend_port=80
  local admin_port=443

  # Check if the NetworkPolicy exists and retrieve its JSON representation.
  debug "Checking for NetworkPolicy '$np_name' in namespace '$namespace'."
  local np_json
  np_json=$(kubectl get networkpolicy "$np_name" -n "$namespace" -o json 2>/dev/null) || {
    debug "NetworkPolicy '$np_name' not found in namespace '$namespace'."
    failed
    return
  }

  # Verify that the NetworkPolicy correctly targets the 'multi-port-pod'.
  debug "Verifying NetworkPolicy podSelector targets pod '$target_pod_name' (via label '$target_pod_label_key=$target_pod_label_value')."
  local np_pod_selector_json
  np_pod_selector_json=$(echo "$np_json" | jq '.spec.podSelector' 2>/dev/null) || {
    debug "Failed to parse .spec.podSelector from NetworkPolicy '$np_name'."
    failed
    return
  }

  local selector_label_val
  selector_label_val=$(echo "$np_pod_selector_json" | jq -r ".matchLabels.\"$target_pod_label_key\"" 2>/dev/null) || {
    debug "Failed to parse podSelector labels from NetworkPolicy '$np_name'."
    failed
    return
  }

  if [ "$selector_label_val" != "$target_pod_label_value" ]; then
    debug "NetworkPolicy podSelector does not target the correct label. Expected '$target_pod_label_key=$target_pod_label_value', but found value '$selector_label_val'."
    failed
    return
  fi
  debug "NetworkPolicy podSelector correctly targets pods with label '$target_pod_label_key=$target_pod_label_value'."

  # Verify policy applies to Ingress. It's the default, so it can be omitted.
  debug "Verifying policy applies to Ingress."
  local policy_types
  policy_types=$(echo "$np_json" | jq -r '.spec.policyTypes' 2>/dev/null)
  if [[ "$policy_types" != "null" ]] && ! echo "$policy_types" | jq -e 'index("Ingress")' >/dev/null 2>&1; then
    debug "If policyTypes is defined, it must include 'Ingress'. Found: $policy_types"
    failed
    return
  fi
  debug "Policy correctly applies to Ingress."

  # Verify the ingress rules.
  debug "Verifying ingress rules are correctly defined."
  local ingress_rules_count
  ingress_rules_count=$(echo "$np_json" | jq '.spec.ingress | length' 2>/dev/null) || {
    debug "Failed to parse ingress rules from NetworkPolicy '$np_name'."
    failed
    return
  }

  if [ "$ingress_rules_count" -ne 2 ]; then
    debug "Expected exactly 2 ingress rules, but found '$ingress_rules_count'."
    failed
    return
  fi

  local found_frontend_rule="false"
  local found_admin_rule="false"

  # Iterate through the rules to verify them independently of their order.
  for i in $(seq 0 $((ingress_rules_count - 1))); do
    local rule_json
    rule_json=$(echo "$np_json" | jq -c ".spec.ingress[$i]" 2>/dev/null) || {
      debug "Failed to parse ingress rule at index $i."
      failed
      return
    }

    # Check for exactly one port and one from selector per rule.
    local port_count
    port_count=$(echo "$rule_json" | jq '.ports | length' 2>/dev/null)
    local from_count
    from_count=$(echo "$rule_json" | jq '.from | length' 2>/dev/null)

    if [ "$port_count" -ne 1 ] || [ "$from_count" -ne 1 ]; then
      debug "Rule at index $i is not structured correctly. Each rule must have exactly one 'port' and one 'from' definition."
      failed
      return
    fi

    local port
    port=$(echo "$rule_json" | jq -r '.ports[0].port' 2>/dev/null)
    local from_role
    from_role=$(echo "$rule_json" | jq -r '.from[0].podSelector.matchLabels.role' 2>/dev/null)

    # Check if it matches the frontend rule
    if [[ "$port" == "$frontend_port" && "$from_role" == "$frontend_label_value" ]]; then
      if [ "$found_frontend_rule" == "true" ]; then
        debug "Found a duplicate rule for the frontend. There should only be one."
        failed
        return
      fi
      debug "Found correct rule: allow '$from_role' to port '$port'."
      found_frontend_rule="true"
      continue
    fi

    # Check if it matches the admin rule
    if [[ "$port" == "$admin_port" && "$from_role" == "$admin_label_value" ]]; then
      if [ "$found_admin_rule" == "true" ]; then
        debug "Found a duplicate rule for the admin role. There should only be one."
        failed
        return
      fi
      debug "Found correct rule: allow '$from_role' to port '$port'."
      found_admin_rule="true"
      continue
    fi
  done

  # Final check to ensure both distinct rules were found.
  if [[ "$found_frontend_rule" != "true" || "$found_admin_rule" != "true" ]]; then
    debug "Verification failed. Missing one or more required ingress rules."
    [ "$found_frontend_rule" != "true" ] && debug "Did not find rule allowing '$frontend_label_value' to port '$frontend_port'."
    [ "$found_admin_rule" != "true" ] && debug "Did not find rule allowing '$admin_label_value' to port '$admin_port'."
    failed
    return
  fi

  debug "All checks passed. NetworkPolicy '$np_name' is correctly configured."
  solved
  return
}

# shellcheck disable=SC2329
verify_task12() {
  TASK_NUMBER="12"
  local namespace="netpol-demo10"
  local np_name="deny-all"
  local pod_name="locked-down"

  # Check if the NetworkPolicy exists.
  debug "Checking for NetworkPolicy '$np_name' in namespace '$namespace'."
  local np_json
  np_json=$(kubectl get networkpolicy "$np_name" -n "$namespace" -o json 2>/dev/null) || {
    debug "NetworkPolicy '$np_name' not found in namespace '$namespace'."
    failed
    return
  }

  # Verify the podSelector targets the 'locked-down' pod.
  debug "Verifying that the podSelector correctly targets the '$pod_name' pod."
  local pod_selector_json
  pod_selector_json=$(echo "$np_json" | jq -c '.spec.podSelector' 2>/dev/null) || {
    debug "Failed to parse .spec.podSelector from NetworkPolicy."
    failed
    return
  }

  local is_specific_selector=true
  local pod_selector_keys_count
  pod_selector_keys_count=$(echo "$pod_selector_json" | jq 'keys | length' 2>/dev/null) || {
      debug "Could not determine number of keys in podSelector."
      failed
      return
  }

  if [ "$pod_selector_keys_count" -eq 0 ]; then
    # This correctly handles podSelector: {}
    debug "podSelector is empty, which correctly includes '$pod_name'. This is a valid approach."
    is_specific_selector=false
  else
    # Check for podSelector: { "matchLabels": {} }
    if echo "$pod_selector_json" | jq -e '.matchLabels' >/dev/null 2>&1; then
      local match_labels_keys_count
      match_labels_keys_count=$(echo "$pod_selector_json" | jq '.matchLabels | keys | length' 2>/dev/null)

      if [ "$pod_selector_keys_count" -eq 1 ] && [ "$match_labels_keys_count" -eq 0 ]; then
        debug "podSelector has empty matchLabels, which correctly includes '$pod_name'. This is a valid approach."
        is_specific_selector=false
      fi
    fi
  fi

  if [ "$is_specific_selector" = true ]; then
    # The selector is specific, so it must uniquely identify the pod using matchLabels.
    debug "podSelector is specific. Verifying it selects only '$pod_name' via 'matchLabels'."
    local selector_string
    selector_string=$(echo "$pod_selector_json" | jq -r '.matchLabels | select(.!=null) | to_entries | .[] | "\(.key)=\(.value)"' | paste -sd, -)

    if [ -z "$selector_string" ]; then
      debug "The podSelector is specific but does not use 'matchLabels', or 'matchLabels' is empty. This script only supports non-empty 'matchLabels' for specific selectors."
      failed
      return
    fi

    local selected_pods_json
    selected_pods_json=$(kubectl get pods -n "$namespace" -l "$selector_string" -o json 2>/dev/null) || {
      debug "Failed to get pods using selector '$selector_string'."
      failed
      return
    }

    local selected_pod_count
    selected_pod_count=$(echo "$selected_pods_json" | jq '.items | length' 2>/dev/null)
    if [ "$selected_pod_count" -ne 1 ]; then
      debug "The podSelector should select exactly one pod, but it selected '$selected_pod_count' pods with selector '$selector_string'."
      failed
      return
    fi

    local selected_pod_name
    selected_pod_name=$(echo "$selected_pods_json" | jq -r '.items[0].metadata.name' 2>/dev/null)
    if [ "$selected_pod_name" != "$pod_name" ]; then
      debug "The podSelector selected the wrong pod. Expected '$pod_name', but found '$selected_pod_name'."
      failed
      return
    fi
    debug "Pod selector correctly targets only '$pod_name'."
  fi

  # Verify policyTypes includes both Ingress and Egress.
  debug "Verifying policyTypes includes both 'Ingress' and 'Egress'."
  local policy_types
  policy_types=$(echo "$np_json" | jq -c '.spec.policyTypes' 2>/dev/null) || {
    debug "Failed to parse .spec.policyTypes from NetworkPolicy."
    failed
    return
  }

  local has_ingress="false"
  local has_egress="false"
  if echo "$policy_types" | jq -e 'any(. == "Ingress")' >/dev/null 2>&1; then has_ingress="true"; fi
  if echo "$policy_types" | jq -e 'any(. == "Egress")' >/dev/null 2>&1; then has_egress="true"; fi

  if [[ "$has_ingress" != "true" || "$has_egress" != "true" ]]; then
    debug "policyTypes must contain both 'Ingress' and 'Egress'. Found: $policy_types"
    failed
    return
  fi
  debug "policyTypes correctly set for full isolation."

  # Verify ingress rules are empty or absent (deny-all).
  debug "Verifying ingress rules are empty (deny-all)."
  local ingress_rule_count
  ingress_rule_count=$(echo "$np_json" | jq '.spec.ingress // [] | length' 2>/dev/null) || {
    debug "Failed to parse ingress rules."
    failed
    return
  }
  if [ "$ingress_rule_count" -ne 0 ]; then
    debug "Expected 0 ingress rules for deny-all, but found '$ingress_rule_count'."
    failed
    return
  fi

  # Verify egress rules are empty or absent (deny-all).
  debug "Verifying egress rules are empty (deny-all)."
  local egress_rule_count
  egress_rule_count=$(echo "$np_json" | jq '.spec.egress // [] | length' 2>/dev/null) || {
    debug "Failed to parse egress rules."
    failed
    return
  }
  if [ "$egress_rule_count" -ne 0 ]; then
    debug "Expected 0 egress rules for deny-all, but found '$egress_rule_count'."
    failed
    return
  fi

  debug "All checks passed. NetworkPolicy '$np_name' is correctly configured to deny all traffic."
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
)
run_verification VERIFY_TASK_FUNCTIONS "$@"

exit 0
