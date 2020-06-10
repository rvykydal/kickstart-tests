#!/bin/sh

# Activate virtualenv with linchpin
source /home/rvykydal/work/virtualenv/linchpin/bin/activate

./kstests-in-cloud.sh destroy race-hunt --cloud upshift --pinfile PinFile --force
