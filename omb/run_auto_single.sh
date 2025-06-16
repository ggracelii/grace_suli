#!/bin/bash
set -euo pipefail

echo 'Running AUTO benchmark on single node...'
BIN="./install/libexec/osu-micro-benchmarks/mpi/collective/osu_allreduce"
N=1
PPN=4
NUM_PROCS=$(($N * $PPN))
mpiexec \
  -n $NUM_PROCS -ppn $PPN \
  -genv LD_LIBRARY_PATH $HOME/rccl/build/lib:/soft/compilers/rocm/rocm-6.3.2/lib:/soft/compilers/rocm/rocm-6.3.2/lib64:$HOME/grace_mpich/build/install/lib:$LD_LIBRARY_PATH \
  -genv MPIR_CVAR_DEVICE_COLLECTIVES all \
  -genv MPIR_CVAR_ALLREDUCE_CCL auto \
  -genv MPIR_CVAR_COLL_SELECTION_TUNING_JSON_FILE tuning.json \
  -genv UCX_TLS=sm,self,rocm \
  "$BIN" -m 0:1048576 -i 10000 -d rocm
