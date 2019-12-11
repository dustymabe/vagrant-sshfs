module VagrantPlugins
  module GuestAlpine
    module Cap
      class SSHFSClient
        def self.sshfs_install(machine)
          # Install sshfs
          machine.communicate.sudo("apk add sshfs")

          # Load the fuse module and autoload it in the feature
          machine.communicate.sudo("modprobe fuse")
          machine.communicate.sudo("echo fuse >> /etc/modules")
        end

        def self.sshfs_installed(machine)
          machine.communicate.test("apk -e info sshfs")
        end
      end
    end
  end
end
