#!/bin/bash

# required wget, virtualbox, vagrant
#   wget       : install from cygwin installer
#   git        : install from cygwin installer
#   gcc-core   : install from cygwin installer
#   libcrypt-devel : install from cygwin installer
#   virtualbox : https://www.virtualbox.org/
#   vagrant    : http://www.vagrantup.com/

script_dir=$(cd $(dirname ${BASH_SOURCE:-$0}); pwd)

is_installed() {
    cmd="$1"
    if which $cmd > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

is_installed_by_apt() {
    pkg="$1"
    if apt-cyg list 2> /dev/null | egrep ^$pkg$ > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

validate_installed_or_die() {
    cmd="$1"
    if ! is_installed $cmd; then
        echo "$cmd install failed."
        exit 1;
    fi
}

validate_installed_by_apt_or_die() {
    pkg="$1"
    if ! is_installed_by_apt $pkg; then
        echo "$pkg install failed."
        exit 1;
    fi
}

install_by_apt() {
    pkg="$1"
    if ! is_installed_by_apt $pkg; then
        echo "$pkg not installed. installing..."
        apt-cyg install $pkg
        validate_installed_by_apt_or_die $pkg
        echo "installed."
    fi
}

install_by_gem() {
    pkg="$1"
    cmd="$2"
    if [ "$cmd" = "" ]; then
        cmd=$pkg
    fi
    if ! is_installed $cmd; then
        echo "$pkg not installed. installing..."
        gem install $pkg
        validate_installed_or_die $cmd
        echo "installed."
    fi
}

cygwin=false
case "$(uname)" in
    CYGWIN*) cygwin=true;;
esac
if ! $cygwin; then
    echo "not cygwin. only cygwin is supported."
    exit 1;
fi

# check dependency
if ! which wget > /dev/null 2>&1; then
    echo "wget not installed. requires wget, ca-certificates,gnupg."
    exit 1;
fi

# install apt-cyg
if ! is_installed apt-cyg; then
    echo "apt-cyg not installed. installing..."
    wget https://raw.githubusercontent.com/transcode-open/apt-cyg/master/apt-cyg
    chmod a+x apt-cyg
    mv apt-cyg /usr/bin/
    validate_installed_or_die apt-cyg
    echo "installed."
fi
#install make tools
install_by_apt make
install_by_apt patch
# install ruby
install_by_apt libyaml0_2
install_by_apt ruby
# update gem
echo "update gem..."
gem update --system
# patch when gem update failed
# see https://gist.github.com/kou1okada/9613061
if [ $? -ne 0 ]; then
    echo "update failed. patching..."
    cat $script_dir/monkeypatch.win32_registry.rb  >> /usr/lib/ruby/1.9.1/win32/registry.rb
    echo "patched. retrying ..."
    gem update --system
    if [ $? -ne 0 ]; then
        echo "failed updating gem."
        exit 1;
    fi
fi
echo "finish updating gem"

# install chef
install_by_gem chef chef-solo
# install knife-solo
if ! knife solo clean --help > /dev/null 2>&1; then
    echo "knife-solo not installed. installing..."
    gem install knife-solo
    echo "installed."
fi
# patch knife-solo
# see https://github.com/keeruline/knife-solo/commit/d57894b671fa25a791d8302e2ada7b6be2d7d72f
if grep @session /usr/lib/ruby/gems/1.9.1/gems/knife-solo-0.4.1/lib/knife-solo/ssh_connection.rb > /dev/null 2>&1; then
    echo "patching knife-solo ..."
    patch /usr/lib/ruby/gems/1.9.1/gems/knife-solo-0.4.1/lib/knife-solo/ssh_connection.rb < $script_dir/ssh_connection.patch
    echo "patched"
fi
