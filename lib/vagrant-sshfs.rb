begin
  require "vagrant"
rescue LoadError
  raise "The Vagrant sshfs plugin must be run within Vagrant"
end

# Only load the gem on Windows since it replaces some methods in Ruby's 
# Process class. Also load it here before Process.uid is called the first 
# time by Vagrant. The Process.create() function actually gets used in
# lib/vagrant-sshfs/cap/guest/linux/sshfs_forward_mount.rb
if Vagrant::Util::Platform.windows?
  require 'win32/process'
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
