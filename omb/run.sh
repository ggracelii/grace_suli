#!/bin/bash

# Usage: ./run.sh <mpi|rccl> <num_ranks>

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <mpi|rccl> <num_ranks>"
    exit 1
fi

backend="$1"
num_ranks="$2"

export HIP_PATH=/soft/compilers/rocm/rocm-6.3.2
export PATH=$HIP_PATH/bin:$PATH
export LD_LIBRARY_PATH=$HIP_PATH/lib:$HIP_PATH/lib64:$LD_LIBRARY_PATH
export HIP_PLATFORM=amd

export MPICH_DIR=$HOME/grace_mpich/build/install
export PATH=$MPICH_DIR/bin:$PATH
export LD_LIBRARY_PATH=$MPICH_DIR/lib:$LD_LIBRARY_PATH

MPI_BIN=./c/mpi/collective/blocking/osu_allreduce
RCCL_SRC=./c/xccl/collective/osu_xccl_allreduce.c
RCCL_BIN=./c/xccl/collective/osu_xccl_allreduce

if [ "$backend" = "mpi" ]; then
    if [ ! -x "$MPI_BIN" ]; then
        echo "Error: MPI binary '$MPI_BIN' not found"
        exit 1
    fi
    echo "Running OSU Allreduce with MPI..."
    FI_PROVIDER=verbs mpiexec -n "$num_ranks" "$MPI_BIN"

elif [ "$backend" = "rccl" ]; then
    echo "Compiling RCCL binary..."
    hipcc \
        -I./include -I./c/xccl/util -I./c/util \
        -I$MPICH_DIR/include -I$HIP_PATH/include -I$HIP_PATH/include/rccl \
        -D__HIP_PLATFORM_AMD__ -D_ENABLE_ROCM_ -D_ENABLE_RCCL_ \
        -DOMB_XCCL_INCLUDE='"osu_util_xccl_rccl.h"' -DOMB_XCCL_TYPE_STR='"RCCL "' -DOMB_XCCL_ACC_TYPE=OMP_ACCELERATOR_ROCM \
        ./c/xccl/collective/osu_xccl_allreduce.c ./c/xccl/util/osu_util_xccl_interface.c \
        ./c/xccl/util/rccl/osu_util_rccl_impl.c \
        ./c/util/osu_util.c ./c/util/osu_util_mpi.c \
        -o ./c/xccl/collective/osu_xccl_allreduce \
        -L$HIP_PATH/lib -L$MPICH_DIR/lib -lrccl -lamdhip64 -lhiprtc -lmpi \
        -Wno-macro-redefined -Wno-format -Wno-absolute-value -Wno-deprecated-non-prototype
    if [ $? -ne 0 ]; then
        echo "Compilation failed"
        exit 1
    else 
        echo "RCCL binary compiled successfully"
    fi
    echo "Running OSU Allreduce with RCCL backend..."
    FI_PROVIDER=verbs MB_DEVICE_TYPE=rocm mpiexec -n "$num_ranks" "$RCCL_BIN" -m 0:1048576 -i 10000

else
    echo "Error: backend must be 'mpi' or 'rccl'"
    exit 1
fi