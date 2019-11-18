#!/bin/bash

set -x

QUEUE=$1
TEST_CONFIGURATION=$2

TARGET=${QUEUE}
LOG_FILE=/var/tmp/kstest.${TARGET}.log
TIMEOUT=43200

# Activate virtualenv for linchpin
source /home/kstest/virtualenv-linchpin/bin/activate

# Separator in the log
echo "TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT" >> ${LOG_FILE}
echo $(date) >> ${LOG_FILE}

# Run the test
./kstests-in-cloud.sh test ${TARGET} --test-run-timeout ${TIMEOUT} --cloud kstests --pinfile PinFile.${TARGET} --remote-user fedora --key-name kstests --key-use-existing --ansible-private-key /home/kstest/.ssh/kstests.pem --test-configuration ${TEST_CONFIGURATION} --key-use-for-master --ansible-python-interpreter /usr/bin/python3 2>&1 | tee -a ${LOG_FILE}

# Dummy run for debugging
#SECS=$((60 + RANDOM % 100))
#echo "${TASK} ${SECS} ${CMDLINE}" > dummy_running
#echo "Sleeping ${SECS}"
#sleep ${SECS}
#
