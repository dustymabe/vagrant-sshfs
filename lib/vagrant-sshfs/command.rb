module VagrantPlugins
  module SyncedFolderSSHFS
    module Command
      class SSHFS < Vagrant.plugin("2", :command)

        include Vagrant::Action::Builtin::MixinSyncedFolders

        def self.synopsis
          "mounts SSHFS shared folder mounts into the remote machine"
        end

        def execute
          opts = OptionParser.new do |o|
            o.banner = "Usage: vagrant sshfs"
            o.separator ""
            o.separator "Mount all sshfs synced folders into the vagrant box"
            o.separator ""
          end

          # Parse the options and return if we don't have any target.
          argv = parse_options(opts)
          return if !argv

          # Go through each machine and perform the rsync
          error = false
          with_target_vms(argv) do |machine|

            # Is the machine up yet?
            if !machine.communicate.ready?
              machine.ui.error(I18n.t("vagrant.sshfs.errors.communicator_not_ready"))
              error = true
              next
            end

            # Determine the sshfs synced folders for this machine
            folders = synced_folders(machine, cached: false)[:sshfs]
            next if !folders || folders.empty?

            # Sync them!
            SyncedFolder.new.enable(machine, folders, {})
          end
          return error ? 1 : 0
        end
      end
    end
  end
end
