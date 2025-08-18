#!/bin/bash

echo "Cleaning up exercise \"${CKAD_EXERCISE_DIR}\"..."


cleanup_kind_cluster() {
  # Set parameters
  NAME=$1

  kind delete cluster --name "${NAME}"
}

cleanup_git_ignored_files() {
  # Set parameters
  WORK_DIR=$1

  # Ensure this script is running inside a Git repository
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Cleaning up Git-ignored files in ${WORK_DIR}..."

    # Dry run to show the files that will be removed
    ignored_files=$(git clean -ndx)
    if [[ -z "$ignored_files" ]]; then
      echo "No Git-ignored files to clean up."
    else
      # Run the actual cleanup by removing the ignored files
      git clean -fx "${WORK_DIR}"
      echo "Git-ignored files have been removed."
    fi
  else
    echo "Warning: This directory is not a Git repository. No files will be cleaned."
  fi
}

cleanup_volume_mounts() {
  sudo rm -rf "$(git rev-parse --show-toplevel)/.cluster/mounts"
}

cleanup_kind_cluster ckad
cleanup_git_ignored_files "$(pwd)/${CKAD_EXERCISE_DIR}"
cleanup_volume_mounts
