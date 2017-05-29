require_relative "../linux/sshfs_forward_mount"

module VagrantPlugins
  module GuestFreeBSD
    module Cap
      class MountSSHFS < VagrantPlugins::GuestLinux::Cap::MountSSHFS
        def self.list_mounts_command
          "mount -p"
        end
      end
    end
  end
end
