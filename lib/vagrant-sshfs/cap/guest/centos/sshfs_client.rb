module VagrantPlugins
  module GuestCentOS
    module Cap
      class SSHFSClient
        def self.sshfs_install(machine)

          # Until a newer version of Vagrant ships with https://github.com/hashicorp/vagrant/pull/12785
          # we need to handle the case where Alma or Rocky end up here
          if machine.communicate.test("grep 'VERSION_ID=\"8' /etc/os-release")
              machine.communicate.sudo("yum -y install --enablerepo=powertools fuse-sshfs")
              return
          elsif machine.communicate.test("grep 'VERSION_ID=\"9' /etc/os-release")
              if !epel_installed(machine)
                epel_install(machine)
              end
              machine.communicate.sudo("yum -y install fuse-sshfs")
              return
          end

          case machine.guest.capability("flavor")
            when :centos_8
              # No need to install epel. fuse-sshfs comes from the powertools repo
              # https://bugzilla.redhat.com/show_bug.cgi?id=1758884
              # https://github.com/dustymabe/vagrant-sshfs/issues/123
              machine.communicate.sudo("yum -y install --enablerepo=powertools fuse-sshfs")
            when :centos_9, :centos_7, :centos # centos{9,7,6}
              # Install fuse-sshfs from epel
              if !epel_installed(machine)
                epel_install(machine)
              end
              machine.communicate.sudo("yum -y --enablerepo=epel install fuse-sshfs")
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
