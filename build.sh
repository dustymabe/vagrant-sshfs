#!/bin/bash -x
set -ex

ctr=$(buildah from registry.fedoraproject.org/fedora:28)

rpms=(
  make gcc ruby ruby-devel redhat-rpm-config # for building gems
  gcc-c++                                    # for building unf_ext
  libvirt-devel                              # for building ruby-libvirt gem
  zlib-devel                                 # for building nokogiri gem
  git                                        # for the git ls-files in gemspec file
  bsdtar                                     # used by vagrant to unpack box files
)

WORKINGDIR='/tmp/workingdir/'

# Set working directory
buildah config --workingdir $WORKINGDIR $ctr

# Get all updates and install needed rpms
buildah run $ctr -- dnf update -y
buildah run $ctr -- dnf install -y ${rpms[@]}

# Add source code
buildah add $ctr './' $WORKINGDIR

# Install bundler
#   [1] when running with bundler 1.13.2 I had to comment out
#       the vagrant-sshfs line in Gemfile because it errored out
#       complaining about it being defined twice. Running with
#       1.12.5 works fine.
#   [2] because of [1] need to add `--version 1.12.5`
buildah run $ctr -- gem install bundler --version 1.12.5

# Install all needed gems
buildah run $ctr -- bundle install --with plugins

# Install all needed gems
buildah run $ctr -- bundle exec rake build

# Copy built files outside of container
mount=$(buildah mount $ctr)
package=$(ls $mount/$WORKINGDIR/pkg/vagrant-sshfs-*gem)
echo "copying to ./$(basename $package)"
cp $package ./
buildah umount $ctr

echo "Built package is at ./$(basename $package)"
