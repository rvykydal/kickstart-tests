#!/bin/sh

# Activate virtualenv with linchpin
source /home/rvykydal/work/virtualenv/linchpin/bin/activate

./kstests-in-cloud.sh provision rawhide-nightly-pet-f32 --test-run-timeout 0 --cloud upshift --pinfile PinFile --remote-user fedora --key-name kstests --key-use-existing --ansible-private-key /home/rvykydal/.ssh/kstests.pem --key-use-for-master --ansible-python-interpreter /usr/bin/python3
