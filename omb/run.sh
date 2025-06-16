#!/bin/bash

# Usage: ./run.sh <mpich|mpichccl|rccl|auto> <1|2>

set -euo pipefail

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <mpich|mpichccl|rccl|auto> <1|2 (number of nodes)>"
    exit 1
fi

backend="$1"
node_mode="$2"

PPN=4
NODES=$node_mode
NUM_PROCS=$((NODES * PPN))

MPI_BIN=./install/libexec/osu-micro-benchmarks/mpi/collective/osu_allreduce
RCCL_BIN=./c/xccl/collective/osu_xccl_allreduce

HIP_PATH=/soft/compilers/rocm/rocm-6.3.2
export HIP_PLATFORM=amd
export PATH=$HIP_PATH/bin:$PATH
export LD_LIBRARY_PATH=$HIP_PATH/lib:$HIP_PATH/lib64:${LD_LIBRARY_PATH:-}

MPICH_DIR=$HOME/grace_mpich/build/install
export PATH=$MPICH_DIR/bin:$PATH
export LD_LIBRARY_PATH=$MPICH_DIR/lib:${LD_LIBRARY_PATH:-}

export LD_LIBRARY_PATH=$HOME/rccl/build/lib:${LD_LIBRARY_PATH:-}
export MB_DEVICE_TYPE=rocm

if [ "$node_mode" = "2" ]; then
    mpiexec_cmd="mpiexec --hostfile hosts.txt -n $NUM_PROCS -ppn $PPN"
else
    mpiexec_cmd="mpiexec -n $NUM_PROCS -ppn $PPN"
fi

case "$backend" in
    mpich)
        echo "Running MPICH benchmark..."
        unset MPIR_CVAR_ALLREDUCE_INTRA_ALGORITHM
        unset MPIR_CVAR_ALLREDUCE_CCL
        export MPIR_CVAR_DEVICE_COLLECTIVES=all
        exec $mpiexec_cmd "$MPI_BIN" -m 0:1048576 -i 10000 --accelerator=rocm
        ;;

    mpichccl)
        echo "Running MPICH + RCCL benchmark..."
        export MPIR_CVAR_ALLREDUCE_INTRA_ALGORITHM=ccl
        export MPIR_CVAR_ALLREDUCE_CCL=rccl
        export MPIR_CVAR_DEVICE_COLLECTIVES=none
        exec $mpiexec_cmd "$MPI_BIN" -m 0:1048576 -i 10000 --accelerator=rocm
        ;;

    rccl)
        echo "Running RCCL-only benchmark..."
        exec $mpiexec_cmd "$RCCL_BIN" -m 0:1048576 -i 10000
        ;;

    auto)
        echo "Running AUTO composite backend benchmark..."
        export MPIR_CVAR_DEVICE_COLLECTIVES=all
        export MPIR_CVAR_COLL_SELECTION_TUNING_JSON_FILE=./tuning.json
        export UCX_TLS=sm,self,rocm
        exec $mpiexec_cmd "$MPI_BIN" -m 0:1048576 -i 10000 --accelerator=rocm
        ;;

    *)
        echo "Error: Unknown backend '$backend'. Use one of: mpich, mpichccl, rccl, auto"
        exit 1
        ;;
esac