module VagrantPlugins
  module GuestArch
    module Cap
      class SSHFSClient
        def self.sshfs_install(machine)
          # Attempt to install sshfs but note that it may likely fail
          # because the package file list is out of date (see [1]). A
          # logical answer to this problem would be to update the
          # package list and then install the package, but since arch
          # doesn't support partial upgrades [2] that would require
          # updating all packages in the system first. Not ideal
          #
          # [1] https://wiki.archlinux.org/index.php/pacman#Packages_cannot_be_retrieved_on_installation
          # [2] https://wiki.archlinux.org/index.php/System_maintenance#Partial_upgrades_are_unsupported

          error_class = VagrantPlugins::SyncedFolderSSHFS::Errors::SSHFSInstallFailed
          error_key = :install_failed_arch
          cmd = "pacman --noconfirm -S sshfs"
          machine.communicate.sudo(
            cmd, error_class: error_class, error_key: error_key)
        end

        def self.sshfs_installed(machine)
          machine.communicate.test("pacman -Q sshfs")
        end
      end
    end
  end
end
