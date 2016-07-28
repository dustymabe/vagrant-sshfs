# This is a cucumber step definition. Cucumber scenarios become automated 
# tests with the addition of what are called step definitions. A step 
# definition is a block of code associated with one or more steps by a 
# regular expression (or, in simple cases, a string).
#
# This is the step definition for the `And vagrant current working
# directory should be mounted` step from sshfs_cwd_mount.feature
#
And(/^vagrant current working directory should be mounted$/) do
  run("vagrant ssh -c 'ls /testdir/Vagrantfile'")
  expect(last_command_started).to have_exit_status(0)
end
