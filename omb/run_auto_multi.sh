#!/bin/bash
set -euo pipefail

echo 'Running AUTO benchmark on multi node(s)...'
BIN="./install/libexec/osu-micro-benchmarks/mpi/collective/osu_allreduce"
N=2
PPN=4
NUM_PROCS=$(($N * $PPN))
mpiexec \
  --hostfile hosts.txt \
  -n $NUM_PROCS -ppn $PPN \
  -genv LD_LIBRARY_PATH $HOME/rccl/build/lib:/soft/compilers/rocm/rocm-6.3.2/lib:/soft/compilers/rocm/rocm-6.3.2/lib64:$HOME/grace_mpich/build/install/lib:$LD_LIBRARY_PATH \
  -genv MPIR_CVAR_ALLREDUCE_CCL auto \
  -genv MPIR_CVAR_DEVICE_COLLECTIVES none \
  -genv MPIR_CVAR_COLL_SELECTION_TUNING_JSON_FILE tuning.json \
  -genv MPIR_CVAR_ACCELERATOR rocm \
  "$BIN" -m 0:1048576 -i 10000 --accelerator=rocm
