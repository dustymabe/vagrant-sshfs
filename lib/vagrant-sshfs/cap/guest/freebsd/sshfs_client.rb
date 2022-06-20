module VagrantPlugins
  module GuestFreeBSD
    module Cap
      class SSHFSClient
        def self.sshfs_install(machine)
          machine.communicate.sudo("pkg install -y fusefs-sshfs")
          # older FreeBSD used fuse, newer uses fusefs
          # https://github.com/dustymabe/vagrant-sshfs/issues/124
          machine.communicate.sudo("kldload fuse || kldload fusefs")
        end

        def self.sshfs_installed(machine)
          installed = machine.communicate.test("pkg info fusefs-sshfs")
          if installed
              # fuse may not get loaded at boot, so check if it's loaded
              # If not loaded then force load it
              loaded = machine.communicate.test("kldstat -m fuse || kldstat -m fusefs")
              if not loaded
                # older FreeBSD used fuse, newer uses fusefs
                # https://github.com/dustymabe/vagrant-sshfs/issues/124
                machine.communicate.sudo("kldload fuse || kldload fusefs")
              end
          end

          installed
        end
      end
    end
  end
end
