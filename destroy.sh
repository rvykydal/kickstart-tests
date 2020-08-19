#!/bin/sh

# Activate virtualenv with linchpin
source /home/rvykydal/work/virtualenv/linchpin/bin/activate

./kstests-in-cloud.sh destroy rawhide-nightly-pet-f32 --cloud upshift --pinfile PinFile --force
