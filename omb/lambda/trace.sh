set -euo pipefail

N=2
PPN=4
NUM_PROCS=$((N * PPN))
BIN="../install/libexec/osu-micro-benchmarks/mpi/collective/osu_allreduce"

stdbuf -o0 mpiexec -n $NUM_PROCS -ppn $PPN -hostfile hosts.txt \
    -genv LD_LIBRARY_PATH="$HOME/rccl/build/lib:/soft/compilers/rocm/rocm-6.3.2/lib:/soft/compilers/rocm/rocm-6.3.2/lib64:$HOME/grace_mpich/build/install/lib:$LD_LIBRARY_PATH" \
    -genv MPIR_CVAR_DEVICE_COLLECTIVES=percoll \
    -genv MPIR_CVAR_ALLREDUCE_INTRA_ALGORITHM=ccl \
    -genv MPIR_CVAR_ALLREDUCE_CCL=rccl \
    -genv MPIR_CVAR_ALLREDUCE_DEVICE_COLLECTIVE=1 \
    -genv UCX_TLS=tcp,sm,self,rocm \
    -genv UCX_WARN_UNUSED_ENV_VARS=n \
    -genv MPIR_CVAR_COLLECTIVE_FALLBACK=error \
    -genv MPIR_CVAR_ALLREDUCE_COMPOSITION=2 \
    "$BIN" -m 16:16 -i 1 -x 0 -u 0 -d rocm > output.log 2>&1

echo "Benchmark completed. Output saved to output.log"