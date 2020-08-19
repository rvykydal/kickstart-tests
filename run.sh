#!/bin/bash
# Run the test including provisioning and destroying of temporary runners.

RESULT_DIR=/var/tmp/kstest.results.rawhide-nightly-pet-f32
mkdir -p ${RESULT_DIR}

# Activate virtualenv with linchpin
source /home/rvykydal/work/virtualenv/linchpin/bin/activate

./kstests-in-cloud.sh run rawhide-nightly-pet-f32 --test-configuration rawhide-nightly-pet-f32.test-configuration.yml --results ${RESULT_DIR}
