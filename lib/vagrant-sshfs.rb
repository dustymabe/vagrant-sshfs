begin
  require "vagrant"
rescue LoadError
  raise "The Vagrant sshfs plugin must be run within Vagrant"
end

require "vagrant-sshfs/errors"
require "vagrant-sshfs/version"
require "vagrant-sshfs/plugin"

module VagrantPlugins
  module SyncedFolderSSHFS
    # Returns the path to the source of this plugin
    def self.source_root
      @source_root ||= Pathname.new(File.expand_path('../../', __FILE__))
    end

    I18n.load_path << File.expand_path('locales/synced_folder_sshfs.yml', source_root)
    I18n.reload!
  end
end
