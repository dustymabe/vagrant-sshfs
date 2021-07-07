module VagrantPlugins
  module GuestSUSE
    module Cap
      class SSHFSClient
        def self.sshfs_install(machine)
          machine.communicate.sudo("zypper -n install sshfs")
          machine.communicate.sudo('if ! grep -q "^[[:space:]]*Subsystem[[:space:]]\+sftp" /etc/ssh/sshd_config; then echo "Subsystem sftp /usr/libexec/ssh/sftp-server" >> /etc/ssh/sshd_config; systemctl restart sshd; fi')
        end

        def self.sshfs_installed(machine)
          machine.communicate.test("rpm -q sshfs")
        end
      end
    end
  end
end
