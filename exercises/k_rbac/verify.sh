#!/bin/bash

# shellcheck source=../../.scripts/verify.sh
source "$(git rev-parse --show-toplevel)/.scripts/verify.sh"

# shellcheck disable=SC2329
verify_task1() {
  TASK_NUMBER="1"
  local expected_namespace="dev-team-1"
  local expected_sa="pod-viewer-sa"
  local expected_role="pod-reader-role"
  local expected_rolebinding="pod-viewer-binding"
  local expected_verbs=("get" "watch" "list")
  local expected_verbs_count=3
  local expected_resource="pods"

  # Check if the namespace exists
  debug "Checking if namespace \"$expected_namespace\" exists."
  kubectl get namespace "$expected_namespace" -o json >/dev/null 2>&1 || {
    debug "Failed to get namespace \"$expected_namespace\"."
    failed
    return
  }

  # Check if the ServiceAccount exists
  debug "Checking if ServiceAccount \"$expected_sa\" exists in namespace \"$expected_namespace\"."
  kubectl get serviceaccount "$expected_sa" -n "$expected_namespace" -o json >/dev/null 2>&1 || {
    debug "Failed to get ServiceAccount \"$expected_sa\" in namespace \"$expected_namespace\"."
    failed
    return
  }

  # Check if the Role exists and has correct rules
  debug "Checking if Role \"$expected_role\" exists in namespace \"$expected_namespace\" and has correct rules."
  local role_json
  role_json="$(kubectl get role "$expected_role" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Failed to get Role \"$expected_role\" in namespace \"$expected_namespace\"."
    failed
    return
  }
  # Find the rule that applies to pods
  local rule_index
  rule_index="$(echo "$role_json" | jq '.rules | map(select(.resources | index("'"$expected_resource"'"))) | .[0]' 2>/dev/null)" || {
    debug "Failed to extract rule for resource \"$expected_resource\" from Role JSON."
    failed
    return
  }
  if [ "$rule_index" = "null" ]; then
    debug "No rule found for resource \"$expected_resource\" in Role \"$expected_role\"."
    failed
    return
  fi
  # Extract verbs array for pods rule
  local verbs_json
  verbs_json="$(echo "$rule_index" | jq -c '.verbs' 2>/dev/null)" || {
    debug "Failed to extract verbs from Role JSON."
    failed
    return
  }
  local verbs_count
  verbs_count="$(echo "$verbs_json" | jq 'length' 2>/dev/null)" || {
    debug "Failed to count verbs in Role JSON."
    failed
    return
  }
  if [ "$verbs_count" -ne "$expected_verbs_count" ]; then
    debug "Role verbs count mismatch: expected $expected_verbs_count, found $verbs_count."
    failed
    return
  fi
  # Check that all expected verbs are present
  local verb
  for verb in "${expected_verbs[@]}"; do
    echo "$verbs_json" | jq -e --arg v "$verb" 'index($v)' >/dev/null 2>&1 || {
      debug "Role verbs missing expected verb: \"$verb\". Found: $verbs_json"
      failed
      return
    }
  done

  # Check if the RoleBinding exists and binds the correct Role and ServiceAccount
  debug "Checking if RoleBinding \"$expected_rolebinding\" exists and binds Role \"$expected_role\" to ServiceAccount \"$expected_sa\"."
  local rb_json
  rb_json="$(kubectl get rolebinding "$expected_rolebinding" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Failed to get RoleBinding \"$expected_rolebinding\" in namespace \"$expected_namespace\"."
    failed
    return
  }
  local rb_role_ref_kind
  rb_role_ref_kind="$(echo "$rb_json" | jq -r '.roleRef.kind' 2>/dev/null)" || {
    debug "Failed to extract roleRef.kind from RoleBinding JSON."
    failed
    return
  }
  local rb_role_ref_name
  rb_role_ref_name="$(echo "$rb_json" | jq -r '.roleRef.name' 2>/dev/null)" || {
    debug "Failed to extract roleRef.name from RoleBinding JSON."
    failed
    return
  }
  if [ "$rb_role_ref_kind" != "Role" ] || [ "$rb_role_ref_name" != "$expected_role" ]; then
    debug "RoleBinding roleRef mismatch: expected kind \"Role\" and name \"$expected_role\", found kind \"$rb_role_ref_kind\" and name \"$rb_role_ref_name\"."
    failed
    return
  fi
  local rb_subject_kind
  rb_subject_kind="$(echo "$rb_json" | jq -r '.subjects[0].kind' 2>/dev/null)" || {
    debug "Failed to extract subject kind from RoleBinding JSON."
    failed
    return
  }
  local rb_subject_name
  rb_subject_name="$(echo "$rb_json" | jq -r '.subjects[0].name' 2>/dev/null)" || {
    debug "Failed to extract subject name from RoleBinding JSON."
    failed
    return
  }
  local rb_subject_ns
  rb_subject_ns="$(echo "$rb_json" | jq -r '.subjects[0].namespace // empty' 2>/dev/null)"
  if [ "$rb_subject_kind" != "ServiceAccount" ] || [ "$rb_subject_name" != "$expected_sa" ]; then
    debug "RoleBinding subject mismatch: expected kind \"ServiceAccount\" and name \"$expected_sa\", found kind \"$rb_subject_kind\" and name \"$rb_subject_name\"."
    failed
    return
  fi
  if [ -n "$rb_subject_ns" ] && [ "$rb_subject_ns" != "$expected_namespace" ]; then
    debug "RoleBinding subject namespace mismatch: expected \"$expected_namespace\", found \"$rb_subject_ns\"."
    failed
    return
  fi

  # Check if the ServiceAccount can list pods in dev-team-1 namespace
  debug "Checking if ServiceAccount \"$expected_sa\" can list pods in namespace \"$expected_namespace\"."
  local sa_can_list
  sa_can_list="$(kubectl auth can-i list pods --as=system:serviceaccount:"$expected_namespace":"$expected_sa" -n "$expected_namespace" 2>/dev/null)" || {
    debug "Failed to check permissions for ServiceAccount \"$expected_sa\" in namespace \"$expected_namespace\"."
    failed
    return
  }
  if [ "$sa_can_list" != "yes" ]; then
    debug "ServiceAccount \"$expected_sa\" cannot list pods in namespace \"$expected_namespace\"."
    failed
    return
  fi

  # Check if the ServiceAccount cannot list pods in default namespace
  debug "Checking if ServiceAccount \"$expected_sa\" cannot list pods in namespace \"default\"."
  local sa_cannot_list_default
  sa_cannot_list_default="$(kubectl auth can-i list pods --as=system:serviceaccount:"$expected_namespace":"$expected_sa" -n default 2>/dev/null)"
  if [ "$sa_cannot_list_default" != "no" ]; then
    debug "ServiceAccount \"$expected_sa\" should not be able to list pods in namespace \"default\", but can."
    failed
    return
  fi
  if [ "$sa_cannot_list_default" != "no" ]; then
    debug "ServiceAccount \"$expected_sa\" should not be able to list pods in namespace \"default\", but can."
    failed
    return
  fi

  debug "All checks passed for Task $TASK_NUMBER. ServiceAccount, Role, RoleBinding, and permissions are correctly configured."
  solved
  return
}

# shellcheck disable=SC2329
verify_task2() {
  TASK_NUMBER="2"
  local expected_namespace="monitoring"
  local expected_sa="node-inspector-sa"
  local expected_clusterrole="node-reader-crole"
  local expected_clusterrolebinding="node-inspector-crbinding"
  local expected_verbs=("get" "list")
  local expected_verbs_count=2
  local expected_resource="nodes"

  # Check if the namespace exists
  debug "Checking if namespace \"$expected_namespace\" exists."
  kubectl get namespace "$expected_namespace" -o json >/dev/null 2>&1 || {
    debug "Failed to get namespace \"$expected_namespace\"."
    failed
    return
  }

  # Check if the ServiceAccount exists
  debug "Checking if ServiceAccount \"$expected_sa\" exists in namespace \"$expected_namespace\"."
  kubectl get serviceaccount "$expected_sa" -n "$expected_namespace" -o json >/dev/null 2>&1 || {
    debug "Failed to get ServiceAccount \"$expected_sa\" in namespace \"$expected_namespace\"."
    failed
    return
  }

  # Check if the ClusterRole exists and has correct rules
  debug "Checking if ClusterRole \"$expected_clusterrole\" exists and has correct rules."
  local cr_json
  cr_json="$(kubectl get clusterrole "$expected_clusterrole" -o json 2>/dev/null)" || {
    debug "Failed to get ClusterRole \"$expected_clusterrole\"."
    failed
    return
  }
  # Find the rule that applies to nodes
  local rule_index
  rule_index="$(echo "$cr_json" | jq '.rules | map(select(.resources | index("'"$expected_resource"'"))) | .[0]' 2>/dev/null)" || {
    debug "Failed to extract rule for resource \"$expected_resource\" from ClusterRole JSON."
    failed
    return
  }
  if [ "$rule_index" = "null" ]; then
    debug "No rule found for resource \"$expected_resource\" in ClusterRole \"$expected_clusterrole\"."
    failed
    return
  fi
  # Extract verbs array for nodes rule
  local verbs_json
  verbs_json="$(echo "$rule_index" | jq -c '.verbs' 2>/dev/null)" || {
    debug "Failed to extract verbs from ClusterRole JSON."
    failed
    return
  }
  local verbs_count
  verbs_count="$(echo "$verbs_json" | jq 'length' 2>/dev/null)" || {
    debug "Failed to count verbs in ClusterRole JSON."
    failed
    return
  }
  if [ "$verbs_count" -ne "$expected_verbs_count" ]; then
    debug "ClusterRole verbs count mismatch: expected $expected_verbs_count, found $verbs_count."
    failed
    return
  fi
  # Check that all expected verbs are present
  local verb
  for verb in "${expected_verbs[@]}"; do
    echo "$verbs_json" | jq -e --arg v "$verb" 'index($v)' >/dev/null 2>&1 || {
      debug "ClusterRole verbs missing expected verb: \"$verb\". Found: $verbs_json"
      failed
      return
    }
  done

  # Check if the ClusterRoleBinding exists and binds the correct ClusterRole and ServiceAccount
  debug "Checking if ClusterRoleBinding \"$expected_clusterrolebinding\" exists and binds ClusterRole \"$expected_clusterrole\" to ServiceAccount \"$expected_sa\"."
  local crb_json
  crb_json="$(kubectl get clusterrolebinding "$expected_clusterrolebinding" -o json 2>/dev/null)" || {
    debug "Failed to get ClusterRoleBinding \"$expected_clusterrolebinding\"."
    failed
    return
  }
  local crb_role_ref_kind
  crb_role_ref_kind="$(echo "$crb_json" | jq -r '.roleRef.kind' 2>/dev/null)" || {
    debug "Failed to extract roleRef.kind from ClusterRoleBinding JSON."
    failed
    return
  }
  local crb_role_ref_name
  crb_role_ref_name="$(echo "$crb_json" | jq -r '.roleRef.name' 2>/dev/null)" || {
    debug "Failed to extract roleRef.name from ClusterRoleBinding JSON."
    failed
    return
  }
  if [ "$crb_role_ref_kind" != "ClusterRole" ] || [ "$crb_role_ref_name" != "$expected_clusterrole" ]; then
    debug "ClusterRoleBinding roleRef mismatch: expected kind \"ClusterRole\" and name \"$expected_clusterrole\", found kind \"$crb_role_ref_kind\" and name \"$crb_role_ref_name\"."
    failed
    return
  fi
  local crb_subject_kind
  crb_subject_kind="$(echo "$crb_json" | jq -r '.subjects[0].kind' 2>/dev/null)" || {
    debug "Failed to extract subject kind from ClusterRoleBinding JSON."
    failed
    return
  }
  local crb_subject_name
  crb_subject_name="$(echo "$crb_json" | jq -r '.subjects[0].name' 2>/dev/null)" || {
    debug "Failed to extract subject name from ClusterRoleBinding JSON."
    failed
    return
  }
  local crb_subject_ns
  crb_subject_ns="$(echo "$crb_json" | jq -r '.subjects[0].namespace // empty' 2>/dev/null)"
  if [ "$crb_subject_kind" != "ServiceAccount" ] || [ "$crb_subject_name" != "$expected_sa" ]; then
    debug "ClusterRoleBinding subject mismatch: expected kind \"ServiceAccount\" and name \"$expected_sa\", found kind \"$crb_subject_kind\" and name \"$crb_subject_name\"."
    failed
    return
  fi
  if [ -z "$crb_subject_ns" ] || [ "$crb_subject_ns" != "$expected_namespace" ]; then
    debug "ClusterRoleBinding subject namespace mismatch: expected \"$expected_namespace\", found \"$crb_subject_ns\"."
    failed
    return
  fi

  # Check if the ServiceAccount can list nodes cluster-wide
  debug "Checking if ServiceAccount \"$expected_sa\" can list nodes cluster-wide."
  local sa_can_list_nodes
  sa_can_list_nodes="$(kubectl auth can-i list nodes --as=system:serviceaccount:"$expected_namespace":"$expected_sa" 2>/dev/null)"
  if [ "$sa_can_list_nodes" != "yes" ]; then
    debug "ServiceAccount \"$expected_sa\" cannot list nodes cluster-wide."
    failed
    return
  fi

  debug "All checks passed for Task $TASK_NUMBER. ServiceAccount, ClusterRole, ClusterRoleBinding, and permissions are correctly configured."
  solved
  return
}

# shellcheck disable=SC2329
verify_task3() {
  TASK_NUMBER="3"
  local expected_namespace="cicd-pipelines"
  local expected_sa="cicd-agent-sa"
  local expected_role="deployment-manager-role"
  local expected_rolebinding="cicd-agent-binding"
  local expected_resources=("deployments" "replicasets" "pods")
  local expected_verbs=("*")
  local expected_verbs_count=1

  # Check if the namespace exists
  debug "Checking if namespace \"$expected_namespace\" exists."
  kubectl get namespace "$expected_namespace" -o json >/dev/null 2>&1 || {
    debug "Failed to get namespace \"$expected_namespace\"."
    failed
    return
  }

  # Check if the ServiceAccount exists
  debug "Checking if ServiceAccount \"$expected_sa\" exists in namespace \"$expected_namespace\"."
  kubectl get serviceaccount "$expected_sa" -n "$expected_namespace" -o json >/dev/null 2>&1 || {
    debug "Failed to get ServiceAccount \"$expected_sa\" in namespace \"$expected_namespace\"."
    failed
    return
  }

  # Check if the Role exists and has correct rules
  debug "Checking if Role \"$expected_role\" exists in namespace \"$expected_namespace\" and has correct rules."
  local role_json
  role_json="$(kubectl get role "$expected_role" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Failed to get Role \"$expected_role\" in namespace \"$expected_namespace\"."
    failed
    return
  }
  local resource
  for resource in "${expected_resources[@]}"; do
    debug "Checking rules for resource \"$resource\"."
    local rule_index
    rule_index="$(echo "$role_json" | jq '.rules | map(select(.resources | index("'"$resource"'"))) | .[0]' 2>/dev/null)" || {
      debug "Failed to extract rule for resource \"$resource\" from Role JSON."
      failed
      return
    }
    if [ "$rule_index" = "null" ]; then
      debug "No rule found for resource \"$resource\" in Role \"$expected_role\"."
      failed
      return
    fi
    local verbs_json
    verbs_json="$(echo "$rule_index" | jq -c '.verbs' 2>/dev/null)" || {
      debug "Failed to extract verbs from Role JSON for resource \"$resource\"."
      failed
      return
    }
    local verbs_count
    verbs_count="$(echo "$verbs_json" | jq 'length' 2>/dev/null)" || {
      debug "Failed to count verbs in Role JSON for resource \"$resource\"."
      failed
      return
    }
    if [ "$verbs_count" -ne "$expected_verbs_count" ]; then
      debug "Role verbs count mismatch for resource \"$resource\": expected $expected_verbs_count, found $verbs_count."
      failed
      return
    fi
    local verb
    for verb in "${expected_verbs[@]}"; do
      echo "$verbs_json" | jq -e --arg v "$verb" 'index($v)' >/dev/null 2>&1 || {
        debug "Role verbs missing expected verb: \"$verb\" for resource \"$resource\". Found: $verbs_json"
        failed
        return
      }
    done
  done

  # Extract and sort all resources from the Role
  local all_resources_sorted
  all_resources_sorted="$(echo "$role_json" | jq -c '[.rules[].resources[]] | unique | sort')" || {
    debug "Failed to extract and sort all resources from Role JSON."
    failed
    return
  }
  # Prepare and sort expected resources
  local expected_resources_json
  expected_resources_json="$(jq -cn '$ARGS.positional | sort' --args -- "${expected_resources[@]}")" || {
    debug "Failed to prepare and sort expected resources."
    failed
    return
  }
  if [ "$all_resources_sorted" != "$expected_resources_json" ]; then
    debug "Role allows resources other than expected: allowed $expected_resources_json, found $all_resources_sorted."
    failed
    return
  fi

  # Check if the RoleBinding exists and binds the correct Role and ServiceAccount
  debug "Checking if RoleBinding \"$expected_rolebinding\" exists and binds Role \"$expected_role\" to ServiceAccount \"$expected_sa\"."
  local rb_json
  rb_json="$(kubectl get rolebinding "$expected_rolebinding" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Failed to get RoleBinding \"$expected_rolebinding\" in namespace \"$expected_namespace\"."
    failed
    return
  }
  local rb_role_ref_kind
  rb_role_ref_kind="$(echo "$rb_json" | jq -r '.roleRef.kind' 2>/dev/null)" || {
    debug "Failed to extract roleRef.kind from RoleBinding JSON."
    failed
    return
  }
  local rb_role_ref_name
  rb_role_ref_name="$(echo "$rb_json" | jq -r '.roleRef.name' 2>/dev/null)" || {
    debug "Failed to extract roleRef.name from RoleBinding JSON."
    failed
    return
  }
  if [ "$rb_role_ref_kind" != "Role" ] || [ "$rb_role_ref_name" != "$expected_role" ]; then
    debug "RoleBinding roleRef mismatch: expected kind \"Role\" and name \"$expected_role\", found kind \"$rb_role_ref_kind\" and name \"$rb_role_ref_name\"."
    failed
    return
  fi
  local rb_subject_kind
  rb_subject_kind="$(echo "$rb_json" | jq -r '.subjects[0].kind' 2>/dev/null)" || {
    debug "Failed to extract subject kind from RoleBinding JSON."
    failed
    return
  }
  local rb_subject_name
  rb_subject_name="$(echo "$rb_json" | jq -r '.subjects[0].name' 2>/dev/null)" || {
    debug "Failed to extract subject name from RoleBinding JSON."
    failed
    return
  }
  local rb_subject_ns
  rb_subject_ns="$(echo "$rb_json" | jq -r '.subjects[0].namespace // empty' 2>/dev/null)"
  if [ "$rb_subject_kind" != "ServiceAccount" ] || [ "$rb_subject_name" != "$expected_sa" ]; then
    debug "RoleBinding subject mismatch: expected kind \"ServiceAccount\" and name \"$expected_sa\", found kind \"$rb_subject_kind\" and name \"$rb_subject_name\"."
    failed
    return
  fi
  if [ -n "$rb_subject_ns" ] && [ "$rb_subject_ns" != "$expected_namespace" ]; then
    debug "RoleBinding subject namespace mismatch: expected \"$expected_namespace\", found \"$rb_subject_ns\"."
    failed
    return
  fi

  # Check if the ServiceAccount can create a Deployment
  debug "Checking if ServiceAccount \"$expected_sa\" can create a Deployment in namespace \"$expected_namespace\"."
  local sa_can_create_deploy
  sa_can_create_deploy="$(kubectl auth can-i create deployment --as=system:serviceaccount:"$expected_namespace":"$expected_sa" -n "$expected_namespace" 2>/dev/null)"
  if [ "$sa_can_create_deploy" != "yes" ]; then
    debug "ServiceAccount \"$expected_sa\" cannot create a Deployment in namespace \"$expected_namespace\"."
    failed
    return
  fi

  # Check if the ServiceAccount cannot create a Service
  debug "Checking if ServiceAccount \"$expected_sa\" cannot create a Service in namespace \"$expected_namespace\"."
  local sa_cannot_create_service
  sa_cannot_create_service="$(kubectl auth can-i create service --as=system:serviceaccount:"$expected_namespace":"$expected_sa" -n "$expected_namespace" 2>/dev/null)"
  if [ "$sa_cannot_create_service" != "no" ]; then
    debug "ServiceAccount \"$expected_sa\" should not be able to create a Service in namespace \"$expected_namespace\", but can."
    failed
    return
  fi

  debug "All checks passed for Task $TASK_NUMBER. ServiceAccount, Role, RoleBinding, and permissions are correctly configured."
  solved
  return
}

# shellcheck disable=SC2329
verify_task4() {
  TASK_NUMBER="4"
  local expected_sa_namespace="default"
  local expected_sa="log-scraper-sa"
  local expected_role_namespace="app-prod"
  local expected_role="log-reader-role"
  local expected_rolebinding="log-scraper-binding"
  local expected_resource="pods"
  local expected_subresource="log"
  local expected_verbs=("get")
  local expected_verbs_count=1

  # Check if the ServiceAccount exists in the default namespace
  debug "Checking if ServiceAccount \"$expected_sa\" exists in namespace \"$expected_sa_namespace\"."
  kubectl get serviceaccount "$expected_sa" -n "$expected_sa_namespace" -o json >/dev/null 2>&1 || {
    debug "Failed to get ServiceAccount \"$expected_sa\" in namespace \"$expected_sa_namespace\"."
    failed
    return
  }

  # Check if the Role exists in app-prod and has correct rules
  debug "Checking if Role \"$expected_role\" exists in namespace \"$expected_role_namespace\" and has correct rules."
  local role_json
  role_json="$(kubectl get role "$expected_role" -n "$expected_role_namespace" -o json 2>/dev/null)" || {
    debug "Failed to get Role \"$expected_role\" in namespace \"$expected_role_namespace\"."
    failed
    return
  }
  # Find the rule that applies to pods/logs
  debug "Checking for a rule that allows 'get' on the pods/logs subresource."
  local rule_index
  rule_index="$(echo "$role_json" | jq '.rules | map(select(.resources | index("'"$expected_resource/$expected_subresource"'")) | select(.verbs | index("get"))) | .[0]' 2>/dev/null)" || {
    debug "Failed to extract rule for resource \"$expected_resource/$expected_subresource\" from Role JSON."
    failed
    return
  }
  if [ "$rule_index" = "null" ]; then
    debug "No rule found for resource \"$expected_resource/$expected_subresource\" in Role \"$expected_role\"."
    failed
    return
  fi
  # Check verbs
  local verbs_json
  verbs_json="$(echo "$rule_index" | jq -c '.verbs' 2>/dev/null)" || {
    debug "Failed to extract verbs from Role JSON."
    failed
    return
  }
  local verbs_count
  verbs_count="$(echo "$verbs_json" | jq 'length' 2>/dev/null)" || {
    debug "Failed to count verbs in Role JSON."
    failed
    return
  }
  if [ "$verbs_count" -ne "$expected_verbs_count" ]; then
    debug "Role verbs count mismatch: expected $expected_verbs_count, found $verbs_count."
    failed
    return
  fi
  local verb
  for verb in "${expected_verbs[@]}"; do
    echo "$verbs_json" | jq -e --arg v "$verb" 'index($v)' >/dev/null 2>&1 || {
      debug "Role verbs missing expected verb: \"$verb\". Found: $verbs_json"
      failed
      return
    }
  done

  # Check that no other resources are allowed (order-independent)
  debug "Checking that Role does not allow access to other resource types."
  local all_resources_sorted
  all_resources_sorted="$(echo "$role_json" | jq -c '[.rules[].resources[]] | unique | sort')" || {
    debug "Failed to extract and sort all resources from Role JSON."
    failed
    return
  }
  local expected_resources_json
  expected_resources_json="$(jq -cn '$ARGS.positional | sort' --args -- "$expected_resource/$expected_subresource")" || {
    debug "Failed to prepare and sort expected resources."
    failed
    return
  }
  if [ "$all_resources_sorted" != "$expected_resources_json" ]; then
    debug "Role allows resources other than expected: allowed $expected_resources_json, found $all_resources_sorted."
    failed
    return
  fi

  # Check if the RoleBinding exists and binds the correct Role and ServiceAccount from default namespace
  debug "Checking if RoleBinding \"$expected_rolebinding\" exists in namespace \"$expected_role_namespace\" and binds Role \"$expected_role\" to ServiceAccount \"$expected_sa\" from namespace \"$expected_sa_namespace\"."
  local rb_json
  rb_json="$(kubectl get rolebinding "$expected_rolebinding" -n "$expected_role_namespace" -o json 2>/dev/null)" || {
    debug "Failed to get RoleBinding \"$expected_rolebinding\" in namespace \"$expected_role_namespace\"."
    failed
    return
  }
  local rb_role_ref_kind
  rb_role_ref_kind="$(echo "$rb_json" | jq -r '.roleRef.kind' 2>/dev/null)" || {
    debug "Failed to extract roleRef.kind from RoleBinding JSON."
    failed
    return
  }
  local rb_role_ref_name
  rb_role_ref_name="$(echo "$rb_json" | jq -r '.roleRef.name' 2>/dev/null)" || {
    debug "Failed to extract roleRef.name from RoleBinding JSON."
    failed
    return
  }
  if [ "$rb_role_ref_kind" != "Role" ] || [ "$rb_role_ref_name" != "$expected_role" ]; then
    debug "RoleBinding roleRef mismatch: expected kind \"Role\" and name \"$expected_role\", found kind \"$rb_role_ref_kind\" and name \"$rb_role_ref_name\"."
    failed
    return
  fi
  local rb_subject_kind
  rb_subject_kind="$(echo "$rb_json" | jq -r '.subjects[0].kind' 2>/dev/null)" || {
    debug "Failed to extract subject kind from RoleBinding JSON."
    failed
    return
  }
  local rb_subject_name
  rb_subject_name="$(echo "$rb_json" | jq -r '.subjects[0].name' 2>/dev/null)" || {
    debug "Failed to extract subject name from RoleBinding JSON."
    failed
    return
  }
  local rb_subject_ns
  rb_subject_ns="$(echo "$rb_json" | jq -r '.subjects[0].namespace // empty' 2>/dev/null)"
  if [ "$rb_subject_kind" != "ServiceAccount" ] || [ "$rb_subject_name" != "$expected_sa" ]; then
    debug "RoleBinding subject mismatch: expected kind \"ServiceAccount\" and name \"$expected_sa\", found kind \"$rb_subject_kind\" and name \"$rb_subject_name\"."
    failed
    return
  fi
  if [ "$rb_subject_ns" != "$expected_sa_namespace" ]; then
    debug "RoleBinding subject namespace mismatch: expected \"$expected_sa_namespace\", found \"$rb_subject_ns\"."
    failed
    return
  fi

  # Check if the ServiceAccount can get pod logs in app-prod namespace
  debug "Checking if ServiceAccount \"$expected_sa\" can get pod logs in namespace \"$expected_role_namespace\"."
  local sa_can_get_logs
  sa_can_get_logs="$(kubectl auth can-i get pods --subresource log --as=system:serviceaccount:"$expected_sa_namespace":"$expected_sa" -n "$expected_role_namespace" 2>/dev/null)"
  if [ "$sa_can_get_logs" != "yes" ]; then
    debug "ServiceAccount \"$expected_sa\" cannot get pod logs in namespace \"$expected_role_namespace\"."
    failed
    return
  fi

  # Check if the ServiceAccount cannot get pods (main resource) in app-prod namespace
  debug "Checking if ServiceAccount \"$expected_sa\" cannot get pods in namespace \"$expected_role_namespace\"."
  local sa_cannot_get_pods
  sa_cannot_get_pods="$(kubectl auth can-i get pods --as=system:serviceaccount:"$expected_sa_namespace":"$expected_sa" -n "$expected_role_namespace" 2>/dev/null)"
  if [ "$sa_cannot_get_pods" != "no" ]; then
    debug "ServiceAccount \"$expected_sa\" should not be able to get pods in namespace \"$expected_role_namespace\", but can."
    failed
    return
  fi

  debug "All checks passed for Task $TASK_NUMBER. ServiceAccount, Role, RoleBinding, and permissions are correctly configured."
  solved
  return
}

# shellcheck disable=SC2329
verify_task5() {
  TASK_NUMBER="5"
  local expected_namespace="project-alpha"
  local expected_sa="dev-user-1"
  local expected_role="config-reader"
  local expected_rolebinding="dev-user-1-binding"
  local expected_resource="configmaps"
  local expected_verb="list"

  # Check if the ServiceAccount exists
  debug "Checking if ServiceAccount \"$expected_sa\" exists in namespace \"$expected_namespace\"."
  kubectl get serviceaccount "$expected_sa" -n "$expected_namespace" -o json >/dev/null 2>&1 || {
    debug "Failed to get ServiceAccount \"$expected_sa\" in namespace \"$expected_namespace\"."
    failed
    return
  }

  # Check if the Role exists
  debug "Checking if Role \"$expected_role\" exists in namespace \"$expected_namespace\"."
  local role_json
  role_json="$(kubectl get role "$expected_role" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Failed to get Role \"$expected_role\" in namespace \"$expected_namespace\"."
    failed
    return
  }

  # Check if the Role allows 'list' on 'configmaps'
  debug "Checking if Role \"$expected_role\" allows '$expected_verb' on '$expected_resource'."
  local rule_found
  rule_found="$(echo "$role_json" | jq '[.rules[] | select((.resources | index("'"$expected_resource"'")) and (.verbs | index("'"$expected_verb"'")))] | length' 2>/dev/null)" || {
    debug "Failed to check rules in Role \"$expected_role\"."
    failed
    return
  }
  if [ "$rule_found" -eq 0 ]; then
    debug "Role \"$expected_role\" does not allow '$expected_verb' on '$expected_resource'."
    failed
    return
  fi

  # Check if the RoleBinding exists and binds the correct Role and ServiceAccount
  debug "Checking if RoleBinding \"$expected_rolebinding\" exists and binds Role \"$expected_role\" to ServiceAccount \"$expected_sa\"."
  local rb_json
  rb_json="$(kubectl get rolebinding "$expected_rolebinding" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Failed to get RoleBinding \"$expected_rolebinding\" in namespace \"$expected_namespace\"."
    failed
    return
  }
  local rb_role_ref_kind
  rb_role_ref_kind="$(echo "$rb_json" | jq -r '.roleRef.kind' 2>/dev/null)" || {
    debug "Failed to extract roleRef.kind from RoleBinding JSON."
    failed
    return
  }
  local rb_role_ref_name
  rb_role_ref_name="$(echo "$rb_json" | jq -r '.roleRef.name' 2>/dev/null)" || {
    debug "Failed to extract roleRef.name from RoleBinding JSON."
    failed
    return
  }
  if [ "$rb_role_ref_kind" != "Role" ] || [ "$rb_role_ref_name" != "$expected_role" ]; then
    debug "RoleBinding roleRef mismatch: expected kind \"Role\" and name \"$expected_role\", found kind \"$rb_role_ref_kind\" and name \"$rb_role_ref_name\"."
    failed
    return
  fi
  local rb_subject_kind
  rb_subject_kind="$(echo "$rb_json" | jq -r '.subjects[0].kind' 2>/dev/null)" || {
    debug "Failed to extract subject kind from RoleBinding JSON."
    failed
    return
  }
  local rb_subject_name
  rb_subject_name="$(echo "$rb_json" | jq -r '.subjects[0].name' 2>/dev/null)" || {
    debug "Failed to extract subject name from RoleBinding JSON."
    failed
    return
  }
  if [ "$rb_subject_kind" != "ServiceAccount" ] || [ "$rb_subject_name" != "$expected_sa" ]; then
    debug "RoleBinding subject mismatch: expected kind \"ServiceAccount\" and name \"$expected_sa\", found kind \"$rb_subject_kind\" and name \"$rb_subject_name\"."
    failed
    return
  fi

  # Check if the ServiceAccount can list configmaps in the namespace
  debug "Checking if ServiceAccount \"$expected_sa\" can list configmaps in namespace \"$expected_namespace\"."
  local can_list
  can_list="$(kubectl auth can-i list configmaps --as=system:serviceaccount:"$expected_namespace":"$expected_sa" -n "$expected_namespace" 2>/dev/null)"
  if [ "$can_list" != "yes" ]; then
    debug "ServiceAccount \"$expected_sa\" cannot list configmaps in namespace \"$expected_namespace\"."
    failed
    return
  fi

  debug "All checks passed for Task $TASK_NUMBER. Role, RoleBinding, and ServiceAccount are correctly configured."
  solved
  return
}

# shellcheck disable=SC2329
verify_task6() {
  TASK_NUMBER="6"
  local expected_namespace="finance"
  local expected_secret="api-key-v2"
  local expected_sa="specific-secret-reader-sa"
  local expected_role="single-secret-getter-role"
  local expected_rolebinding="single-secret-getter-binding"
  local expected_resource="secrets"
  local expected_verb="get"

  # Check if the namespace exists
  debug "Checking if namespace \"$expected_namespace\" exists."
  kubectl get namespace "$expected_namespace" -o json >/dev/null 2>&1 || {
    debug "Failed to get namespace \"$expected_namespace\"."
    failed
    return
  }

  # Check if the Secret exists
  debug "Checking if Secret \"$expected_secret\" exists in namespace \"$expected_namespace\"."
  kubectl get secret "$expected_secret" -n "$expected_namespace" -o json >/dev/null 2>&1 || {
    debug "Failed to get Secret \"$expected_secret\" in namespace \"$expected_namespace\"."
    failed
    return
  }

  # Check if the ServiceAccount exists
  debug "Checking if ServiceAccount \"$expected_sa\" exists in namespace \"$expected_namespace\"."
  kubectl get serviceaccount "$expected_sa" -n "$expected_namespace" -o json >/dev/null 2>&1 || {
    debug "Failed to get ServiceAccount \"$expected_sa\" in namespace \"$expected_namespace\"."
    failed
    return
  }

  # Check if the Role exists and has correct rules
  debug "Checking if Role \"$expected_role\" exists in namespace \"$expected_namespace\" and has correct rules."
  local role_json
  role_json="$(kubectl get role "$expected_role" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Failed to get Role \"$expected_role\" in namespace \"$expected_namespace\"."
    failed
    return
  }
  # Find the rule that applies to secrets with resourceNames
  local rule_index
  rule_index="$(echo "$role_json" | jq '.rules | map(select((.resources | index("'"$expected_resource"'")) and (.verbs | index("'"$expected_verb"'")) and (.resourceNames | index("'"$expected_secret"'")))) | .[0]' 2>/dev/null)" || {
    debug "Failed to extract rule for resource \"$expected_resource\" with resourceName \"$expected_secret\" from Role JSON."
    failed
    return
  }
  if [ "$rule_index" = "null" ]; then
    debug "No rule found for resource \"$expected_resource\" with resourceName \"$expected_secret\" in Role \"$expected_role\"."
    failed
    return
  fi
  # Check that only the expected secret is allowed
  local resource_names_count
  resource_names_count="$(echo "$rule_index" | jq '.resourceNames | length' 2>/dev/null)" || {
    debug "Failed to count resourceNames in Role JSON."
    failed
    return
  }
  if [ "$resource_names_count" -ne 1 ]; then
    debug "Role \"$expected_role\" allows more than one resourceName for \"$expected_resource\"."
    failed
    return
  fi
  local resource_name
  resource_name="$(echo "$rule_index" | jq -r '.resourceNames[0]' 2>/dev/null)" || {
    debug "Failed to extract resourceName from Role JSON."
    failed
    return
  }
  if [ "$resource_name" != "$expected_secret" ]; then
    debug "Role \"$expected_role\" allows resourceName \"$resource_name\" instead of \"$expected_secret\"."
    failed
    return
  fi

  # Check if the RoleBinding exists and binds the correct Role and ServiceAccount
  debug "Checking if RoleBinding \"$expected_rolebinding\" exists and binds Role \"$expected_role\" to ServiceAccount \"$expected_sa\"."
  local rb_json
  rb_json="$(kubectl get rolebinding "$expected_rolebinding" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Failed to get RoleBinding \"$expected_rolebinding\" in namespace \"$expected_namespace\"."
    failed
    return
  }
  local rb_role_ref_kind
  rb_role_ref_kind="$(echo "$rb_json" | jq -r '.roleRef.kind' 2>/dev/null)" || {
    debug "Failed to extract roleRef.kind from RoleBinding JSON."
    failed
    return
  }
  local rb_role_ref_name
  rb_role_ref_name="$(echo "$rb_json" | jq -r '.roleRef.name' 2>/dev/null)" || {
    debug "Failed to extract roleRef.name from RoleBinding JSON."
    failed
    return
  }
  if [ "$rb_role_ref_kind" != "Role" ] || [ "$rb_role_ref_name" != "$expected_role" ]; then
    debug "RoleBinding roleRef mismatch: expected kind \"Role\" and name \"$expected_role\", found kind \"$rb_role_ref_kind\" and name \"$rb_role_ref_name\"."
    failed
    return
  fi
  local rb_subject_kind
  rb_subject_kind="$(echo "$rb_json" | jq -r '.subjects[0].kind' 2>/dev/null)" || {
    debug "Failed to extract subject kind from RoleBinding JSON."
    failed
    return
  }
  local rb_subject_name
  rb_subject_name="$(echo "$rb_json" | jq -r '.subjects[0].name' 2>/dev/null)" || {
    debug "Failed to extract subject name from RoleBinding JSON."
    failed
    return
  }
  if [ "$rb_subject_kind" != "ServiceAccount" ] || [ "$rb_subject_name" != "$expected_sa" ]; then
    debug "RoleBinding subject mismatch: expected kind \"ServiceAccount\" and name \"$expected_sa\", found kind \"$rb_subject_kind\" and name \"$rb_subject_name\"."
    failed
    return
  fi

  # Check if the ServiceAccount can get the specific secret
  debug "Checking if ServiceAccount \"$expected_sa\" can get secret \"$expected_secret\" in namespace \"$expected_namespace\"."
  local sa_can_get_secret
  sa_can_get_secret="$(kubectl auth can-i get secret/"$expected_secret" --as=system:serviceaccount:"$expected_namespace":"$expected_sa" -n "$expected_namespace" 2>/dev/null)"
  if [ "$sa_can_get_secret" != "yes" ]; then
    debug "ServiceAccount \"$expected_sa\" cannot get secret \"$expected_secret\" in namespace \"$expected_namespace\"."
    failed
    return
  fi

  # Check if the ServiceAccount cannot get any other secret in the namespace
  debug "Checking if ServiceAccount \"$expected_sa\" cannot get other secrets in namespace \"$expected_namespace\"."
  local other_secret
  other_secret="$(kubectl get secrets -n "$expected_namespace" -o json | jq -r '.items[] | select(.metadata.name != "'"$expected_secret"'") | .metadata.name' | head -n1)"
  if [ -n "$other_secret" ]; then
    local sa_cannot_get_other
    sa_cannot_get_other="$(kubectl auth can-i get secret/"$other_secret" --as=system:serviceaccount:"$expected_namespace":"$expected_sa" -n "$expected_namespace" 2>/dev/null)"
    if [ "$sa_cannot_get_other" != "no" ]; then
      debug "ServiceAccount \"$expected_sa\" should not be able to get secret \"$other_secret\" in namespace \"$expected_namespace\", but can."
      failed
      return
    fi
  fi

  debug "All checks passed for Task $TASK_NUMBER. ServiceAccount, Role, RoleBinding, and permissions are correctly configured."
  solved
  return
}

# shellcheck disable=SC2329
verify_task7() {
  TASK_NUMBER="7"
  local expected_namespace="qa-environment"
  local expected_sa="debugger-sa"
  local expected_role="pod-exec-role"
  local expected_rolebinding="debugger-binding"
  local expected_role_kind="Role"
  local expected_role_name="pod-exec-role"
  local expected_subject_name="debugger-sa"
  local expected_subject_ns="qa-environment"

  # Check if namespace exists
  debug "Checking if namespace '$expected_namespace' exists."
  kubectl get namespace "$expected_namespace" -o json 2>/dev/null | jq .metadata.name >/dev/null || {
    debug "Namespace '$expected_namespace' not found."
    failed
    return
  }

  # Check if ServiceAccount exists
  debug "Checking if ServiceAccount '$expected_sa' exists in namespace '$expected_namespace'."
  kubectl get serviceaccount "$expected_sa" -n "$expected_namespace" -o json 2>/dev/null | jq .metadata.name >/dev/null || {
    debug "ServiceAccount '$expected_sa' not found in namespace '$expected_namespace'."
    failed
    return
  }

  # Check if Role exists and has correct rules
  debug "Checking if Role '$expected_role' exists in namespace '$expected_namespace' and has correct rules."
  local role_json
  role_json="$(kubectl get role "$expected_role" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Role '$expected_role' not found in namespace '$expected_namespace'."
    failed
    return
  }

  # Check for pods/exec rule with create verb
  local exec_rule_count
  exec_rule_count="$(echo "$role_json" | jq '[.rules[]? | select((.resources? // []) | index("pods/exec")) | select((.verbs? // []) | index("create"))] | length')" || {
    debug "Failed to parse Role rules for pods/exec."
    failed
    return
  }
  if [ "$exec_rule_count" -eq 0 ]; then
    debug "Role '$expected_role' does not grant 'create' on 'pods/exec'."
    failed
    return
  fi

  # Check for pods rule with get and list verbs
  local pod_rule_count
  pod_rule_count="$(echo "$role_json" | jq '[.rules[]? | select((.resources? // []) | index("pods")) | select((.verbs? // []) | index("get") and index("list"))] | length')" || {
    debug "Failed to parse Role rules for pods."
    failed
    return
  }
  if [ "$pod_rule_count" -eq 0 ]; then
    debug "Role '$expected_role' does not grant 'get' and 'list' on 'pods'."
    failed
    return
  fi

  # Check if RoleBinding exists and is correct
  debug "Checking if RoleBinding '$expected_rolebinding' exists and binds the Role to the ServiceAccount."
  local rb_json
  rb_json="$(kubectl get rolebinding "$expected_rolebinding" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "RoleBinding '$expected_rolebinding' not found in namespace '$expected_namespace'."
    failed
    return
  }

  # Check RoleRef
  local rb_role_kind
  rb_role_kind="$(echo "$rb_json" | jq -r '.roleRef.kind')" || {
    debug "Failed to parse RoleBinding roleRef.kind."
    failed
    return
  }
  if [ "$rb_role_kind" != "$expected_role_kind" ]; then
    debug "RoleBinding '$expected_rolebinding' roleRef.kind is '$rb_role_kind', expected '$expected_role_kind'."
    failed
    return
  fi
  local rb_role_name
  rb_role_name="$(echo "$rb_json" | jq -r '.roleRef.name')" || {
    debug "Failed to parse RoleBinding roleRef.name."
    failed
    return
  }
  if [ "$rb_role_name" != "$expected_role_name" ]; then
    debug "RoleBinding '$expected_rolebinding' roleRef.name is '$rb_role_name', expected '$expected_role_name'."
    failed
    return
  fi

  # Check subjects
  local subject_count
  subject_count="$(echo "$rb_json" | jq '[.subjects[]? | select(.kind=="ServiceAccount" and .name=="'"$expected_subject_name"'" and .namespace=="'"$expected_subject_ns"'")] | length')" || {
    debug "Failed to parse RoleBinding subjects."
    failed
    return
  }
  if [ "$subject_count" -eq 0 ]; then
    debug "RoleBinding '$expected_rolebinding' does not bind to ServiceAccount '$expected_subject_name' in namespace '$expected_subject_ns'."
    failed
    return
  fi

  # Check if ServiceAccount can exec into pods (using kubectl auth can-i)
  debug "Checking if ServiceAccount '$expected_sa' can exec into pods in namespace '$expected_namespace'."
  local pod_exec_auth
  pod_exec_auth=$(kubectl auth can-i create pods --subresource exec --as=system:serviceaccount:"$expected_namespace":"$expected_sa" -n "$expected_namespace" 2>/dev/null)
  if [ "$pod_exec_auth" != "yes" ]; then
    debug "ServiceAccount '$expected_sa' cannot exec into pods in namespace '$expected_namespace'."
    failed
    return
  fi

  debug "All checks passed for Task 7. Verification successful."
  solved
  return
}

# shellcheck disable=SC2329
verify_task8() {
  TASK_NUMBER="8"
  local expected_namespace="batch-processing"
  local expected_sa="cron-manager-sa"
  local expected_role="cronjob-lifecycle-role"
  local expected_rolebinding="bind-cron-manager"
  local expected_role_kind="Role"
  local expected_role_name="cronjob-lifecycle-role"
  local expected_subject_name="cron-manager-sa"
  local expected_subject_ns="batch-processing"
  local expected_cronjob_api_group="batch"
  local expected_cronjob_resource="cronjobs"
  local expected_verbs=("get" "list" "watch" "create" "update" "patch" "delete")
  local expected_verbs_count="${#expected_verbs[@]}"

  # Check if namespace exists
  debug "Checking if namespace '$expected_namespace' exists."
  kubectl get namespace "$expected_namespace" -o json 2>/dev/null | jq .metadata.name >/dev/null || {
    debug "Namespace '$expected_namespace' not found."
    failed
    return
  }

  # Check if ServiceAccount exists
  debug "Checking if ServiceAccount '$expected_sa' exists in namespace '$expected_namespace'."
  kubectl get serviceaccount "$expected_sa" -n "$expected_namespace" -o json 2>/dev/null | jq .metadata.name >/dev/null || {
    debug "ServiceAccount '$expected_sa' not found in namespace '$expected_namespace'."
    failed
    return
  }

  # Check if Role exists and has correct rules
  debug "Checking if Role '$expected_role' exists in namespace '$expected_namespace' and has correct rules."
  local role_json
  role_json="$(kubectl get role "$expected_role" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Role '$expected_role' not found in namespace '$expected_namespace'."
    failed
    return
  }

  # Find the rule for cronjobs in the batch API group
  local rule_index
  rule_index="$(echo "$role_json" | jq '[.rules[]? | select((.apiGroups? // []) | index("'"$expected_cronjob_api_group"'")) | select((.resources? // []) | index("'"$expected_cronjob_resource"'"))][0]')" || {
    debug "Failed to extract cronjobs rule from Role JSON."
    failed
    return
  }
  if [ -z "$rule_index" ] || [ "$rule_index" = "null" ]; then
    debug "Role '$expected_role' does not have a rule for resource '$expected_cronjob_resource' in apiGroup '$expected_cronjob_api_group'."
    failed
    return
  fi

  # Extract verbs array for cronjobs rule
  local verbs_json
  verbs_json="$(echo "$rule_index" | jq -c '.verbs' 2>/dev/null)" || {
    debug "Failed to extract verbs from Role JSON."
    failed
    return
  }
  local verbs_count
  verbs_count="$(echo "$verbs_json" | jq 'length' 2>/dev/null)" || {
    debug "Failed to count verbs in Role JSON."
    failed
    return
  }
  if [ "$verbs_count" -ne "$expected_verbs_count" ]; then
    debug "Role verbs count mismatch: expected $expected_verbs_count, found $verbs_count."
    failed
    return
  fi
  # Check that all expected verbs are present
  local verb
  for verb in "${expected_verbs[@]}"; do
    echo "$verbs_json" | jq -e --arg v "$verb" 'index($v)' >/dev/null 2>&1 || {
      debug "Role verbs missing expected verb: \"$verb\". Found: $verbs_json"
      failed
      return
    }
  done

  # Check if RoleBinding exists and is correct
  debug "Checking if RoleBinding '$expected_rolebinding' exists and binds the Role to the ServiceAccount."
  local rb_json
  rb_json="$(kubectl get rolebinding "$expected_rolebinding" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "RoleBinding '$expected_rolebinding' not found in namespace '$expected_namespace'."
    failed
    return
  }

  # Check RoleRef
  local rb_role_kind
  rb_role_kind="$(echo "$rb_json" | jq -r '.roleRef.kind')" || {
    debug "Failed to parse RoleBinding roleRef.kind."
    failed
    return
  }
  if [ "$rb_role_kind" != "$expected_role_kind" ]; then
    debug "RoleBinding '$expected_rolebinding' roleRef.kind is '$rb_role_kind', expected '$expected_role_kind'."
    failed
    return
  fi
  local rb_role_name
  rb_role_name="$(echo "$rb_json" | jq -r '.roleRef.name')" || {
    debug "Failed to parse RoleBinding roleRef.name."
    failed
    return
  }
  if [ "$rb_role_name" != "$expected_role_name" ]; then
    debug "RoleBinding '$expected_rolebinding' roleRef.name is '$rb_role_name', expected '$expected_role_name'."
    failed
    return
  fi

  # Check subjects
  local subject_count
  subject_count="$(echo "$rb_json" | jq '[.subjects[]? | select(.kind=="ServiceAccount" and .name=="'"$expected_subject_name"'" and .namespace=="'"$expected_subject_ns"'")] | length')" || {
    debug "Failed to parse RoleBinding subjects."
    failed
    return
  }
  if [ "$subject_count" -eq 0 ]; then
    debug "RoleBinding '$expected_rolebinding' does not bind to ServiceAccount '$expected_subject_name' in namespace '$expected_subject_ns'."
    failed
    return
  fi

  # Check if ServiceAccount can create CronJobs
  debug "Checking if ServiceAccount '$expected_sa' can create CronJobs in namespace '$expected_namespace'."
  kubectl auth can-i create cronjobs.batch --as=system:serviceaccount:"$expected_namespace":"$expected_sa" -n "$expected_namespace" 2>/dev/null | grep -q '^yes$' || {
    debug "ServiceAccount '$expected_sa' cannot create CronJobs in namespace '$expected_namespace'."
    failed
    return
  }

  # Check if ServiceAccount cannot create Pods
  debug "Checking if ServiceAccount '$expected_sa' cannot create Pods in namespace '$expected_namespace'."
  kubectl auth can-i create pods --as=system:serviceaccount:"$expected_namespace":"$expected_sa" -n "$expected_namespace" 2>/dev/null | grep -q '^no$' || {
    debug "ServiceAccount '$expected_sa' is able to create Pods in namespace '$expected_namespace', but should not be able to."
    failed
    return
  }

  debug "All checks passed for Task 8. Verification successful."
  solved
  return
}

# shellcheck disable=SC2329
verify_task9() {
  TASK_NUMBER="9"
  local expected_clusterrole="storage-viewer-crole"
  local expected_crbinding="sara-storage-viewer-crbinding"
  local expected_user="sara.jones@example.com"
  local expected_pvc_resource="persistentvolumeclaims"
  local expected_pvc_apigroup=""
  local expected_sc_resource="storageclasses"
  local expected_sc_apigroup="storage.k8s.io"
  local expected_verbs=("get" "list" "watch")
  local expected_verbs_count="${#expected_verbs[@]}"

  # Check if ClusterRole exists
  debug "Checking if ClusterRole '$expected_clusterrole' exists."
  local cr_json
  cr_json="$(kubectl get clusterrole "$expected_clusterrole" -o json 2>/dev/null)" || {
    debug "ClusterRole '$expected_clusterrole' not found."
    failed
    return
  }

  # Check for PVC rule in core API group
  debug "Checking for PVC rule in ClusterRole."
  local pvc_rule
  pvc_rule="$(echo "$cr_json" | jq '[.rules[]? | select((.apiGroups? // [""]) | index("'"$expected_pvc_apigroup"'")) | select((.resources? // []) | index("'"$expected_pvc_resource"'"))][0]')" || {
    debug "Failed to extract PVC rule from ClusterRole JSON."
    failed
    return
  }
  if [ -z "$pvc_rule" ] || [ "$pvc_rule" = "null" ]; then
    debug "ClusterRole '$expected_clusterrole' does not have a rule for resource '$expected_pvc_resource' in core API group."
    failed
    return
  fi

  # Extract verbs array for PVC rule
  local pvc_verbs_json
  pvc_verbs_json="$(echo "$pvc_rule" | jq -c '.verbs' 2>/dev/null)" || {
    debug "Failed to extract verbs from PVC rule."
    failed
    return
  }
  local pvc_verbs_count
  pvc_verbs_count="$(echo "$pvc_verbs_json" | jq 'length' 2>/dev/null)" || {
    debug "Failed to count verbs in PVC rule."
    failed
    return
  }
  if [ "$pvc_verbs_count" -ne "$expected_verbs_count" ]; then
    debug "PVC rule verbs count mismatch: expected $expected_verbs_count, found $pvc_verbs_count."
    failed
    return
  fi
  local verb
  for verb in "${expected_verbs[@]}"; do
    echo "$pvc_verbs_json" | jq -e --arg v "$verb" 'index($v)' >/dev/null 2>&1 || {
      debug "PVC rule verbs missing expected verb: \"$verb\". Found: $pvc_verbs_json"
      failed
      return
    }
  done

  # Check for StorageClass rule in storage.k8s.io API group
  debug "Checking for StorageClass rule in ClusterRole."
  local sc_rule
  sc_rule="$(echo "$cr_json" | jq '[.rules[]? | select((.apiGroups? // []) | index("'"$expected_sc_apigroup"'")) | select((.resources? // []) | index("'"$expected_sc_resource"'"))][0]')" || {
    debug "Failed to extract StorageClass rule from ClusterRole JSON."
    failed
    return
  }
  if [ -z "$sc_rule" ] || [ "$sc_rule" = "null" ]; then
    debug "ClusterRole '$expected_clusterrole' does not have a rule for resource '$expected_sc_resource' in apiGroup '$expected_sc_apigroup'."
    failed
    return
  fi

  # Extract verbs array for StorageClass rule
  local sc_verbs_json
  sc_verbs_json="$(echo "$sc_rule" | jq -c '.verbs' 2>/dev/null)" || {
    debug "Failed to extract verbs from StorageClass rule."
    failed
    return
  }
  local sc_verbs_count
  sc_verbs_count="$(echo "$sc_verbs_json" | jq 'length' 2>/dev/null)" || {
    debug "Failed to count verbs in StorageClass rule."
    failed
    return
  }
  if [ "$sc_verbs_count" -ne "$expected_verbs_count" ]; then
    debug "StorageClass rule verbs count mismatch: expected $expected_verbs_count, found $sc_verbs_count."
    failed
    return
  fi
  for verb in "${expected_verbs[@]}"; do
    echo "$sc_verbs_json" | jq -e --arg v "$verb" 'index($v)' >/dev/null 2>&1 || {
      debug "StorageClass rule verbs missing expected verb: \"$verb\". Found: $sc_verbs_json"
      failed
      return
    }
  done

  # Check if ClusterRoleBinding exists and is correct
  debug "Checking if ClusterRoleBinding '$expected_crbinding' exists and binds the ClusterRole to the User."
  local crb_json
  crb_json="$(kubectl get clusterrolebinding "$expected_crbinding" -o json 2>/dev/null)" || {
    debug "ClusterRoleBinding '$expected_crbinding' not found."
    failed
    return
  }

  # Check RoleRef
  local crb_role_kind
  crb_role_kind="$(echo "$crb_json" | jq -r '.roleRef.kind')" || {
    debug "Failed to parse ClusterRoleBinding roleRef.kind."
    failed
    return
  }
  if [ "$crb_role_kind" != "ClusterRole" ]; then
    debug "ClusterRoleBinding '$expected_crbinding' roleRef.kind is '$crb_role_kind', expected 'ClusterRole'."
    failed
    return
  fi
  local crb_role_name
  crb_role_name="$(echo "$crb_json" | jq -r '.roleRef.name')" || {
    debug "Failed to parse ClusterRoleBinding roleRef.name."
    failed
    return
  }
  if [ "$crb_role_name" != "$expected_clusterrole" ]; then
    debug "ClusterRoleBinding '$expected_crbinding' roleRef.name is '$crb_role_name', expected '$expected_clusterrole'."
    failed
    return
  fi

  # Check subjects
  local subject_count
  subject_count="$(echo "$crb_json" | jq '[.subjects[]? | select(.kind=="User" and .name=="'"$expected_user"'")] | length')" || {
    debug "Failed to parse ClusterRoleBinding subjects."
    failed
    return
  }
  if [ "$subject_count" -eq 0 ]; then
    debug "ClusterRoleBinding '$expected_crbinding' does not bind to User '$expected_user'."
    failed
    return
  fi

  # Check if user can get PVCs cluster-wide
  debug "Checking if user '$expected_user' can get PVCs cluster-wide."
  kubectl auth can-i get persistentvolumeclaims --as="$expected_user" --all-namespaces 2>/dev/null | grep -q '^yes$' || {
    debug "User '$expected_user' cannot get PVCs cluster-wide."
    failed
    return
  }

  # Check if user can get StorageClasses cluster-wide
  debug "Checking if user '$expected_user' can get StorageClasses cluster-wide."
  kubectl auth can-i get storageclasses.storage.k8s.io --as="$expected_user" --all-namespaces 2>/dev/null | grep -q '^yes$' || {
    debug "User '$expected_user' cannot get StorageClasses cluster-wide."
    failed
    return
  }

  debug "All checks passed for Task 9. Verification successful."
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
