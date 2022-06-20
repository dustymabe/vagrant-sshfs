#!/bin/bash
set -eu

# Test the four mounts we have done

echo -en "Testing slave forward mount!\n\t"
vagrant ssh -- cat /tmp/forward_slave_mount_etc/machine-id

echo -en "Testing slave forward mount with owner/group!\n\t"
vagrant ssh -- stat --printf '%U:%G' /tmp/forward_slave_mount_etc_uid_gid
echo -en "\n\t"
vagrant ssh -- cat /tmp/forward_slave_mount_etc_uid_gid/machine-id

# https://github.com/dustymabe/vagrant-sshfs/issues/44
echo -en "Testing slave forward mount with a symlink!\n\t"
vagrant ssh -- cat /run/forward_slave_mount_sym_link_test/machine-id

echo -en "Testing normal forward mount!\n\t"
vagrant ssh -- cat /tmp/forward_normal_mount_etc/machine-id

echo -en "Testing reverse mount with owner/group!\n\t"
stat --printf '%U:%G' /tmp/reverse_mount_etc_uid_gid/
echo -en "\n\t"
cat /tmp/reverse_mount_etc_uid_gid/machine-id
