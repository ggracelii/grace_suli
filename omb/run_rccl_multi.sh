#!/bin/bash
set -euo pipefail

echo 'Running RCCL benchmark on multiple nodes...'
BIN="./c/xccl/collective/osu_xccl_allreduce"
N=2
PPN=4
NUM_PROCS=$(($N * $PPN))
mpiexec \
  --hostfile hosts.txt \
  -n $NUM_PROCS \
  -ppn $PPN \
  -genv FI_PROVIDER verbs \
  -genv MPIR_CVAR_VERBOSE 1 \
  -genv LD_LIBRARY_PATH $HOME/rccl/build/lib:/soft/compilers/rocm/rocm-6.3.2/lib:/soft/compilers/rocm/rocm-6.3.2/lib64:$HOME/grace_mpich/build/install/lib:$LD_LIBRARY_PATH \
  "$BIN" -m 0:1048576 -i 10000
