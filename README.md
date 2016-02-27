# vagrant-sshfs

This is a vagrant plugin that adds synced folder support for mounting
folders from the Vagrant host into the Vagrant guest via
[SSHFS](https://github.com/libfuse/sshfs). It does this by executing
the `SSHFS` client software within the guest, which creates and SSH
connection from the Vagrant guest back to the Vagrant host. 

The benefits of this approach:
- Works on any host platform and hypervisor type
    - Windows, Linux, Mac OS X
    - Virtualbox, Libvirt, Hyper-V, VMWare

The drawbacks with this approach:
- Performance is worse than an implementation like NFS
- There must be an SSH daemon running on the Vagrant host 
- The Vagrant guest must be able to SSH to the Vagrant host and authenticate.

Running an SSH daemon on the host is mainly only a problem on the
Windows platform. [Here](http://docs.oracle.com/cd/E24628_01/install.121/e22624/preinstall_req_cygwin_ssh.htm#EMBSC150) 
is a guide for intalling the cygwin SSH daemon on Windows.

In order to authenticate back to the host daemon you must either
provide your password or use SSH keys and agent forwarding.

## Getting Started

In order to use this synced folder implementation perform the
following steps:

### Install plugin

In order to install the plugin simply run the following command:

```
# vagrant plugin install vagrant-sshfs --plugin-source https://dustymabe.fedorapeople.org/gemrepo/
```

### Add SSHFS synced folder in Vagrantfile

Edit your Vagrantfile to specify a folder to mount from the host into
the guest:

```
config.vm.synced_folder "/path/on/host", "/path/on/guest", type: "sshfs"
```

For more options that you can add see the [OPTIONS] section.

### Recommended: Using Keys and Forwarding SSH Agent


If you want a completely non-interactive experience you can either
hard code your password in the Vagrantfile or you can use SSH keys.

If `key1` is a key that is authorized to log in to the Vagrant host
,meaning there is an entry for `key1` in the `~/.ssh/authorized_keys` 
file, then you should be able to do the following to have a
non-interactive experience with SSH keys and agent forwarding:

Modify the Vagrantfile to forward your SSH agent:

```
config.ssh.forward_agent = 'true'
```

Now set up your agent and add your key to the agent:

```
# eval $(ssh-agent)
# ssh-add /path/to/key1
```

And finally bring up your Vagrant guest:

```
# vagrant up
```

## Executing the `vagrant sshfs` command

The Vagrant SSHFS plugin also supports execution of the `vagrant sshfs`
command from the command line. Executing this command will
iterate through the Vagrant file and attempt to mount (via SSHFS) any
folders that aren't already mounted in the Vagrant guest that is
associated with the current directory.

```
vagrant sshfs
```

## Options

The SSHFS synced folder plugin supports a few options that can be
provided on the command line. They are described below:

- `ssh_host`
    - The host to connect to via SSH. If not provided this will be 
      detected as the Vagrant host that is running the Vagrant guest.
- `ssh_port`
    - The port to use when connecting. Defaults to port 22.
- `ssh_username` 
    - The username to use when connecting. If not provided it is
    detected as the current user who is interacting with Vagrant.
- `ssh_password` - NOT RECOMMENDED
    - The password to use when connecting. If not provided and the
      user is not using SSH keys, then the user will be prompted for
      the password. Please use SSH keys and don't use this option!
- `prompt_for_password`
    - The user can force Vagrant to interactively prompt the user for
      a password by setting this to 'true'. Alternatively the user can
      deny Vagrant from ever prompting for the password by setting
      this to 'false'.

## Contributing

TODO finish this section: 
For local development of this plugin run...



