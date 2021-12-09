module VagrantPlugins
  module GuestFreeBSD
    module Cap
      class SSHFSClient
        def self.sshfs_install(machine)
          machine.communicate.sudo("pkg install -y fusefs-sshfs")
          machine.communicate.sudo("kldload fusefs")
        end

        def self.sshfs_installed(machine)
          installed = machine.communicate.test("pkg info fusefs-sshfs")
          if installed
              # fuse may not get loaded at boot, so check if it's loaded otherwise force load it
              machine.communicate.sudo("kldstat -m fusefs || kldload fusefs")
          end

          installed
        end
      end
    end
  end
end
