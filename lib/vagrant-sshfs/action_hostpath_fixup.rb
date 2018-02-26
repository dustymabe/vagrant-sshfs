require "log4r"

require "vagrant/action/builtin/mixin_synced_folders"

module VagrantPlugins
  module SyncedFolderSSHFS

    # Class that contains common function that are called by both
    # HostPathFix and HostPathUnfix classes.
    class HostPathFixCommon

      include Vagrant::Action::Builtin::MixinSyncedFolders

      def initialize()
        @logger = Log4r::Logger.new("vagrant::synced_folders::sshfs")
      end

      def fix(data)
        # If this is an arbitrary host mount we need to set the hostpath
        # to something that will pass the config checks that assume the
        # hostpath is coming from the vagrant host and not from an arbitrary
        # host. Save off the original hostpath and then set the hostpath to 
        # "." to pass the checks.
        if data[:ssh_host]
          data[:hostpath_orig] = data[:hostpath]
          data[:hostpath] = "."
        end
      end

      def unfix(data)
        # If this is a reverse mounted folder or an arbitrary host mount
        # then we'll set "hostpath_exact" so they don't try to create a
        # folder on the host in Vagrant::Action::Builtin::SyncedFolders.
        if data[:ssh_host]
          data[:hostpath_exact] = true
          data[:hostpath] = data[:hostpath_orig]
          data.delete(:hostpath_orig)
        end
      end

      # Loop through synced folder entries and either fix or unfix
      # based on the fix arg
      def loop_and_fix_unfix(env, fix)

        opts = {
          cached: !!env[:synced_folders_cached],
          config: env[:synced_folders_config],
        }

        @logger.debug("SyncedFolders loading from cache: #{opts[:cached]}")
        folders = synced_folders(env[:machine], **opts)

        folders.each do |impl_name, fs|
          next if impl_name != :sshfs
          @logger.debug("Synced Folder Implementation: #{impl_name}")

          fs.each do |id, data|

            # replace data with a copy since we may delete/add new data to the config
            data = data.dup

            if fix
                @logger.debug("fixup host path before:  - #{id}: #{data[:hostpath]} => #{data[:guestpath]}")
                fix(data)
                @logger.debug("fixup host path after:  - #{id}: #{data[:hostpath]} => #{data[:guestpath]}")
            else
                @logger.debug("unfixup host path before:  - #{id}: #{data[:hostpath]} => #{data[:guestpath]}")
                unfix(data)
                @logger.debug("fixup host path after:  - #{id}: #{data[:hostpath]} => #{data[:guestpath]}")
            end

            # Replace the entry in the config with the updated one
            env[:machine].config.vm.synced_folders.delete(id)
            env[:machine].config.vm.synced_folder(
                data[:hostpath],
                data[:guestpath],
                data)
          end
        end
      end
    end

    # Class that will massage the data for synced folders that are
    # arbitrary host mounts (contain ssh_host in the options) to make
    # it so that "host path checking" isn't performed on the vagrant
    # host machine
    class HostPathFix

      def initialize(app, env)
        @app    = app
        @logger = Log4r::Logger.new("vagrant::synced_folders::sshfs")
      end

      def call(env)
        classname = "VagrantPlugins::SyncedFolderSSHFS::HostPathFix"
        @logger.debug("Executing hook within #{classname}")

        # This part is for the IN action call
        HostPathFixCommon.new().loop_and_fix_unfix(env, fix=true)

        # Now continue until the OUT call
        @app.call(env)

      end
    end


    # Class that will undo the data manipulation that was done in
    # HostPathFix and also set hostpath_exact=true if necessary
    class HostPathUnfix

      def initialize(app, env)
        @app    = app
        @logger = Log4r::Logger.new("vagrant::synced_folders::sshfs")
      end

      def call(env)
        classname = "VagrantPlugins::SyncedFolderSSHFS::HostPathUnfix"
        @logger.debug("Executing hook within #{classname}")

        # This part is for the IN action call
        HostPathFixCommon.new().loop_and_fix_unfix(env, fix=false)

        # Now continue until the OUT call
        @app.call(env)

      end
    end
  end
end
