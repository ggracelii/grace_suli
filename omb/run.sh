#!/bin/bash

# Usage: ./run.sh <mpich|mpichccl|rccl|auto> <num_ranks> [n]
set -euo pipefail

if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
    echo "Usage: $0 <mpich|mpichccl|rccl|auto> <num_ranks> [n]"
    exit 1
fi

backend="$1"
num_ranks="$2"
multi_node="${3:-}"

# Exec paths
MPI_BIN=./install/libexec/osu-micro-benchmarks/mpi/collective/osu_allreduce
RCCL_BIN=./c/xccl/collective/osu_xccl_allreduce

# ROCm paths
HIP_PATH=/soft/compilers/rocm/rocm-6.3.2
export HIP_PLATFORM=amd
export PATH=$HIP_PATH/bin:$PATH
export LD_LIBRARY_PATH=$HIP_PATH/lib:$HIP_PATH/lib64:${LD_LIBRARY_PATH:-}

# MPICH paths
MPICH_DIR=$HOME/grace_mpich/build/install
export PATH=$MPICH_DIR/bin:$PATH
export LD_LIBRARY_PATH=$MPICH_DIR/lib:${LD_LIBRARY_PATH:-}

# RCCL/CCL lib path
export LD_LIBRARY_PATH=$HOME/rccl/build/lib:${LD_LIBRARY_PATH:-}

# Env variables for MPI + RCCL
export FI_PROVIDER=verbs
export MPIR_CVAR_VERBOSE=1
export MB_DEVICE_TYPE=rocm

# Select mpiexec command
if [ "$multi_node" = "n" ]; then
    mpiexec_cmd="mpiexec --hostfile ./hosts.txt -n $num_ranks"
    export HIP_VISIBLE_DEVICES=0
    echo "Running on multiple nodes with hostfile ./hosts.txt"
    $mpiexec_cmd bash -c 'echo Rank on $(hostname) starting...'
else
    mpiexec_cmd="mpiexec -n $num_ranks"
fi

case "$backend" in
    mpich)
        echo "Running default MPICH..."
        unset MPIR_CVAR_ALLREDUCE_INTRA_ALGORITHM
        unset MPIR_CVAR_ALLREDUCE_CCL
        export MPIR_CVAR_DEVICE_COLLECTIVES=all

        if [ ! -x "$MPI_BIN" ]; then
            echo "MPI binary not found at $MPI_BIN"
            exit 1
        fi


        $mpiexec_cmd $MPI_BIN -m 0:1048576 -i 10000
        ;;

    mpichccl)
        echo "Running MPICH + RCCL..."
        export MPIR_CVAR_ALLREDUCE_INTRA_ALGORITHM=ccl
        export MPIR_CVAR_DEVICE_COLLECTIVES=none
        export MPIR_CVAR_ALLREDUCE_CCL=rccl 

        if [ ! -x "$MPI_BIN" ]; then
            echo "MPI binary not found at $MPI_BIN"
            exit 1
        fi

        $mpiexec_cmd "$MPI_BIN" -m 0:1048576 -i 10000 --accelerator=rocm
        ;;

    rccl)
        echo "Running RCCL-only benchmark..."
        if [ ! -x "$RCCL_BIN" ]; then
            echo "RCCL binary not found at $RCCL_BIN"
            exit 1
        fi

        $mpiexec_cmd "$RCCL_BIN" -m 0:1048576 -i 10000 --accelerator=rocm
        ;;

    auto)
        echo "Running composite backend..."
        if [ ! -x "$MPI_BIN" ]; then
            echo "MPI binary not found at $MPI_BIN"
            exit 1
        fi

        export MPIR_CVAR_ALLREDUCE_INTRA_ALGORITHM=ccl
        export MPIR_CVAR_ALLREDUCE_CCL=auto
        export MPIR_CVAR_DEVICE_COLLECTIVES=none
        export MPIR_CVAR_COLL_SELECTION_TUNING_JSON_FILE="$MPICH_DIR/../../maint/tuning/coll/mpir/generic.json"
        export MPIR_CVAR_COLL_SELECTION_VERBOSE=2

        $mpiexec_cmd "$MPI_BIN" -m 0:1048576 -i 1
        ;;

    *)
        echo "Error: unknown backend '$backend'. Use one of: mpich, mpichccl, rccl, auto"
        exit 1
        ;;
esac