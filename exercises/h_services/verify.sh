#!/bin/bash

# shellcheck source=../../.scripts/verify.sh
source "$(git rev-parse --show-toplevel)/.scripts/verify.sh"

# shellcheck disable=SC2329
verify_task1() {
  TASK_NUMBER="1"
  local expected_deploy_name="web-deploy"
  local expected_namespace="default"
  local expected_image="nginx:1.25"
  local expected_service_name="web-svc"
  local expected_service_type="ClusterIP"
  local expected_service_port=80
  local expected_service_target_port=80

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

  debug "All checks passed for Task $TASK_NUMBER. Deployment and service are correctly configured and selectors match."
  solved
  return
}

# shellcheck disable=SC2329
verify_task2() {
  TASK_NUMBER="2"
  local expected_deploy_name="api-deploy"
  local expected_namespace="dev"
  local expected_image="httpd:2.4"
  local expected_service_name="api-nodeport"
  local expected_service_type="NodePort"
  local expected_service_port=8080
  local expected_service_target_port=80
  local expected_service_nodeport=30080

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

  # Check if the service exposes the correct port, targetPort, and nodePort
  debug "Checking if service \"$expected_service_name\" exposes port $expected_service_port, targetPort $expected_service_target_port, and nodePort $expected_service_nodeport."
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
  local svc_node_port
  svc_node_port="$(echo "$svc_json" | jq -r '.spec.ports[0].nodePort' 2>/dev/null)" || {
    debug "Failed to extract service nodePort from service JSON."
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
  if [ "$svc_node_port" != "$expected_service_nodeport" ]; then
    debug "Service nodePort mismatch: expected \"$expected_service_nodeport\", found \"$svc_node_port\"."
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

  debug "All checks passed for Task $TASK_NUMBER. Deployment and NodePort service are correctly configured and selectors match."
  solved
  return
}

# shellcheck disable=SC2329
verify_task3() {
  TASK_NUMBER="3"
  local expected_statefulset_name="db-set"
  local expected_namespace="database"
  local expected_image="mongo:6.0"
  local expected_service_name="db-headless"
  local expected_service_port=27017
  local expected_cluster_ip="None"

  # Check if the StatefulSet exists and uses the correct image
  debug "Checking if StatefulSet \"$expected_statefulset_name\" exists in namespace \"$expected_namespace\" and uses image \"$expected_image\"."
  local sts_json
  sts_json="$(kubectl get statefulset "$expected_statefulset_name" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Failed to get StatefulSet \"$expected_statefulset_name\" in namespace \"$expected_namespace\"."
    failed
    return
  }
  local sts_image
  sts_image="$(echo "$sts_json" | jq -r '.spec.template.spec.containers[0].image' 2>/dev/null)" || {
    debug "Failed to extract image from StatefulSet JSON."
    failed
    return
  }
  if [ "$sts_image" != "$expected_image" ]; then
    debug "StatefulSet image mismatch: expected \"$expected_image\", found \"$sts_image\"."
    failed
    return
  fi

  # Extract StatefulSet pod template labels
  debug "Extracting StatefulSet pod template labels."
  local sts_labels_json
  sts_labels_json="$(echo "$sts_json" | jq -c '.spec.template.metadata.labels' 2>/dev/null)" || {
    debug "Failed to extract StatefulSet pod template labels."
    failed
    return
  }

  # Check if the headless service exists and is correctly configured
  debug "Checking if headless service \"$expected_service_name\" exists in namespace \"$expected_namespace\" and has no cluster IP."
  local svc_json
  svc_json="$(kubectl get service "$expected_service_name" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Failed to get service \"$expected_service_name\" in namespace \"$expected_namespace\"."
    failed
    return
  }
  local svc_cluster_ip
  svc_cluster_ip="$(echo "$svc_json" | jq -r '.spec.clusterIP' 2>/dev/null)" || {
    debug "Failed to extract clusterIP from service JSON."
    failed
    return
  }
  if [ "$svc_cluster_ip" != "$expected_cluster_ip" ]; then
    debug "Service clusterIP mismatch: expected \"$expected_cluster_ip\", found \"$svc_cluster_ip\"."
    failed
    return
  fi

  # Check if the service exposes the correct port
  debug "Checking if service \"$expected_service_name\" exposes port $expected_service_port."
  local svc_port
  svc_port="$(echo "$svc_json" | jq -r '.spec.ports[0].port' 2>/dev/null)" || {
    debug "Failed to extract service port from service JSON."
    failed
    return
  }
  if [ "$svc_port" != "$expected_service_port" ]; then
    debug "Service port mismatch: expected \"$expected_service_port\", found \"$svc_port\"."
    failed
    return
  fi

  # Check if the service selector matches the StatefulSet pod template labels
  debug "Checking if service selector matches StatefulSet pod template labels."
  local svc_selector_json
  svc_selector_json="$(echo "$svc_json" | jq -c '.spec.selector' 2>/dev/null)" || {
    debug "Failed to extract service selector from service JSON."
    failed
    return
  }
  if [ "$svc_selector_json" != "$sts_labels_json" ]; then
    debug "Service selector does not match StatefulSet pod template labels. Expected: $sts_labels_json, Found: $svc_selector_json"
    failed
    return
  fi

  debug "All checks passed for Task $TASK_NUMBER. StatefulSet and headless service are correctly configured and selectors match."
  solved
  return
}

# shellcheck disable=SC2329
verify_task4() {
  TASK_NUMBER="4"
  local expected_service_name="external-svc"
  local expected_namespace="default"
  local expected_service_type="ExternalName"
  local expected_external_name="example.com"

  # Check if the ExternalName service exists and is of correct type
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

  # Check if the service resolves to the correct external DNS name
  debug "Checking if service \"$expected_service_name\" resolves to external name \"$expected_external_name\"."
  local svc_external_name
  svc_external_name="$(echo "$svc_json" | jq -r '.spec.externalName' 2>/dev/null)" || {
    debug "Failed to extract externalName from service JSON."
    failed
    return
  }
  if [ "$svc_external_name" != "$expected_external_name" ]; then
    debug "Service externalName mismatch: expected \"$expected_external_name\", found \"$svc_external_name\"."
    failed
    return
  fi

  debug "All checks passed for Task $TASK_NUMBER. ExternalName service is correctly configured."
  solved
  return
}

# shellcheck disable=SC2329
verify_task5() {
  TASK_NUMBER="5"
  local expected_deploy_name="custom-app"
  local expected_namespace="prod"
  local expected_image="python:3.12-slim"
  local expected_label_key="tier"
  local expected_label_value="backend"
  local expected_service_name="custom-svc"
  local expected_service_type="ClusterIP"
  local expected_service_port=9000
  local expected_service_target_port=9000

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

  # Check if the pod template has the correct label
  debug "Checking if deployment pod template has label \"$expected_label_key: $expected_label_value\"."
  local deploy_labels_json
  deploy_labels_json="$(echo "$deploy_json" | jq -c '.spec.template.metadata.labels' 2>/dev/null)" || {
    debug "Failed to extract deployment pod template labels."
    failed
    return
  }
  local deploy_label_value
  deploy_label_value="$(echo "$deploy_labels_json" | jq -r --arg key "$expected_label_key" '.[$key]' 2>/dev/null)" || {
    debug "Failed to extract label value for key \"$expected_label_key\" from deployment pod template labels."
    failed
    return
  }
  if [ "$deploy_label_value" != "$expected_label_value" ]; then
    debug "Deployment pod template label mismatch: expected \"$expected_label_key: $expected_label_value\", found \"$expected_label_key: $deploy_label_value\"."
    failed
    return
  fi

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

  # Check if the service selector matches the required label
  debug "Checking if service selector matches \"$expected_label_key: $expected_label_value\"."
  local svc_selector_json
  svc_selector_json="$(echo "$svc_json" | jq -c '.spec.selector' 2>/dev/null)" || {
    debug "Failed to extract service selector from service JSON."
    failed
    return
  }
  local svc_selector_value
  svc_selector_value="$(echo "$svc_selector_json" | jq -r --arg key "$expected_label_key" '.[$key]' 2>/dev/null)" || {
    debug "Failed to extract selector value for key \"$expected_label_key\" from service selector."
    failed
    return
  }
  if [ "$svc_selector_value" != "$expected_label_value" ]; then
    debug "Service selector mismatch: expected \"$expected_label_key: $expected_label_value\", found \"$expected_label_key: $svc_selector_value\"."
    failed
    return
  fi

  debug "All checks passed for Task $TASK_NUMBER. Deployment and service are correctly configured with custom labels and selectors."
  solved
  return
}

# shellcheck disable=SC2329
verify_task6() {
  TASK_NUMBER="6"
  local expected_deploy_name="multi-port-app"
  local expected_namespace="default"
  local expected_image="nginx:1.25"
  local expected_service_name="multi-port-svc"
  local expected_service_type="ClusterIP"
  local expected_ports=(80 443)
  local expected_target_ports=(80 443)

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

  # Check if the service exposes the correct ports and targetPorts
  debug "Checking if service \"$expected_service_name\" exposes ports ${expected_ports[*]} and targetPorts ${expected_target_ports[*]}."
  local svc_ports_length
  svc_ports_length="$(echo "$svc_json" | jq '.spec.ports | length' 2>/dev/null)" || {
    debug "Failed to get number of ports from service JSON."
    failed
    return
  }
  if [ "$svc_ports_length" -ne 2 ]; then
    debug "Service should have 2 ports, but found $svc_ports_length."
    failed
    return
  fi

  local i
  for i in 0 1; do
    # Check port
    local svc_port
    svc_port="$(echo "$svc_json" | jq -r ".spec.ports[$i].port" 2>/dev/null)" || {
      debug "Failed to extract port index $i from service JSON."
      failed
      return
    }
    if [ "$svc_port" != "${expected_ports[$i]}" ]; then
      debug "Service port at index $i mismatch: expected \"${expected_ports[$i]}\", found \"$svc_port\"."
      failed
      return
    fi
    # Check targetPort
    local svc_target_port
    svc_target_port="$(echo "$svc_json" | jq -r ".spec.ports[$i].targetPort" 2>/dev/null)" || {
      debug "Failed to extract targetPort index $i from service JSON."
      failed
      return
    }
    if [ "$svc_target_port" != "${expected_target_ports[$i]}" ]; then
      debug "Service targetPort at index $i mismatch: expected \"${expected_target_ports[$i]}\", found \"$svc_target_port\"."
      failed
      return
    fi
  done

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

  debug "All checks passed for Task $TASK_NUMBER. Deployment and multi-port service are correctly configured."
  solved
  return
}

# shellcheck disable=SC2329
verify_task7() {
  TASK_NUMBER="7"
  local expected_deploy_name="session-app"
  local expected_namespace="default"
  local expected_image="nginx:1.25"
  local expected_service_name="session-svc"
  local expected_service_type="ClusterIP"
  local expected_service_port=9080
  local expected_service_target_port=80
  local expected_session_affinity="ClientIP"

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

  # Check if session affinity is enabled and set to ClientIP
  debug "Checking if session affinity is enabled and set to \"$expected_session_affinity\"."
  local svc_session_affinity
  svc_session_affinity="$(echo "$svc_json" | jq -r '.spec.sessionAffinity' 2>/dev/null)" || {
    debug "Failed to extract sessionAffinity from service JSON."
    failed
    return
  }
  if [ "$svc_session_affinity" != "$expected_session_affinity" ]; then
    debug "Session affinity mismatch: expected \"$expected_session_affinity\", found \"$svc_session_affinity\"."
    failed
    return
  fi

  debug "All checks passed for Task $TASK_NUMBER. Deployment and service are correctly configured with session affinity."
  solved
  return
}

# shellcheck disable=SC2329
verify_task8() {
  TASK_NUMBER="8"
  local expected_deploy_name="payment-api"
  local expected_namespace="finance"
  local expected_image="python:3.12-slim"
  local expected_container_port=5000
  local expected_service_name="payment-lb"
  local expected_service_type="LoadBalancer"
  local expected_service_port=443
  local expected_service_target_port=5000
  local expected_annotation_key="service.beta.kubernetes.io/aws-load-balancer-backend-protocol"
  local expected_annotation_value="http"

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

  # Check if the service has the required annotation
  debug "Checking if service \"$expected_service_name\" has annotation \"$expected_annotation_key: $expected_annotation_value\"."
  local svc_annotation_value
  svc_annotation_value="$(echo "$svc_json" | jq -r --arg key "$expected_annotation_key" '.metadata.annotations[$key]' 2>/dev/null)" || {
    debug "Failed to extract annotation \"$expected_annotation_key\" from service JSON."
    failed
    return
  }
  if [ "$svc_annotation_value" != "$expected_annotation_value" ]; then
    debug "Service annotation mismatch: expected \"$expected_annotation_key: $expected_annotation_value\", found \"$expected_annotation_key: $svc_annotation_value\"."
    failed
    return
  fi

  debug "All checks passed for Task $TASK_NUMBER. Deployment and LoadBalancer service are correctly configured with health check and annotation."
  solved
  return
}

# shellcheck disable=SC2329
verify_task9() {
  TASK_NUMBER="9"
  local expected_deploy_name="audit-logger"
  local expected_namespace="security"
  local expected_image="alpine:3.20"
  local expected_service_name="audit-main-svc"
  local expected_service_type="ClusterIP"
  local expected_service_port=7000
  local expected_service_target_port=7000
  local expected_label_key="role"
  local expected_label_value="main"

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

  # Check if there is at least one pod with the unique label
  debug "Checking for at least one pod with label \"$expected_label_key: $expected_label_value\" in namespace \"$expected_namespace\"."
  local pods_json
  pods_json="$(kubectl get pods -n "$expected_namespace" -l "$expected_label_key=$expected_label_value" -o json 2>/dev/null)" || {
    debug "Failed to get pods with label \"$expected_label_key: $expected_label_value\" in namespace \"$expected_namespace\"."
    failed
    return
  }
  local pod_count
  pod_count="$(echo "$pods_json" | jq '.items | length' 2>/dev/null)" || {
    debug "Failed to count pods with label \"$expected_label_key: $expected_label_value\"."
    failed
    return
  }
  if [ "$pod_count" -lt 1 ]; then
    debug "No pod found with label \"$expected_label_key: $expected_label_value\" in namespace \"$expected_namespace\"."
    failed
    return
  fi

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

  # Check if the service selector matches the unique label
  debug "Checking if service selector matches \"$expected_label_key: $expected_label_value\"."
  local svc_selector_json
  svc_selector_json="$(echo "$svc_json" | jq -c '.spec.selector' 2>/dev/null)" || {
    debug "Failed to extract service selector from service JSON."
    failed
    return
  }
  local svc_selector_value
  svc_selector_value="$(echo "$svc_selector_json" | jq -r --arg key "$expected_label_key" '.[$key]' 2>/dev/null)" || {
    debug "Failed to extract selector value for key \"$expected_label_key\" from service selector."
    failed
    return
  }
  if [ "$svc_selector_value" != "$expected_label_value" ]; then
    debug "Service selector mismatch: expected \"$expected_label_key: $expected_label_value\", found \"$expected_label_key: $svc_selector_value\"."
    failed
    return
  fi

  debug "All checks passed for Task $TASK_NUMBER. Service correctly exposes only the uniquely labeled pod."
  solved
  return
}

# shellcheck disable=SC2329
verify_task10() {
  TASK_NUMBER="10"
  local expected_namespace="dns-test"
  local expected_api_server_pod="api-server"
  local expected_api_server_label_key="app"
  local expected_api_server_label_value="api-server"
  local expected_service_name="dns-svc"
  local expected_service_type="ClusterIP"
  local expected_service_port=80
  local expected_test_pod="api-test"
  local expected_test_image="busybox:1.36"
  local expected_test_command="sleep 28800"

  # Check if the namespace exists
  debug "Checking if namespace \"$expected_namespace\" exists."
  kubectl get namespace "$expected_namespace" >/dev/null 2>&1 || {
    debug "Namespace \"$expected_namespace\" does not exist."
    failed
    return
  }

  # Check if the api-server pod exists and has the correct label
  debug "Checking if pod \"$expected_api_server_pod\" exists and has label \"$expected_api_server_label_key: $expected_api_server_label_value\"."
  local api_server_pod_json
  api_server_pod_json="$(kubectl get pod "$expected_api_server_pod" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Failed to get pod \"$expected_api_server_pod\" in namespace \"$expected_namespace\"."
    failed
    return
  }
  local api_server_label_value
  api_server_label_value="$(echo "$api_server_pod_json" | jq -r ".metadata.labels[\"$expected_api_server_label_key\"]" 2>/dev/null)" || {
    debug "Failed to extract api-server pod label \"$expected_api_server_label_key\"."
    failed
    return
  }
  if [ "$api_server_label_value" != "$expected_api_server_label_value" ]; then
    debug "api-server pod label mismatch: expected \"$expected_api_server_label_key: $expected_api_server_label_value\", found \"$expected_api_server_label_key: $api_server_label_value\"."
    failed
    return
  fi

  # Check if the service exists and is of correct type and port
  debug "Checking if service \"$expected_service_name\" exists and is of type \"$expected_service_type\"."
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

  # Check if the service selector matches the api-server pod label
  debug "Checking if service selector matches api-server pod label."
  local svc_selector_json
  svc_selector_json="$(echo "$svc_json" | jq -c '.spec.selector' 2>/dev/null)" || {
    debug "Failed to extract service selector from service JSON."
    failed
    return
  }
  local selector_value
  selector_value="$(echo "$svc_selector_json" | jq -r ".${expected_api_server_label_key}" 2>/dev/null)" || {
    debug "Failed to extract selector value for key \"$expected_api_server_label_key\" from service selector."
    failed
    return
  }
  if [ "$selector_value" != "$expected_api_server_label_value" ]; then
    debug "Service selector mismatch: expected \"$expected_api_server_label_key: $expected_api_server_label_value\", found \"$expected_api_server_label_key: $selector_value\"."
    failed
    return
  fi

  # Check if the test pod exists and has the correct image and command
  debug "Checking if test pod \"$expected_test_pod\" exists and has correct image and command."
  local test_pod_json
  test_pod_json="$(kubectl get pod "$expected_test_pod" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Failed to get test pod \"$expected_test_pod\" in namespace \"$expected_namespace\"."
    failed
    return
  }
  local test_image
  test_image="$(echo "$test_pod_json" | jq -r '.spec.containers[0].image' 2>/dev/null)" || {
    debug "Failed to extract image from test pod JSON."
    failed
    return
  }
  if [ "$test_image" != "$expected_test_image" ]; then
    debug "Test pod image mismatch: expected \"$expected_test_image\", found \"$test_image\"."
    failed
    return
  fi
  local test_command
  test_command="$(echo "$test_pod_json" | jq -r '.spec.containers[0].command | join(" ")' 2>/dev/null)" || {
    debug "Failed to extract command from test pod JSON."
    failed
    return
  }
  if [ "$test_command" != "$expected_test_command" ]; then
    debug "Test pod command mismatch: expected \"$expected_test_command\", found \"$test_command\"."
    failed
    return
  fi

  # Test DNS resolution and connectivity from api-test pod to dns-svc using wget
  debug "Testing DNS resolution and HTTP connectivity from pod \"$expected_test_pod\" to service \"$expected_service_name\" using wget."
  local wget_result
  wget_result="$(kubectl exec -n "$expected_namespace" "$expected_test_pod" -- wget -O - -T 5 "http://$expected_service_name" 2>/dev/null)" || {
    debug "Failed to wget http://$expected_service_name from test pod."
    failed
    return
  }
  # Check if wget output contains typical nginx welcome page content
  echo "$wget_result" | grep -q "Welcome to nginx!" 2>/dev/null || {
    debug "wget to http://$expected_service_name succeeded but did not return expected nginx content."
    failed
    return
  }

  debug "All checks passed for Task $TASK_NUMBER. DNS resolution and HTTP connectivity from test pod to service succeeded."
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
)
run_verification VERIFY_TASK_FUNCTIONS "$@"

exit 0
