require "log4r"

require "vagrant/util/retryable"
require "tempfile"

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

        def self.sshfs_unmount_folder(machine, opts)
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
          ssh_cmd+= ' "' + sshfs_cmd + '"'

          # Log some information
          @@logger.debug("sftp-server cmd: #{sftp_server_cmd}")
          @@logger.debug("ssh cmd: #{ssh_cmd}")
          machine.ui.info(I18n.t("vagrant.sshfs.actions.slave_mounting_folder", 
                          hostpath: hostpath, guestpath: expanded_guest_path))

          # Create two named pipes for communication between sftp-server and
          # sshfs running in slave mode
          r1, w1 = IO.pipe # reader/writer from pipe1
          r2, w2 = IO.pipe # reader/writer from pipe2

          # For issue #27 we'll need to create a tmp files for STDERR
          # Can't send to /dev/null. Doesn't work on Windows.
          # Can't close FD with :close. Doesn't work on Windows.
          t1 = Tempfile.new('vagrant_sshfs_sftp_server_stderr').path()
          t2 = Tempfile.new('vagrant_sshfs_ssh_stderr').path()

          # The way this works is by hooking up the stdin+stdout of the
          # sftp-server process to the stdin+stdout of the sshfs process
          # running inside the guest in slave mode. An illustration is below:
          # 
          #          stdout => w1      pipe1         r1 => stdin 
          #         />------------->==============>----------->\
          #        /                                            \
          #        |                                            |
          #    sftp-server (on vm host)                      sshfs (inside guest)
          #        |                                            |
          #        \                                            /
          #         \<-------------<==============<-----------</
          #          stdin <= r2        pipe2         w2 <= stdout 
          #
          # Wire up things appropriately and start up the processes
          p1 = spawn(sftp_server_cmd, :out => w2, :in => r1, :err => t1)
          p2 = spawn(ssh_cmd,         :out => w1, :in => r2, :err => t2)

          # Check that the mount made it
          mounted = false
          for i in 0..6
            machine.ui.info("Checking Mount..")
            if self.sshfs_is_folder_mounted(machine, opts)
              mounted = true
              break
            end
            sleep(2)
          end
          if !mounted
            raise VagrantPlugins::SyncedFolderSSHFS::Errors::SSHFSSlaveMountFailed
          end
          machine.ui.info("Folder Successfully Mounted!")

          # Detach from the processes so they will keep running
          Process.detach(p1)
          Process.detach(p2)
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
          retryable(on: error_class, tries: 3, sleep: 3) do
            machine.communicate.sudo(
              cmd, error_class: error_class, error_key: :normal_mount_failed)
          end
        end
      end
    end
  end
end
