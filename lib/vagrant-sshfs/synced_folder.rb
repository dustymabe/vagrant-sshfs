require "log4r"

require "vagrant/util/platform"
require "vagrant/util/which"

module VagrantPlugins
  module SyncedFolderSSHFS
    class SyncedFolder < Vagrant.plugin("2", :synced_folder)
      @@vagrant_host_machine_ip

      def initialize(*args)
        super

        @logger = Log4r::Logger.new("vagrant::synced_folders::sshfs")
        @@vagrant_host_machine_ip = nil
      end

      # This is called early when the synced folder is set to determine
      # if this implementation can be used for this machine. This should
      # return true or false.
      #
      # @param [Machine] machine
      # @param [Boolean] raise_error If true, should raise an exception
      #   if it isn't usable.
      # @return [Boolean]
      def usable?(machine, raise_error=false)
        return true #for now
      end

      # This is called after the machine is booted and after networks
      # are setup.
      #
      # This might be called with new folders while the machine is running.
      # If so, then this should add only those folders without removing
      # any existing ones.
      #
      # No return value.
      def enable(machine, folders, pluginopts)

        # Check to see if sshfs software is in the guest
        if machine.guest.capability?(:sshfs_installed)
          if !machine.guest.capability(:sshfs_installed)
            can_install = machine.guest.capability?(:sshfs_install)
            if !can_install
              raise VagrantPlugins::SyncedFolderSSHFS::Errors::SSHFSNotInstalledInGuest
            end
            machine.ui.info(I18n.t("vagrant.sshfs.actions.installing"))
            machine.guest.capability(:sshfs_install)
          end
        end

        # Iterate through the folders and mount if needed
        folders.each do |id, opts|

          # If already mounted then there is nothing to do
          if machine.guest.capability(:sshfs_is_folder_mounted, opts)
            machine.ui.info(
              I18n.t("vagrant.sshfs.info.already_mounted",
                     folder: opts[:guestpath]))
            next
          end

          # Find out the host info and auth info for each folder
          get_host_info(machine, opts)
          get_auth_info(machine, opts)

          # Do the mount
          machine.ui.info(I18n.t("vagrant.sshfs.actions.mounting"))
          machine.guest.capability(:sshfs_mount_folder, opts)
        end
      end

      # This is called after destroying the machine during a
      # `vagrant destroy` and also prior to syncing folders during
      # a `vagrant up`.
      #
      # No return value.
      #
      # @param [Machine] machine
      # @param [Hash] opts
      def cleanup(machine, opts)
      end

      protected

      def get_host_info(machine, opts)
        # opts - the synced folder options hash
        # machine - 

        # If the synced folder entry doesn't have host information in it then
        # detect the vagrant host machine IP and use that
        if not opts.has_key?(:ssh_host) or not opts[:ssh_host]
            opts[:ssh_host] = detect_vagrant_host_ip(machine)
        end

        # If the synced folder doesn't have host port information in it 
        # default to port 22 for ssh
        # detect the vagrant host machine IP and use that
        if not opts.has_key?(:ssh_port) or not opts[:ssh_port]
            opts[:ssh_port] = '22'
        end
      end

      def detect_vagrant_host_ip(machine)
        # Only run detection if it hasn't been run before
        if not @@vagrant_host_machine_ip
          # Attempt to detect host machine IP by connecting over ssh
          # and then using the $SSH_CONNECTION env variable information to
          # determine the vagrant host IP address
          hostip = ''
          machine.communicate.execute('echo $SSH_CONNECTION') do |type, data|
            if type == :stdout
              hostip = data.split()[0]
            end
          end
          # TODO do some error checking here to make sure hostip was detected
          machine.ui.info(I18n.t("vagrant.sshfs.info.detected_host_ip", ip: hostip))
          @@vagrant_host_machine_ip = hostip
        end
        # Return the detected host IP
        @@vagrant_host_machine_ip
      end

      # Function to gather authentication information (username/password)
      # for doing a normal sshfs mount
      def get_auth_info(machine, opts)
        prompt_for_password = false
        ssh_info = machine.ssh_info

        # Detect the username of the current user
        username = `whoami`.strip

        # If no username provided then default to the current
        # user that is executing vagrant
          if not opts.has_key?(:ssh_username) or not opts[:ssh_username]
            opts[:ssh_username] = username
          end

        # Check to see if we need to prompt the user for a password.
        # We will prompt if:
        #  - User asked us to via prompt_for_password option
        #  - User did not provide a password in options and is not fwding ssh agent
        #
        if opts.has_key?(:prompt_for_password) and opts[:prompt_for_password]
            prompt_for_password = opts[:prompt_for_password]
        end
          if not opts.has_key?(:ssh_password) or not opts[:ssh_password]
            if not ssh_info.has_key?(:forward_agent) or not ssh_info[:forward_agent]
            prompt_for_password = true
            end 
          end

        # Now do the prompt
        if prompt_for_password
          opts[:ssh_password] = machine.ui.ask(
              I18n.t("vagrant.sshfs.ask.prompt_for_password", username: opts[:ssh_username]),
              echo: false)
        end
      end

      # Function to find the path to an executable with name "name"
      def find_executable(name)
        error_class = VagrantPlugins::SyncedFolderSSHFS::Errors::SSHFSExeNotAvailable

        # Save off PATH env var before we modify it
        oldpath = ENV['PATH']

        # Try to include paths where sftp-server may live so
        # That we have a good chance of finding it
        if Vagrant::Util::Platform.windows? and
             Vagrant::Util::Platform.cygwin?
          cygwin_root = Vagrant::Util::Platform.cygwin_windows_path('/')
          ENV['PATH'] += ';' + cygwin_root + '\usr\sbin'
        else
          ENV['PATH'] += ':/usr/libexec/openssh' # Linux (Red Hat Family)
          ENV['PATH'] += ':/usr/lib/openssh'     # Linux (Debian Family)
          ENV['PATH'] += ':/usr/libexec/'        # Mac OS X
        end

        # Try to find the executable
        exepath = Vagrant::Util::Which.which(name)
        raise error_class, executable: name if !exepath

        # Restore the PATH variable and return
        ENV['PATH'] = oldpath
        return exepath
      end
    end
  end
end
