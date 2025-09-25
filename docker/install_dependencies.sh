#!/bin/bash

#  Copyright (C) 2018-2024 LEIDOS.
#
#  Licensed under the Apache License, Version 2.0 (the "License"); you may not
#  use this file except in compliance with the License. You may obtain a copy of
#  the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#  WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#  License for the specific language governing permissions and limitations under
#  the License.

set -e

# Install software-proprties-common to be able to setup PPA repos
sudo apt-get update
sudo apt-get install -y software-properties-common

sudo add-apt-repository -y ppa:ubuntu-toolchain-r/test
sudo add-apt-repository -y ppa:deadsnakes/ppa
sudo apt-get update

export DEBIAN_FRONTEND="noninteractive"
export TZ="Etc/UTC"

# Download apt dependencies
apt-get install -y --allow-unauthenticated \
  gcc-11 g++-11 unzip tar pkg-config sqlite3 autoconf libtool curl make \
  libxml2 libsqlite3-dev libxml2-dev cmake libxerces-c-dev libfox-1.6-dev \
  libgdal-dev libproj-dev libxslt1-dev libgl2ps-dev automake openjdk-11-jdk \
  ant x11-xserver-utils dconf-editor dbus-x11 libglvnd0 libgl1 zlib1g-dev \
  libglx0 libegl1 libxext6 libx11-6 python3-dev build-essential lbzip2 \
  libprotobuf-dev protobuf-compiler patch rsync wget vim nano xterm git \
  libffi-dev libbz2-dev libreadline-dev tk-dev zlib1g-dev libncurses5-dev \
  libncursesw5-dev liblzma-dev xz-utils libgdbm-dev libnss3-dev uuid-dev perl
sudo rm -rf /var/lib/apt/lists/*

sudo apt-get clean
sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-11 20 --slave /usr/bin/g++ g++ /usr/bin/g++-11

# Build OpenSSL 1.1 (Python3.6 dependency)
OPENSSL_PREFIX="/opt/openssl-1.1"
if [ ! -d "${OPENSSL_PREFIX}" ]; then
  tmpdir="$(mktemp -d)"
  pushd "$tmpdir"
  curl -fsSL https://www.openssl.org/source/openssl-1.1.1w.tar.gz -o openssl-1.1.1w.tar.gz
  tar xzf openssl-1.1.1w.tar.gz
  cd openssl-1.1.1w
  ./config --prefix="${OPENSSL_PREFIX}" --openssldir="${OPENSSL_PREFIX}" no-shared
  make -j"$(nproc)"
  sudo make install_sw
  popd
  rm -rf "$tmpdir"
fi

# Install pyenv and Python 3.6.15 and 3.7.17
export PYENV_ROOT="/opt/pyenv"
if [ ! -d "${PYENV_ROOT}" ]; then
  sudo git clone https://github.com/pyenv/pyenv.git "${PYENV_ROOT}"
fi

# Add pyenv to path
export PATH="${PYENV_ROOT}/bin:${PYENV_ROOT}/shims:${PATH}"

# Set flags for custom OpenSSL install for python3.6 build
export CPPFLAGS="-I${OPENSSL_PREFIX}/include"
export LDFLAGS="-L${OPENSSL_PREFIX}/lib"
export PKG_CONFIG_PATH="${OPENSSL_PREFIX}/lib/pkgconfig"

# Python Versions
PY36="3.6.15"
PY37="3.7.17"

# Install both Python versions
if [ ! -x "${PYENV_ROOT}/versions/${PY36}/bin/python3.6" ]; then
  "${PYENV_ROOT}/bin/pyenv" install "${PY36}"
fi
if [ ! -x "${PYENV_ROOT}/versions/${PY37}/bin/python3.7" ]; then
  "${PYENV_ROOT}/bin/pyenv" install "${PY37}"
fi

# Create symlinks for python3.6 and python3.7
sudo ln -sf "${PYENV_ROOT}/versions/${PY36}/bin/python3.6" /usr/local/bin/python3.6
sudo ln -sf "${PYENV_ROOT}/versions/${PY37}/bin/python3.7" /usr/local/bin/python3.7
sudo ln -sf "${PYENV_ROOT}/versions/${PY37}/bin/pip3.7"      /usr/local/bin/pip3.7
hash -r

# Install pip for python3.6 and python3.7
python3.6 -m ensurepip
python3.6 -m pip install --no-cache-dir "pip<22" "setuptools<60" "wheel<0.38"
# Create symlink for pip3.6
sudo ln -sf "/opt/pyenv/versions/${PY36}/bin/pip3.6" /usr/local/bin/pip3.6

python3.7 -m ensurepip
python3.7 -m pip install --no-cache-dir -U pip
# Create symlink for pip3.7
sudo ln -sf "/opt/pyenv/versions/${PY37}/bin/pip3.7" /usr/local/bin/pip3.7

# Install SUMO-1.15.0
cd /home/carma/src/
wget -q "https://github.com/eclipse/sumo/archive/refs/tags/v1_15_0.tar.gz"
sudo mkdir -p /opt/sumo
sudo chown -R carma:carma /opt/sumo
tar xvf v1_15_0.tar.gz -C /opt/sumo
cd /opt/sumo/sumo-1_15_0
mkdir -p build/cmake-build && cd build/cmake-build
cmake ../..
make -j$(nproc)
sudo make install

# Install python3.7 lxml
python3.7 -m pip install "lxml==4.5.0"

# Install CARLA
CARLA_TAR="Carla-0.10.0-Linux-Shipping.tar.gz"
cd /home/carma/src/
if [[ ! -f "$CARLA_TAR" ]]; then
    echo "!!! $CARLA_TAR not present in the installation directory, downloading automatically instead. This could take a long time, consider downloading the file manually and placing it in the installation directory. !!!"
    curl -fL "https://tiny.carla.org/carla-0-10-0-linux-tar" -o "$CARLA_TAR"
fi

sudo mkdir -p /opt/carla
sudo chown -R carma:carma /opt/carla
tar xzvf "$CARLA_TAR" -C /opt/carla
# Adding configuration file to fix error output from CARLA (https://github.com/carla-simulator/carla/issues/2820)
# echo $'pcm.!default {\n  type plug\n  slave.pcm \"null\"\n}' | sudo tee /etc/asound.conf

# Installation of maven
wget -q "https://archive.apache.org/dist/maven/maven-3/3.8.3/binaries/apache-maven-3.8.3-bin.tar.gz"
tar xzvf apache-maven-3.8.3-bin.tar.gz -C /opt/
sudo chown -R carma:carma /opt/apache-maven-3.8.3/
rm apache-maven-3.8.3-bin.tar.gz

echo "Install Dependencies Complete!!!"
