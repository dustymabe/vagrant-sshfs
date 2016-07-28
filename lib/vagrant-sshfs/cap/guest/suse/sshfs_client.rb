module VagrantPlugins
  module GuestSUSE
    module Cap
      class SSHFSClient
        def self.sshfs_install(machine)
          machine.communicate.sudo("zypper -n install sshfs")
        end

        def self.sshfs_installed(machine)
          machine.communicate.test("rpm -q sshfs")
        end
      end
    end
  end
end
