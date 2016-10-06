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
  module HostLinux
    module Cap
      class MountSSHFS
        extend Vagrant::Util::Retryable
        @@logger = Log4r::Logger.new("vagrant::synced_folders::sshfs_reverse_mount")

        def self.sshfs_reverse_is_folder_mounted(env, opts)
          mounted = false
          hostpath = opts[:hostpath].dup
          hostpath.gsub!("'", "'\\\\''")
          hostpath = hostpath.chomp('/') # remove trailing / if exists
          cat_cmd = Vagrant::Util::Which.which('cat')
          result = Vagrant::Util::Subprocess.execute(cat_cmd, '/proc/mounts')
          mounts = File.open('/proc/mounts', 'r')
          mounts.each_line do |line|
            if line.split()[1] == hostpath
              mounted = true
              break
            end
          end
          return mounted
        end

        def self.sshfs_reverse_mount_folder(env, machine, opts)
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
          self.sshfs_mount(machine, opts)
        end

        def self.sshfs_reverse_unmount_folder(env, machine, opts)
          self.sshfs_unmount(machine, opts)
        end

        protected

        # Perform a mount by running an sftp-server on the vagrant host 
        # and piping stdin/stdout to sshfs running inside the guest
        def self.sshfs_mount(machine, opts)

          sshfs_path = Vagrant::Util::Which.which('sshfs')

          # expand the guest path so we can handle things like "~/vagrant"
          expanded_guest_path = machine.guest.capability(
            :shell_expand_guest_path, opts[:guestpath])

          # Mount path information
          hostpath = opts[:hostpath].dup
          hostpath.gsub!("'", "'\\\\''")

          # Add in some sshfs/fuse options that are common to both mount methods
          opts[:sshfs_opts] = ' -o noauto_cache '# disable caching based on mtime

          # Add in some ssh options that are common to both mount methods
          opts[:ssh_opts] = ' -o StrictHostKeyChecking=no '# prevent yes/no question 
          opts[:ssh_opts]+= ' -o ServerAliveInterval=30 '  # send keepalives

          # SSH connection options
          # Note the backslash escapes for IdentityFile - handles spaces in key path
          ssh_opts = opts[:ssh_opts]
          ssh_opts+= ' -o Port=' + machine.ssh_info[:port].to_s
          ssh_opts+= ' -o "IdentityFile=\"' + machine.ssh_info[:private_key_path][0] + '\""'
          ssh_opts+= ' -o UserKnownHostsFile=/dev/null '
          ssh_opts+= ' -F /dev/null ' # Don't pick up options from user's config

          ssh_opts_append = opts[:ssh_opts_append].to_s # provided by user

          # SSHFS executable options
          sshfs_opts = opts[:sshfs_opts]
          sshfs_opts_append = opts[:sshfs_opts_append].to_s # provided by user

          username = machine.ssh_info[:username]
          host = machine.ssh_info[:host]


          # The sshfs command to mount the guest directory on the host
          sshfs_cmd = "#{sshfs_path} #{ssh_opts} #{ssh_opts_append} "
          sshfs_cmd+= "#{sshfs_opts} #{sshfs_opts_append} "
          sshfs_cmd+= "#{username}@#{host}:#{expanded_guest_path} #{hostpath}" 

          # Log some information
          @@logger.debug("sshfs cmd: #{sshfs_cmd}")

          machine.ui.info(I18n.t("vagrant.sshfs.actions.reverse_mounting_folder", 
                          hostpath: hostpath, guestpath: expanded_guest_path))

          # Log STDERR to predictable files so that we can inspect them
          # later in case things go wrong. We'll use the machines data
          # directory (i.e. .vagrant/machines/default/virtualbox/) for this
          f1path = machine.data_dir.join('vagrant_sshfs_sshfs_stderr.txt')
          f1 = File.new(f1path, 'w+')

          # Launch sshfs command to mount guest dir into the host
          if Vagrant::Util::Platform.windows?
            # Need to handle Windows differently. Kernel.spawn fails to work, 
            # if the shell creating the process is closed.
            # See https://github.com/dustymabe/vagrant-sshfs/issues/31
            Process.create(:command_line => ssh_cmd,
                           :creation_flags => Process::DETACHED_PROCESS,
                           :process_inherit => false,
                           :thread_inherit => true,
                           :startup_info => {:stdin => w2, :stdout => r1, :stderr => f1})
          else
            p1 = spawn(sshfs_cmd,   :out => f1, :err => f1, :pgroup => true)
            Process.detach(p1) # Detach so process will keep running
          end

          # Check that the mount made it
          mounted = false
          for i in 0..6
            machine.ui.info("Checking Mount..")
            if self.sshfs_reverse_is_folder_mounted(machine, opts)
              mounted = true
              break
            end
            sleep(2)
          end
          if !mounted
            f1.rewind # Seek to beginning of the file
            error_class = VagrantPlugins::SyncedFolderSSHFS::Errors::SSHFSReverseMountFailed
            raise error_class, sshfs_output: f1.read
          end
          machine.ui.info("Folder Successfully Mounted!")
        end

        def self.sshfs_unmount(machine, opts)
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

          # Mount path information
          hostpath = opts[:hostpath].dup
          hostpath.gsub!("'", "'\\\\''")

          # Log some information
          machine.ui.info(I18n.t("vagrant.sshfs.actions.reverse_unmounting_folder",
                                 hostpath: hostpath))

          # Build up the command and connect
          error_class = VagrantPlugins::SyncedFolderSSHFS::Errors::SSHFSUnmountFailed
          fusermount_cmd = Vagrant::Util::Which.which('fusermount')
          cmd = "#{fusermount_cmd} -u #{hostpath}"
          result = Vagrant::Util::Subprocess.execute(*cmd.split())
          if result.exit_code != 0
            raise error_class, command: cmd, stdout: result.stdout, stderr: result.stderr
          end
        end
      end
    end
  end
end
