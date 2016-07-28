source "https://rubygems.org"

gemspec

group :development do
  # We depend on Vagrant for development, but we don't add it as a
  # gem dependency because we expect to be installed within the
  # Vagrant environment itself using `vagrant plugin`.
  gem "vagrant", :git => "https://github.com/mitchellh/vagrant.git", :ref => 'v1.8.4'
end

group :plugins do
  gem "vagrant-sshfs" , path: "."
  # Add vagrant-libvirt plugin here, otherwise you won't be able to
  # use libvirt as a provider when you execute `bundle exec vagrant up`
  gem "vagrant-libvirt" , '0.0.33'
end
