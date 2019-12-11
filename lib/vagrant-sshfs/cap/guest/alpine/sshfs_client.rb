module VagrantPlugins
  module GuestAlpine
    module Cap
      class SSHFSClient
        def self.sshfs_install(machine)
          # Install sshfs
          machine.communicate.sudo("apk add sshfs")
          # Load the fuse module
          machine.communicate.sudo("modprobe fuse")
        end

        def self.sshfs_installed(machine)
          installed = machine.communicate.test("apk -e info sshfs")
          if installed
              # fuse may not get loaded at boot, so check if it's loaded otherwise force load it
              machine.communicate.sudo("lsmod | grep fuse || modprobe fuse")
          end

          installed
        end
      end
    end
  end
end
