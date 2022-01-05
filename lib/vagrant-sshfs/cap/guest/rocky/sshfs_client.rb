module VagrantPlugins
  module GuestRocky
    module Cap
      class SSHFSClient
        def self.sshfs_install(machine)
          # No need to install epel. fuse-sshfs comes from the powertools repo
          # https://bugzilla.redhat.com/show_bug.cgi?id=1758884
          # https://github.com/dustymabe/vagrant-sshfs/issues/123
          machine.communicate.sudo("yum -y install --enablerepo=powertools fuse-sshfs")
        end

        def self.sshfs_installed(machine)
          machine.communicate.test("rpm -q fuse-sshfs")
        end

      end
    end
  end
end
