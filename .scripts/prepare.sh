#!/bin/bash

CKAD_EXERCISE_DIR=${PWD##*/}
CKAD_WORKSPACE_DIR=$(git rev-parse --show-toplevel)

export CKAD_EXERCISE_DIR
export CKAD_WORKSPACE_DIR

prepare_kind_cluster() {
  kind create cluster --config "${CKAD_WORKSPACE_DIR}/.cluster/kind-cluster-config.yaml"
}

create_exam_resources() {
  kubectl apply -f "${CKAD_WORKSPACE_DIR}/.templates/${CKAD_EXERCISE_DIR}/" &>/dev/null
}


if [ "$(dirname "$PWD")" == "$CKAD_WORKSPACE_DIR/exercises" ]; then
  echo "Preparing exercise \"${CKAD_EXERCISE_DIR}\"..."
  prepare_kind_cluster
  create_exam_resources
fi
