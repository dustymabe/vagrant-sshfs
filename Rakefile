require 'bundler/gem_tasks'
require 'rake/clean'
require 'cucumber/rake/task'
require 'launchy'

CLOBBER.include('pkg')
CLEAN.include('build')

task :init do
  FileUtils.mkdir_p 'build'
end

# Cucumber acceptance test task
Cucumber::Rake::Task.new(:features)
task :features => :init

namespace :features do
  desc 'Opens the HTML Cucumber test report'
  task :open_report do
    Launchy.open('./build/features_report.html')
  end
end

