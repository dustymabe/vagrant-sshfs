module VagrantPlugins
  module GuestFedora
    module Cap
      class SSHFSClient
        def self.sshfs_install(machine)
          machine.communicate.sudo("dnf -y install fuse-sshfs")
        end

        def self.sshfs_installed(machine)
          machine.communicate.test("rpm -q fuse-sshfs")
        end
      end
    end
  end
end
