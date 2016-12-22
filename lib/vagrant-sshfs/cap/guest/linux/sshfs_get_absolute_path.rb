module VagrantPlugins
  module GuestLinux
    module Cap
      class SSHFSGetAbsolutePath
        def self.sshfs_get_absolute_path(machine, path)
          abs_path = ""
          machine.communicate.execute("readlink -f #{path}", sudo: true) do |type, data|
            if type == :stdout
              abs_path = data
            end
          end

          if ! abs_path
            # If no real absolute path was detected then error out
            error_class = VagrantPlugins::SyncedFolderSSHFS::Errors::SSHFSGetAbsolutePathFailed
            raise error_class, path: path
          end

          # Chomp the string so that any trailing newlines are killed
          return abs_path.chomp
        end
      end
    end
  end
end
