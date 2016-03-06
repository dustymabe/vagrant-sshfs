require "vagrant"

module VagrantPlugins
  module SyncedFolderSSHFS
    # This plugin implements SSHFS synced folders.
    class Plugin < Vagrant.plugin("2")
      name "SSHFS synced folders"
      description <<-EOF
      The SSHFS synced folders plugin enables you to use SSHFS as a synced folder
      implementation.
      EOF

      synced_folder("sshfs", 5) do
        require_relative "synced_folder"
        SyncedFolder
      end

      command("sshfs", primary: false) do
        require_relative "command"
        Command::SSHFS
      end

      guest_capability("linux", "sshfs_mount_folder") do
        require_relative "cap/linux/sshfs_mount"
        VagrantPlugins::GuestLinux::Cap::MountSSHFS
      end

      guest_capability("redhat", "sshfs_installed") do
        require_relative "cap/redhat/sshfs_client"
        VagrantPlugins::GuestRedHat::Cap::SSHFSClient
      end

      guest_capability("redhat", "sshfs_install") do
        require_relative "cap/redhat/sshfs_client"
        VagrantPlugins::GuestRedHat::Cap::SSHFSClient
      end

      guest_capability("fedora", "sshfs_installed") do
        require_relative "cap/fedora/sshfs_client"
        VagrantPlugins::GuestFedora::Cap::SSHFSClient
      end

      guest_capability("fedora", "sshfs_install") do
        require_relative "cap/fedora/sshfs_client"
        VagrantPlugins::GuestFedora::Cap::SSHFSClient
      end

      guest_capability("debian", "sshfs_installed") do
        require_relative "cap/debian/sshfs_client"
        VagrantPlugins::GuestDebian::Cap::SSHFSClient
      end

      guest_capability("debian", "sshfs_install") do
        require_relative "cap/debian/sshfs_client"
        VagrantPlugins::GuestDebian::Cap::SSHFSClient
      end

    end
  end
end
