# XXX Note this is not working right now as nested virt. I keep
# getting kernel tracebacks on Fedora 24.

To bring up vagrant host:

vagrant up

To run tests:

vagrant ssh

and then:

cd /sharedfolder/code/github.com/dustymabe/vagrant-sshfs/
gem install bundler
bundle install
bundle exec rake featuretests
