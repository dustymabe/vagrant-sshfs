# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'vagrant-sshfs/version'

Gem::Specification.new do |spec|
  spec.name          = "vagrant-sshfs"
  spec.version       = VagrantPlugins::SyncedFolderSSHFS::VERSION
  spec.authors       = ["Dusty Mabe"]
  spec.email         = ["dusty@dustymabe.com"]
  spec.description   = """
    A Vagrant synced folder plugin that mounts folders via SSHFS. 
    This is the successor to Fabio Kreusch's implementation:
    https://github.com/fabiokr/vagrant-sshfs"""
  spec.summary       = spec.description
  spec.homepage      = "https://github.com/dustymabe/vagrant-sshfs"
  spec.license       = "GPL-2.0"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"
end
