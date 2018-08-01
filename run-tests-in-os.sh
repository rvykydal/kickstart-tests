#!/bin/sh

set -x

### Check linchpin configuration

# Do any linchpin credentials exist?

# Are any credentials used in the topology?

### Check ansible configuration

# Does deployment key exist?

# Show key that should match

# Show kstest private key

# Show kstest host authorized keys, should include kstest public key

# Check that syncing is configured

### Clean the linchpin generated inventory
rm -rf linchpin/inventories/*.inventory

### Provision test hosts (all which are defined in the PinFile)
linchpin -v --workspace linchpin -p linchpin/PinFile -c linchpin/linchpin.conf up

### Pass inventory generated by linchpin to ansible
cp linchpin/inventories/*.inventory ansible/linchpin.inventory

cd ansible

### Deploy the remote hosts
ansible-playbook kstest.yml
### Deploy the master and configure the test
ansible-playbook kstest-master.yml
### Run the test and sync results
ansible kstest-master -m shell -a 'PATH=$PATH:/usr/sbin ~/run_tests.sh' -u kstest

cd -

### Destroy the provisioned hosts
linchpin -v --workspace linchpin -p linchpin/PinFile -c linchpin/linchpin.conf destroy
