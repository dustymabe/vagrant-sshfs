#!/bin/bash
set -eu

# Test the three mounts we have done

echo "Testing normal mount!"
vagrant ssh -- cat /tmp/forward_normal_mount_etc/machine-id

echo "Testing slave mount!"
vagrant ssh -- cat /tmp/forward_slave_mount_etc/machine-id

echo "Testing reverse mount!"
cat /tmp/reverse_mount_etc/machine-id
