
To bring up vagrant host:

vagrant up

To run tests:

vagrant ssh

and then:

cd /sharedfolder/code/github.com/dustymabe/vagrant-sshfs/
gem install bundler
bundle install --with plugins # see [1]
bundle exec rake featuretests

[1] when running with bundler 1.13.2 I had to comment out
    the vagrant-sshfs line in Gemfile because it errored out
    complaining about it being defined twice. Running with
    1.12.5 works fine.
