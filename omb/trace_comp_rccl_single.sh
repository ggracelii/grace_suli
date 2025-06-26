#!/bin/bash
set -euo pipefail

# Usage: ./trace_comp_rccl_single.sh

N=1
PPN=4
NUM_PROCS=$((N * PPN))
BIN="./install/libexec/osu-micro-benchmarks/mpi/collective/osu_allreduce"

run_composition () {
    local comp=$1
    local label

    case "$comp" in
        1) label="alpha" ;;
        2) label="beta" ;;
        3) label="gamma" ;;
        4) label="delta" ;;
        *) echo "Unsupported composition: $comp" >&2; exit 1 ;;
    esac

    echo "Running Composition $comp (${label})..."
    echo -e "\n\nRunning Composition $comp (${label})..." >> rccl_single_output.log

    stdbuf -o0 mpiexec -n $NUM_PROCS -ppn $PPN \
        -genv LD_LIBRARY_PATH=$HOME/rccl/build/lib:/soft/compilers/rocm/rocm-6.3.2/lib:/soft/compilers/rocm/rocm-6.3.2/lib64:$HOME/grace_mpich/build/install/lib:$LD_LIBRARY_PATH \
        -genv MPIR_CVAR_DEVICE_COLLECTIVES percoll \
        -genv MPIR_CVAR_ALLREDUCE_INTRA_ALGORITHM ccl \
        -genv MPIR_CVAR_ALLREDUCE_CCL rccl \
        -genv MPIR_CVAR_ALLREDUCE_DEVICE_COLLECTIVE 1 \
        -genv MPIR_CVAR_ALLREDUCE_COMPOSITION $comp \
        -genv UCX_TLS sm,self,rocm \
        -genv UCX_WARN_UNUSED_ENV_VARS n \
        "$BIN" -m 4:4 -i 1 -x 0 -d rocm >> rccl_single_output.log 2>&1
}

run_dc_none () {
    local label="dc-none"
    echo "Running Device Collectives None..."
    echo "Running Device Collectives None..." > rccl_single_output.log
    
    stdbuf -o0 mpiexec -n $NUM_PROCS -ppn $PPN \
        -genv LD_LIBRARY_PATH=$HOME/rccl/build/lib:/soft/compilers/rocm/rocm-6.3.2/lib:/soft/compilers/rocm/rocm-6.3.2/lib64:$HOME/grace_mpich/build/install/lib:$LD_LIBRARY_PATH \
        -genv MPIR_CVAR_DEVICE_COLLECTIVES none \
        -genv MPIR_CVAR_ALLREDUCE_INTRA_ALGORITHM ccl \
        -genv MPIR_CVAR_ALLREDUCE_CCL rccl \
        -genv UCX_TLS sm,self,rocm \
        -genv UCX_WARN_UNUSED_ENV_VARS n \
        "$BIN" -m :4 -i 1 -x 0 -d rocm >> rccl_single_output.log 2>&1
}

run_dc_none

for COMP in 1 2 3 4; do
    run_composition $COMP
done

sed -i '/^\([0-9]\|#\)/d' rccl_single_output.log
