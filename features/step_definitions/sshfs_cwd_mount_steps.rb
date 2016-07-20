And(/^vagrant current working directory should be mounted$/) do
  run("vagrant ssh -c 'ls /testdir/Vagrantfile'")
  expect(last_command_started).to have_exit_status(0)
end
