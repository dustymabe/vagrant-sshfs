module VagrantPlugins
  module GuestCentos
    module Cap
      class SSHFSClient
        def self.sshfs_install(machine)

          case machine.guest.capability("flavor")
            when :centos_8
              machine.communicate.sudo("yum -y install --enablerepo=PowerTools fuse-sshfs")
            when :centos_7, :centos
              if !epel_installed(machine)
                epel_install(machine)
              end
              machine.communicate.sudo("yum -y install fuse-sshfs")
          end
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
