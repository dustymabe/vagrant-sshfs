module VagrantPlugins
  module GuestRedHat
    module Cap
      class SSHFSClient
        def self.sshfs_install(machine)

          case machine.guest.capability("flavor")
            when :rhel_8
              # fuse-sshfs isn't in EPEL8 and how to get it from RHEL repos
              # without having to have the system subscribed is unclear:
              # https://github.com/dustymabe/vagrant-sshfs/issues/108#issuecomment-601061947
              # Using fuse-sshfs from EPEL7 works for now so let's just go with it.
              # Do the install in such a way that the epel7 repo doesn't hang around
              # on the system, which may have unintended consequences on RHEL8.
              machine.communicate.sudo("rpm --import https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-7")
              machine.communicate.sudo("yum -y install fuse-sshfs --repofrompath=epel7,'http://download.fedoraproject.org/pub/epel/7/$basearch'")
            when :rhel_7, :rhel # rhel7 and rhel6
              # Install fuse-sshfs from epel
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
          case machine.guest.capability("flavor")
            when :rhel_7
              machine.communicate.sudo("rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm")
            when :rhel # rhel6
              machine.communicate.sudo("rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-6.noarch.rpm")
          end
        end
      end
    end
  end
end
