Tests
-----


Linked to github issue [GH-ISSUE#1](https://github.com/dustymabe/vagrant-sshfs/issues/1)


#### If you are testing the current release of this plugin via bundler

```
bundle exec vagrant up default
```

#### List the rake tasks available for testing

```
bundle exec rake -T
```

#### Example of how to run all the serverspec tests on the `default` vagrant VM.

```
bundle exec rake spec:_default
```

#### Run all the serverspec tests against all vagrant VMs.

```
bundle exec rake spec
```
