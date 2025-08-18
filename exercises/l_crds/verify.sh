#!/bin/bash

# shellcheck source=../../.scripts/verify.sh
source "$(git rev-parse --show-toplevel)/.scripts/verify.sh"

# shellcheck disable=SC2329
verify_task1() {
  TASK_NUMBER="1"
  local expected_crd="websites.stable.example.com"
  local expected_version="v1"
  local expected_plural="websites"
  local expected_singular="website"
  local expected_kind="Website"
  local expected_shortname="ws"
  local expected_namespace="default"
  local expected_instance="my-site"
  local expected_gitrepo="https://github.com/example/my-site.git"

  # Check if CRD exists
  debug "Checking if CRD '$expected_crd' exists."
  local crd_json
  crd_json="$(kubectl get crd "$expected_crd" -o json 2>/dev/null)" || {
    debug "CRD '$expected_crd' not found."
    failed
    return
  }

  # Check CRD is namespaced
  local scope
  scope="$(echo "$crd_json" | jq -r '.spec.scope')" || {
    debug "Failed to extract CRD scope."
    failed
    return
  }
  if [ "$scope" != "Namespaced" ]; then
    debug "CRD scope is '$scope', expected 'Namespaced'."
    failed
    return
  fi

  # Check CRD version
  local version_found
  version_found="$(echo "$crd_json" | jq -r '.spec.versions[]? | select(.name=="'"$expected_version"'") | .name')" || {
    debug "Failed to extract CRD versions."
    failed
    return
  }
  if [ "$version_found" != "$expected_version" ]; then
    debug "CRD version '$expected_version' not found."
    failed
    return
  fi

  # Check plural, singular, kind, shortNames
  local plural
  plural="$(echo "$crd_json" | jq -r '.spec.names.plural')" || {
    debug "Failed to extract CRD plural name."
    failed
    return
  }
  if [ "$plural" != "$expected_plural" ]; then
    debug "CRD plural name is '$plural', expected '$expected_plural'."
    failed
    return
  fi

  local singular
  singular="$(echo "$crd_json" | jq -r '.spec.names.singular')" || {
    debug "Failed to extract CRD singular name."
    failed
    return
  }
  if [ "$singular" != "$expected_singular" ]; then
    debug "CRD singular name is '$singular', expected '$expected_singular'."
    failed
    return
  fi

  local kind
  kind="$(echo "$crd_json" | jq -r '.spec.names.kind')" || {
    debug "Failed to extract CRD kind."
    failed
    return
  }
  if [ "$kind" != "$expected_kind" ]; then
    debug "CRD kind is '$kind', expected '$expected_kind'."
    failed
    return
  fi

  local shortnames
  shortnames="$(echo "$crd_json" | jq -r '.spec.names.shortNames[]?')" || {
    debug "Failed to extract CRD shortNames."
    failed
    return
  }
  local found_shortname="false"
  local sn
  for sn in $shortnames; do
    if [ "$sn" = "$expected_shortname" ]; then
      found_shortname="true"
      break
    fi
  done
  if [ "$found_shortname" != "true" ]; then
    debug "CRD shortNames does not include '$expected_shortname'. Found: $shortnames"
    failed
    return
  fi

  # Check schema for spec.gitRepo (string, optional)
  debug "Checking CRD schema for spec.gitRepo."
  local schema_gitrepo_type
  schema_gitrepo_type="$(echo "$crd_json" | jq -r '.spec.versions[]? | select(.name=="'"$expected_version"'") | .schema.openAPIV3Schema.properties.spec.properties.gitRepo.type // empty')" || {
    debug "Failed to extract schema for spec.gitRepo."
    failed
    return
  }
  if [ -z "$schema_gitrepo_type" ]; then
    debug "CRD schema does not define spec.gitRepo."
    failed
    return
  fi
  if [ "$schema_gitrepo_type" != "string" ]; then
    debug "CRD schema for spec.gitRepo is '$schema_gitrepo_type', expected 'string'."
    failed
    return
  fi

  # Check that the CRD is established
  debug "Checking if CRD '$expected_crd' is established."
  local established
  established="$(echo "$crd_json" | jq -r '.status.conditions[]? | select(.type=="Established") | .status')" || {
    debug "Failed to extract CRD status conditions."
    failed
    return
  }
  if [ "$established" != "True" ]; then
    debug "CRD '$expected_crd' is not established."
    failed
    return
  fi

  # Check Website instance exists in default namespace
  debug "Checking if Website instance '$expected_instance' exists in namespace '$expected_namespace'."
  local ws_json
  ws_json="$(kubectl get website "$expected_instance" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Website instance '$expected_instance' not found in namespace '$expected_namespace'."
    failed
    return
  }

  # Check spec.gitRepo value
  local ws_gitrepo
  ws_gitrepo="$(echo "$ws_json" | jq -r '.spec.gitRepo // empty')" || {
    debug "Failed to extract spec.gitRepo from Website instance."
    failed
    return
  }
  if [ "$ws_gitrepo" != "$expected_gitrepo" ]; then
    debug "Website instance spec.gitRepo is '$ws_gitrepo', expected '$expected_gitrepo'."
    failed
    return
  fi

  debug "All checks passed for Task 1. Verification successful."
  solved
  return
}

# shellcheck disable=SC2329
verify_task2() {
  TASK_NUMBER="2"
  local expected_crd="scheduledrunners.apps.example.com"
  local expected_group="apps.example.com"
  local expected_version="v1alpha1"
  local expected_kind="ScheduledRunner"
  local expected_plural="scheduledrunners"
  local expected_namespace="default"
  local expected_instance="nightly-job"
  local cron_regex='^(\d+|\*)(/\d+)?(\s+(\d+|\*)(/\d+)?){4}$'

  # Check if CRD exists
  debug "Checking if CRD '$expected_crd' exists."
  local crd_json
  crd_json="$(kubectl get crd "$expected_crd" -o json 2>/dev/null)" || {
    debug "CRD '$expected_crd' not found."
    failed
    return
  }

  # Check CRD is namespaced
  local scope
  scope="$(echo "$crd_json" | jq -r '.spec.scope')" || {
    debug "Failed to extract CRD scope."
    failed
    return
  }
  if [ "$scope" != "Namespaced" ]; then
    debug "CRD scope is '$scope', expected 'Namespaced'."
    failed
    return
  fi

  # Check CRD group, version, kind, plural
  local group
  group="$(echo "$crd_json" | jq -r '.spec.group')" || {
    debug "Failed to extract CRD group."
    failed
    return
  }
  if [ "$group" != "$expected_group" ]; then
    debug "CRD group is '$group', expected '$expected_group'."
    failed
    return
  fi

  local version_found
  version_found="$(echo "$crd_json" | jq -r '.spec.versions[]? | select(.name=="'"$expected_version"'") | .name')" || {
    debug "Failed to extract CRD versions."
    failed
    return
  }
  if [ "$version_found" != "$expected_version" ]; then
    debug "CRD version '$expected_version' not found."
    failed
    return
  fi

  local kind
  kind="$(echo "$crd_json" | jq -r '.spec.names.kind')" || {
    debug "Failed to extract CRD kind."
    failed
    return
  }
  if [ "$kind" != "$expected_kind" ]; then
    debug "CRD kind is '$kind', expected '$expected_kind'."
    failed
    return
  fi

  local plural
  plural="$(echo "$crd_json" | jq -r '.spec.names.plural')" || {
    debug "Failed to extract CRD plural name."
    failed
    return
  }
  if [ "$plural" != "$expected_plural" ]; then
    debug "CRD plural name is '$plural', expected '$expected_plural'."
    failed
    return
  fi

  # Check CRD schema for spec fields
  debug "Checking CRD schema for spec fields."
  local schema_path=".spec.versions[]? | select(.name==\"$expected_version\") | .schema.openAPIV3Schema.properties.spec.properties"
  local cronSpec_type
  cronSpec_type="$(echo "$crd_json" | jq -r "$schema_path.cronSpec.type // empty")" || {
    debug "Failed to extract cronSpec type from schema."
    failed
    return
  }
  if [ "$cronSpec_type" != "string" ]; then
    debug "spec.cronSpec type is '$cronSpec_type', expected 'string'."
    failed
    return
  fi
  local cronSpec_pattern
  cronSpec_pattern="$(echo "$crd_json" | jq -r "$schema_path.cronSpec.pattern // empty")" || {
    debug "Failed to extract cronSpec pattern from schema."
    failed
    return
  }
  if [ "$cronSpec_pattern" != "$cron_regex" ]; then
    debug "spec.cronSpec pattern does not match expected regex."
    failed
    return
  fi
  local cronSpec_required
  cronSpec_required="$(echo "$crd_json" | jq -r ".spec.versions[]? | select(.name==\"$expected_version\") | .schema.openAPIV3Schema.properties.spec.required[]? | select(.==\"cronSpec\")")" || {
    debug "Failed to check if cronSpec is required."
    failed
    return
  }
  if [ "$cronSpec_required" != "cronSpec" ]; then
    debug "spec.cronSpec is not marked as required."
    failed
    return
  fi

  local image_type
  image_type="$(echo "$crd_json" | jq -r "$schema_path.image.type // empty")" || {
    debug "Failed to extract image type from schema."
    failed
    return
  }
  if [ "$image_type" != "string" ]; then
    debug "spec.image type is '$image_type', expected 'string'."
    failed
    return
  fi
  local image_required
  image_required="$(echo "$crd_json" | jq -r ".spec.versions[]? | select(.name==\"$expected_version\") | .schema.openAPIV3Schema.properties.spec.required[]? | select(.==\"image\")")" || {
    debug "Failed to check if image is required."
    failed
    return
  }
  if [ "$image_required" != "image" ]; then
    debug "spec.image is not marked as required."
    failed
    return
  fi

  local replicas_type
  replicas_type="$(echo "$crd_json" | jq -r "$schema_path.replicas.type // empty")" || {
    debug "Failed to extract replicas type from schema."
    failed
    return
  }
  if [ -n "$replicas_type" ] && [ "$replicas_type" != "integer" ]; then
    debug "spec.replicas type is '$replicas_type', expected 'integer' or empty."
    failed
    return
  fi
  local replicas_min
  replicas_min="$(echo "$crd_json" | jq -r "$schema_path.replicas.minimum // empty")" || {
    debug "Failed to extract replicas minimum from schema."
    failed
    return
  }
  if [ -n "$replicas_min" ] && [ "$replicas_min" != "1" ]; then
    debug "spec.replicas minimum is '$replicas_min', expected '1'."
    failed
    return
  fi
  local replicas_max
  replicas_max="$(echo "$crd_json" | jq -r "$schema_path.replicas.maximum // empty")" || {
    debug "Failed to extract replicas maximum from schema."
    failed
    return
  }
  if [ -n "$replicas_max" ] && [ "$replicas_max" != "5" ]; then
    debug "spec.replicas maximum is '$replicas_max', expected '5'."
    failed
    return
  fi

  # Check that the CRD is established
  debug "Checking if CRD '$expected_crd' is established."
  local established
  established="$(echo "$crd_json" | jq -r '.status.conditions[]? | select(.type=="Established") | .status')" || {
    debug "Failed to extract CRD status conditions."
    failed
    return
  }
  if [ "$established" != "True" ]; then
    debug "CRD '$expected_crd' is not established."
    failed
    return
  fi

  # Check ScheduledRunner instance exists in default namespace
  debug "Checking if ScheduledRunner instance '$expected_instance' exists in namespace '$expected_namespace'."
  local sr_json
  sr_json="$(kubectl get scheduledrunner "$expected_instance" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "ScheduledRunner instance '$expected_instance' not found in namespace '$expected_namespace'."
    failed
    return
  }

  # Check required fields in instance
  local sr_cronSpec
  sr_cronSpec="$(echo "$sr_json" | jq -r '.spec.cronSpec // empty')" || {
    debug "Failed to extract spec.cronSpec from ScheduledRunner instance."
    failed
    return
  }
  if [ -z "$sr_cronSpec" ]; then
    debug "ScheduledRunner instance spec.cronSpec is missing."
    failed
    return
  fi
  local sr_image
  sr_image="$(echo "$sr_json" | jq -r '.spec.image // empty')" || {
    debug "Failed to extract spec.image from ScheduledRunner instance."
    failed
    return
  }
  if [ -z "$sr_image" ]; then
    debug "ScheduledRunner instance spec.image is missing."
    failed
    return
  fi
  local sr_replicas
  sr_replicas="$(echo "$sr_json" | jq -r '.spec.replicas // empty')" || {
    debug "Failed to extract spec.replicas from ScheduledRunner instance."
    failed
    return
  }
  if [ -n "$sr_replicas" ]; then
    if [ "$sr_replicas" -lt 1 ] || [ "$sr_replicas" -gt 5 ]; then
      debug "ScheduledRunner instance spec.replicas is '$sr_replicas', expected between 1 and 5."
      failed
      return
    fi
  fi

  debug "All checks passed for Task 2. Verification successful."
  solved
  return
}

# shellcheck disable=SC2329
verify_task3() {
  TASK_NUMBER="3"
  local expected_crd="books.myorg.io"
  local expected_version="v1"
  local expected_kind="Book"
  local expected_plural="books"
  local expected_namespace="library"
  local expected_instance="moby-dick"
  local expected_title="Moby Dick"
  local expected_author="Herman Melville"
  local expected_pages="635"

  # Check if CRD exists
  debug "Checking if CRD '$expected_crd' exists."
  local crd_json
  crd_json="$(kubectl get crd "$expected_crd" -o json 2>/dev/null)" || {
    debug "CRD '$expected_crd' not found."
    failed
    return
  }

  # Check CRD version
  local version_found
  version_found="$(echo "$crd_json" | jq -r '.spec.versions[]? | select(.name=="'"$expected_version"'") | .name')" || {
    debug "Failed to extract CRD versions."
    failed
    return
  }
  if [ "$version_found" != "$expected_version" ]; then
    debug "CRD version '$expected_version' not found."
    failed
    return
  fi

  # Check kind and plural
  local kind
  kind="$(echo "$crd_json" | jq -r '.spec.names.kind')" || {
    debug "Failed to extract CRD kind."
    failed
    return
  }
  if [ "$kind" != "$expected_kind" ]; then
    debug "CRD kind is '$kind', expected '$expected_kind'."
    failed
    return
  fi

  local plural
  plural="$(echo "$crd_json" | jq -r '.spec.names.plural')" || {
    debug "Failed to extract CRD plural name."
    failed
    return
  }
  if [ "$plural" != "$expected_plural" ]; then
    debug "CRD plural name is '$plural', expected '$expected_plural'."
    failed
    return
  fi

  # Check CRD schema for spec fields
  debug "Checking CRD schema for spec fields."
  local schema_path=".spec.versions[]? | select(.name==\"$expected_version\") | .schema.openAPIV3Schema.properties.spec.properties"
  local title_type
  title_type="$(echo "$crd_json" | jq -r "$schema_path.title.type // empty")" || {
    debug "Failed to extract title type from schema."
    failed
    return
  }
  if [ "$title_type" != "string" ]; then
    debug "spec.title type is '$title_type', expected 'string'."
    failed
    return
  fi
  local author_type
  author_type="$(echo "$crd_json" | jq -r "$schema_path.author.type // empty")" || {
    debug "Failed to extract author type from schema."
    failed
    return
  }
  if [ "$author_type" != "string" ]; then
    debug "spec.author type is '$author_type', expected 'string'."
    failed
    return
  fi
  local pages_type
  pages_type="$(echo "$crd_json" | jq -r "$schema_path.pages.type // empty")" || {
    debug "Failed to extract pages type from schema."
    failed
    return
  }
  if [ "$pages_type" != "integer" ]; then
    debug "spec.pages type is '$pages_type', expected 'integer'."
    failed
    return
  fi

  # Check that the CRD is established
  debug "Checking if CRD '$expected_crd' is established."
  local established
  established="$(echo "$crd_json" | jq -r '.status.conditions[]? | select(.type=="Established") | .status')" || {
    debug "Failed to extract CRD status conditions."
    failed
    return
  }
  if [ "$established" != "True" ]; then
    debug "CRD '$expected_crd' is not established."
    failed
    return
  fi

  # Check Book instance exists in library namespace
  debug "Checking if Book instance '$expected_instance' exists in namespace '$expected_namespace'."
  local book_json
  book_json="$(kubectl get book "$expected_instance" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Book instance '$expected_instance' not found in namespace '$expected_namespace'."
    failed
    return
  }

  # Check spec fields in instance
  local book_title
  book_title="$(echo "$book_json" | jq -r '.spec.title // empty')" || {
    debug "Failed to extract spec.title from Book instance."
    failed
    return
  }
  if [ "$book_title" != "$expected_title" ]; then
    debug "Book instance spec.title is '$book_title', expected '$expected_title'."
    failed
    return
  fi

  local book_author
  book_author="$(echo "$book_json" | jq -r '.spec.author // empty')" || {
    debug "Failed to extract spec.author from Book instance."
    failed
    return
  }
  if [ "$book_author" != "$expected_author" ]; then
    debug "Book instance spec.author is '$book_author', expected '$expected_author'."
    failed
    return
  fi

  local book_pages
  book_pages="$(echo "$book_json" | jq -r '.spec.pages // empty')" || {
    debug "Failed to extract spec.pages from Book instance."
    failed
    return
  }
  if [ "$book_pages" != "$expected_pages" ]; then
    debug "Book instance spec.pages is '$book_pages', expected '$expected_pages'."
    failed
    return
  fi

  debug "All checks passed for Task 3. Verification successful."
  solved
  return
}

# shellcheck disable=SC2329
verify_task4() {
  TASK_NUMBER="4"
  local expected_crd="devices.tech.io"
  local expected_version="v1beta1"
  local expected_kind="Device"
  local expected_plural="devices"
  local expected_namespace="default"
  local expected_instance="router-1"
  local expected_model="RTX1000"
  local expected_location="datacenter-1"
  local expected_column_model="Model"
  local expected_column_location="Location"

  # Check if CRD exists
  debug "Checking if CRD '$expected_crd' exists."
  local crd_json
  crd_json="$(kubectl get crd "$expected_crd" -o json 2>/dev/null)" || {
    debug "CRD '$expected_crd' not found."
    failed
    return
  }

  # Check CRD version
  local version_found
  version_found="$(echo "$crd_json" | jq -r '.spec.versions[]? | select(.name=="'"$expected_version"'") | .name')" || {
    debug "Failed to extract CRD versions."
    failed
    return
  }
  if [ "$version_found" != "$expected_version" ]; then
    debug "CRD version '$expected_version' not found."
    failed
    return
  fi

  # Check kind and plural
  local kind
  kind="$(echo "$crd_json" | jq -r '.spec.names.kind')" || {
    debug "Failed to extract CRD kind."
    failed
    return
  }
  if [ "$kind" != "$expected_kind" ]; then
    debug "CRD kind is '$kind', expected '$expected_kind'."
    failed
    return
  fi

  local plural
  plural="$(echo "$crd_json" | jq -r '.spec.names.plural')" || {
    debug "Failed to extract CRD plural name."
    failed
    return
  }
  if [ "$plural" != "$expected_plural" ]; then
    debug "CRD plural name is '$plural', expected '$expected_plural'."
    failed
    return
  fi

  # Check CRD schema for spec fields
  debug "Checking CRD schema for spec fields."
  local schema_path=".spec.versions[]? | select(.name==\"$expected_version\") | .schema.openAPIV3Schema.properties.spec.properties"
  local model_type
  model_type="$(echo "$crd_json" | jq -r "$schema_path.model.type // empty")" || {
    debug "Failed to extract model type from schema."
    failed
    return
  }
  if [ "$model_type" != "string" ]; then
    debug "spec.model type is '$model_type', expected 'string'."
    failed
    return
  fi
  local location_type
  location_type="$(echo "$crd_json" | jq -r "$schema_path.location.type // empty")" || {
    debug "Failed to extract location type from schema."
    failed
    return
  }
  if [ "$location_type" != "string" ]; then
    debug "spec.location type is '$location_type', expected 'string'."
    failed
    return
  fi

  # Check additional printer columns
  debug "Checking CRD additional printer columns."
  local columns_json
  columns_json="$(echo "$crd_json" | jq '.spec.versions[]? | select(.name=="'"$expected_version"'") | .additionalPrinterColumns')" || {
    debug "Failed to extract additionalPrinterColumns."
    failed
    return
  }
  local found_model="false"
  local found_location="false"
  local col_count
  col_count="$(echo "$columns_json" | jq 'length')" || {
    debug "Failed to count additionalPrinterColumns."
    failed
    return
  }
  if [ "$col_count" -eq 0 ]; then
    debug "No additionalPrinterColumns found."
    failed
    return
  fi
  local i
  for i in $(seq 0 $((col_count - 1))); do
    local col_name
    col_name="$(echo "$columns_json" | jq -r ".[$i].name")"
    if [ "$col_name" = "$expected_column_model" ]; then
      local col_jsonpath
      col_jsonpath="$(echo "$columns_json" | jq -r ".[$i].jsonPath")"
      if [ "$col_jsonpath" = ".spec.model" ]; then
        found_model="true"
      fi
    fi
    if [ "$col_name" = "$expected_column_location" ]; then
      local col_jsonpath
      col_jsonpath="$(echo "$columns_json" | jq -r ".[$i].jsonPath")"
      if [ "$col_jsonpath" = ".spec.location" ]; then
        found_location="true"
      fi
    fi
  done
  if [ "$found_model" != "true" ]; then
    debug "CRD does not have additionalPrinterColumn for '$expected_column_model' with jsonPath '.spec.model'."
    failed
    return
  fi
  if [ "$found_location" != "true" ]; then
    debug "CRD does not have additionalPrinterColumn for '$expected_column_location' with jsonPath '.spec.location'."
    failed
    return
  fi

  # Check that the CRD is established
  debug "Checking if CRD '$expected_crd' is established."
  local established
  established="$(echo "$crd_json" | jq -r '.status.conditions[]? | select(.type=="Established") | .status')" || {
    debug "Failed to extract CRD status conditions."
    failed
    return
  }
  if [ "$established" != "True" ]; then
    debug "CRD '$expected_crd' is not established."
    failed
    return
  fi

  # Check Device instance exists in default namespace
  debug "Checking if Device instance '$expected_instance' exists in namespace '$expected_namespace'."
  local device_json
  device_json="$(kubectl get device "$expected_instance" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Device instance '$expected_instance' not found in namespace '$expected_namespace'."
    failed
    return
  }

  # Check spec fields in instance
  local device_model
  device_model="$(echo "$device_json" | jq -r '.spec.model // empty')" || {
    debug "Failed to extract spec.model from Device instance."
    failed
    return
  }
  if [ "$device_model" != "$expected_model" ]; then
    debug "Device instance spec.model is '$device_model', expected '$expected_model'."
    failed
    return
  fi

  local device_location
  device_location="$(echo "$device_json" | jq -r '.spec.location // empty')" || {
    debug "Failed to extract spec.location from Device instance."
    failed
    return
  }
  if [ "$device_location" != "$expected_location" ]; then
    debug "Device instance spec.location is '$device_location', expected '$expected_location'."
    failed
    return
  fi

  debug "All checks passed for Task 4. Verification successful."
  solved
  return
}

# shellcheck disable=SC2329
verify_task5() {
  TASK_NUMBER="5"
  local expected_crd="settings.config.io"
  local expected_version="v1"
  local expected_kind="Settings"
  local expected_plural="settings"
  local expected_namespace="default"
  local expected_instance="feature-x"
  local expected_enabled_default="true"
  local expected_color_enum=("red" "green" "blue")
  local expected_color="blue"

  # Check if CRD exists
  debug "Checking if CRD '$expected_crd' exists."
  local crd_json
  crd_json="$(kubectl get crd "$expected_crd" -o json 2>/dev/null)" || {
    debug "CRD '$expected_crd' not found."
    failed
    return
  }

  # Check CRD version
  local version_found
  version_found="$(echo "$crd_json" | jq -r '.spec.versions[]? | select(.name=="'"$expected_version"'") | .name')" || {
    debug "Failed to extract CRD versions."
    failed
    return
  }
  if [ "$version_found" != "$expected_version" ]; then
    debug "CRD version '$expected_version' not found."
    failed
    return
  fi

  # Check kind and plural
  local kind
  kind="$(echo "$crd_json" | jq -r '.spec.names.kind')" || {
    debug "Failed to extract CRD kind."
    failed
    return
  }
  if [ "$kind" != "$expected_kind" ]; then
    debug "CRD kind is '$kind', expected '$expected_kind'."
    failed
    return
  fi

  local plural
  plural="$(echo "$crd_json" | jq -r '.spec.names.plural')" || {
    debug "Failed to extract CRD plural name."
    failed
    return
  }
  if [ "$plural" != "$expected_plural" ]; then
    debug "CRD plural name is '$plural', expected '$expected_plural'."
    failed
    return
  fi

  # Check CRD schema for spec fields
  debug "Checking CRD schema for spec fields."
  local schema_path=".spec.versions[]? | select(.name==\"$expected_version\") | .schema.openAPIV3Schema.properties.spec.properties"
  local enabled_type
  enabled_type="$(echo "$crd_json" | jq -r "$schema_path.enabled.type // empty")" || {
    debug "Failed to extract enabled type from schema."
    failed
    return
  }
  if [ "$enabled_type" != "boolean" ]; then
    debug "spec.enabled type is '$enabled_type', expected 'boolean'."
    failed
    return
  fi
  local enabled_default
  enabled_default="$(echo "$crd_json" | jq -r "$schema_path.enabled.default // empty")" || {
    debug "Failed to extract enabled default from schema."
    failed
    return
  }
  if [ "$enabled_default" != "$expected_enabled_default" ]; then
    debug "spec.enabled default is '$enabled_default', expected '$expected_enabled_default'."
    failed
    return
  fi

  local color_type
  color_type="$(echo "$crd_json" | jq -r "$schema_path.color.type // empty")" || {
    debug "Failed to extract color type from schema."
    failed
    return
  }
  if [ "$color_type" != "string" ]; then
    debug "spec.color type is '$color_type', expected 'string'."
    failed
    return
  fi
  local color_enum_json
  color_enum_json="$(echo "$crd_json" | jq -c "$schema_path.color.enum // empty")" || {
    debug "Failed to extract color enum from schema."
    failed
    return
  }
  local color_enum_count
  color_enum_count="$(echo "$color_enum_json" | jq 'length' 2>/dev/null)" || {
    debug "Failed to count color enum values."
    failed
    return
  }
  if [ "$color_enum_count" -ne "${#expected_color_enum[@]}" ]; then
    debug "spec.color enum count is '$color_enum_count', expected '${#expected_color_enum[@]}'."
    failed
    return
  fi
  local color_value
  for color_value in "${expected_color_enum[@]}"; do
    echo "$color_enum_json" | jq -e --arg v "$color_value" 'index($v)' >/dev/null 2>&1 || {
      debug "spec.color enum missing expected value: \"$color_value\". Found: $color_enum_json"
      failed
      return
    }
  done

  # Check that the CRD is established
  debug "Checking if CRD '$expected_crd' is established."
  local established
  established="$(echo "$crd_json" | jq -r '.status.conditions[]? | select(.type=="Established") | .status')" || {
    debug "Failed to extract CRD status conditions."
    failed
    return
  }
  if [ "$established" != "True" ]; then
    debug "CRD '$expected_crd' is not established."
    failed
    return
  fi

  # Check Setting instance exists in default namespace
  debug "Checking if Setting instance '$expected_instance' exists in namespace '$expected_namespace'."
  local setting_json
  setting_json="$(kubectl get settings "$expected_instance" -n "$expected_namespace" -o json 2>/dev/null)" || {
    debug "Setting instance '$expected_instance' not found in namespace '$expected_namespace'."
    failed
    return
  }

  # Check spec fields in instance
  local setting_enabled
  setting_enabled="$(echo "$setting_json" | jq -r '.spec.enabled // empty')" || {
    debug "Failed to extract spec.enabled from Setting instance."
    failed
    return
  }
  if [ "$setting_enabled" != "$expected_enabled_default" ]; then
    debug "Setting instance spec.enabled is '$setting_enabled', expected '$expected_enabled_default'."
    failed
    return
  fi

  local setting_color
  setting_color="$(echo "$setting_json" | jq -r '.spec.color // empty')" || {
    debug "Failed to extract spec.color from Setting instance."
    failed
    return
  }
  if [ "$setting_color" != "$expected_color" ]; then
    debug "Setting instance spec.color is '$setting_color', expected '$expected_color'."
    failed
    return
  fi

  debug "All checks passed for Task 5. Verification successful."
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
)
run_verification VERIFY_TASK_FUNCTIONS "$@"

exit 0
