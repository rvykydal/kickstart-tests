#!/bin/bash

HOME=/home/kstest
SERVICE_DIR=${HOME}/on-demand-1
KSTESTS_REPO_DIR=${SERVICE_DIR}/kickstart-tests

STATUS_FILE=${SERVICE_DIR}/queue/status.txt
LOG_FILE=${SERVICE_DIR}/queue/log.txt
DONE_DIR=${SERVICE_DIR}/queue/done
TODO_DIR=${SERVICE_DIR}/queue/todo
RUNNING_DIR=${SERVICE_DIR}/queue/running

QUEUE=on-demand-1
TARGET=${QUEUE}

STATUS="Unknown"
KSTEST_LOG_FILE=/var/tmp/kstest.${TARGET}.log

# If running dir is empty
if [ -z "$(ls -A ${RUNNING_DIR})" ]; then
    if [ -z "$(ls -A ${TODO_DIR})" ]; then
        STATUS="No tasks in the queue."
    else
        STATUS="There are tasks in the queue but none seems to be running."
    fi
else
    pushd ${KSTESTS_REPO_DIR}
    STATUS=$(${KSTESTS_REPO_DIR}/kstests-in-cloud.sh status ${TARGET})
    popd
    tail -n 100 ${KSTEST_LOG_FILE} > ${LOG_FILE}
fi

echo "$(date) ${STATUS}" > ${STATUS_FILE}
