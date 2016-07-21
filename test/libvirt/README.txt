
To bring up vagrant host:

vagrant up

To run tests:

vagrant ssh

and then:

cd /sharedfolder/code/github.com/dustymabe/vagrant-sshfs/
gem install bundler
bundle install
bundle exec rake featuretests
