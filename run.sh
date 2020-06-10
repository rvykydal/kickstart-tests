#!/bin/bash
# Run the test including provisioning and destroying of temporary runners.

RESULT_DIR=/var/tmp/kstest.results.race-hunt
mkdir -p ${RESULT_DIR}

# Activate virtualenv with linchpin
source /home/rvykydal/work/virtualenv/linchpin/bin/activate

./kstests-in-cloud.sh run race-hunt --test-configuration race-hunt.test-configuration.yml --results ${RESULT_DIR}
