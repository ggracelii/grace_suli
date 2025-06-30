#!/bin/bash
set -euo pipefail

# Usage: ./trace_comp_mpi_single.sh

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
    echo -e "\n\nRunning Composition $comp (${label})..." >> mpi_single_output.log

    stdbuf -o0 mpiexec -n $NUM_PROCS -ppn $PPN \
        -genv LD_LIBRARY_PATH=$HOME/grace_mpich/build/install/lib:$LD_LIBRARY_PATH \
        -genv MPIR_CVAR_DEVICE_COLLECTIVES percoll \
        -genv MPIR_CVAR_ALLREDUCE_DEVICE_COLLECTIVE 1 \
        -genv MPIR_CVAR_ALLREDUCE_COMPOSITION $comp \
        "$BIN" -m 4:4 -i 1 -x 0 >> mpi_single_output.log 2>&1
}

run_dc_none () {
    local label="dc-none"
    echo "Running Device Collectives None..."
    echo "Running Device Collectives None..." > mpi_single_output.log

    stdbuf -o0 mpiexec -n $NUM_PROCS -ppn $PPN \
        -genv LD_LIBRARY_PATH=$HOME/grace_mpich/build/install/lib:$LD_LIBRARY_PATH \
        -genv MPIR_CVAR_DEVICE_COLLECTIVES none \
        "$BIN" -m 4:4 -i 1 -x 0 >> mpi_single_output.log 2>&1

}

run_dc_none

for COMP in 2 3 4; do
    run_composition $COMP
done

sed -i '/^\([0-9]\|#\)/d' mpi_single_output.log
