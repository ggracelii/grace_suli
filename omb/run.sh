#!/bin/bash

# Usage: ./run.sh <mpi|rccl> <num_ranks> [ccl]

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <mpi|rccl> <num_ranks> [ccl]"
    exit 1
fi

backend="$1"
num_ranks="$2"
ccl_flag="$3"

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

    if [ "$ccl_flag" = "ccl" ]; then
        echo "Running OSU Allreduce with MPI + CCL algorithm..."
        export MPIR_CVAR_ALLREDUCE_INTRA_ALGORITHM=ccl
    else
        echo "Running OSU Allreduce with default MPI algorithm..."
        unset MPIR_CVAR_ALLREDUCE_INTRA_ALGORITHM
        outfile="mpi_default_${num_ranks}.txt"
    fi

    FI_PROVIDER=verbs mpiexec -n "$num_ranks" "$MPI_BIN"

elif [ "$backend" = "rccl" ]; then
    if [ ! -x "$RCCL_BIN" ]; then
        echo "Error: RCCL binary '$RCCL_BIN' not found"
        exit 1
    fi

    echo "Running OSU Allreduce with RCCL backend..."
    FI_PROVIDER=verbs MB_DEVICE_TYPE=rocm mpiexec -n "$num_ranks" "$RCCL_BIN" -m 0:1048576 -i 10000

else
    echo "Error: backend must be 'mpi' or 'rccl'"
    exit 1
fi