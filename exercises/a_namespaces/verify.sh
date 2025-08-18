#!/bin/bash

# shellcheck source=../../.scripts/verify.sh
source "$(git rev-parse --show-toplevel)/.scripts/verify.sh"

# shellcheck disable=SC2329
verify_task1() {
  TASK_NUMBER="1"

  # Expected values
  local namespace="ckad"

  # Check if the expected namespace exists by retrieving its JSON
  debug "Verifying that namespace '$namespace' exists."
  kubectl get ns "$namespace" -o json > /dev/null 2>&1 || {
    debug "Failed to retrieve namespace '$namespace'. Expected namespace to exist."
    failed
    return
  }

  debug "Namespace '$namespace' exists. Verification successful."
  solved
  return
}

# shellcheck disable=SC2329
verify_task2() {
  TASK_NUMBER="2"

  # Expected values
  local namespace="foo"
  local yaml_file="./${namespace}.yaml"

  # Check if the expected YAML file exists
  debug "Checking if file '$yaml_file' exists."
  [ -f "$yaml_file" ] || {
    debug "File '$yaml_file' does not exist. Expected file to be present."
    failed
    return
  }

  # Check if the expected namespace exists by retrieving its JSON
  debug "Verifying that namespace '$namespace' exists."
  kubectl get ns "$namespace" -o json > /dev/null 2>&1 || {
    debug "Failed to retrieve namespace '$namespace'. Expected namespace to exist."
    failed
    return
  }

  debug "File '$yaml_file' exists and namespace '$namespace' exists. Verification successful."
  solved
  return
}

# shellcheck disable=SC2329
verify_task3() {
  TASK_NUMBER="3"

  # Expected values
  local namespace="foo"
  local expected_annotation_hello="world"
  local expected_annotation_learning="kubernetes"

  # Retrieve the namespace JSON once
  debug "Retrieving JSON for namespace '$namespace'."
  local ns_json
  ns_json="$(kubectl get ns "$namespace" -o json 2>/dev/null)" || {
    debug "Failed to retrieve namespace '$namespace'. Expected namespace to exist."
    failed
    return
  }

  # Check the 'hello' annotation
  debug "Checking if annotation 'hello' is set to '$expected_annotation_hello'."
  local rs_annotation_hello
  rs_annotation_hello="$(echo "$ns_json" | jq -r '.metadata.annotations.hello // empty' 2>/dev/null)" || {
    debug "Failed to parse 'hello' annotation from namespace JSON."
    failed
    return
  }
  if [ "$rs_annotation_hello" != "$expected_annotation_hello" ]; then
    debug "Annotation 'hello' mismatch. Expected '$expected_annotation_hello', found '$rs_annotation_hello'."
    failed
    return
  fi

  # Check the 'learning' annotation
  debug "Checking if annotation 'learning' is set to '$expected_annotation_learning'."
  local rs_annotation_learning
  rs_annotation_learning="$(echo "$ns_json" | jq -r '.metadata.annotations.learning // empty' 2>/dev/null)" || {
    debug "Failed to parse 'learning' annotation from namespace JSON."
    failed
    return
  }
  if [ "$rs_annotation_learning" != "$expected_annotation_learning" ]; then
    debug "Annotation 'learning' mismatch. Expected '$expected_annotation_learning', found '$rs_annotation_learning'."
    failed
    return
  fi

  debug "All required annotations are present and correct. Verification successful."
  solved
  return
}

# shellcheck disable=SC2329
verify_task4() {
  TASK_NUMBER="4"

  # Expected values
  local namespace="foo"
  local annotations_file="${namespace}-annotations-jq.json"

  # Check if the expected annotations file exists
  debug "Checking if file '$annotations_file' exists."
  [ -f "$annotations_file" ] || {
    debug "File '$annotations_file' does not exist. Expected file to be present."
    failed
    return
  }

  # Retrieve the namespace JSON once
  debug "Retrieving JSON for namespace '$namespace'."
  local ns_json
  ns_json="$(kubectl get ns "$namespace" -o json 2>/dev/null)" || {
    debug "Failed to retrieve namespace '$namespace'. Expected namespace to exist."
    failed
    return
  }

  # Extract annotations from the namespace JSON
  debug "Extracting annotations from namespace JSON."
  local ns_annotations_json
  ns_annotations_json="$(echo "$ns_json" | jq '.metadata.annotations' 2>/dev/null)" || {
    debug "Failed to extract annotations from namespace JSON."
    failed
    return
  }

  # Compare extracted annotations with the expected file
  debug "Comparing extracted annotations with file '$annotations_file'."
  diff <(echo "$ns_annotations_json") "$annotations_file" > /dev/null 2>&1 || {
    debug "Annotations do not match. Expected contents of '$annotations_file' to match extracted annotations."
    failed
    return
  }

  debug "Annotations match the expected file. Verification successful."
  solved
  return
}

# shellcheck disable=SC2329
verify_task5() {
  TASK_NUMBER="5"

  # Expected values
  local namespace="foo"
  local annotations_file="${namespace}-annotations-jsonpath.json"

  # Check if the expected annotations file exists
  debug "Checking if file '$annotations_file' exists."
  [ -f "$annotations_file" ] || {
    debug "File '$annotations_file' does not exist. Expected file to be present."
    failed
    return
  }

  # Retrieve the namespace annotations using jsonpath
  debug "Retrieving annotations for namespace '$namespace' using jsonpath."
  local ns_annotations
  ns_annotations="$(kubectl get ns "$namespace" -o jsonpath='{.metadata.annotations}' 2>/dev/null)" || {
    debug "Failed to retrieve annotations for namespace '$namespace' using jsonpath."
    failed
    return
  }

  # Compare retrieved annotations with the expected file
  debug "Comparing retrieved annotations with file '$annotations_file'."
  diff <(echo -n "$ns_annotations") "$annotations_file" > /dev/null 2>&1 || {
    debug "Annotations do not match. Expected contents of '$annotations_file' to match retrieved annotations."
    failed
    return
  }

  debug "Annotations match the expected file. Verification successful."
  solved
  return
}

# shellcheck disable=SC2329
verify_task6() {
  TASK_NUMBER="6"

  # Expected values
  local file="all-namespaces.txt"

  # Check if the expected file exists
  debug "Checking if file '$file' exists."
  [ -f "$file" ] || {
    debug "File '$file' does not exist. Expected file to be present."
    failed
    return
  }

  # Retrieve all namespaces by name
  debug "Retrieving all namespaces using 'kubectl get ns -o name'."
  local all_ns
  all_ns="$(kubectl get ns -o name 2>/dev/null)" || {
    debug "Failed to retrieve namespaces using 'kubectl get ns -o name'."
    failed
    return
  }

  # Compare retrieved namespaces with the expected file
  debug "Comparing retrieved namespaces with file '$file'."
  diff <(echo "$all_ns") "$file" > /dev/null 2>&1 || {
    debug "Namespaces do not match. Expected contents of '$file' to match retrieved namespaces."
    failed
    return
  }

  debug "Namespaces match the expected file. Verification successful."
  solved
  return
}

# shellcheck disable=SC2329
verify_task7() {
  TASK_NUMBER="7"

  # Expected values
  local namespace="blueberry"
  local rq_name="berry-quota"
  local expected_line_length="36"
  local expected_cpu="2"
  local expected_pods="3"
  local expected_memory="2G"

  # Retrieve the resourcequota JSON once
  debug "Retrieving JSON for resourcequota '$rq_name' in namespace '$namespace'."
  local rq_json
  rq_json="$(kubectl get -n "$namespace" resourcequotas "$rq_name" -o json 2>/dev/null)" || {
    debug "Failed to retrieve resourcequota '$rq_name' in namespace '$namespace'."
    failed
    return
  }

  # Check the length of the .spec.hard line
  debug "Checking the maximum line length of '.spec.hard'."
  local rs_line_length
  rs_line_length="$(echo "$rq_json" | jq -c '.spec.hard' 2>/dev/null | wc -L)" || {
    debug "Failed to calculate line length of '.spec.hard'."
    failed
    return
  }
  if [ "$rs_line_length" != "$expected_line_length" ]; then
    debug "Line length mismatch for '.spec.hard'. Expected '$expected_line_length', found '$rs_line_length'."
    failed
    return
  fi

  # Check the cpu value
  debug "Checking if '.spec.hard.cpu' is set to '$expected_cpu'."
  local rs_cpu
  rs_cpu="$(echo "$rq_json" | jq -r '.spec.hard.cpu // empty' 2>/dev/null)" || {
    debug "Failed to extract '.spec.hard.cpu' from resourcequota JSON."
    failed
    return
  }
  if [ "$rs_cpu" != "$expected_cpu" ]; then
    debug "CPU value mismatch. Expected '$expected_cpu', found '$rs_cpu'."
    failed
    return
  fi

  # Check the pods value
  debug "Checking if '.spec.hard.pods' is set to '$expected_pods'."
  local rs_pods
  rs_pods="$(echo "$rq_json" | jq -r '.spec.hard.pods // empty' 2>/dev/null)" || {
    debug "Failed to extract '.spec.hard.pods' from resourcequota JSON."
    failed
    return
  }
  if [ "$rs_pods" != "$expected_pods" ]; then
    debug "Pods value mismatch. Expected '$expected_pods', found '$rs_pods'."
    failed
    return
  fi

  # Check the memory value
  debug "Checking if '.spec.hard.memory' is set to '$expected_memory'."
  local rs_memory
  rs_memory="$(echo "$rq_json" | jq -r '.spec.hard.memory // empty' 2>/dev/null)" || {
    debug "Failed to extract '.spec.hard.memory' from resourcequota JSON."
    failed
    return
  }
  if [ "$rs_memory" != "$expected_memory" ]; then
    debug "Memory value mismatch. Expected '$expected_memory', found '$rs_memory'."
    failed
    return
  fi

  debug "All resourcequota values are correct. Verification successful."
  solved
  return
}

# shellcheck disable=SC2329
verify_task8() {
  TASK_NUMBER="8"
  local expected_namespace="sunshine"
  local expected_limitrange_name="cpu-limit"
  local expected_min_cpu="100m"
  local expected_max_cpu="1"
  local expected_default_cpu="200m"
  local expected_default_request_cpu="100m"

  # Check if the LimitRange exists in the correct namespace
  debug "Checking if LimitRange \"$expected_limitrange_name\" exists in namespace \"$expected_namespace\"."
  local lr_json
  lr_json="$(kubectl get limitrange "$expected_limitrange_name" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Failed to get LimitRange \"$expected_limitrange_name\" in namespace \"$expected_namespace\"."
    failed
    return
  }

  # Extract the limits for type "Container"
  debug "Extracting limits for type \"Container\" from LimitRange."
  local lr_limits_json
  lr_limits_json="$(echo "$lr_json" | jq '.spec.limits[] | select(.type == "Container")' 2>/dev/null)" || {
    debug "Failed to extract limits for type \"Container\" from LimitRange JSON."
    failed
    return
  }

  # Check minimum CPU
  debug "Checking minimum CPU setting."
  local lr_min_cpu
  lr_min_cpu="$(echo "$lr_limits_json" | jq -r '.min.cpu' 2>/dev/null)" || {
    debug "Failed to extract min.cpu from LimitRange."
    failed
    return
  }
  if [ "$lr_min_cpu" != "$expected_min_cpu" ]; then
    debug "LimitRange min.cpu mismatch: expected \"$expected_min_cpu\", found \"$lr_min_cpu\"."
    failed
    return
  fi

  # Check maximum CPU
  debug "Checking maximum CPU setting."
  local lr_max_cpu
  lr_max_cpu="$(echo "$lr_limits_json" | jq -r '.max.cpu' 2>/dev/null)" || {
    debug "Failed to extract max.cpu from LimitRange."
    failed
    return
  }
  if [ "$lr_max_cpu" != "$expected_max_cpu" ]; then
    debug "LimitRange max.cpu mismatch: expected \"$expected_max_cpu\", found \"$lr_max_cpu\"."
    failed
    return
  fi

  # Check default CPU
  debug "Checking default CPU setting."
  local lr_default_cpu
  lr_default_cpu="$(echo "$lr_limits_json" | jq -r '.default.cpu' 2>/dev/null)" || {
    debug "Failed to extract default.cpu from LimitRange."
    failed
    return
  }
  if [ "$lr_default_cpu" != "$expected_default_cpu" ]; then
    debug "LimitRange default.cpu mismatch: expected \"$expected_default_cpu\", found \"$lr_default_cpu\"."
    failed
    return
  fi

  # Check defaultRequest CPU
  debug "Checking defaultRequest CPU setting."
  local lr_default_request_cpu
  lr_default_request_cpu="$(echo "$lr_limits_json" | jq -r '.defaultRequest.cpu' 2>/dev/null)" || {
    debug "Failed to extract defaultRequest.cpu from LimitRange."
    failed
    return
  }
  if [ "$lr_default_request_cpu" != "$expected_default_request_cpu" ]; then
    debug "LimitRange defaultRequest.cpu mismatch: expected \"$expected_default_request_cpu\", found \"$lr_default_request_cpu\"."
    failed
    return
  fi

  debug "All checks passed for Task $TASK_NUMBER. LimitRange is correctly configured."
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
)
run_verification VERIFY_TASK_FUNCTIONS "$@"

exit 0
