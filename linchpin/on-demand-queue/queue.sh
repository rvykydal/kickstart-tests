#!/bin/bash

set -x

QUEUE=on-demand-1

HOME=/home/kstest
SERVICE_DIR=${HOME}/${QUEUE}
KSTESTS_REPO_DIR=${SERVICE_DIR}/kickstart-tests
TEST_CONFIGURATION=${KSTESTS_REPO_DIR}/${QUEUE}.test-configuration.yml

STATUS_FILE=${SERVICE_DIR}/queue/status.txt
DONE_DIR=${SERVICE_DIR}/queue/done
TODO_DIR=${SERVICE_DIR}/queue/todo
RUNNING_DIR=${SERVICE_DIR}/queue/running

REMOTE_RESULTS_PATH="root@10.43.136.2:/mnt/trees/kstests/${QUEUE}"
REMOTE_RESULTS_URL="http://10.43.136.2/trees/kstests/${QUEUE}"

STATUS="Unknown"
SLEEP=60

while :; do

    RUNNING_TASK=$(ls -A1 ${RUNNING_DIR})
    # If there is no running task
    if [ -z "${RUNNING_TASK}" ]; then
        # If there are no tasks in the queue
        if [ -z "$(ls -A ${TODO_DIR})" ]; then
            STATUS="There are no tasks in the queue, I'll check in ${SLEEP} seconds."
        else
            # Select task
            TASK=$(ls ${TODO_DIR} | sort | head -n 1)

            # Move task to running
            mv ${TODO_DIR}/${TASK} ${RUNNING_DIR}/${TASK}
            STATUS="Starting task ${TASK}."
            echo "$(date) ${STATUS}" > ${STATUS_FILE}

            # Update task configuration with results location
            cp ${RUNNING_DIR}/${TASK} ${TEST_CONFIGURATION}
            START_TIME=$(date +%F-%H_%M_%S)
            RUN_DIR_NAME="${TASK}.${START_TIME}"
            echo "kstest_result_run_dir_name: ${RUN_DIR_NAME}" >> ${TEST_CONFIGURATION}
            echo "kstest_remote_results_path: ${REMOTE_RESULTS_PATH}" >> ${TEST_CONFIGURATION}
            echo "kstest_updates_upload_path: ${REMOTE_RESULTS_PATH}" >> ${TEST_CONFIGURATION}
            echo "kstest_updates_dir_url: ${REMOTE_RESULTS_URL}" >> ${TEST_CONFIGURATION}

            # Run the test with the configuration
            pushd ${KSTESTS_REPO_DIR}
            ./run_ondemand_test.sh ${QUEUE} ${TEST_CONFIGURATION}
            popd

            # Add info about results location and move to done
            REMOTE_RESULTS_URL="http://10.43.136.2/trees/kstests/${QUEUE}"
            echo "# Results are here: ${REMOTE_RESULTS_URL}/results/runs/${RUN_DIR_NAME}" >> ${RUNNING_DIR}/${TASK}
            mv ${RUNNING_DIR}/${TASK} ${DONE_DIR}/${TASK}

            STATUS="Finished task ${TASK}."
            echo "$(date) ${STATUS}" > ${STATUS_FILE}
            continue
        fi
    else
        STATUS="There is a running task ${RUNNING_TASK}. I'll check in ${SLEEP} seconds."
    fi
    echo "$(date) ${STATUS}" > ${STATUS_FILE}
    sleep ${SLEEP}
done
