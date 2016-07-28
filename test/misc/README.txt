
# This directory is for testing the three different mount modes
# that are supported by vagrant-sshfs

# To test we will first create the directory on the machien where
# we will mount the guest /etc/ into the host (the reverse mount).

mkdir /tmp/reverse_mount_etc

# Next we will define where our 3rd party host is (the normal mount).
# This can be another vagrant box or whatever machine you want.
export THIRD_PARTY_HOST='192.168.121.73'                                                                                                                                               
export THIRD_PARTY_HOST_USER='vagrant'                                                                                                                                                 
export THIRD_PARTY_HOST_PASS='vagrant'

# Next vagrant up - will do 3 mounts (normal, slave, reverse).
vagrant up

# Next run the script to test the mounts:
$ bash dotests.sh 
Testing normal mount!
a57e39fa692f294e860349a9451be67c
Testing slave mount!
e2c4ceac71dc414cb3ed864cff04a917
Testing reverse mount!
508619e7e68e446c84d1fcdf7e0dc577

# We are printing out the machine-id under each mount to prove each
# mount is from a different machine.
