module VagrantPlugins
  module GuestRedHat
    module Cap
      class SSHFSClient
        def self.sshfs_install(machine)

          rhel_version = machine.guest.capability("flavor")

          # Handle the case where Vagrant doesn't yet know how to
          # detect and return :rhel_8 https://github.com/hashicorp/vagrant/pull/11453
          if Gem::Version.new(Vagrant::VERSION) < Gem::Version.new('2.2.8')
            rhel_version = vagrant_lt_228_flavor_compat(machine)
          end

          case rhel_version
            when :rhel_8
              # No need to install epel. fuse-sshfs comes from the PowerTools repo
              # https://bugzilla.redhat.com/show_bug.cgi?id=1758884
              machine.communicate.sudo("yum -y install --enablerepo=PowerTools fuse-sshfs")
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
          machine.communicate.sudo("yum -y install epel-release")
        end

        def self.vagrant_lt_228_flavor_compat(machine)
          # This is a compatibility function to handle RHEL8 for
          # vagrant versions that didn't include:
          # https://github.com/hashicorp/vagrant/pull/11453
          output = ""
          machine.communicate.sudo("cat /etc/redhat-release") do |_, data|
            output = data
          end
          if output =~ /(CentOS|Red Hat Enterprise|Scientific|Cloud|Virtuozzo)\s*Linux( .+)? release 8/i
            return :rhel_8
          elsif output =~ /(CentOS|Red Hat Enterprise|Scientific|Cloud|Virtuozzo)\s*Linux( .+)? release 7/i
            return :rhel_7
          else
            return :rhel
          end
        end
      end
    end
  end
end
