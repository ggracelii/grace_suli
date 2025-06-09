#!/bin/bash

set -e

export HIP_PATH=/soft/compilers/rocm/rocm-6.3.2
export PATH=$HIP_PATH/bin:$PATH
export LD_LIBRARY_PATH=$HIP_PATH/lib:$HIP_PATH/lib64:$LD_LIBRARY_PATH
export HIP_PLATFORM=amd

export MPICH_DIR=$HOME/grace_mpich/build/install
export PATH=$MPICH_DIR/bin:$PATH
export LD_LIBRARY_PATH=$MPICH_DIR/lib:$LD_LIBRARY_PATH
export MPICC=$MPICH_DIR/bin/mpicc
export MPICXX=$MPICH_DIR/bin/mpicxx

if [ ! -f "./configure" ]; then
    echo "Error: run this script from the root of osu-micro-benchmarks"
    exit 1
fi

export CFLAGS="-I$MPICH_DIR/include"
export CPPFLAGS="-I$HIP_PATH/include"
export LDFLAGS="-L$MPICH_DIR/lib -L$HIP_PATH/lib -L$HIP_PATH/lib64"
export LIBS="-lmpi"

make clean || true

echo "Configuring OSU Micro-Benchmarks with ROCm and MPI..."
./configure \
  CC="$MPICC" \
  CXX="$HIP_PATH/bin/hipcc" \
  CFLAGS="$CFLAGS" \
  LDFLAGS="$LDFLAGS" \
  LIBS="$LIBS" \
  --enable-rocm \
  --enable-mpi-collective \
  --with-rocm="$HIP_PATH" \
  --prefix="$HOME/osu-micro-benchmarks-install"

if [ $? -ne 0 ]; then
    echo "Configure failed"
    exit 1
fi

echo "Building OSU Micro-Benchmarks..."
make -j$(nproc)
make install

if [ $? -eq 0 ]; then
    echo "Build completed successfully"
else
    echo "Build failed"
    exit 1
fi