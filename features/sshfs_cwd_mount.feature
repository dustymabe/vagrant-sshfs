# The language in this file is Gherkin. It is the language Cucumber
# uses to define test cases and is designed to be non-technical and
# human readable. All Gherkin files have a .feature extension
#
# See more here: https://en.wikipedia.org/wiki/Cucumber_(software)
#
# Additionally in the setup/env.rb file we set up Aruba. Aruba is used
# to define most of the basic step definitions that we use as part of
# the Gherkin syntax in this file.
#
# For more information on the step definitions provided see:
# https://github.com/cucumber/aruba/tree/bb5d7ff71809b5461e29153ded793d2b9a3a0624/features/testing_frameworks/cucumber/steps
#
Feature: SSHFS mount of vagrant current working directory

  Scenario Outline: SSHFS mounting of vagrant cwd
    Given a file named "Vagrantfile" with:
    """
    Vagrant.configure('2') do |config|
      config.vm.box = '<box>'
      # Disable the default rsync
      config.vm.synced_folder '.', '/vagrant', disabled: true

      # If using libvirt and nested virt (vagrant in vagrant) then
      # we need to use a different network than 192.168.121.0
      config.vm.provider :libvirt do |libvirt|
        libvirt.management_network_name = 'vagrant-libvirt-test'
        libvirt.management_network_address = '192.168.129.0/24'
      end

      # Mount up the current dir. It will have the Vagrantfile in there.
      config.vm.synced_folder './', '/testdir', type: 'sshfs'
    end
    """
    When I successfully run `bundle exec vagrant up`
    Then stdout from "bundle exec vagrant up" should contain "Installing SSHFS client..."
    And  stdout from "bundle exec vagrant up" should contain "Mounting SSHFS shared folder..."
    And  stdout from "bundle exec vagrant up" should contain "Folder Successfully Mounted!"
    # The code for the following test is in ./step_definitions/sshfs_cwd_mount_steps.rb
    And vagrant current working directory should be mounted

    Examples:
      | box      |
      | centos/7 |


