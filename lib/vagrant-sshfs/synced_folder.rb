require "log4r"

require "vagrant/util/platform"
require "vagrant/util/which"

require_relative "synced_folder/sshfs_forward_mount"
require_relative "synced_folder/sshfs_reverse_mount"

module VagrantPlugins
  module SyncedFolderSSHFS
    class SyncedFolder < Vagrant.plugin("2", :synced_folder)

      def initialize(*args)
        super

        @logger = Log4r::Logger.new("vagrant::synced_folders::sshfs")
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

        # Iterate through the folders and mount if needed
        folders.each do |id, opts|

          if opts.has_key?(:reverse) and opts[:reverse]
            do_reverse_mount(machine, opts)
          else
            do_forward_mount(machine, opts)
          end
        end
      end

      # This is called to remove the synced folders from a running
      # machine.
      #
      # This is not guaranteed to be called, but this should be implemented
      # by every synced folder implementation.
      #
      # @param [Machine] machine The machine to modify.
      # @param [Hash] folders The folders to remove. This will not contain
      #   any folders that should remain.
      # @param [Hash] opts Any options for the synced folders.
      def disable(machine, folders, opts)

        # Iterate through the folders and mount if needed
        folders.each do |id, opts|
          if opts.has_key?(:reverse) and opts[:reverse]
            do_reverse_unmount(machine, opts)
          else
            do_forward_unmount(machine, opts)
          end
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

      # Function to find the path to an executable with name "name"
      def find_executable(name)
        error_class = VagrantPlugins::SyncedFolderSSHFS::Errors::SSHFSExeNotAvailable

        # Save off PATH env var before we modify it
        oldpath = ENV['PATH']

        # Try to include paths where sftp-server may live so
        # That we have a good chance of finding it
        if Vagrant::Util::Platform.windows?
          if Vagrant::Util::Platform.cygwin?
            # If in a cygwin terminal then we can programmatically
            # determine where sftp-server would be. ssh should already
            # be in path.
            cygwin_root = Vagrant::Util::Platform.cygwin_windows_path('/')
            ENV['PATH'] += ';' + cygwin_root + '\usr\sbin'
          else
            # If not in a cygwin terminal then we'll have to guess
            # where cygwin is installed and add the /bin/ (for ssh) and
            # /usr/sbin (for sftp-server) to the PATH.
            ENV['PATH'] += ';C:\cygwin\bin'
            ENV['PATH'] += ';C:\cygwin\usr\sbin'
            ENV['PATH'] += ';C:\cygwin64\bin'
            ENV['PATH'] += ';C:\cygwin64\usr\sbin'
          end
        else
          ENV['PATH'] += ':/usr/libexec/openssh' # Linux (Red Hat Family)
          ENV['PATH'] += ':/usr/lib/openssh'     # Linux (Debian Family)
          ENV['PATH'] += ':/usr/lib/ssh'         # Linux (Arch Linux Family)
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
