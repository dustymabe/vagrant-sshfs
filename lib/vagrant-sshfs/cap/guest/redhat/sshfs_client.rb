module VagrantPlugins
  module GuestRedHat
    module Cap
      class SSHFSClient
        def self.sshfs_install(machine)
          # Install epel rpm if not installed
          if !epel_installed(machine)
            epel_install(machine)
          end

          # Install sshfs (comes from epel repos)
          machine.communicate.sudo("yum -y install fuse-sshfs")
        end

        def self.sshfs_installed(machine)
          machine.communicate.test("rpm -q fuse-sshfs")
        end

        protected

        def self.epel_installed(machine)
          machine.communicate.test("rpm -q epel-release")
        end

        def self.epel_install(machine)
          machine.communicate.sudo("yum -y install epel-release")
        end
      end
    end
  end
end
