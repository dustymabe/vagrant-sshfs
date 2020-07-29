require 'simplecov'
SimpleCov.start do
  add_filter "/spec/"
end

require "bundler/setup"


PROJECT_DIR = File.absolute_path(__dir__)

RSpec.configure do |config|

  config.color = true
  config.tty = true
  config.formatter = :documentation

  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
