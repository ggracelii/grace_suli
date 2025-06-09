#!/bin/bash

# Usage: ./run.sh <backend: rccl|mpi> <num_ranks> <message_size_in_bytes> [--int|--double|--float] [--corrupt]

export LD_LIBRARY_PATH=$HOME/grace_mpich/build/install/lib:$LD_LIBRARY_PATH

if [ "$#" -lt 3 ]; then
    echo "Usage: $0 <backend: rccl|mpi> <num_ranks> <message_size_in_bytes> [--int|--double|--float] [--corrupt]"
    exit 1
fi

backend="$1"
num_ranks="$2"
bytes="$3"
shift 3

if [[ "$backend" != "rccl" && "$backend" != "mpi" ]]; then
    echo "Error: backend must be 'rccl' or 'mpi'"
    exit 1
fi

if ! [[ "$num_ranks" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: num_ranks must be a positive integer"
    exit 1
fi

if ! [[ "$bytes" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: message_size_in_bytes must be a positive integer"
    exit 1
fi

exec="./allreduce_benchmark_$backend"

if [ ! -x "$exec" ]; then
    echo "Error: executable '$exec' not found or not executable"
    exit 1
fi

# Only set GPU-related CVARs if using RCCL
extra_envs=""
if [ "$backend" = "rccl" ]; then
    extra_envs="-genv MPIR_CVAR_ALLREDUCE_INTRA_ALGORITHM ccl -genv MPIR_CVAR_ALLREDUCE_CCL rccl"
fi

echo "Running: FI_PROVIDER=verbs ~/mpich/build/install/bin/mpiexec -n $num_ranks $extra_envs $exec $bytes $@"
FI_PROVIDER=verbs ~/mpich/build/install/bin/mpiexec -n "$num_ranks" $extra_envs "$exec" "$bytes" "$@"