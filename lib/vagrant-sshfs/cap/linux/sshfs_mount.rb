require "log4r"

require "vagrant/util/retryable"

module VagrantPlugins
  module GuestLinux
    module Cap
      class MountSSHFS
        extend Vagrant::Util::Retryable
        @@logger = Log4r::Logger.new("vagrant::synced_folders::sshfs_mount")

        def self.sshfs_is_folder_mounted(machine, opts)
          mounted = false
          # expand the guest path so we can handle things like "~/vagrant"
          expanded_guest_path = machine.guest.capability(
            :shell_expand_guest_path, opts[:guestpath])
          machine.communicate.execute("cat /proc/mounts") do |type, data|
            if type == :stdout
              data.each_line do |line|
                if line.split()[1] == expanded_guest_path
                  mounted = true
                  break
                end
              end
            end
          end
          return mounted
        end

        def self.sshfs_mount_folder(machine, opts)
          # opts contains something like:
          #   { :type=>:sshfs,
          #     :guestpath=>"/sharedfolder",
          #     :hostpath=>"/guests/sharedfolder", 
          #     :disabled=>false
          #     :ssh_host=>"192.168.1.1"
          #     :ssh_port=>"22"
          #     :ssh_username=>"username"
          #     :ssh_password=>"password"
          #   }

          # expand the guest path so we can handle things like "~/vagrant"
          expanded_guest_path = machine.guest.capability(
            :shell_expand_guest_path, opts[:guestpath])

          # Create the mountpoint inside the guest
          machine.communicate.tap do |comm|
            comm.sudo("mkdir -p #{expanded_guest_path}")
            comm.sudo("chmod 777 #{expanded_guest_path}")
          end

          # Mount path information
          hostpath = opts[:hostpath].dup
          hostpath.gsub!("'", "'\\\\''")

          # Log some information
          machine.ui.info(I18n.t("vagrant.sshfs.actions.mounting_folder", 
                          hostpath: hostpath, guestpath: expanded_guest_path))

          # Figure out any options
          # TODO - Allow options override via an option
          mount_opts = '-o StrictHostKeyChecking=no '
          mount_opts+= '-o allow_other '
          mount_opts+= '-o noauto_cache '

          # TODO some other options we might use in the future to help
          # connections over low bandwidth
          #options+= '-o kernel_cache -o Ciphers=arcfour -o big_writes -o auto_cache -o cache_timeout=115200 -o attr_timeout=115200 -o entry_timeout=1200 -o max_readahead=90000 '
          #options+= '-o kernel_cache -o big_writes -o auto_cache -o cache_timeout=115200 -o attr_timeout=115200 -o entry_timeout=1200 -o max_readahead=90000 '
          #options+= '-o cache_timeout=3600 '

          username = opts[:ssh_username]
          password = opts[:ssh_password]
          host     = opts[:ssh_host]
          port     = opts[:ssh_port]

          echopipe = ""
          if password
            echopipe = "echo '#{password}' | "
            mount_opts+= '-o password_stdin '
          end
          
          error_class = VagrantPlugins::SyncedFolderSSHFS::Errors::SSHFSMountFailed
          cmd = echopipe 
          cmd+= "sshfs -p #{port} "
          cmd+= mount_opts
          cmd+= "#{username}@#{host}:'#{hostpath}' #{expanded_guest_path}"
          retryable(on: error_class, tries: 3, sleep: 3) do
            machine.communicate.sudo(
              cmd, error_class: error_class, error_key: :mount_failed)
          end
        end
      end
    end
  end
end
