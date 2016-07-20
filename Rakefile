require 'bundler/gem_tasks'
require 'rake/clean'
require 'cucumber/rake/task'

CLOBBER.include('pkg')
CLEAN.include('build')

task :init do
  FileUtils.mkdir_p 'build'
end

# Cucumber acceptance test task
Cucumber::Rake::Task.new(:features)
task :features => :init

