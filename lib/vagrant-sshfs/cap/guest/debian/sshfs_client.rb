module VagrantPlugins
  module GuestDebian
    module Cap
      class SSHFSClient
        def self.sshfs_install(machine)
          machine.communicate.sudo("apt-get update")
          machine.communicate.sudo("apt-get install -y sshfs")
        end

        def self.sshfs_installed(machine)
          machine.communicate.test("dpkg -l sshfs")
        end
      end
    end
  end
end
