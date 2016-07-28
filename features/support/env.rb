# This is a support file for the cucumber tests. This file sets up the
# environment for the tests to run. At this point mainly that means
# configuring Aruba. Aruba is used to define most of the basic step
# definitions that we use as part of the Gherkin syntax in our .feature files.
#
# For more information on the step definitions provided see:
# https://github.com/cucumber/aruba/tree/bb5d7ff71809b5461e29153ded793d2b9a3a0624/features/testing_frameworks/cucumber/steps
require 'aruba/cucumber'
require 'komenda' # use komenda for easily executing a command

# Configure aruba. The options can be inferred from here:
# https://github.com/cucumber/aruba/tree/bb5d7ff71809b5461e29153ded793d2b9a3a0624/features/configuration
Aruba.configure do |config|
  # Wait up to 300 seconds for the test to run
  config.exit_timeout = 300
  # Output stdout and stderr on test failure
  config.activate_announcer_on_command_failure = [:stdout, :stderr]
  # The directory where the tests are to be run
  config.working_directory = 'build/aruba'
end

# After running tests, clean up
After do |_scenario|
  if File.exist?(File.join(aruba.config.working_directory, 'Vagrantfile'))
    Komenda.run('bundle exec vagrant destroy -f', cwd: aruba.config.working_directory, fail_on_fail: true)
  end
end
