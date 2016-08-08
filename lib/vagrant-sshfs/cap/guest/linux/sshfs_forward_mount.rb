require "log4r"
require "vagrant/util/retryable"
require "tempfile"

module VagrantPlugins
  module GuestLinux
    module Cap
      class MountSSHFS
        @@logger = Log4r::Logger.new("vagrant::synced_folders::sshfs_mount")

        def self.sshfs_forward_is_folder_mounted(machine, opts)
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

        def self.sshfs_forward_mount_folder(machine, opts)
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

          # Add in some sshfs/fuse options that are common to both mount methods
          opts[:sshfs_opts] = ' -o allow_other ' # allow non-root users to access
          opts[:sshfs_opts]+= ' -o noauto_cache '# disable caching based on mtime

          # Add in some ssh options that are common to both mount methods
          opts[:ssh_opts] = ' -o StrictHostKeyChecking=no '# prevent yes/no question 
          opts[:ssh_opts]+= ' -o ServerAliveInterval=30 '  # send keepalives

          # Do a normal mount only if the user provided host information
          if opts.has_key?(:ssh_host) and opts[:ssh_host]
            self.sshfs_normal_mount(machine, opts, hostpath, expanded_guest_path)
          else
            self.sshfs_slave_mount(machine, opts, hostpath, expanded_guest_path)
          end
        end

        def self.sshfs_forward_unmount_folder(machine, opts)
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

          # Log some information
          machine.ui.info(I18n.t("vagrant.sshfs.actions.unmounting_folder",
                                 guestpath: expanded_guest_path))

          # Build up the command and connect
          error_class = VagrantPlugins::SyncedFolderSSHFS::Errors::SSHFSUnmountFailed
          cmd = "umount #{expanded_guest_path}"
          machine.communicate.sudo(
            cmd, error_class: error_class, error_key: :unmount_failed)
        end

        protected

        # Perform a mount by running an sftp-server on the vagrant host 
        # and piping stdin/stdout to sshfs running inside the guest
        def self.sshfs_slave_mount(machine, opts, hostpath, expanded_guest_path)

          sftp_server_path = opts[:sftp_server_exe_path]
          ssh_path = opts[:ssh_exe_path]

          # SSH connection options
          ssh_opts = opts[:ssh_opts]
          ssh_opts_append = opts[:ssh_opts_append].to_s # provided by user

          # SSHFS executable options
          sshfs_opts = opts[:sshfs_opts]
          sshfs_opts_append = opts[:sshfs_opts_append].to_s # provided by user

          # The sftp-server command
          sftp_server_cmd = sftp_server_path

          # The remote sshfs command that will run (in slave mode)
          sshfs_opts+= ' -o slave '
          sshfs_cmd = "sudo -E sshfs :#{hostpath} #{expanded_guest_path}" 
          sshfs_cmd+= sshfs_opts + ' ' + sshfs_opts_append + ' '

          # The ssh command to connect to guest and then launch sshfs
          ssh_opts = opts[:ssh_opts]
          ssh_opts+= ' -o User=' + machine.ssh_info[:username]
          ssh_opts+= ' -o Port=' + machine.ssh_info[:port].to_s
          ssh_opts+= ' -o IdentityFile=' + machine.ssh_info[:private_key_path][0]
          ssh_opts+= ' -o UserKnownHostsFile=/dev/null '
          ssh_opts+= ' -F /dev/null ' # Don't pick up options from user's config
          ssh_cmd = ssh_path + ssh_opts + ' ' + ssh_opts_append + ' ' + machine.ssh_info[:host]
          ssh_cmd+= " '" + sshfs_cmd + "'"

          # Log some information
          @@logger.debug("sftp-server cmd: #{sftp_server_cmd}")
          @@logger.debug("ssh cmd: #{ssh_cmd}")
          machine.ui.info(I18n.t("vagrant.sshfs.actions.slave_mounting_folder",
                          hostpath: hostpath, guestpath: expanded_guest_path))

          # We are going to spawn twice. This is required mainly for Windows were
          # processes executing the Vagrant command and echoing its IO, cannot
          # exit even though the main Ruby process exits.
          # We are going to spawn a independent Ruby process first in which we then
          # set up the IO pipes for sshfs.
          ensure_ruby_on_path
          create_processes_path = Pathname(__dir__).join('create_processes.rb')
          if Vagrant::Util::Platform.windows?
            Process.create(:command_line => %Q[ruby "#{create_processes_path}" "#{machine.env.gems_path}" "#{sftp_server_cmd}" "#{ssh_cmd}" "#{machine.data_dir}" "true"],
                           :creation_flags => Process::DETACHED_PROCESS,
                           :process_inherit => false,
                           :thread_inherit => true)
          else
            p1 = spawn('ruby', create_processes_path.to_s, machine.env.gems_path.to_s, sftp_server_cmd, ssh_cmd, machine.data_dir.to_s, 'false', :pgroup => true)
            Process.detach(p1)
          end

          # Check that the mount made it
          mounted = false
          (0..6).each do
            machine.ui.info('Checking Mount..')
            if self.sshfs_forward_is_folder_mounted(machine, opts)
              mounted = true
              break
            end
            sleep(2)
          end
          if mounted
            machine.ui.info('Folder Successfully Mounted!')
          else
            machine.ui.error("Folder mount failed! Check #{machine.data_dir} for error log files.")
            raise VagrantPlugins::SyncedFolderSSHFS::Errors::SSHFSSlaveMountFailed
          end
        end

        # Do a normal sshfs mount in which we will ssh into the guest
        # and then execute the sshfs command to connect the the opts[:ssh_host]
        # and mount a folder from opts[:ssh_host] into the guest.
        def self.sshfs_normal_mount(machine, opts, hostpath, expanded_guest_path)

          # SSH connection options
          ssh_opts = opts[:ssh_opts]
          ssh_opts_append = opts[:ssh_opts_append].to_s # provided by user

          # SSHFS executable options
          sshfs_opts = opts[:sshfs_opts]
          sshfs_opts_append = opts[:sshfs_opts_append].to_s # provided by user

          # Host/Port and Auth Information
          username = opts[:ssh_username]
          password = opts[:ssh_password]
          host     = opts[:ssh_host]
          port     = opts[:ssh_port]

          # Add echo of password if password is being used
          echopipe = ""
          if password
            echopipe = "echo '#{password}' | "
            sshfs_opts+= '-o password_stdin '
          end

          # Log some information
          machine.ui.info(I18n.t("vagrant.sshfs.actions.normal_mounting_folder", 
                          user: username, host: host, 
                          hostpath: hostpath, guestpath: expanded_guest_path))

          # Build up the command and connect
          error_class = VagrantPlugins::SyncedFolderSSHFS::Errors::SSHFSNormalMountFailed
          cmd = echopipe 
          cmd+= "sshfs -p #{port} "
          cmd+= ssh_opts + ' ' + ssh_opts_append + ' '
          cmd+= sshfs_opts + ' ' + sshfs_opts_append + ' '
          cmd+= "#{username}@#{host}:'#{hostpath}' #{expanded_guest_path}"
          Vagrant::Util::Retryable.retryable(on: error_class, tries: 3, sleep: 3) do
            machine.communicate.sudo(
              cmd, error_class: error_class, error_key: :normal_mount_failed)
          end
        end

        # On a machine with just Vagrant installed there might be no other Ruby except the
        # one bundled with Vagrant. Let's make sure the embedded bin directory containing
        # the Ruby executable is added to the PATH.
        def self.ensure_ruby_on_path
          vagrant_binary = Vagrant::Util::Which.which('vagrant')
          vagrant_binary = File.realpath(vagrant_binary) if File.symlink?(vagrant_binary)
          # in a Vagrant installation the Ruby executable is in ../embedded/bin relative to the vagrant executable
          # we don't use File.join here, since even on Cygwin we want a Windows path - see https://github.com/vagrant-landrush/landrush/issues/237
          if Vagrant::Util::Platform.windows?
            separator = '\\'
          else
            separator = '/'
          end
          embedded_bin_dir = File.dirname(File.dirname(vagrant_binary)) + separator + 'embedded' + separator + 'bin'
          ENV['PATH'] = embedded_bin_dir + File::PATH_SEPARATOR + ENV['PATH'] if File.exist?(embedded_bin_dir)
        end
      end
    end
  end
end

