# -*- mode: ruby -*-
# vi: set ft=ruby :
Vagrant.configure(2) do |config|

    config.ssh.insert_key = 'true'
    config.vm.synced_folder "/var/b/shared", "/var/b/shared", type: "sshfs"

    config.vm.provider :libvirt do |domain|
      domain.memory = 4096
      domain.cpus = 4
      domain.nested = true
    end

    host = 'vagrant-sshfs-builder'
    box  = 'fedora/31-cloud-base'

    config.vm.define host do | tmp |
        tmp.vm.hostname = host
        tmp.vm.box = box
    end
    config.vm.provision "shell", inline: <<-SHELL
      dnf update -y 
      dnf install -y buildah
      cd /var/b/shared/code/github.com/dustymabe/vagrant-sshfs
      ./build.sh
    SHELL
end
