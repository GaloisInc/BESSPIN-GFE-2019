#!/usr/bin/env bash

# Get the path to the script folder of the git repository
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
source $BASE_DIR/setup_env.sh
err_msg $SETUP_ENV_ERR "Sourcing setup_env.sh failed"

proc_picker $1

# Fail loud and fast if commands exit nonzero or reference unset vars
set -eu

echo "Compiling ISA tests"
pushd $BASE_DIR/riscv-tests/isa/
make
popd

echo "Building Verilator simulator for  $proc_name"
pushd $BASE_DIR/verilator_simulators/
make simulator PROC=$proc_name

echo "Testing $proc_name"
pushd run/
make isa_tests PROC=$proc_name
