#!/bin/bash

# shellcheck source=../../.scripts/verify.sh
source "$(git rev-parse --show-toplevel)/.scripts/verify.sh"

# shellcheck disable=SC2329
verify_task1() {
  TASK_NUMBER="1"
  local namespace="default"
  local job_name="simple-job"
  local expected_image="busybox:1.28"
  local expected_command='echo "Hello CKAD"'

  # Retrieve the Job JSON once
  debug "Retrieving JSON for job '$job_name' in namespace '$namespace'."
  local job_json
  job_json="$(kubectl get job "$job_name" -n "$namespace" -o json 2>/dev/null)" || {
    debug "Job '$job_name' does not exist in namespace '$namespace'."
    failed
    return
  }

  # Verify the Job image
  debug "Checking if job image is '$expected_image'."
  local rs_job_image
  rs_job_image="$(echo "$job_json" | jq -r '.spec.template.spec.containers[0].image // empty' 2>/dev/null)" || {
    debug "Failed to extract job image from job JSON."
    failed
    return
  }
  if [[ "$rs_job_image" != "$expected_image" ]]; then
    debug "Job image mismatch. Expected '$expected_image', found '$rs_job_image'."
    failed
    return
  fi

  # Verify the Job command
  debug "Checking if job command contains '$expected_command'."
  local rs_job_command
  rs_job_command="$(echo "$job_json" | jq -r '.spec.template.spec.containers[0].command | join(" ")' 2>/dev/null)" || {
    debug "Failed to extract job command from job JSON."
    failed
    return
  }
  if [[ "$rs_job_command" != *"$expected_command"* ]]; then
    debug "Job command mismatch. Expected to contain '$expected_command', found '$rs_job_command'."
    failed
    return
  fi

  # Verify that the Job's status shows successful completion
  debug "Checking if job has at least one successful completion."
  local rs_completions
  rs_completions="$(echo "$job_json" | jq -r '.status.succeeded // 0' 2>/dev/null)" || {
    debug "Failed to extract job completions from job JSON."
    failed
    return
  }
  if [[ "$rs_completions" -lt 1 ]]; then
    debug "Job completions less than 1. Found '$rs_completions'."
    failed
    return
  fi

  debug "Job '$job_name' in namespace '$namespace' meets all verification criteria. Verification successful."
  solved
  return
}

# shellcheck disable=SC2329
verify_task2() {
  TASK_NUMBER="2"
  local job_name="parallel-job"
  local namespace="processor"
  local expected_parallelism=3
  local expected_completions=6
  local expected_image="busybox:1.28"
  local expected_command='echo "Processing data"'
  local expected_restart_policy="Never"

  # Retrieve the Job JSON once
  debug "Retrieving JSON for job '$job_name' in namespace '$namespace'."
  local job_json
  job_json="$(kubectl get job "$job_name" -n "$namespace" -o json 2>/dev/null)" || {
    debug "Job '$job_name' does not exist in namespace '$namespace'."
    failed
    return
  }

  # Validate parallelism
  debug "Checking if parallelism is '$expected_parallelism'."
  local rs_parallelism
  rs_parallelism="$(echo "$job_json" | jq '.spec.parallelism // 0' 2>/dev/null)" || {
    debug "Failed to extract parallelism from job JSON."
    failed
    return
  }
  if [[ "$rs_parallelism" -ne "$expected_parallelism" ]]; then
    debug "Parallelism mismatch. Expected '$expected_parallelism', found '$rs_parallelism'."
    failed
    return
  fi

  # Validate completions
  debug "Checking if completions is '$expected_completions'."
  local rs_completions
  rs_completions="$(echo "$job_json" | jq '.spec.completions // 0' 2>/dev/null)" || {
    debug "Failed to extract completions from job JSON."
    failed
    return
  }
  if [[ "$rs_completions" -ne "$expected_completions" ]]; then
    debug "Completions mismatch. Expected '$expected_completions', found '$rs_completions'."
    failed
    return
  fi

  # Validate container image
  debug "Checking if container image is '$expected_image'."
  local rs_image
  rs_image="$(echo "$job_json" | jq -r '.spec.template.spec.containers[0].image // empty' 2>/dev/null)" || {
    debug "Failed to extract container image from job JSON."
    failed
    return
  }
  if [[ "$rs_image" != "$expected_image" ]]; then
    debug "Container image mismatch. Expected '$expected_image', found '$rs_image'."
    failed
    return
  fi

  # Validate container command
  debug "Checking if container command contains '$expected_command'."
  local rs_command
  rs_command="$(echo "$job_json" | jq -r '.spec.template.spec.containers[0].command | join(" ")' 2>/dev/null)" || {
    debug "Failed to extract container command from job JSON."
    failed
    return
  }
  if [[ "$rs_command" != *"$expected_command"* ]]; then
    debug "Container command mismatch. Expected to contain '$expected_command', found '$rs_command'."
    failed
    return
  fi

  # Verify restartPolicy is set to Never
  debug "Checking if restartPolicy is '$expected_restart_policy'."
  local rs_restart_policy
  rs_restart_policy="$(echo "$job_json" | jq -r '.spec.template.spec.restartPolicy // empty' 2>/dev/null)" || {
    debug "Failed to extract restartPolicy from job JSON."
    failed
    return
  }
  if [[ "$rs_restart_policy" != "$expected_restart_policy" ]]; then
    debug "RestartPolicy mismatch. Expected '$expected_restart_policy', found '$rs_restart_policy'."
    failed
    return
  fi

  # Check if all pods are successfully completed
  debug "Checking if all pods for job '$job_name' are successfully completed."
  local pods_json
  pods_json="$(kubectl get pods -n "$namespace" -l "job-name=$job_name" -o json 2>/dev/null)" || {
    debug "Failed to retrieve pods for job '$job_name' in namespace '$namespace'."
    failed
    return
  }
  local rs_succeeded_pods
  rs_succeeded_pods="$(echo "$pods_json" | jq '[.items[] | select(.status.phase == "Succeeded")] | length' 2>/dev/null)" || {
    debug "Failed to count succeeded pods for job '$job_name'."
    failed
    return
  }
  if [[ "$rs_succeeded_pods" -ne "$expected_completions" ]]; then
    debug "Succeeded pods mismatch. Expected '$expected_completions', found '$rs_succeeded_pods'."
    failed
    return
  fi

  debug "Job '$job_name' in namespace '$namespace' meets all verification criteria. Verification successful."
  solved
  return
}

# shellcheck disable=SC2329
verify_task3() {
  TASK_NUMBER="3"
  local namespace="cleanup"
  local job_name="ttl-cleanup-job"
  local expected_image="alpine:3.22"
  local job_yaml_file="t3job.yaml"
  local expected_ttl="20"

  # Check if the Job YAML file exists
  debug "Checking if job YAML file '$job_yaml_file' exists."
  [ -f "$job_yaml_file" ] || {
    debug "Job YAML file '$job_yaml_file' does not exist."
    failed
    return
  }

  # Validate that the Job YAML definition includes the correct TTL
  debug "Validating that the job YAML includes ttlSecondsAfterFinished: $expected_ttl."
  local job_ttl
  job_ttl="$(grep "ttlSecondsAfterFinished:" "$job_yaml_file" | awk '{print $2}')" || {
    debug "Failed to extract ttlSecondsAfterFinished from '$job_yaml_file'."
    failed
    return
  }
  if [[ "$job_ttl" != "$expected_ttl" ]]; then
    debug "TTL mismatch in YAML. Expected '$expected_ttl', found '$job_ttl'."
    failed
    return
  fi

  # Validate container image in YAML
  debug "Validating that the job YAML includes image: $expected_image."
  local job_image
  job_image="$(grep "image:" "$job_yaml_file" | awk '{print $3}')" || {
    debug "Failed to extract image from '$job_yaml_file'."
    failed
    return
  }
  if [[ "$job_image" != "$expected_image" ]]; then
    debug "Image mismatch in YAML. Expected '$expected_image', found '$job_image'."
    failed
    return
  fi

  # Check Kubernetes events for Job creation and completion
  debug "Checking Kubernetes events for job creation and completion."
  local pod_events
  pod_events="$(kubectl get events -n "$namespace" --field-selector involvedObject.name="$job_name" -o json 2>/dev/null | jq -r '.items[].reason' 2>/dev/null)" || {
    debug "Failed to retrieve events for job '$job_name' in namespace '$namespace'."
    failed
    return
  }
  if [[ "$pod_events" != *"SuccessfulCreate"* || "$pod_events" != *"Completed"* ]]; then
    debug "Job events do not include both 'SuccessfulCreate' and 'Completed'. Found: $pod_events"
    failed
    return
  fi

  # Check the Job is not present in Kubernetes anymore
  debug "Checking that job '$job_name' is not present in Kubernetes anymore."
  local job_not_found
  job_not_found="$(kubectl get jobs -n "$namespace" "$job_name" 2>&1)"
  if [[ "$job_not_found" != "Error from server (NotFound):"* ]]; then
    debug "Job '$job_name' still exists or unexpected error. Output: $job_not_found"
    failed
    return
  fi

  debug "Job '$job_name' in namespace '$namespace' meets all verification criteria. Verification successful."
  solved
  return
}

# shellcheck disable=SC2329
verify_task4() {
  TASK_NUMBER="4"
  local job_name="failure-job"
  local namespace="default"
  local expected_image="busybox:1.28"
  local expected_command='ls /nonexistent-directory'
  local expected_backoff_limit=2

  # Retrieve the Job JSON once
  debug "Retrieving JSON for job '$job_name' in namespace '$namespace'."
  local job_json
  job_json="$(kubectl get job "$job_name" -n "$namespace" -o json 2>/dev/null)" || {
    debug "Job '$job_name' does not exist in namespace '$namespace'."
    failed
    return
  }

  # Validate container image
  debug "Checking if container image is '$expected_image'."
  local rs_image
  rs_image="$(echo "$job_json" | jq -r '.spec.template.spec.containers[0].image // empty' 2>/dev/null)" || {
    debug "Failed to extract container image from job JSON."
    failed
    return
  }
  if [[ "$rs_image" != "$expected_image" ]]; then
    debug "Container image mismatch. Expected '$expected_image', found '$rs_image'."
    failed
    return
  fi

  # Validate container command
  debug "Checking if container command contains '$expected_command'."
  local rs_command
  rs_command="$(echo "$job_json" | jq -r '.spec.template.spec.containers[0].command | join(" ")' 2>/dev/null)" || {
    debug "Failed to extract container command from job JSON."
    failed
    return
  }
  if [[ "$rs_command" != *"$expected_command"* ]]; then
    debug "Container command mismatch. Expected to contain '$expected_command', found '$rs_command'."
    failed
    return
  fi

  # Verify the backoffLimit is set to 2
  debug "Checking if backoffLimit is '$expected_backoff_limit'."
  local rs_backoff_limit
  rs_backoff_limit="$(echo "$job_json" | jq '.spec.backoffLimit // empty' 2>/dev/null)" || {
    debug "Failed to extract backoffLimit from job JSON."
    failed
    return
  }
  if [[ "$rs_backoff_limit" -ne "$expected_backoff_limit" ]]; then
    debug "backoffLimit mismatch. Expected '$expected_backoff_limit', found '$rs_backoff_limit'."
    failed
    return
  fi

  # Check if the Job failed (at least one failed pod)
  debug "Checking if at least one pod for job '$job_name' has failed."
  local pods_json
  pods_json="$(kubectl get pods -n "$namespace" -o json 2>/dev/null)" || {
    debug "Failed to retrieve pods in namespace '$namespace'."
    failed
    return
  }
  local rs_failed_pods
  rs_failed_pods="$(echo "$pods_json" | jq "[.items[] | select(.metadata.ownerReferences[].name == \"$job_name\" and .status.phase == \"Failed\")] | length" 2>/dev/null)" || {
    debug "Failed to count failed pods for job '$job_name'."
    failed
    return
  }
  if [[ "$rs_failed_pods" -lt 1 ]]; then
    debug "No failed pods found for job '$job_name'."
    failed
    return
  fi

  # Ensure no new Runs or infinite retries (Job condition type Failed is True)
  debug "Checking if job condition type 'Failed' is True."
  local rs_job_failed_condition
  rs_job_failed_condition="$(echo "$job_json" | jq -r '.status.conditions[]? | select(.type == "Failed") | .status // empty' 2>/dev/null)" || {
    debug "Failed to extract job failed condition from job JSON."
    failed
    return
  }
  if [[ "$rs_job_failed_condition" != "True" ]]; then
    debug "Job failed condition is not 'True'. Found '$rs_job_failed_condition'."
    failed
    return
  fi

  debug "Job '$job_name' in namespace '$namespace' meets all verification criteria. Verification successful."
  solved
  return
}

# shellcheck disable=SC2329
verify_task5() {
  TASK_NUMBER="5"
  local namespace="scheduled"
  local cronjob_name="scheduled-job"
  local expected_image="busybox:1.28"
  local expected_schedule="*/1 * * * *"
  local min_success_count=2

  # Retrieve the CronJob JSON once
  debug "Retrieving JSON for cronjob '$cronjob_name' in namespace '$namespace'."
  local cronjob_json
  cronjob_json="$(kubectl get cronjob "$cronjob_name" -n "$namespace" -o json 2>/dev/null)" || {
    debug "CronJob '$cronjob_name' does not exist in namespace '$namespace'."
    failed
    return
  }

  # Verify the image version
  debug "Checking if cronjob image is '$expected_image'."
  local rs_image
  rs_image="$(echo "$cronjob_json" | jq -r '.spec.jobTemplate.spec.template.spec.containers[0].image // empty' 2>/dev/null)" || {
    debug "Failed to extract image from cronjob JSON."
    failed
    return
  }
  if [[ "$rs_image" != "$expected_image" ]]; then
    debug "CronJob image mismatch. Expected '$expected_image', found '$rs_image'."
    failed
    return
  fi

  # Verify the schedule
  debug "Checking if cronjob schedule is '$expected_schedule'."
  local rs_schedule
  rs_schedule="$(echo "$cronjob_json" | jq -r '.spec.schedule // empty' 2>/dev/null)" || {
    debug "Failed to extract schedule from cronjob JSON."
    failed
    return
  }
  if [[ "$rs_schedule" != "$expected_schedule" ]]; then
    debug "CronJob schedule mismatch. Expected '$expected_schedule', found '$rs_schedule'."
    failed
    return
  fi

  # Verify at least 2 successful runs
  debug "Checking for at least $min_success_count successful job runs."
  local jobs_json
  jobs_json="$(kubectl get jobs -n "$namespace" -o json 2>/dev/null)" || {
    debug "Failed to retrieve jobs in namespace '$namespace'."
    failed
    return
  }
  local rs_successful_runs
  rs_successful_runs="$(echo "$jobs_json" | jq "[.items[] | select(.metadata.ownerReferences[]?.kind == \"CronJob\" and .metadata.ownerReferences[]?.name == \"$cronjob_name\" and .status.succeeded == 1)] | length" 2>/dev/null)" || {
    debug "Failed to count successful job runs for cronjob '$cronjob_name'."
    failed
    return
  }
  if [[ "$rs_successful_runs" -lt "$min_success_count" ]]; then
    debug "Not enough successful job runs. Expected at least '$min_success_count', found '$rs_successful_runs'."
    failed
    return
  fi

  debug "CronJob '$cronjob_name' in namespace '$namespace' meets all verification criteria. Verification successful."
  solved
  return
}

# shellcheck disable=SC2329
verify_task6() {
  TASK_NUMBER="6"

  # Expected values
  local job_name="indexed-completion-job"
  local namespace="default"
  local expected_command="This is task $JOB_COMPLETION_INDEX"
  local expected_completions=3
  local expected_completion_mode="Indexed"
  local expected_image="busybox:1.28"
  local expected_restart_policy="Never"

  # Verify Namespace exists
  debug "Checking if namespace '$namespace' exists"
  kubectl get namespace "$namespace" &>/dev/null || { debug "Namespace '$namespace' not found"; failed; return; }

  # Get Job JSON
  debug "Fetching job '$job_name' in namespace '$namespace'"
  local job_json
  job_json=$(kubectl get job "$job_name" -n "$namespace" -o json 2>/dev/null) || { debug "Failed to get job '$job_name'"; failed; return; }
  [[ -n "$job_json" ]] || { debug "Job '$job_name' JSON is empty"; failed; return; }

  # Verify Job completions
  debug "Verifying job completions"
  local job_completions
  job_completions=$(echo "$job_json" | jq -r '.spec.completions') || { debug "Failed to extract completions from job JSON"; failed; return; }
  [[ "$job_completions" -eq "$expected_completions" ]] || { debug "Expected completions: $expected_completions, found: $job_completions"; failed; return; }

  # Verify completionMode
  debug "Verifying job completionMode"
  local job_completion_mode
  job_completion_mode=$(echo "$job_json" | jq -r '.spec.completionMode') || { debug "Failed to extract completionMode from job JSON"; failed; return; }
  [[ "$job_completion_mode" == "$expected_completion_mode" ]] || { debug "Expected completionMode: $expected_completion_mode, found: $job_completion_mode"; failed; return; }

  # Extract Pod template spec
  debug "Extracting pod template spec"
  local template_spec
  template_spec=$(echo "$job_json" | jq '.spec.template.spec') || { debug "Failed to extract template spec from job JSON"; failed; return; }

  # Verify Container Image
  debug "Verifying container image"
  local container_image
  container_image=$(echo "$template_spec" | jq -r '.containers[0].image') || { debug "Failed to extract container image"; failed; return; }
  [[ "$container_image" == "$expected_image" ]] || { debug "Expected image: $expected_image, found: $container_image"; failed; return; }

  # Verify Container Command
  debug "Verifying container command"
  local container_command
  container_command=$(echo "$template_spec" | jq -r '.containers[0].command | join(" ")') || { debug "Failed to extract container command"; failed; return; }
  [[ "$container_command" == *"$expected_command"* ]] || { debug "Expected command to contain: $expected_command, found: $container_command"; failed; return; }

  # Verify Restart Policy
  debug "Verifying restart policy"
  local restart_policy
  restart_policy=$(echo "$template_spec" | jq -r '.restartPolicy') || { debug "Failed to extract restart policy"; failed; return; }
  [[ "$restart_policy" == "$expected_restart_policy" ]] || { debug "Expected restartPolicy: $expected_restart_policy, found: $restart_policy"; failed; return; }

  # Get pods for the job
  debug "Fetching pods for job '$job_name'"
  local pods_json
  pods_json=$(kubectl get pods -n "$namespace" -l job-name="$job_name" -o json 2>/dev/null) || { debug "Failed to get pods for job '$job_name'"; failed; return; }
  local pod_count
  pod_count=$(echo "$pods_json" | jq '.items | length') || { debug "Failed to count pods"; failed; return; }
  [[ "$pod_count" -eq "$expected_completions" ]] || { debug "Expected $expected_completions pods, found: $pod_count"; failed; return; }

  # Verify logs for each pod
  local i
  for i in $(seq 0 $((expected_completions - 1))); do
    # Get pod name
    local pod_name
    pod_name=$(echo "$pods_json" | jq -r ".items[$i].metadata.name") || { debug "Failed to extract pod name at index $i"; failed; return; }
    [[ -n "$pod_name" ]] || { debug "Pod name at index $i is empty"; failed; return; }

    # Get pod logs
    debug "Checking logs for pod '$pod_name'"
    local log_contents
    log_contents=$(kubectl logs -n "$namespace" "$pod_name" 2>/dev/null) || { debug "Failed to get logs for pod '$pod_name'"; failed; return; }
    local expected_log="This is task $i"
    [[ "$log_contents" == "$expected_log" ]] || { debug "Expected log: '$expected_log', found: '$log_contents' in pod '$pod_name'"; failed; return; }
  done

  debug "All verifications passed for task $TASK_NUMBER"
  solved
  return
}

# shellcheck disable=SC2329
verify_task7() {
  TASK_NUMBER="7"
  local job_name="retry-policy-job"
  local namespace="default"
  local expected_backoff_limit="3"
  local expected_action="FailJob"
  local expected_operator="NotIn"
  local expected_exit_code="2"
  local expected_image="busybox:1.28"
  local expected_command="cat /nonexistent-file"
  local expected_restart_policy="Never"

  # Retrieve the Job JSON once
  debug "Retrieving JSON for job '$job_name' in namespace '$namespace'."
  local job_json
  job_json="$(kubectl get job "$job_name" -n "$namespace" -o json 2>/dev/null)" || {
    debug "Job '$job_name' does not exist in namespace '$namespace'."
    failed
    return
  }

  # Verify the backoffLimit is set to 3
  debug "Checking if backoffLimit is '$expected_backoff_limit'."
  local rs_backoff_limit
  rs_backoff_limit="$(echo "$job_json" | jq -r '.spec.backoffLimit // empty' 2>/dev/null)" || {
    debug "Failed to extract backoffLimit from job JSON."
    failed
    return
  }
  if [[ "$rs_backoff_limit" != "$expected_backoff_limit" ]]; then
    debug "backoffLimit mismatch. Expected '$expected_backoff_limit', found '$rs_backoff_limit'."
    failed
    return
  fi

  # Verify the PodFailurePolicy configuration
  debug "Checking PodFailurePolicy configuration."
  local rs_pod_failure_policy
  rs_pod_failure_policy="$(echo "$job_json" | jq -r '.spec.podFailurePolicy')" || {
    debug "Failed to extract podFailurePolicy from job JSON."
    failed
    return
  }

  local rs_action
  rs_action="$(echo "$rs_pod_failure_policy" | jq -r '.rules[0].action // empty' 2>/dev/null)" || {
    debug "Failed to extract action from podFailurePolicy."
    failed
    return
  }
  if [[ "$rs_action" != "$expected_action" ]]; then
    debug "PodFailurePolicy action mismatch. Expected '$expected_action', found '$rs_action'."
    failed
    return
  fi

  local rs_operator
  rs_operator="$(echo "$rs_pod_failure_policy" | jq -r '.rules[0].onExitCodes.operator // empty' 2>/dev/null)" || {
    debug "Failed to extract operator from podFailurePolicy."
    failed
    return
  }
  if [[ "$rs_operator" != "$expected_operator" ]]; then
    debug "PodFailurePolicy operator mismatch. Expected '$expected_operator', found '$rs_operator'."
    failed
    return
  fi

  local rs_exit_code_value
  rs_exit_code_value="$(echo "$rs_pod_failure_policy" | jq -r '.rules[0].onExitCodes.values[0] // empty' 2>/dev/null)" || {
    debug "Failed to extract exit code value from podFailurePolicy."
    failed
    return
  }
  if [[ "$rs_exit_code_value" != "$expected_exit_code" ]]; then
    debug "PodFailurePolicy exit code value mismatch. Expected '$expected_exit_code', found '$rs_exit_code_value'."
    failed
    return
  fi

  # Verify the Job template configuration (image, container name, command, etc.)
  debug "Checking if container image is '$expected_image'."
  local rs_image
  rs_image="$(echo "$job_json" | jq -r '.spec.template.spec.containers[0].image // empty' 2>/dev/null)" || {
    debug "Failed to extract container image from job JSON."
    failed
    return
  }
  if [[ "$rs_image" != "$expected_image" ]]; then
    debug "Container image mismatch. Expected '$expected_image', found '$rs_image'."
    failed
    return
  fi

  debug "Checking if container command contains '$expected_command'."
  local rs_command
  rs_command="$(echo "$job_json" | jq -r '.spec.template.spec.containers[0].command | join(" ")' 2>/dev/null)" || {
    debug "Failed to extract container command from job JSON."
    failed
    return
  }
  if [[ "$rs_command" != *"$expected_command"* ]]; then
    debug "Container command mismatch. Expected to contain '$expected_command', found '$rs_command'."
    failed
    return
  fi

  debug "Checking if restartPolicy is '$expected_restart_policy'."
  local rs_restart_policy
  rs_restart_policy="$(echo "$job_json" | jq -r '.spec.template.spec.restartPolicy // empty' 2>/dev/null)" || {
    debug "Failed to extract restartPolicy from job JSON."
    failed
    return
  }
  if [[ "$rs_restart_policy" != "$expected_restart_policy" ]]; then
    debug "Restart policy mismatch. Expected '$expected_restart_policy', found '$rs_restart_policy'."
    failed
    return
  fi

  debug "Job '$job_name' in namespace '$namespace' meets all verification criteria. Verification successful."
  solved
  return
}

# shellcheck disable=SC2329
verify_task8() {
  TASK_NUMBER="8"
  local job_name="resource-limited-job"
  local namespace="default"
  local expected_image="busybox:1.28"
  local expected_command='echo "Resources handled"'
  local expected_memory_request="32Mi"
  local expected_memory_limit="64Mi"
  local expected_cpu_request="250m"
  local expected_cpu_limit="500m"

  # Retrieve the Job JSON once
  debug "Retrieving JSON for job '$job_name' in namespace '$namespace'."
  local job_json
  job_json="$(kubectl get job "$job_name" -n "$namespace" -o json 2>/dev/null)" || {
    debug "Job '$job_name' does not exist in namespace '$namespace'."
    failed
    return
  }

  # Verify the Job's container image
  debug "Checking if container image is '$expected_image'."
  local rs_image
  rs_image="$(echo "$job_json" | jq -r '.spec.template.spec.containers[0].image // empty' 2>/dev/null)" || {
    debug "Failed to extract container image from job JSON."
    failed
    return
  }
  if [[ "$rs_image" != "$expected_image" ]]; then
    debug "Container image mismatch. Expected '$expected_image', found '$rs_image'."
    failed
    return
  fi

  # Verify Container Command
  debug "Checking if container command contains '$expected_command'."
  local rs_command
  rs_command="$(echo "$job_json" | jq -r '.spec.template.spec.containers[0].command | join(" ")' 2>/dev/null)" || {
    debug "Failed to extract container command from job JSON."
    failed
    return
  }
  if [[ "$rs_command" != *"$expected_command"* ]]; then
    debug "Container command mismatch. Expected to contain '$expected_command', found '$rs_command'."
    failed
    return
  fi

  # Verify resource requests
  debug "Checking resource requests for memory and CPU."
  local rs_memory_request
  rs_memory_request="$(echo "$job_json" | jq -r '.spec.template.spec.containers[0].resources.requests.memory // empty' 2>/dev/null)" || {
    debug "Failed to extract memory request from job JSON."
    failed
    return
  }
  if [[ "$rs_memory_request" != "$expected_memory_request" ]]; then
    debug "Memory request mismatch. Expected '$expected_memory_request', found '$rs_memory_request'."
    failed
    return
  fi

  local rs_cpu_request
  rs_cpu_request="$(echo "$job_json" | jq -r '.spec.template.spec.containers[0].resources.requests.cpu // empty' 2>/dev/null)" || {
    debug "Failed to extract CPU request from job JSON."
    failed
    return
  }
  if [[ "$rs_cpu_request" != "$expected_cpu_request" ]]; then
    debug "CPU request mismatch. Expected '$expected_cpu_request', found '$rs_cpu_request'."
    failed
    return
  fi

  # Verify resource limits
  debug "Checking resource limits for memory and CPU."
  local rs_memory_limit
  rs_memory_limit="$(echo "$job_json" | jq -r '.spec.template.spec.containers[0].resources.limits.memory // empty' 2>/dev/null)" || {
    debug "Failed to extract memory limit from job JSON."
    failed
    return
  }
  if [[ "$rs_memory_limit" != "$expected_memory_limit" ]]; then
    debug "Memory limit mismatch. Expected '$expected_memory_limit', found '$rs_memory_limit'."
    failed
    return
  fi

  local rs_cpu_limit
  rs_cpu_limit="$(echo "$job_json" | jq -r '.spec.template.spec.containers[0].resources.limits.cpu // empty' 2>/dev/null)" || {
    debug "Failed to extract CPU limit from job JSON."
    failed
    return
  }
  if [[ "$rs_cpu_limit" != "$expected_cpu_limit" ]]; then
    debug "CPU limit mismatch. Expected '$expected_cpu_limit', found '$rs_cpu_limit'."
    failed
    return
  fi

  # Verify Job status and ensure completion
  debug "Checking if job has completed successfully."
  local rs_job_status
  rs_job_status="$(echo "$job_json" | jq -r '.status.conditions[]? | select(.type=="Complete" and .status=="True")' 2>/dev/null)" || {
    debug "Failed to extract job status conditions from job JSON."
    failed
    return
  }
  if [[ -z "$rs_job_status" ]]; then
    debug "Job has not completed successfully."
    failed
    return
  fi

  debug "Job '$job_name' in namespace '$namespace' meets all verification criteria. Verification successful."
  solved
  return
}

# shellcheck disable=SC2329
verify_task9() {
  TASK_NUMBER="9"
  local job_name="label-job"
  local namespace="default"
  local expected_image="busybox:1.28"
  local expected_label_key="purpose"
  local expected_label_value="testing"

  # Retrieve the Job JSON once
  debug "Retrieving JSON for job '$job_name' in namespace '$namespace'."
  local job_json
  job_json="$(kubectl get job "$job_name" -n "$namespace" -o json 2>/dev/null)" || {
    debug "Job '$job_name' does not exist in namespace '$namespace'."
    failed
    return
  }

  # Verify the image used in the Job
  debug "Checking if container image is '$expected_image'."
  local rs_image
  rs_image="$(echo "$job_json" | jq -r '.spec.template.spec.containers[0].image // empty' 2>/dev/null)" || {
    debug "Failed to extract container image from job JSON."
    failed
    return
  }
  if [[ "$rs_image" != "$expected_image" ]]; then
    debug "Container image mismatch. Expected '$expected_image', found '$rs_image'."
    failed
    return
  fi

  # Verify the custom label exists in the Pod template
  debug "Checking if pod template has label '$expected_label_key: $expected_label_value'."
  local rs_label_value
  rs_label_value="$(echo "$job_json" | jq -r --arg key "$expected_label_key" '.spec.template.metadata.labels[$key] // empty' 2>/dev/null)" || {
    debug "Failed to extract label '$expected_label_key' from job JSON."
    failed
    return
  }
  if [[ "$rs_label_value" != "$expected_label_value" ]]; then
    debug "Pod template label mismatch. Expected '$expected_label_value', found '$rs_label_value'."
    failed
    return
  fi

  # Verify that the Pod created by the Job includes the custom label
  debug "Retrieving pod created by job '$job_name' and checking label."
  local pod_name
  pod_name="$(kubectl get pod -n "$namespace" -l "job-name=$job_name" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)" || {
    debug "Failed to retrieve pod created by job '$job_name'."
    failed
    return
  }
  if [[ -z "$pod_name" ]]; then
    debug "No pod found for job '$job_name'."
    failed
    return
  fi

  local pod_json
  pod_json="$(kubectl get pod "$pod_name" -n "$namespace" -o json 2>/dev/null)" || {
    debug "Failed to retrieve pod JSON for pod '$pod_name'."
    failed
    return
  }
  local rs_pod_label_value
  rs_pod_label_value="$(echo "$pod_json" | jq -r --arg key "$expected_label_key" '.metadata.labels[$key] // empty' 2>/dev/null)" || {
    debug "Failed to extract label '$expected_label_key' from pod JSON."
    failed
    return
  }
  if [[ "$rs_pod_label_value" != "$expected_label_value" ]]; then
    debug "Pod label mismatch. Expected '$expected_label_value', found '$rs_pod_label_value'."
    failed
    return
  fi

  debug "Job '$job_name' and its pod in namespace '$namespace' have the correct image and label. Verification successful."
  solved
  return
}

# shellcheck disable=SC2329
verify_task10() {
  TASK_NUMBER="10"
  local namespace="affinity"
  local job_name="affinity-job"
  local expected_image="busybox:1.28"
  local required_label_key="app"
  local required_label_value="web-server"
  local topology_key="kubernetes.io/hostname"

  # Check if the Job exists in the given namespace
  debug "Checking if job '$job_name' exists in namespace '$namespace'."
  kubectl get job "$job_name" -n "$namespace" > /dev/null 2>&1 || {
    debug "Job '$job_name' does not exist in namespace '$namespace'."
    failed
    return
  }

  # Retrieve the Job JSON once
  debug "Retrieving JSON for job '$job_name' in namespace '$namespace'."
  local job_json
  job_json="$(kubectl get job "$job_name" -n "$namespace" -o json 2>/dev/null)" || {
    debug "Failed to retrieve job JSON for '$job_name'."
    failed
    return
  }

  # Verify image name and version
  debug "Checking if container image is '$expected_image'."
  local rs_image
  rs_image="$(echo "$job_json" | jq -r '.spec.template.spec.containers[0].image // empty' 2>/dev/null)" || {
    debug "Failed to extract container image from job JSON."
    failed
    return
  }
  if [[ "$rs_image" != "$expected_image" ]]; then
    debug "Container image mismatch. Expected '$expected_image', found '$rs_image'."
    failed
    return
  fi

  # Verify podAffinity configuration
  debug "Checking podAffinity configuration."
  local pod_affinity
  pod_affinity="$(echo "$job_json" | jq '.spec.template.spec.affinity.podAffinity.requiredDuringSchedulingIgnoredDuringExecution')" || {
    debug "Failed to extract podAffinity from job JSON."
    failed
    return
  }
  if [[ "$pod_affinity" == "null" ]]; then
    debug "podAffinity.requiredDuringSchedulingIgnoredDuringExecution is not set."
    failed
    return
  fi

  # Check the required affinity conditions (labelSelector and topologyKey)
  debug "Checking affinity labelSelector and topologyKey."
  local affinity_label_key
  affinity_label_key="$(echo "$pod_affinity" | jq -r '.[0].labelSelector.matchExpressions[0].key // empty' 2>/dev/null)"
  local affinity_label_operator
  affinity_label_operator="$(echo "$pod_affinity" | jq -r '.[0].labelSelector.matchExpressions[0].operator // empty' 2>/dev/null)"
  local affinity_label_value
  affinity_label_value="$(echo "$pod_affinity" | jq -r '.[0].labelSelector.matchExpressions[0].values[0] // empty' 2>/dev/null)"
  local affinity_topology_key
  affinity_topology_key="$(echo "$pod_affinity" | jq -r '.[0].topologyKey // empty' 2>/dev/null)"

  if [[ "$affinity_label_key" != "$required_label_key" ]]; then
    debug "Affinity label key mismatch. Expected '$required_label_key', found '$affinity_label_key'."
    failed
    return
  fi
  if [[ "$affinity_label_operator" != "In" ]]; then
    debug "Affinity label operator mismatch. Expected 'In', found '$affinity_label_operator'."
    failed
    return
  fi
  if [[ "$affinity_label_value" != "$required_label_value" ]]; then
    debug "Affinity label value mismatch. Expected '$required_label_value', found '$affinity_label_value'."
    failed
    return
  fi
  if [[ "$affinity_topology_key" != "$topology_key" ]]; then
    debug "Affinity topologyKey mismatch. Expected '$topology_key', found '$affinity_topology_key'."
    failed
    return
  fi

  # Check if any Pod of the Job has been created and ensure it meets the affinity rules
  debug "Retrieving pod created by job '$job_name'."
  local pod_name
  pod_name="$(kubectl get pod -n "$namespace" -l "job-name=$job_name" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)" || {
    debug "Failed to retrieve pod created by job '$job_name'."
    failed
    return
  }
  if [[ -z "$pod_name" ]]; then
    debug "No pod found for job '$job_name'."
    failed
    return
  fi

  # Verify if the Pod is scheduled on a node with the required label `app=web-server`
  debug "Checking if pod '$pod_name' is scheduled on a node with label '$required_label_key=$required_label_value'."
  local pod_node
  pod_node="$(kubectl get pod "$pod_name" -n "$namespace" -o jsonpath='{.spec.nodeName}' 2>/dev/null)" || {
    debug "Failed to extract nodeName for pod '$pod_name'."
    failed
    return
  }
  if [[ -z "$pod_node" ]]; then
    debug "Pod '$pod_name' is not scheduled to any node."
    failed
    return
  fi

  local web_server_pods
  web_server_pods="$(kubectl get pod -A -l "$required_label_key=$required_label_value" -o jsonpath='{.items[*].spec.nodeName}' 2>/dev/null)" || {
    debug "Failed to retrieve pods with label '$required_label_key=$required_label_value'."
    failed
    return
  }
  if [[ ! "$web_server_pods" =~ $pod_node ]]; then
    debug "Pod '$pod_name' is not scheduled on a node with a pod labeled '$required_label_key=$required_label_value'."
    failed
    return
  fi

  debug "Job '$job_name' in namespace '$namespace' meets all verification criteria. Verification successful."
  solved
  return
}

# shellcheck disable=SC2329
verify_task11() {
  TASK_NUMBER="11"
  local job_name="long-job"
  local namespace="default"
  local expected_image="busybox:1.28"
  local expected_command="for i in \$(seq 1 60); do echo \"Running step \$i\"; sleep 1; done"
  local expected_restart_policy="Never"

  # Retrieve the Job JSON once
  debug "Retrieving JSON for job '$job_name' in namespace '$namespace'."
  local job_json
  job_json="$(kubectl get job "$job_name" -n "$namespace" -o json 2>/dev/null)" || {
    debug "Job '$job_name' does not exist in namespace '$namespace'."
    failed
    return
  }

  # Verify the Job's container image
  debug "Checking if container image is '$expected_image'."
  local rs_image
  rs_image="$(echo "$job_json" | jq -r '.spec.template.spec.containers[0].image // empty' 2>/dev/null)" || {
    debug "Failed to extract container image from job JSON."
    failed
    return
  }
  if [[ "$rs_image" != "$expected_image" ]]; then
    debug "Container image mismatch. Expected '$expected_image', found '$rs_image'."
    failed
    return
  fi

  # Verify the Job's command
  debug "Checking if container command contains expected command."
  local rs_command
  rs_command="$(echo "$job_json" | jq -r '.spec.template.spec.containers[0].command | join(" ")' 2>/dev/null)" || {
    debug "Failed to extract container command from job JSON."
    failed
    return
  }
  if [[ "$rs_command" != *"$expected_command"* ]]; then
    debug "Container command mismatch. Expected to contain '$expected_command', found '$rs_command'."
    failed
    return
  fi

  # Verify the restart policy
  debug "Checking if restartPolicy is '$expected_restart_policy'."
  local rs_restart_policy
  rs_restart_policy="$(echo "$job_json" | jq -r '.spec.template.spec.restartPolicy // empty' 2>/dev/null)" || {
    debug "Failed to extract restartPolicy from job JSON."
    failed
    return
  }
  if [[ "$rs_restart_policy" != "$expected_restart_policy" ]]; then
    debug "Restart policy mismatch. Expected '$expected_restart_policy', found '$rs_restart_policy'."
    failed
    return
  fi

  # Check if the Job completed successfully
  debug "Checking if job completed successfully."
  local rs_status
  rs_status="$(echo "$job_json" | jq -r '.status.succeeded // 0' 2>/dev/null)" || {
    debug "Failed to extract job status from job JSON."
    failed
    return
  }
  if [[ "$rs_status" != "1" ]]; then
    debug "Job did not complete successfully. Succeeded count: '$rs_status'."
    failed
    return
  fi

  # Verify the logs of the Job's Pod
  debug "Retrieving pod created by job '$job_name'."
  local pod_name
  pod_name="$(kubectl get pods -n "$namespace" -l job-name="$job_name" -o json | jq -r '.items[0].metadata.name' 2>/dev/null)" || {
    debug "Failed to retrieve pod for job '$job_name'."
    failed
    return
  }
  if [[ -z "$pod_name" ]]; then
    debug "No pod found for job '$job_name'."
    failed
    return
  fi

  debug "Retrieving logs for pod '$pod_name'."
  local pod_logs
  pod_logs="$(kubectl logs "$pod_name" -n "$namespace" 2>/dev/null)" || {
    debug "Failed to retrieve logs for pod '$pod_name'."
    failed
    return
  }
  if [[ -z "$pod_logs" ]]; then
    debug "Pod logs are empty for pod '$pod_name'."
    failed
    return
  fi

  for i in $(seq 1 60); do
    if ! grep -q "Running step $i" <<< "$pod_logs"; then
      debug "Log for 'Running step $i' not found in pod logs."
      failed
      return
    fi
  done

  debug "Job '$job_name' in namespace '$namespace' meets all verification criteria. Verification successful."
  solved
  return
}

# shellcheck disable=SC2329
verify_task12() {
  TASK_NUMBER="12"
  local namespace="default"
  local cronjob_name="print-date"
  local expected_image="busybox:1.28"
  local expected_command="/bin/sh -c"
  local expected_args="echo \"Current date: \$(date)\""
  local expected_restart_policy="Never"
  local expected_schedule="*/5 * * * *"

  # Retrieve the CronJob JSON once
  debug "Retrieving JSON for cronjob '$cronjob_name' in namespace '$namespace'."
  local cronjob_json
  cronjob_json="$(kubectl get cronjob "$cronjob_name" -n "$namespace" -o json 2>/dev/null)" || {
    debug "CronJob '$cronjob_name' does not exist in namespace '$namespace'."
    failed
    return
  }

  # Verify the schedule
  debug "Checking if cronjob schedule is '$expected_schedule'."
  local rs_schedule
  rs_schedule="$(echo "$cronjob_json" | jq -r '.spec.schedule // empty' 2>/dev/null)" || {
    debug "Failed to extract schedule from cronjob JSON."
    failed
    return
  }
  if [[ "$rs_schedule" != "$expected_schedule" ]]; then
    debug "CronJob schedule mismatch. Expected '$expected_schedule', found '$rs_schedule'."
    failed
    return
  fi

  # Verify the image
  debug "Checking if cronjob image is '$expected_image'."
  local rs_image
  rs_image="$(echo "$cronjob_json" | jq -r '.spec.jobTemplate.spec.template.spec.containers[0].image // empty' 2>/dev/null)" || {
    debug "Failed to extract image from cronjob JSON."
    failed
    return
  }
  if [[ "$rs_image" != "$expected_image" ]]; then
    debug "CronJob image mismatch. Expected '$expected_image', found '$rs_image'."
    failed
    return
  fi

  # Verify the command
  debug "Checking if cronjob command is '$expected_command'."
  local rs_command
  rs_command="$(echo "$cronjob_json" | jq -r '.spec.jobTemplate.spec.template.spec.containers[0].command | join(" ")' 2>/dev/null)" || {
    debug "Failed to extract command from cronjob JSON."
    failed
    return
  }
  if [[ "$rs_command" != "$expected_command" ]]; then
    debug "CronJob command mismatch. Expected '$expected_command', found '$rs_command'."
    failed
    return
  fi

  # Verify the args
  debug "Checking if cronjob args is '$expected_args'."
  local rs_args
  rs_args="$(echo "$cronjob_json" | jq -r '.spec.jobTemplate.spec.template.spec.containers[0].args | join(" ")' 2>/dev/null)" || {
    debug "Failed to extract args from cronjob JSON."
    failed
    return
  }
  if [[ "$rs_args" != "$expected_args" ]]; then
    debug "CronJob args mismatch. Expected '$expected_args', found '$rs_args'."
    failed
    return
  fi

  # Verify the restart policy
  debug "Checking if restartPolicy is '$expected_restart_policy'."
  local rs_restart_policy
  rs_restart_policy="$(echo "$cronjob_json" | jq -r '.spec.jobTemplate.spec.template.spec.restartPolicy // empty' 2>/dev/null)" || {
    debug "Failed to extract restartPolicy from cronjob JSON."
    failed
    return
  }
  if [[ "$rs_restart_policy" != "$expected_restart_policy" ]]; then
    debug "CronJob restartPolicy mismatch. Expected '$expected_restart_policy', found '$rs_restart_policy'."
    failed
    return
  fi

  debug "CronJob '$cronjob_name' in namespace '$namespace' meets all verification criteria. Verification successful."
  solved
  return
}

# shellcheck disable=SC2329
verify_task13() {
  TASK_NUMBER="13"
  local namespace="sidecar"
  local job_name="sidecar-job"
  local container_name="sidecar-job"
  local init_container_name="log-forwarder"
  local main_image="alpine:3.22"
  local init_image="busybox:1.28"
  local shared_volume_name="data"
  local main_command='echo "app log" > /opt/logs.txt'
  local init_command="tail -F /opt/logs.txt"
  local expected_restart_policy="Never"
  local expected_init_restart_policy="Always"
  local expected_mount_path="/opt"

  # Verify the namespace exists
  debug "Checking if namespace '$namespace' exists."
  kubectl get ns "$namespace" > /dev/null 2>&1 || {
    debug "Namespace '$namespace' does not exist."
    failed
    return
  }

  # Retrieve the Job JSON once
  debug "Retrieving JSON for job '$job_name' in namespace '$namespace'."
  local job_json
  job_json="$(kubectl get job "$job_name" -n "$namespace" -o json 2>/dev/null)" || {
    debug "Job '$job_name' does not exist in namespace '$namespace'."
    failed
    return
  }

  # Check if the job has the correct container(s)
  debug "Checking if main container '$container_name' exists."
  local rs_containers
  rs_containers="$(echo "$job_json" | jq -r '.spec.template.spec.containers[].name' 2>/dev/null)" || {
    debug "Failed to extract containers from job JSON."
    failed
    return
  }
  if ! grep -qx "$container_name" <<< "$rs_containers"; then
    debug "Main container '$container_name' not found."
    failed
    return
  fi

  # Verify main container image and command
  debug "Checking main container image and command."
  local rs_main_image
  rs_main_image="$(echo "$job_json" | jq -r --arg name "$container_name" '.spec.template.spec.containers[] | select(.name==$name).image // empty' 2>/dev/null)" || {
    debug "Failed to extract main container image."
    failed
    return
  }
  if [[ "$rs_main_image" != "$main_image" ]]; then
    debug "Main container image mismatch. Expected '$main_image', found '$rs_main_image'."
    failed
    return
  fi

  local rs_main_command
  rs_main_command="$(echo "$job_json" | jq -r --arg name "$container_name" '.spec.template.spec.containers[] | select(.name==$name).command | join(" ")' 2>/dev/null)" || {
    debug "Failed to extract main container command."
    failed
    return
  }
  if [[ "$rs_main_command" != *"$main_command"* ]]; then
    debug "Main container command mismatch. Expected to contain '$main_command', found '$rs_main_command'."
    failed
    return
  fi

  # Verify initContainer image, command, and restart policy
  debug "Checking initContainer image, command, and restart policy."
  local rs_init_container
  rs_init_container="$(echo "$job_json" | jq -r --arg name "$init_container_name" '.spec.template.spec.initContainers[] | select(.name==$name)' 2>/dev/null)" || {
    debug "Failed to extract initContainer '$init_container_name'."
    failed
    return
  }
  local rs_init_image
  rs_init_image="$(echo "$rs_init_container" | jq -r '.image // empty' 2>/dev/null)" || {
    debug "Failed to extract initContainer image."
    failed
    return
  }
  if [[ "$rs_init_image" != "$init_image" ]]; then
    debug "InitContainer image mismatch. Expected '$init_image', found '$rs_init_image'."
    failed
    return
  fi

  local rs_init_command
  rs_init_command="$(echo "$rs_init_container" | jq -r '.command | join(" ")' 2>/dev/null)" || {
    debug "Failed to extract initContainer command."
    failed
    return
  }
  if [[ "$rs_init_command" != *"$init_command"* ]]; then
    debug "InitContainer command mismatch. Expected to contain '$init_command', found '$rs_init_command'."
    failed
    return
  fi

  local rs_init_restart_policy
  rs_init_restart_policy="$(echo "$job_json" | jq -r --arg name "$init_container_name" '.spec.template.spec.initContainers[] | select(.name==$name).restartPolicy // empty' 2>/dev/null)" || {
    debug "Failed to extract initContainer restartPolicy."
    failed
    return
  }
  if [[ "$rs_init_restart_policy" != "$expected_init_restart_policy" ]]; then
    debug "InitContainer restartPolicy mismatch. Expected '$expected_init_restart_policy', found '$rs_init_restart_policy'."
    failed
    return
  fi

  # Verify shared volume configuration
  debug "Checking shared volume configuration."
  local rs_volume
  rs_volume="$(echo "$job_json" | jq -r --arg name "$shared_volume_name" '.spec.template.spec.volumes[] | select(.name==$name)' 2>/dev/null)" || {
    debug "Failed to extract shared volume from job JSON."
    failed
    return
  }
  if [[ -z "$rs_volume" ]]; then
    debug "Shared volume '$shared_volume_name' not found."
    failed
    return
  fi
  local rs_empty_dir
  rs_empty_dir="$(echo "$rs_volume" | jq -r '.emptyDir | type' 2>/dev/null)" || {
    debug "Failed to extract emptyDir from shared volume."
    failed
    return
  }
  if [[ "$rs_empty_dir" != "object" ]]; then
    debug "Shared volume '$shared_volume_name' is not an emptyDir."
    failed
    return
  fi

  # Verify volume mounts in the main container
  debug "Checking volume mount in main container."
  local rs_main_volume_mount
  rs_main_volume_mount="$(echo "$job_json" | jq -r --arg name "$container_name" --arg vol "$shared_volume_name" '.spec.template.spec.containers[] | select(.name==$name).volumeMounts[] | select(.name==$vol).mountPath // empty' 2>/dev/null)" || {
    debug "Failed to extract main container volume mount."
    failed
    return
  }
  if [[ "$rs_main_volume_mount" != "$expected_mount_path" ]]; then
    debug "Main container volume mount mismatch. Expected '$expected_mount_path', found '$rs_main_volume_mount'."
    failed
    return
  fi

  # Verify volume mounts in the initContainer
  debug "Checking volume mount in initContainer."
  local rs_init_volume_mount
  rs_init_volume_mount="$(echo "$job_json" | jq -r --arg name "$init_container_name" --arg vol "$shared_volume_name" '.spec.template.spec.initContainers[] | select(.name==$name).volumeMounts[] | select(.name==$vol).mountPath // empty' 2>/dev/null)" || {
    debug "Failed to extract initContainer volume mount."
    failed
    return
  }
  if [[ "$rs_init_volume_mount" != "$expected_mount_path" ]]; then
    debug "InitContainer volume mount mismatch. Expected '$expected_mount_path', found '$rs_init_volume_mount'."
    failed
    return
  fi

  # Ensure the Job has the correct restartPolicy
  debug "Checking job restartPolicy."
  local rs_restart_policy
  rs_restart_policy="$(echo "$job_json" | jq -r '.spec.template.spec.restartPolicy // empty' 2>/dev/null)" || {
    debug "Failed to extract job restartPolicy."
    failed
    return
  }
  if [[ "$rs_restart_policy" != "$expected_restart_policy" ]]; then
    debug "Job restartPolicy mismatch. Expected '$expected_restart_policy', found '$rs_restart_policy'."
    failed
    return
  fi

  debug "Job '$job_name' in namespace '$namespace' meets all verification criteria. Verification successful."
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
)
run_verification VERIFY_TASK_FUNCTIONS "$@"

exit 0
