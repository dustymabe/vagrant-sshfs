module VagrantPlugins
  module SyncedFolderSSHFS
    module Errors
      # A convenient superclass for all our errors.
      class SSHFSError < Vagrant::Errors::VagrantError
        error_namespace("vagrant.sshfs.errors")
      end

      class SSHFSNormalMountFailed < SSHFSError
        error_key(:normal_mount_failed)
      end

      class SSHFSSlaveMountFailed < SSHFSError
        error_key(:slave_mount_failed)
      end

      class SSHFSInstallFailed < SSHFSError
        error_key(:install_failed)
      end

      class SSHFSNotInstalledInGuest < SSHFSError
        error_key(:sshfs_not_in_guest)
      end

      class SSHFSExeNotAvailable < SSHFSError
        error_key(:exe_not_in_host)
      end
    end
  end
end
