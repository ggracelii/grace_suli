#!/bin/bash
set -euo pipefail

echo 'Running MPICH benchmark on multiple nodes...'
BIN="./install/libexec/osu-micro-benchmarks/mpi/collective/osu_allreduce"
N=2
PPN=4
NUM_PROCS=$(($N * $PPN))
mpiexec \
  --hostfile hosts.txt \
  -n $NUM_PROCS -ppn $PPN \
  -genv LD_LIBRARY_PATH $HOME/rccl/build/lib:/soft/compilers/rocm/rocm-6.3.2/lib:/soft/compilers/rocm/rocm-6.3.2/lib64:$HOME/grace_mpich/build/install/lib:$LD_LIBRARY_PATH \
  -genv MPIR_CVAR_DEVICE_COLLECTIVES all \
  "$BIN" -m 0:1048576 -i 10000 -d rocm
