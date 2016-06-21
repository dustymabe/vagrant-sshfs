And(/^user's home directory should be mounted$/) do
  run("vagrant ssh -c \"ls #{ENV['HOME']}\"")
  expect(last_command_started).to have_exit_status(0)
end
