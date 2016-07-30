# This file gets execute outside the Vagrant (bundled) environment.
# For that reason we have to put the gems we need ourself onto the LOADPATH.
# The caller of this file will pass the Vagrant gem dir as first argument which
# we use as base to find the required gems
gem_path = ARGV[0]
is_windows = ARGV[4]
Dir.entries(gem_path).select { |f| f =~ /^ffi.*$/ || f =~ /^win32-process.*$/ }
    .each { |gem_dir| $:.unshift "#{File.join(ARGV[0], gem_dir)}/lib" }

require 'pathname'
if 'true'.eql? is_windows
  require 'win32-process'
end

module VagrantPlugins
  module GuestLinux
    module Cap
      class CreateProcesses
        def self.setup_communication_channels(sftp_server_cmd, ssh_cmd, data_dir, is_windows)
          # Create two named pipes for communication between sftp-server and
          # sshfs running in slave mode
          r1, w1 = IO.pipe # reader/writer from pipe1
          r2, w2 = IO.pipe # reader/writer from pipe2

          # Log STDERR to predictable files so that we can inspect them
          # later in case things go wrong. We'll use the machines data
          # directory (i.e. .vagrant/machines/default/virtualbox/) for this
          f1path = Pathname(data_dir).join('vagrant_sshfs_sftp_server_stderr.txt')
          f2path = Pathname(data_dir).join('vagrant_sshfs_ssh_stderr.txt')
          f1 = File.new(f1path, 'w+')
          f2 = File.new(f2path, 'w+')

          # The way this works is by hooking up the stdin+stdout of the
          # sftp-server process to the stdin+stdout of the sshfs process
          # running inside the guest in slave mode. An illustration is below:
          #
          #          stdout => w1      pipe1         r1 => stdin
          #         />------------->==============>----------->\
          #        /                                            \
          #        |                                            |
          #    sftp-server (on vm host)                      sshfs (inside guest)
          #        |                                            |
          #        \                                            /
          #         \<-------------<==============<-----------</
          #          stdin <= r2        pipe2         w2 <= stdout
          #
          # Wire up things appropriately and start up the processes
          if 'true'.eql? is_windows
            Process.create(:command_line => sftp_server_cmd,
                           :creation_flags => Process::DETACHED_PROCESS,
                           :process_inherit => false,
                           :thread_inherit => true,
                           :startup_info => {:stdin => w2, :stdout => r1, :stderr => f1})

            Process.create(:command_line => ssh_cmd,
                           :creation_flags => Process::DETACHED_PROCESS,
                           :process_inherit => false,
                           :thread_inherit => true,
                           :startup_info => {:stdin => w1, :stdout => r2, :stderr => f2})
          else
            p1 = spawn(sftp_server_cmd, :out => w2, :in => r1, :err => f1, :pgroup => true)
            p2 = spawn(ssh_cmd, :out => w1, :in => r2, :err => f2, :pgroup => true)
          end

          # Detach from the processes so they will keep running
          Process.detach(p1)
          Process.detach(p2)
        end
      end
    end
  end
end

if __FILE__ == $0
  VagrantPlugins::GuestLinux::Cap::CreateProcesses.setup_communication_channels(ARGV[1], ARGV[2], ARGV[3], ARGV[4])
end
