Feature: Mount of user home directory

  Scenario Outline: Mounting the user's home directory
    Given a file named "Vagrantfile" with:
    """
    Vagrant.configure('2') do |config|
      config.vm.box = '<box>'
      config.vm.synced_folder '.', '/vagrant', disabled: true

      if Vagrant::Util::Platform.windows?
        target_path = ENV['USERPROFILE'].gsub(/\\/,'/').gsub(/[[:alpha:]]{1}:/){|s|'/' + s.downcase.sub(':', '')}
        config.vm.synced_folder ENV['USERPROFILE'], target_path, type: 'sshfs', sshfs_opts_append: '-o umask=000 -o uid=1000 -o gid=1000'
      else
        config.vm.synced_folder ENV['HOME'], ENV['HOME'], type: 'sshfs', sshfs_opts_append: '-o umask=000 -o uid=1000 -o gid=1000'
      end
    end
    """
    When I successfully run `bundle exec vagrant up --provider <provider>`
    Then stdout from "bundle exec vagrant up --provider <provider>" should contain "Installing SSHFS client..."
    And  stdout from "bundle exec vagrant up --provider <provider>" should contain "Mounting SSHFS shared folder..."
    And  stdout from "bundle exec vagrant up --provider <provider>" should contain "Folder Successfully Mounted!"
    And user's home directory should be mounted

    Examples:
      | box              | provider   |
      | centos/7         | virtualbox |
    
    