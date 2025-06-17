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

MPI_BIN="./install/libexec/osu-micro-benchmarks/mpi/collective/osu_allreduce"
RCCL_BIN="./c/xccl/collective/osu_xccl_allreduce"

HIP_PATH=/soft/compilers/rocm/rocm-6.3.2
MPICH_DIR=$HOME/grace_mpich/build/install
RCCL_DIR=$HOME/rccl/build

export HIP_PLATFORM=amd
export MB_DEVICE_TYPE=rocm

export PATH=$HIP_PATH/bin:$MPICH_DIR/bin:$PATH
export LD_LIBRARY_PATH=$HIP_PATH/lib:$HIP_PATH/lib64:$MPICH_DIR/lib:$RCCL_DIR/lib:${LD_LIBRARY_PATH:-}

if [ "$node_mode" = "2" ]; then
    hosts="--hostfile hosts.txt"
else
    hosts=""
fi

case "$backend" in
    mpich)
        echo "Running MPICH benchmark..."
        mpiexec $hosts -n $NUM_PROCS -ppn $PPN \
            -genv LD_LIBRARY_PATH "$LD_LIBRARY_PATH" \
            -genv MPIR_CVAR_DEVICE_COLLECTIVES all \
            "$MPI_BIN" -m 0:1048576 -i 10000  -d rocm
        ;;

    mpichccl)
        echo "Running MPICH + RCCL benchmark..."
        mpiexec $hosts -n $NUM_PROCS -ppn $PPN \
            -genv LD_LIBRARY_PATH "$LD_LIBRARY_PATH" \
            -genv MPIR_CVAR_ALLREDUCE_INTRA_ALGORITHM ccl \
            -genv MPIR_CVAR_DEVICE_COLLECTIVES none \
            "$MPI_BIN" -m 0:1048576 -i 10000 -d rocm
        ;;

    rccl)
        echo "Running RCCL-only benchmark..."
        mpiexec $hosts -n $NUM_PROCS -ppn $PPN \
            -genv LD_LIBRARY_PATH "$LD_LIBRARY_PATH" \
            "$RCCL_BIN" -m 0:1048576 -i 10000
        ;;

    auto)
        echo "Running AUTO composite backend benchmark..."
        mpiexec $hosts -n $NUM_PROCS -ppn $PPN \
            -genv LD_LIBRARY_PATH "$LD_LIBRARY_PATH" \
            -genv MPIR_CVAR_DEVICE_COLLECTIVES none \
            -genv MPIR_CVAR_COLL_SELECTION_TUNING_JSON_FILE tuning.json \
            -genv UCX_TLS=sm,self,rocm \
            "$MPI_BIN" -m 0:1048576 -i 10000 -d rocm
        ;;

    auto_dcall)
        echo "Running AUTO backend with device collectives = all..."
        # mpiexec $hosts -n $NUM_PROCS -ppn $PPN \
        #     -genv LD_LIBRARY_PATH "$LD_LIBRARY_PATH" \
        #     -genv MPIR_CVAR_DEVICE_COLLECTIVES all \
        #     -genv MPIR_CVAR_ALLREDUCE_CCL auto \
        #     -genv MPIR_CVAR_COLL_SELECTION_TUNING_JSON_FILE tuning.json \
        #     -genv UCX_TLS=sm,self,rocm \
        #     "$MPI_BIN" -m 0:1048576 -i 10000 -d rocm
        mpiexec \
            --hostfile hosts.txt \
            -n $NUM_PROCS -ppn $PPN \
            -genv LD_LIBRARY_PATH $HOME/rccl/build/lib:/soft/compilers/rocm/rocm-6.3.2/lib:/soft/compilers/rocm/rocm-6.3.2/lib64:$HOME/grace_mpich/build/install/lib:$LD_LIBRARY_PATH \
            -genv MPIR_CVAR_ALLREDUCE_CCL auto \
            -genv MPIR_CVAR_DEVICE_COLLECTIVES all \
            -genv MPIR_CVAR_COLL_SELECTION_TUNING_JSON_FILE tuning.json \
            -genv UCX_TLS=tcp,self,sm \
            "$MPI_BIN" -m 0:1048576 -i 10000 -d rocm
        ;;

    auto_dcnone)
        echo "Running AUTO backend with device collectives = none..."
        # mpiexec $hosts -n $NUM_PROCS -ppn $PPN \
        #     -genv LD_LIBRARY_PATH "$LD_LIBRARY_PATH" \
        #     -genv MPIR_CVAR_DEVICE_COLLECTIVES none \
        #     -genv MPIR_CVAR_ALLREDUCE_CCL auto \
        #     -genv MPIR_CVAR_COLL_SELECTION_TUNING_JSON_FILE tuning.json \
        #     -genv UCX_TLS=sm,self,rocm \
        #     "$MPI_BIN" -m 0:1048576 -i 10000 -d rocm
        mpiexec \
            --hostfile hosts.txt \
            -n $NUM_PROCS -ppn $PPN \
            -genv LD_LIBRARY_PATH $HOME/rccl/build/lib:/soft/compilers/rocm/rocm-6.3.2/lib:/soft/compilers/rocm/rocm-6.3.2/lib64:$HOME/grace_mpich/build/install/lib:$LD_LIBRARY_PATH \
            -genv MPIR_CVAR_ALLREDUCE_CCL auto \
            -genv MPIR_CVAR_DEVICE_COLLECTIVES none \
            -genv MPIR_CVAR_COLL_SELECTION_TUNING_JSON_FILE tuning.json \
            -genv UCX_TLS=tcp,self,sm \
            "$MPI_BIN" -m 0:1048576 -i 10000 -d rocm
        ;;
    *)
        echo "Error: Unknown backend '$backend'. Use one of: mpich, mpichccl, rccl, auto"
        exit 1
        ;;
esac