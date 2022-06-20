
# This directory is for testing the three different mount modes
# that are supported by vagrant-sshfs

# To test we will first create the directory on the machine where
# we will mount the guest /etc/ into the host (the reverse mount).

mkdir /tmp/reverse_mount_etc_uid_gid/

# Next we will define where our 3rd party host is (the normal mount).
# This can be another vagrant box or whatever machine you want.
export THIRD_PARTY_HOST='192.168.121.73'
export THIRD_PARTY_HOST_USER='vagrant'
export THIRD_PARTY_HOST_PASS='vagrant'

# Open an extra file descriptor to test it is not passed onto child processes
# https://github.com/dustymabe/vagrant-sshfs/issues/120
tmpfile=$(mktemp)
exec {extra_fd}<> "$tmpfile"

# Next vagrant up - will do 5 mounts
#  - slave
#  - slave with owner/group
#  - slave with sym link
#  - normal (from 3rd party host)
#  - reverse with owner/group
vagrant up

# Next run the script to test the mounts:
$ bash dotests.sh 
Testing slave forward mount!
        1358d4a18a2d4ba7be380b991e899952
Testing slave forward mount with owner/group!
        root:wheel
        1358d4a18a2d4ba7be380b991e899952
Testing slave forward mount with a symlink!
        1358d4a18a2d4ba7be380b991e899952
Testing normal forward mount!
        ef56862ae88f43c0a81962ba6f68a668
Testing reverse mount with owner/group!
        root:wheel
        ef4f3b50e2034b3593a9eb8b71350abe

# We are printing out the machine-id under each mount. The first three
should be the same, because they are from the same machine (the host).
The last two should be different; one from 3rd party machine and one
from the test VM itself (read from the host).

# Close our file descriptor. No other process should be using it
exec {extra_fd}>&-
if lsof -wn -d $extra_fd | grep "$tmpfile"; then
  echo "Failure: there are processes running that hold an inherited file descriptor"
fi
