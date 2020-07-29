require 'spec_helper'

# package tests
[
  'epel-release',
  'fuse-sshfs',
].each do |name|

  describe package(name) do
    it { should be_installed }
  end

end

describe file('/vagrant') do
  it { should be_mounted.with(:type => 'fuse.sshfs') }
  it { should be_mode 700 }
  it { should be_owned_by "vagrant" }
  it { should be_grouped_into "vagrant" }
end

