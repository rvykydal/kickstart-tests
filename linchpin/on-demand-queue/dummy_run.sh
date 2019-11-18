#!/bin/bash

TASK=$1

SECS=$((60 + RANDOM % 100))
echo "${TASK} ${SECS}" > dummy_running
echo "Sleeping ${SECS}"
sleep ${SECS}
