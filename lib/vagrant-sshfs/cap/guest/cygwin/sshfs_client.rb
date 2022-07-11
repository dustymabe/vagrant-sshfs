module VagrantPlugins
  module GuestCygwin
    module Cap
      class SSHFSClient
        def self.sshfs_installed(machine)
          machine.communicate.test("type sshfs")
        end
      end
    end
  end
end
