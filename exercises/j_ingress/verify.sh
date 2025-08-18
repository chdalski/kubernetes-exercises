#!/bin/bash

# shellcheck source=../../.scripts/verify.sh
source "$(git rev-parse --show-toplevel)/.scripts/verify.sh"

# shellcheck disable=SC2329
verify_task1() {
  TASK_NUMBER="1"
  local expected_ingress_name="frontend-ingress"
  local expected_namespace="default"
  local expected_host="frontend.example.com"
  local expected_service_name="frontend-svc"
  local expected_service_port=80

  # Check if the Ingress exists
  debug "Checking if Ingress \"$expected_ingress_name\" exists in namespace \"$expected_namespace\"."
  local ingress_json
  ingress_json="$(kubectl get ingress "$expected_ingress_name" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Failed to get Ingress \"$expected_ingress_name\" in namespace \"$expected_namespace\"."
    failed
    return
  }

  # Check if the Ingress has the correct host rule
  debug "Checking if Ingress has a rule for host \"$expected_host\"."
  local host_count
  host_count="$(echo "$ingress_json" | jq --arg host "$expected_host" '[.spec.rules[] | select(.host == $host)] | length' 2>/dev/null)" || {
    debug "Failed to check Ingress rules for host \"$expected_host\"."
    failed
    return
  }
  if [ "$host_count" -eq 0 ]; then
    debug "Ingress does not have a rule for host \"$expected_host\"."
    failed
    return
  fi

  # Check if the Ingress routes to the correct service and port
  debug "Checking if Ingress routes host \"$expected_host\" to service \"$expected_service_name\" on port $expected_service_port."
  local backend_service
  backend_service="$(echo "$ingress_json" | jq -r --arg host "$expected_host" '.spec.rules[] | select(.host == $host) | .http.paths[0].backend.service.name' 2>/dev/null)" || {
    debug "Failed to extract backend service from Ingress rule."
    failed
    return
  }
  local backend_port
  backend_port="$(echo "$ingress_json" | jq -r --arg host "$expected_host" '.spec.rules[] | select(.host == $host) | .http.paths[0].backend.service.port.number' 2>/dev/null)" || {
    debug "Failed to extract backend port from Ingress rule."
    failed
    return
  }
  if [ "$backend_service" != "$expected_service_name" ]; then
    debug "Ingress backend service mismatch: expected \"$expected_service_name\", found \"$backend_service\"."
    failed
    return
  fi
  if [ "$backend_port" != "$expected_service_port" ]; then
    debug "Ingress backend port mismatch: expected \"$expected_service_port\", found \"$backend_port\"."
    failed
    return
  fi

  debug "All checks passed for Task $TASK_NUMBER. Ingress correctly routes host \"$expected_host\" to service \"$expected_service_name\" on port $expected_service_port."
  solved
  return
}

# shellcheck disable=SC2329
verify_task2() {
  TASK_NUMBER="2"
  local expected_ingress_name="app-ingress"
  local expected_namespace="streaming"
  local expected_host="app.example.com"
  local expected_api_path="/api"
  local expected_video_path="/video"
  local expected_api_service="api-service"
  local expected_video_service="video-service"
  local expected_service_port=80
  local expected_path_type="Prefix"

  # Check if the Ingress exists
  debug "Checking if Ingress \"$expected_ingress_name\" exists in namespace \"$expected_namespace\"."
  local ingress_json
  ingress_json="$(kubectl get ingress "$expected_ingress_name" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Failed to get Ingress \"$expected_ingress_name\" in namespace \"$expected_namespace\"."
    failed
    return
  }

  # Check if the Ingress has the correct host rule
  debug "Checking if Ingress has a rule for host \"$expected_host\"."
  local host_count
  host_count="$(echo "$ingress_json" | jq --arg host "$expected_host" '[.spec.rules[] | select(.host == $host)] | length' 2>/dev/null)" || {
    debug "Failed to check Ingress rules for host \"$expected_host\"."
    failed
    return
  }
  if [ "$host_count" -eq 0 ]; then
    debug "Ingress does not have a rule for host \"$expected_host\"."
    failed
    return
  fi

  # Check for /api path rule
  debug "Checking if Ingress routes path \"$expected_api_path\" to service \"$expected_api_service\" on port $expected_service_port with pathType \"$expected_path_type\"."
  local api_path_rule
  api_path_rule="$(echo "$ingress_json" | jq -r --arg host "$expected_host" --arg path "$expected_api_path" --arg pathType "$expected_path_type" \
    '.spec.rules[] | select(.host == $host) | .http.paths[] | select(.path == $path and .pathType == $pathType) | .backend.service.name + ":" + (.backend.service.port.number|tostring)' 2>/dev/null)" || {
    debug "Failed to extract /api path rule from Ingress."
    failed
    return
  }
  if [ "$api_path_rule" != "$expected_api_service:$expected_service_port" ]; then
    debug "Ingress /api path rule mismatch: expected \"$expected_api_service:$expected_service_port\", found \"$api_path_rule\"."
    failed
    return
  fi

  # Check for /video path rule
  debug "Checking if Ingress routes path \"$expected_video_path\" to service \"$expected_video_service\" on port $expected_service_port with pathType \"$expected_path_type\"."
  local video_path_rule
  video_path_rule="$(echo "$ingress_json" | jq -r --arg host "$expected_host" --arg path "$expected_video_path" --arg pathType "$expected_path_type" \
    '.spec.rules[] | select(.host == $host) | .http.paths[] | select(.path == $path and .pathType == $pathType) | .backend.service.name + ":" + (.backend.service.port.number|tostring)' 2>/dev/null)" || {
    debug "Failed to extract /video path rule from Ingress."
    failed
    return
  }
  if [ "$video_path_rule" != "$expected_video_service:$expected_service_port" ]; then
    debug "Ingress /video path rule mismatch: expected \"$expected_video_service:$expected_service_port\", found \"$video_path_rule\"."
    failed
    return
  fi

  debug "All checks passed for Task $TASK_NUMBER. Ingress correctly routes /api and /video paths to the correct services."
  solved
  return
}

# shellcheck disable=SC2329
verify_task3() {
  TASK_NUMBER="3"
  local expected_ingress_name="dashboard-ingress"
  local expected_namespace="default"
  local expected_host="dashboard.example.com"
  local expected_service_name="dashboard-svc"
  local expected_service_port=80
  local expected_tls_secret="app-tls-secret"

  # Check if the Ingress exists
  debug "Checking if Ingress \"$expected_ingress_name\" exists in namespace \"$expected_namespace\"."
  local ingress_json
  ingress_json="$(kubectl get ingress "$expected_ingress_name" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Failed to get Ingress \"$expected_ingress_name\" in namespace \"$expected_namespace\"."
    failed
    return
  }

  # Check if the Ingress has the correct host rule
  debug "Checking if Ingress has a rule for host \"$expected_host\"."
  local host_count
  host_count="$(echo "$ingress_json" | jq --arg host "$expected_host" '[.spec.rules[] | select(.host == $host)] | length' 2>/dev/null)" || {
    debug "Failed to check Ingress rules for host \"$expected_host\"."
    failed
    return
  }
  if [ "$host_count" -eq 0 ]; then
    debug "Ingress does not have a rule for host \"$expected_host\"."
    failed
    return
  fi

  # Check if the Ingress routes to the correct service and port
  debug "Checking if Ingress routes host \"$expected_host\" to service \"$expected_service_name\" on port $expected_service_port."
  local backend_service
  backend_service="$(echo "$ingress_json" | jq -r --arg host "$expected_host" '.spec.rules[] | select(.host == $host) | .http.paths[0].backend.service.name' 2>/dev/null)" || {
    debug "Failed to extract backend service from Ingress rule."
    failed
    return
  }
  local backend_port
  backend_port="$(echo "$ingress_json" | jq -r --arg host "$expected_host" '.spec.rules[] | select(.host == $host) | .http.paths[0].backend.service.port.number' 2>/dev/null)" || {
    debug "Failed to extract backend port from Ingress rule."
    failed
    return
  }
  if [ "$backend_service" != "$expected_service_name" ]; then
    debug "Ingress backend service mismatch: expected \"$expected_service_name\", found \"$backend_service\"."
    failed
    return
  fi
  if [ "$backend_port" != "$expected_service_port" ]; then
    debug "Ingress backend port mismatch: expected \"$expected_service_port\", found \"$backend_port\"."
    failed
    return
  fi

  # Check if the Ingress is configured for TLS with the correct secret and host
  debug "Checking if Ingress is configured for TLS with secret \"$expected_tls_secret\" and host \"$expected_host\"."
  local tls_count
  tls_count="$(echo "$ingress_json" | jq --arg secret "$expected_tls_secret" --arg host "$expected_host" \
    '[.spec.tls[] | select(.secretName == $secret and (.hosts | index($host)))] | length' 2>/dev/null)" || {
    debug "Failed to check Ingress TLS configuration."
    failed
    return
  }
  if [ "$tls_count" -eq 0 ]; then
    debug "Ingress is not configured for TLS with secret \"$expected_tls_secret\" and host \"$expected_host\"."
    failed
    return
  fi

  debug "All checks passed for Task $TASK_NUMBER. Ingress correctly routes host \"$expected_host\" to service \"$expected_service_name\" with TLS termination."
  solved
  return
}

# shellcheck disable=SC2329
verify_task4() {
  TASK_NUMBER="4"
  local expected_ingress_name="legacy-ingress"
  local expected_namespace="legacy"
  local expected_host="legacy.example.com"
  local expected_path="/app"
  local expected_service_name="legacy-svc"
  local expected_service_port=80
  local expected_path_type="Prefix"
  local expected_rewrite_annotation="nginx.ingress.kubernetes.io/rewrite-target"
  local expected_rewrite_value="/"

  # Check if the Ingress exists
  debug "Checking if Ingress \"$expected_ingress_name\" exists in namespace \"$expected_namespace\"."
  local ingress_json
  ingress_json="$(kubectl get ingress "$expected_ingress_name" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Failed to get Ingress \"$expected_ingress_name\" in namespace \"$expected_namespace\"."
    failed
    return
  }

  # Check for the rewrite annotation
  debug "Checking if Ingress has annotation \"$expected_rewrite_annotation: $expected_rewrite_value\"."
  local rewrite_value
  rewrite_value="$(echo "$ingress_json" | jq -r --arg key "$expected_rewrite_annotation" '.metadata.annotations[$key]' 2>/dev/null)" || {
    debug "Failed to extract rewrite annotation from Ingress."
    failed
    return
  }
  if [ "$rewrite_value" != "$expected_rewrite_value" ]; then
    debug "Ingress rewrite annotation mismatch: expected \"$expected_rewrite_value\", found \"$rewrite_value\"."
    failed
    return
  fi

  # Check if the Ingress has the correct host and path rule
  debug "Checking if Ingress has a rule for host \"$expected_host\" and path \"$expected_path\"."
  local path_rule
  path_rule="$(echo "$ingress_json" | jq -r --arg host "$expected_host" --arg path "$expected_path" --arg pathType "$expected_path_type" \
    '.spec.rules[] | select(.host == $host) | .http.paths[] | select(.path == $path and .pathType == $pathType) | .backend.service.name + ":" + (.backend.service.port.number|tostring)' 2>/dev/null)" || {
    debug "Failed to extract path rule from Ingress."
    failed
    return
  }
  if [ "$path_rule" != "$expected_service_name:$expected_service_port" ]; then
    debug "Ingress path rule mismatch: expected \"$expected_service_name:$expected_service_port\", found \"$path_rule\"."
    failed
    return
  fi

  debug "All checks passed for Task $TASK_NUMBER. Ingress correctly rewrites /app to / and routes to \"$expected_service_name\"."
  solved
  return
}

# shellcheck disable=SC2329
verify_task5() {
  TASK_NUMBER="5"
  local expected_ingress_name="site-ingress"
  local expected_namespace="main"
  local expected_host="main.example.com"
  local expected_main_service="main-site-svc"
  local expected_error_service="error-page-svc"
  local expected_service_port=80

  # Check if the Ingress exists
  debug "Checking if Ingress \"$expected_ingress_name\" exists in namespace \"$expected_namespace\"."
  local ingress_json
  ingress_json="$(kubectl get ingress "$expected_ingress_name" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Failed to get Ingress \"$expected_ingress_name\" in namespace \"$expected_namespace\"."
    failed
    return
  }

  # Check if the Ingress has the correct host rule for main-site-svc
  debug "Checking if Ingress has a rule for host \"$expected_host\" routing to \"$expected_main_service\"."
  local main_rule
  main_rule="$(echo "$ingress_json" | jq -r --arg host "$expected_host" \
    '.spec.rules[] | select(.host == $host) | .http.paths[0].backend.service.name + ":" + (.http.paths[0].backend.service.port.number|tostring)' 2>/dev/null)" || {
    debug "Failed to extract main host rule from Ingress."
    failed
    return
  }
  if [ "$main_rule" != "$expected_main_service:$expected_service_port" ]; then
    debug "Ingress host rule mismatch: expected \"$expected_main_service:$expected_service_port\", found \"$main_rule\"."
    failed
    return
  fi

  # Check if the Ingress has a default backend for error-page-svc
  debug "Checking if Ingress has a default backend for \"$expected_error_service\"."
  local default_backend_name
  default_backend_name="$(echo "$ingress_json" | jq -r '.spec.defaultBackend.service.name // empty' 2>/dev/null)" || {
    debug "Failed to extract default backend service name from Ingress."
    failed
    return
  }
  local default_backend_port
  default_backend_port="$(echo "$ingress_json" | jq -r '.spec.defaultBackend.service.port.number // empty' 2>/dev/null)" || {
    debug "Failed to extract default backend service port from Ingress."
    failed
    return
  }
  if [ "$default_backend_name" != "$expected_error_service" ]; then
    debug "Ingress default backend service mismatch: expected \"$expected_error_service\", found \"$default_backend_name\"."
    failed
    return
  fi
  if [ "$default_backend_port" != "$expected_service_port" ]; then
    debug "Ingress default backend port mismatch: expected \"$expected_service_port\", found \"$default_backend_port\"."
    failed
    return
  fi

  debug "All checks passed for Task $TASK_NUMBER. Ingress correctly routes main.example.com to \"$expected_main_service\" and uses \"$expected_error_service\" as the default backend."
  solved
  return
}

# shellcheck disable=SC2329
verify_task6() {
  TASK_NUMBER="6"
  local expected_ingress_name="reports-ingress"
  local expected_namespace="default"
  local expected_host="reports.example.com"
  local expected_service_name="reports-svc"
  local expected_service_port=80
  local expected_ingress_class="external-nginx"

  # Check if the Ingress exists
  debug "Checking if Ingress \"$expected_ingress_name\" exists in namespace \"$expected_namespace\"."
  local ingress_json
  ingress_json="$(kubectl get ingress "$expected_ingress_name" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Failed to get Ingress \"$expected_ingress_name\" in namespace \"$expected_namespace\"."
    failed
    return
  }

  # Check if the Ingress has the correct ingressClassName
  debug "Checking if Ingress has ingressClassName \"$expected_ingress_class\"."
  local ingress_class
  ingress_class="$(echo "$ingress_json" | jq -r '.spec.ingressClassName // empty' 2>/dev/null)" || {
    debug "Failed to extract ingressClassName from Ingress."
    failed
    return
  }
  if [ "$ingress_class" != "$expected_ingress_class" ]; then
    debug "Ingress ingressClassName mismatch: expected \"$expected_ingress_class\", found \"$ingress_class\"."
    failed
    return
  fi

  # Check if the Ingress has the correct host rule for reports-svc
  debug "Checking if Ingress has a rule for host \"$expected_host\" routing to \"$expected_service_name\"."
  local rule_service
  rule_service="$(echo "$ingress_json" | jq -r --arg host "$expected_host" \
    '.spec.rules[] | select(.host == $host) | .http.paths[0].backend.service.name' 2>/dev/null)" || {
    debug "Failed to extract host rule from Ingress."
    failed
    return
  }
  local rule_port
  rule_port="$(echo "$ingress_json" | jq -r --arg host "$expected_host" \
    '.spec.rules[] | select(.host == $host) | .http.paths[0].backend.service.port.number' 2>/dev/null)" || {
    debug "Failed to extract host rule port from Ingress."
    failed
    return
  }
  if [ "$rule_service" != "$expected_service_name" ]; then
    debug "Ingress host rule service mismatch: expected \"$expected_service_name\", found \"$rule_service\"."
    failed
    return
  fi
  if [ "$rule_port" != "$expected_service_port" ]; then
    debug "Ingress host rule port mismatch: expected \"$expected_service_port\", found \"$rule_port\"."
    failed
    return
  fi

  debug "All checks passed for Task $TASK_NUMBER. Ingress is correctly assigned to class \"$expected_ingress_class\" and routes to \"$expected_service_name\"."
  solved
  return
}

# shellcheck disable=SC2329
verify_task7() {
  TASK_NUMBER="7"
  local expected_ingress_name="wildcard-ingress"
  local expected_namespace="default"
  local expected_host_pattern="*.apps.example.com"
  local expected_service_name="multi-tenant-svc"
  local expected_service_port=80
  local expected_tls_secret="apps-wildcard-tls"

  # Check if the Ingress exists
  debug "Checking if Ingress \"$expected_ingress_name\" exists in namespace \"$expected_namespace\"."
  local ingress_json
  ingress_json="$(kubectl get ingress "$expected_ingress_name" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Failed to get Ingress \"$expected_ingress_name\" in namespace \"$expected_namespace\"."
    failed
    return
  }

  # Check if there is exactly one rule
  debug "Checking if Ingress has exactly one rule."
  local rule_count
  rule_count="$(echo "$ingress_json" | jq '.spec.rules | length' 2>/dev/null)" || {
    debug "Failed to extract rules from Ingress JSON."
    failed
    return
  }
  if [ "$rule_count" -ne 1 ]; then
    debug "Ingress rule count mismatch: expected 1, found $rule_count."
    failed
    return
  fi

  # Check if the rule host matches the wildcard pattern
  debug "Checking if Ingress rule host matches the wildcard pattern \"$expected_host_pattern\"."
  local rule_host
  rule_host="$(echo "$ingress_json" | jq -r '.spec.rules[0].host' 2>/dev/null)" || {
    debug "Failed to extract rule host from Ingress JSON."
    failed
    return
  }
  # Accept only hosts starting with "*." and ending with ".apps.example.com"
  if [[ "$rule_host" != *.apps.example.com ]] || [[ "${rule_host:0:2}" != "*." ]]; then
    debug "Ingress rule host mismatch: expected pattern \"$expected_host_pattern\", found \"$rule_host\"."
    failed
    return
  fi

  # Check if the backend service and port are correct
  debug "Checking if Ingress backend service is \"$expected_service_name\" on port $expected_service_port."
  local backend_service_name
  backend_service_name="$(echo "$ingress_json" | jq -r '.spec.rules[0].http.paths[0].backend.service.name' 2>/dev/null)" || {
    debug "Failed to extract backend service name from Ingress JSON."
    failed
    return
  }
  local backend_service_port
  backend_service_port="$(echo "$ingress_json" | jq -r '.spec.rules[0].http.paths[0].backend.service.port.number // .spec.rules[0].http.paths[0].backend.service.port.name' 2>/dev/null)" || {
    debug "Failed to extract backend service port from Ingress JSON."
    failed
    return
  }
  if [ "$backend_service_name" != "$expected_service_name" ]; then
    debug "Ingress backend service name mismatch: expected \"$expected_service_name\", found \"$backend_service_name\"."
    failed
    return
  fi
  if [ "$backend_service_port" != "$expected_service_port" ]; then
    debug "Ingress backend service port mismatch: expected \"$expected_service_port\", found \"$backend_service_port\"."
    failed
    return
  fi

  # Check if TLS is configured with the correct secret and host
  debug "Checking if Ingress TLS is configured with secret \"$expected_tls_secret\" and correct host."
  local tls_count
  tls_count="$(echo "$ingress_json" | jq '.spec.tls | length' 2>/dev/null)" || {
    debug "Failed to extract TLS configuration from Ingress JSON."
    failed
    return
  }
  if [ "$tls_count" -lt 1 ]; then
    debug "Ingress TLS configuration missing."
    failed
    return
  fi
  local tls_secret_name
  tls_secret_name="$(echo "$ingress_json" | jq -r '.spec.tls[0].secretName' 2>/dev/null)" || {
    debug "Failed to extract TLS secret name from Ingress JSON."
    failed
    return
  }
  if [ "$tls_secret_name" != "$expected_tls_secret" ]; then
    debug "Ingress TLS secret name mismatch: expected \"$expected_tls_secret\", found \"$tls_secret_name\"."
    failed
    return
  fi
  local tls_hosts_json
  tls_hosts_json="$(echo "$ingress_json" | jq -c '.spec.tls[0].hosts' 2>/dev/null)" || {
    debug "Failed to extract TLS hosts from Ingress JSON."
    failed
    return
  }
  # Check that the TLS hosts array contains the wildcard host
  if ! echo "$tls_hosts_json" | jq -e --arg host "$rule_host" 'index($host)' >/dev/null 2>&1; then
    debug "Ingress TLS hosts do not include the rule host \"$rule_host\". TLS hosts: $tls_hosts_json"
    failed
    return
  fi

  debug "All checks passed for Task $TASK_NUMBER. Ingress is correctly configured for wildcard host and TLS."
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
