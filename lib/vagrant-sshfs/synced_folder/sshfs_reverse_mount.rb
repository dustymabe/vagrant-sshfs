require "log4r"

require "vagrant/util/platform"
require "vagrant/util/which"

module VagrantPlugins
  module SyncedFolderSSHFS
    class SyncedFolder < Vagrant.plugin("2", :synced_folder)

      protected

      # Do a reverse mount: mounting guest folder onto the host
      def do_reverse_mount(machine, opts)

        # Check to see if sshfs software is in the host
        if machine.env.host.capability?(:sshfs_installed)
          if !machine.env.host.capability(:sshfs_installed)
            raise VagrantPlugins::SyncedFolderSSHFS::Errors::SSHFSNotInstalledInHost
          end
        end

        # If already mounted then there is nothing to do
        if machine.env.host.capability(:sshfs_reverse_is_folder_mounted, opts)
          machine.ui.info(
            I18n.t("vagrant.sshfs.info.already_mounted",
                   location: 'host', folder: opts[:hostpath]))
          return
        end

        # Do the mount
        machine.ui.info(I18n.t("vagrant.sshfs.actions.mounting"))
        machine.env.host.capability(:sshfs_reverse_mount_folder, machine, opts)
      end

      def do_reverse_unmount(machine, opts)

        # If not mounted then there is nothing to do
        if ! machine.env.host.capability(:sshfs_reverse_is_folder_mounted, opts)
          machine.ui.info(
            I18n.t("vagrant.sshfs.info.not_mounted",
                   location: 'host', folder: opts[:hostpath]))
          return
        end

        # Do the Unmount
        machine.ui.info(I18n.t("vagrant.sshfs.actions.unmounting"))
        machine.env.host.capability(:sshfs_reverse_unmount_folder, machine, opts)
      end
    end
  end
end
