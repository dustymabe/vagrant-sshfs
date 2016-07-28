require "log4r"

require "vagrant/util/platform"
require "vagrant/util/which"

module VagrantPlugins
  module SyncedFolderSSHFS
    class SyncedFolder < Vagrant.plugin("2", :synced_folder)

      protected

      # Do a forward mount: mounting host folder into the guest
      def do_forward_mount(machine, opts)

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

        # If already mounted then there is nothing to do
        if machine.guest.capability(:sshfs_forward_is_folder_mounted, opts)
          machine.ui.info(
            I18n.t("vagrant.sshfs.info.already_mounted",
                   location: 'guest', folder: opts[:guestpath]))
          return
        end

        # If the synced folder entry has host information in it then
        # assume we are doing a normal sshfs mount to a host that isn't
        # the machine running vagrant. Rely on password/ssh keys.
        #
        # If not, then we are doing a slave mount and we need to
        # make sure we can find the sftp-server and ssh execuatable
        # files on the host.
        if opts.has_key?(:ssh_host) and opts[:ssh_host]
            # Check port information and find out auth info
            check_host_port(machine, opts)
            get_auth_info(machine, opts)
        else
            opts[:ssh_exe_path] = find_executable('ssh')
            opts[:sftp_server_exe_path] = find_executable('sftp-server')
        end
        # Do the mount
        machine.ui.info(I18n.t("vagrant.sshfs.actions.mounting"))
        machine.guest.capability(:sshfs_forward_mount_folder, opts)
      end

      def do_forward_unmount(machine, opts)

        # If not mounted then there is nothing to do
        if ! machine.guest.capability(:sshfs_forward_is_folder_mounted, opts)
          machine.ui.info(
            I18n.t("vagrant.sshfs.info.not_mounted",
                   location: 'guest', folder: opts[:guestpath]))
          return
        end

        # Do the Unmount
        machine.ui.info(I18n.t("vagrant.sshfs.actions.unmounting"))
        machine.guest.capability(:sshfs_forward_unmount_folder, opts)
      end

      # Check if port information was provided in the options. If not,
      # then default to port 22 for ssh
      def check_host_port(machine, opts)
        if not opts.has_key?(:ssh_port) or not opts[:ssh_port]
            opts[:ssh_port] = '22'
        end
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
    end
  end
end
