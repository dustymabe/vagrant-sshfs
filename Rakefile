# A Rakefile is like a Makefile for ruby

# bundler/gem_tasks provides functionality like:
#   bundle exec rake build
#   bundle exec rake install
#   bundle exec rake release
#
require 'bundler/gem_tasks'

# cucumber/rake/task provides us with an easy way to call cucumber
require 'cucumber/rake/task'

# rake/clean provides CLEAN/CLOBBER
# http://www.virtuouscode.com/2014/04/28/rake-part-6-clean-and-clobber/
# CLEAN - list to let rake know what files can be cleaned up after build
# CLOBBER - list to let rake know what files are final products of the build
#
require 'rake/clean'


# Add the build dir to the list of items to clean up
CLEAN.include('build')

# We want to keep the build artifacts in the pkg dir
CLOBBER.include('pkg')

# Define a Rake::Task that will do initialization for us
# See http://www.ultrasaurus.com/2009/12/creating-a-custom-rake-task/
task :init do
  FileUtils.mkdir_p 'build'
end
