require_relative "../linux/sshfs_forward_mount"

module VagrantPlugins
  module GuestCygwin
    module Cap
      class MountSSHFS < VagrantPlugins::GuestLinux::Cap::MountSSHFS
        def self.sshfs_command
            # cygwin does not have sudo command
            "env sshfs"
        end

        def self.get_umount_command(expanded_guest_path)
          # sshfs-win mount is not seen as mount by cygwin,
          # so we cannot unmount it using umount,
          # we need to kill sshfs process ( which causes umount )

          cmd = 'sh -c "'
          # iterate over cmdlines of all cygwin processes
          cmd += 'for cmdline in /proc/*/cmdline ; do'
          # if command starts with sshfs
          cmd += ' if strings -n 1 \\"\\${cmdline}\\" | head -n 1 | grep -q \'^sshfs\\$\''
          # and contains #{expanded_guest_path}
          cmd += " && strings -n 1 \\\"\\${cmdline}\\\" | grep -q '^#{expanded_guest_path}\\$' ;"
          cmd += ' then'
          # get pid from proc path
          cmd += ' pid=\\"\\$( basename \\"\\$( dirname \\"\\${cmdline}\\" )\\" )\\" ;'
          cmd += ' printf \'Syncing cached writes ...\\\\n\' ;'
          # synchronize cashed writes to filesystems (just in case)
          cmd += ' sync ;'
          cmd += ' printf \'Killing sshfs process: %s ...\\\\n\' \\"\\${pid}\\" ;'
          # kill sshfs process
          cmd += ' kill \\"\\${pid}\\" ;'
          # break the loop
          cmd += ' break ;'
          cmd += ' fi'
          cmd += ' done'
          cmd += '"'

          return cmd
        end

        def self.create_mount_point(machine, guest_path)
          # for sshfs-win/cygwin to work, directory must NOT exist in place
          # of future mount (unlike for sshfs/linux)
        end

        def self.sshfs_forward_is_folder_mounted(machine, opts)
          guest_path = opts[:guestpath]
          # If path exists in cygwin it is considered mounted
          # ( see comments for create_mount_point higher )
          return machine.communicate.test("test -e #{guest_path}", sudo: true)
        end
      end
    end
  end
end
