require "log4r"
require "vagrant/util/retryable"
require "tempfile"

# This is already done for us in lib/vagrant-sshfs.rb. We needed to
# do it there before Process.uid is called the first time by Vagrant
# This provides a new Process.create() that works on Windows.
if Vagrant::Util::Platform.windows?
  require 'win32/process'
end

module VagrantPlugins
  module GuestLinux
    module Cap
      class MountSSHFS
        extend Vagrant::Util::Retryable
        @@logger = Log4r::Logger.new("vagrant::synced_folders::sshfs_mount")

        def self.sshfs_forward_is_folder_mounted(machine, opts)
          mounted = false
          # find the absolute path so that we can properly check if it is mounted
          # https://github.com/dustymabe/vagrant-sshfs/issues/44
          absolute_guest_path = machine.guest.capability(
            :sshfs_get_absolute_path, opts[:guestpath])
          machine.communicate.execute("cat /proc/mounts") do |type, data|
            if type == :stdout
              data.each_line do |line|
                if line.split()[1] == absolute_guest_path
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

        def self.windows_uninherit_handles
          # For win32-process Process.create, if we pass any file handles to the 
          # underlying process for stdin/stdout/stderr then all file handles are 
          # inherited by default. We'll explicitly go through and set all Handles
          # to not be inheritable by default. See following links for more info
          # 
          # https://github.com/djberg96/win32-process/blob/6b380f450aebb69d44bb7accd958ecb6b9e1d246/lib/win32/process.rb#L445-L447
          # bInheritHandles from https://msdn.microsoft.com/en-us/library/windows/desktop/ms682425(v=vs.85).aspx
          # 
          # For each open IO object 
          ObjectSpace.each_object(IO) do |io|
            if !io.closed?
              fileno = io.fileno 
              @@logger.debug("Setting file handle #{fileno} to not be inherited")
              self.windows_uninherit_handle(fileno)
            end
          end
        end

        def self.windows_uninherit_handle(fileno)
          # Right now we'll be doing this using private methods from the win32-process
          # module by calling  For each open IO object. Much of this code was copied from 
          # that module. We access the private methods by using the object.send(:method, args)
          # technique. In the future we want to get a patch upstream so we don't need to
          # access private methods. Upstream request is here:
          # https://github.com/djberg96/win32-process/pulls

          # Get the windows IO handle and make sure we were successful getting it
          handle = Process.send(:get_osfhandle, fileno)
          if handle == Process::Constants::INVALID_HANDLE_VALUE
            ptr = FFI::MemoryPointer.new(:int)
            if Process.send(:windows_version) >= 6 && Process.get_errno(ptr) == 0
              errno = ptr.read_int
            else
              errno = FFI.errno
            end
            raise SystemCallError.new("get_osfhandle", errno)
          end

          # Now clear the HANDLE_FLAG_INHERIT from the HANDLE so that the handle
          # won't get shared by default. See: 
          # https://msdn.microsoft.com/en-us/library/windows/desktop/ms724935(v=vs.85).aspx
          # 
          bool = Process.send(:SetHandleInformation,
          handle, Process::Constants::HANDLE_FLAG_INHERIT, 0)
          raise SystemCallError.new("SetHandleInformation", FFI.errno) unless bool
        end

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
          # Note the backslash escapes for IdentityFile - handles spaces in key path
          ssh_opts = opts[:ssh_opts]
          ssh_opts+= ' -o User=' + machine.ssh_info[:username]
          ssh_opts+= ' -o Port=' + machine.ssh_info[:port].to_s
          ssh_opts+= ' -o "IdentityFile=\"' + machine.ssh_info[:private_key_path][0] + '\""'
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

          # Log STDERR to predictable files so that we can inspect them
          # later in case things go wrong. We'll use the machines data
          # directory (i.e. .vagrant/machines/default/virtualbox/) for this
          f1path = machine.data_dir.join('vagrant_sshfs_sftp_server_stderr.txt')
          f2path = machine.data_dir.join('vagrant_sshfs_ssh_stderr.txt')
          f1 = File.new(f1path, 'w+')
          f2 = File.new(f2path, 'w+')

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
          if Vagrant::Util::Platform.windows?
            # For windows we need to set it so not all file handles are inherited
            # by default. See https://github.com/dustymabe/vagrant-sshfs/issues/41
            # The r1,r2,w1,w2,f1,f2 we pass below will get set back to be shared
            self.windows_uninherit_handles
            # For windows, we are using win32-process' Process.create because ruby
            # doesn't properly detach processes. See https://github.com/dustymabe/vagrant-sshfs/issues/31
            Process.create(:command_line => sftp_server_cmd,
                           :creation_flags => Process::DETACHED_PROCESS,
                           :process_inherit => false,
                           :thread_inherit => true,
                           :startup_info => {:stdin => w2, :stdout => r1, :stderr => f1})

            Process.create(:command_line => ssh_cmd,
                           :creation_flags => Process::DETACHED_PROCESS,
                           :process_inherit => false,
                           :thread_inherit => true,
                           :startup_info => {:stdin => w1, :stdout => r2, :stderr => f2})
          else
            p1 = spawn(sftp_server_cmd, :out => w2, :in => r1, :err => f1, :pgroup => true)
            p2 = spawn(ssh_cmd,         :out => w1, :in => r2, :err => f2, :pgroup => true)

            # Detach from the processes so they will keep running
            Process.detach(p1)
            Process.detach(p2)
          end

          # Check that the mount made it
          mounted = false
          for i in 0..6
            machine.ui.info("Checking Mount..")
            if self.sshfs_forward_is_folder_mounted(machine, opts)
              mounted = true
              break
            end
            sleep(2)
          end
          if !mounted
            f1.rewind # Seek to beginning of the file
            f2.rewind # Seek to beginning of the file
            error_class = VagrantPlugins::SyncedFolderSSHFS::Errors::SSHFSSlaveMountFailed
            raise error_class, sftp_stderr: f1.read, ssh_stderr: f2.read
          end
          machine.ui.info("Folder Successfully Mounted!")
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
