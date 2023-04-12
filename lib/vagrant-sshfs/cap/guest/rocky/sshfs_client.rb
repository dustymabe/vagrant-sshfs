module VagrantPlugins
  module GuestRocky
    module Cap
      class SSHFSClient
        def self.sshfs_install(machine)

          case machine.guest.capability("flavor")
            when :rocky_8
              # No need to install epel. fuse-sshfs comes from the powertools repo
              # https://bugzilla.redhat.com/show_bug.cgi?id=1758884
              # https://github.com/dustymabe/vagrant-sshfs/issues/123
              machine.communicate.sudo("yum -y install --enablerepo=powertools fuse-sshfs")
            when :rocky_9, :rocky # rocky9 or unknown
              # Install fuse-sshfs from epel
              if !epel_installed(machine)
                epel_install(machine)
              end
              machine.communicate.sudo("yum -y install fuse-sshfs")
          end
        end

        def self.sshfs_installed(machine)
          machine.communicate.test("rpm -q --whatprovides fuse-sshfs")
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
