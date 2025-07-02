#!/bin/bash
set -euo pipefail

# Usage: ./trace_comp_single.sh

> comp_single.log

N=1
PPN=4
NUM_PROCS=$((N * PPN))
BIN="./install/libexec/osu-micro-benchmarks/mpi/collective/osu_allreduce"

# RCCL - composition none
echo "Running rccl composition none (rccl-dc-none)..."
echo -e "\n\nRunning rccl composition none (rccl-dc-none)..." >> comp_single.log
mpiexec -n $NUM_PROCS -ppn $PPN \
    -genv LD_LIBRARY_PATH "$HOME/rccl/build/lib:/soft/compilers/rocm/rocm-6.3.2/lib:/soft/compilers/rocm/rocm-6.3.2/lib64:$HOME/grace_mpich/build/install/lib:$LD_LIBRARY_PATH" \
    -genv MPIR_CVAR_COLLECTIVE_FALLBACK error \
    -genv MPIR_CVAR_DEVICE_COLLECTIVES none \
    -genv MPIR_CVAR_ALLREDUCE_INTRA_ALGORITHM ccl \
    -genv MPIR_CVAR_ALLREDUCE_CCL rccl \
    -genv MPIR_CVAR_CH4_GPU_COLL_SWAP_BUFFER_SZ 32768 \
    -genv UCX_TLS=sm,self,rocm \
    "$BIN" -m 4:4 -i 1 -x 0 -u 0 -d rocm >> comp_single.log 2>&1


# RCCL - composition 2 (beta)
echo "Running rccl composition 2 (rccl-beta)..."
echo -e "\n\nRunning rccl composition 2 (rccl-beta)..." >> comp_single.log
mpiexec -n $NUM_PROCS -ppn $PPN \
    -genv LD_LIBRARY_PATH "$HOME/rccl/build/lib:/soft/compilers/rocm/rocm-6.3.2/lib:/soft/compilers/rocm/rocm-6.3.2/lib64:$HOME/grace_mpich/build/install/lib:$LD_LIBRARY_PATH" \
    -genv MPIR_CVAR_COLLECTIVE_FALLBACK error \
    -genv MPIR_CVAR_DEVICE_COLLECTIVES percoll \
    -genv MPIR_CVAR_ALLREDUCE_DEVICE_COLLECTIVE 1 \
    -genv MPIR_CVAR_ALLREDUCE_INTRA_ALGORITHM ccl \
    -genv MPIR_CVAR_ALLREDUCE_CCL rccl \
    -genv MPIR_CVAR_ALLREDUCE_COMPOSITION 2 \
    -genv MPIR_CVAR_CH4_GPU_COLL_SWAP_BUFFER_SZ 32768 \
    -genv UCX_TLS=sm,self,rocm \
    "$BIN" -m 4:4 -i 1 -x 0 -u 0 -d rocm >> comp_single.log 2>&1

# RCCL - composition 3 (gamma)
echo "Running rccl composition 3 (rccl-gamma)..."
echo -e "\n\nRunning rccl composition 3 (rccl-gamma)..." >> comp_single.log
mpiexec -n $NUM_PROCS -ppn $PPN \
    -genv LD_LIBRARY_PATH "$HOME/rccl/build/lib:/soft/compilers/rocm/rocm-6.3.2/lib:/soft/compilers/rocm/rocm-6.3.2/lib64:$HOME/grace_mpich/build/install/lib:$LD_LIBRARY_PATH" \
    -genv MPIR_CVAR_COLLECTIVE_FALLBACK error \
    -genv MPIR_CVAR_DEVICE_COLLECTIVES percoll \
    -genv MPIR_CVAR_ALLREDUCE_DEVICE_COLLECTIVE 1 \
    -genv MPIR_CVAR_ALLREDUCE_INTRA_ALGORITHM ccl \
    -genv MPIR_CVAR_ALLREDUCE_CCL rccl \
    -genv MPIR_CVAR_ALLREDUCE_COMPOSITION 3 \
    -genv MPIR_CVAR_CH4_GPU_COLL_SWAP_BUFFER_SZ 32768 \
    -genv UCX_TLS=sm,self,rocm \
    "$BIN" -m 4:4 -i 1 -x 0 -u 0 -d rocm >> comp_single.log 2>&1

# MPI - composition none
echo "Running mpi composition none (mpi-dc-none)..."
echo -e "\n\nRunning mpi composition none (mpi-dc-none)..." >> comp_single.log
mpiexec -n $NUM_PROCS -ppn $PPN \
    -genv LD_LIBRARY_PATH "$HOME/grace_mpich/build/install/lib:$LD_LIBRARY_PATH" \
    -genv MPIR_CVAR_COLLECTIVE_FALLBACK error \
    -genv MPIR_CVAR_DEVICE_COLLECTIVES none \
    -genv MPIR_CVAR_CH4_GPU_COLL_SWAP_BUFFER_SZ 32768 \
    "$BIN" -m 4:4 -i 1 -x 0 -u 0 -d rocm >> comp_single.log 2>&1

# MPI - composition 2 (beta)
echo "Running mpi composition 2 (mpi-beta)..."
echo -e "\n\nRunning mpi composition 2 (mpi-beta)..." >> comp_single.log
mpiexec -n $NUM_PROCS -ppn $PPN \
    -genv LD_LIBRARY_PATH "$HOME/grace_mpich/build/install/lib:$LD_LIBRARY_PATH" \
    -genv MPIR_CVAR_COLLECTIVE_FALLBACK error \
    -genv MPIR_CVAR_DEVICE_COLLECTIVES percoll \
    -genv MPIR_CVAR_ALLREDUCE_DEVICE_COLLECTIVE 1 \
    -genv MPIR_CVAR_ALLREDUCE_COMPOSITION 2 \
    -genv MPIR_CVAR_CH4_GPU_COLL_SWAP_BUFFER_SZ 32768 \
    "$BIN" -m 4:4 -i 1 -x 0 -u 0 -d rocm >> comp_single.log 2>&1

# MPI - composition 3 (gamma)
echo "Running mpi composition 3 (mpi-gamma)..."
echo -e "\n\nRunning mpi composition 2 (mpi-beta)..." >> comp_single.log
mpiexec -n $NUM_PROCS -ppn $PPN \
    -genv LD_LIBRARY_PATH "$HOME/grace_mpich/build/install/lib:$LD_LIBRARY_PATH" \
    -genv MPIR_CVAR_COLLECTIVE_FALLBACK error \
    -genv MPIR_CVAR_DEVICE_COLLECTIVES percoll \
    -genv MPIR_CVAR_ALLREDUCE_DEVICE_COLLECTIVE 1 \
    -genv MPIR_CVAR_ALLREDUCE_COMPOSITION 3 \
    -genv MPIR_CVAR_CH4_GPU_COLL_SWAP_BUFFER_SZ 32768 \
    "$BIN" -m 4:4 -i 1 -x 0 -u 0 -d rocm >> comp_single.log 2>&1

# CH4 JSON tuning-based composition
echo "Running ch4 tuning composition (ch4-tuning) for small msg..."
echo -e "\n\nRunning ch4 tuning composition (ch4-tuning) for small msg..." >> comp_single.log
mpiexec -n "$NUM_PROCS" -ppn "$PPN" \
    -genv LD_LIBRARY_PATH "$HOME/rccl/build/lib:/soft/compilers/rocm/rocm-6.3.2/lib:/soft/compilers/rocm/rocm-6.3.2/lib64:$HOME/grace_mpich/build/install/lib:$LD_LIBRARY_PATH" \
    -genv MPIR_CVAR_COLLECTIVE_FALLBACK error \
    -genv MPIR_CVAR_DEVICE_COLLECTIVES percoll \
    -genv MPIR_CVAR_ALLREDUCE_DEVICE_COLLECTIVE 1 \
    -genv MPIR_CVAR_ALLREDUCE_INTRA_ALGORITHM ccl \
    -genv MPIR_CVAR_ALLREDUCE_CCL auto \
    -genv MPIR_CVAR_ALLREDUCE_COMPOSITION 0 \
    -genv MPIR_CVAR_CH4_GPU_COLL_SWAP_BUFFER_SZ 32768 \
    -genv MPIR_CVAR_CH4_COLL_SELECTION_TUNING_JSON_FILE ch4_tuning.json \
    -genv UCX_TLS sm,self,rocm \
    "$BIN" -m 4:4 -i 1 -x 0 -u 0 -d rocm >> comp_single.log 2>&1
echo "Running ch4 tuning composition (ch4-tuning) for large msg..."
echo -e "\n\nRunning ch4 tuning composition (ch4-tuning) for large msg..." >> comp_single.log
mpiexec -n "$NUM_PROCS" -ppn "$PPN" \
    -genv LD_LIBRARY_PATH "$HOME/rccl/build/lib:/soft/compilers/rocm/rocm-6.3.2/lib:/soft/compilers/rocm/rocm-6.3.2/lib64:$HOME/grace_mpich/build/install/lib:$LD_LIBRARY_PATH" \
    -genv MPIR_CVAR_COLLECTIVE_FALLBACK error \
    -genv MPIR_CVAR_DEVICE_COLLECTIVES percoll \
    -genv MPIR_CVAR_ALLREDUCE_DEVICE_COLLECTIVE 1 \
    -genv MPIR_CVAR_ALLREDUCE_INTRA_ALGORITHM ccl \
    -genv MPIR_CVAR_ALLREDUCE_CCL auto \
    -genv MPIR_CVAR_ALLREDUCE_COMPOSITION 0 \
    -genv MPIR_CVAR_CH4_GPU_COLL_SWAP_BUFFER_SZ 32768 \
    -genv MPIR_CVAR_CH4_COLL_SELECTION_TUNING_JSON_FILE ch4_tuning.json \
    -genv UCX_TLS sm,self,rocm \
    "$BIN" -m  65536:65536 -i 1 -x 0 -u 0 -d rocm >> comp_single.log 2>&1

sed -i '/^\([0-9]\|#\)/d' comp_single.log
echo "All runs complete."
