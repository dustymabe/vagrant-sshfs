
# This directory is for testing the three different mount modes
# that are supported by vagrant-sshfs

# To test we will first create the directory on the machine where
# we will mount the guest /etc/ into the host (the reverse mount).

mkdir /tmp/reverse_mount_etc

# Next we will define where our 3rd party host is (the normal mount).
# This can be another vagrant box or whatever machine you want.
export THIRD_PARTY_HOST='192.168.121.73'                                                                                                                                               
export THIRD_PARTY_HOST_USER='vagrant'                                                                                                                                                 
export THIRD_PARTY_HOST_PASS='vagrant'

# Next vagrant up - will do 4 mounts
#  - slave
#  - slave with sym link
#  - normal
#  - reverse
vagrant up

# Next run the script to test the mounts:
$ bash dotests.sh 
Testing slave forward mount!
        d635332fe7aa4d4fb48e5cb9357bdedf
Testing slave forward mount with a symlink!
        d635332fe7aa4d4fb48e5cb9357bdedf
Testing normal forward mount!
        6ccc3034df924bd289dd16205bf3d629
Testing reverse mount!
        508619e7e68e446c84d1fcdf7e0dc577

# We are printing out the machine-id under each mount. The first two
should be the same, because they are from the same machine. The last
two should be different.
