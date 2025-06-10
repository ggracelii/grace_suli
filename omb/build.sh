#!/bin/bash

set -e

# ROCm HIP configuration
export HIP_PATH=/soft/compilers/rocm/rocm-6.3.2
export PATH=$HIP_PATH/bin:$PATH
export LD_LIBRARY_PATH=$HIP_PATH/lib:$HIP_PATH/lib64:$LD_LIBRARY_PATH
export HIP_PLATFORM=amd

# RCCL configuration
RCCL_DIR=$HOME/rccl/build
RCCL_INC=$RCCL_DIR/include/rccl
RCCL_LIB=$RCCL_DIR/lib

# MPICH with RCCL support
export MPICH_DIR=$HOME/grace_mpich/build/install
export PATH=$MPICH_DIR/bin:$PATH
export LD_LIBRARY_PATH=$MPICH_DIR/lib:$LD_LIBRARY_PATH
export MPICC=$MPICH_DIR/bin/mpicc
export MPICXX=$MPICH_DIR/bin/mpicxx

# Compilation and link flags
CPPFLAGS="-DENABLE_CCLCOMM -DENABLE_RCCL"
CFLAGS="-I${RCCL_INC} -I${HIP_PATH}/include"
LDFLAGS="-L${RCCL_LIB} -L${HIP_PATH}/lib"
LIBS="-lrccl -lamdhip64"

# Optional: see verbose collective selection
export MPIR_CVAR_VERBOSE=coll

# Check location
if [ ! -f "./configure" ]; then
    echo "Error: run this script from the root of osu-micro-benchmarks"
    exit 1
fi

# Clean prior build
make clean || true
rm -rf install

echo "Configuring OSU Micro-Benchmarks with GPU and MPI support..."
./configure \
  CC="$MPICC" \
  CXX="$MPICXX" \
  CPPFLAGS="$CPPFLAGS" \
  CFLAGS="$CFLAGS" \
  LDFLAGS="$LDFLAGS" \
  LIBS="$LIBS" \
  --enable-gpu \
  --enable-mpi \
  --enable-rocm \
  --enable-mpi-collective \
  --with-rocm="$HIP_PATH" \
  --prefix="$(pwd)/install"

echo "Building..."
make -j$(nproc)

echo "Installing..."
make install

echo "OSU Micro-Benchmarks built and installed to: $(pwd)/install"