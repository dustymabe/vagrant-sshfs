Feature: SSHFS mount of vagrant current working directory

  Scenario Outline: SSHFS mounting of vagrant cwd
    Given a file named "Vagrantfile" with:
    """
    Vagrant.configure('2') do |config|
      config.vm.box = '<box>'
      # Disable the default rsync
      config.vm.synced_folder '.', '/vagrant', disabled: true

      # Mount up the current dir. It will have the Vagrantfile in there.
      config.vm.synced_folder './', '/testdir', type: 'sshfs'
    end
    """
    When I successfully run `bundle exec vagrant up`
    Then stdout from "bundle exec vagrant up" should contain "Installing SSHFS client..."
    And  stdout from "bundle exec vagrant up" should contain "Mounting SSHFS shared folder..."
    And  stdout from "bundle exec vagrant up" should contain "Folder Successfully Mounted!"
    And vagrant current working directory should be mounted

    Examples:
      | box      |
      | centos/7 |
    
    
