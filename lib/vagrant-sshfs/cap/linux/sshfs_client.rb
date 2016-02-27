module VagrantPlugins
  module GuestLinux
    module Cap
      class SSHFSClient
        def self.sshfs_installed(machine)
          machine.communicate.test("test -x /usr/bin/sshfs")
        end
      end
    end
  end
end
