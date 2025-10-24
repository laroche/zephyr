#!/bin/bash
#
# TODO:
# - change k_thread_name_get to inline
# - check for -O2/-Os differences, what does -O3 result in?
#

VER=0.17.0

# Install all needed software:
if test "X$1" = Xinstall ; then
  sudo apt-get install --no-install-recommends git cmake ninja-build gperf \
    ccache dfu-util device-tree-compiler wget \
    python3-venv python3-dev python3-pip python3-setuptools python3-tk python3-wheel xz-utils file libpython3-dev \
    make gcc gcc-multilib g++-multilib libsdl2-dev libmagic1 libpcap-dev
  #sudo apt-get install gcc-arm-none-eabi
  python3 -m venv venv
  . venv/bin/activate
  #pip3 install cmake
  pip3 install west
  if ! test -f zephyr-sdk-${VER}_linux-x86_64.tar.xz ; then
    wget      https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v$VER/zephyr-sdk-${VER}_linux-x86_64.tar.xz
    wget -O - https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v$VER/sha256.sum | shasum --check --ignore-missing
  fi
  if ! test -d zephyr-sdk-${VER} ; then
    tar xJf zephyr-sdk-${VER}_linux-x86_64.tar.xz
  fi
  pushd zephyr-sdk-$VER
    ./setup.sh
  popd
  exit 0
fi

# First checkout of source:
if ! test -f venv/bin/activate ; then
  echo "venv/bin/activate not found, exiting."
  exit 1
fi
. venv/bin/activate
if ! test -d zephyrproject ; then
  west init zephyrproject
  pushd zephyrproject
    west update
    pip3 install -r zephyr/scripts/requirements.txt
    pushd zephyr
      git config pull.rebase false
      patch -s -p1 < ../../zephyr.patch
    popd
  popd
fi
#if ! test -d example-application ; then
#  git clone https://github.com/zephyrproject-rtos/example-application
#fi
# Extra software updates:
if test "X$1" = Xupdate ; then
  pushd zephyrproject
    #git pull -a --all
    west update
    #west zephyr-export
    pip3 install -r zephyr/scripts/requirements.txt -U
    pip3 list --outdated
    pushd zephyr
      git stash
      git pull -a --all
      git stash pop
    popd
  popd
  #pushd example-application
  #  git pull -a --all
  #popd
  exit 0
fi
if test "X$1" = Xpatch ; then
  pushd zephyrproject/zephyr
    git diff > ../../zephyr.patch2
  popd
  diff -u zephyr.patch zephyr.patch2
  mv zephyr.patch2 zephyr.patch
  exit 0
fi

# Build the software:
export ZEPHYR_TOOLCHAIN_VARIANT=zephyr
export ZEPHYR_SDK_INSTALL_DIR=$PWD/zephyr-sdk-$VER

# Static Code Analysis (SCA) via sparse/gcc:
#export ZEPHYR_SCA_VARIANT=sparse
#export ZEPHYR_SCA_VARIANT=gcc

# To enable debugging with gdb from extra console:
#ZDEBUG="-t debugserver_qemu"

if test "X$1" != X ; then
export BOARD="$1"
else
# 32bit arm:
#export BOARD=qemu_cortex_r5
#export BOARD=qemu_cortex_a9
#export BOARD=mps2/an385
# 64bit arm:
# https://github.com/zephyrproject-rtos/zephyr/pull/61200
#export BOARD=qemu_cortex_a53
export BOARD=qemu_cortex_a53/qemu_cortex_a53/smp
# x86:
#export BOARD=qemu_x86
#export BOARD=qemu_x86_64
# native Linux or Windows:
#export BOARD=native_posix
#export BOARD=fvp_baser_aemv8r
fi

pushd zephyrproject/zephyr
    . zephyr-env.sh
    #west build -p always $ZDEBUG samples/synchronization
    #west build -p always $ZDEBUG samples/basic/minimal
    #west build -p always samples/basic/minimal -- -DCONF_FILE="common.conf arm.conf no-mt.conf no-preempt.conf no-timers.conf"
    #west build -p always samples/basic/minimal -- -DCONF_FILE="arm.conf mt.conf"
    #west build -p always samples/hello_world
    #west build -p always samples/philosophers
    #west build -p always -T samples/subsys/portability/cmsis_rtos_v1/philosophers/sample.portability.cmsis_rtos_v1.philosopher.semaphores
    #west twister -s samples/subsys/portability/cmsis_rtos_v1/philosophers/sample.portability.cmsis_rtos_v1.philosopher.semaphores

    west build -p always $ZDEBUG samples/net/dhcpv4_client -- -DEXTRA_CONF_FILE=overlay-e1000.conf #-DZEPHYR_SCA_VARIANT=gcc #sparse
    #west build -p always $ZDEBUG samples/net/dhcpv4_client
    #west build -p always $ZDEBUG samples/net/sockets/echo_server
    #west build -p always $ZDEBUG samples/net/sockets/echo_server -- -DEXTRA_CONF_FILE=overlay-smsc911x.conf
    #west build -p always $ZDEBUG samples/net/sockets/echo_server -- -DEXTRA_CONF_FILE=overlay-e1000.conf
    #west build -p always -T tests/kernel/workq/work/kernel.work.api
    #west build -t rom_report -d build/reel_board/mt
    #west build -p always tests/integration/kernel/

    # Ubuntu/Debian toolchain to disassemble firmware build:
    #arm-none-eabi-objdump -d zephyrproject/zephyr/build/zephyr/zephyr.elf

    west build -t run
popd
