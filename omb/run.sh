#!/bin/bash

# Usage: ./run.sh <mpich|mpichccl|ompiccl|rccl> <num_ranks>

set -e

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <mpich|mpichccl|ompiccl|rccl> <num_ranks>"
    exit 1
fi

backend="$1"
num_ranks="$2"

MPI_BIN=./c/mpi/collective/blocking/osu_allreduce
RCCL_BIN=./c/xccl/collective/osu_xccl_allreduce

export HIP_PATH=/soft/compilers/rocm/rocm-6.3.2
export HIP_PLATFORM=amd
export PATH=$HIP_PATH/bin:$PATH
export LD_LIBRARY_PATH=$HIP_PATH/lib:$HIP_PATH/lib64:$LD_LIBRARY_PATH
export FI_PROVIDER=verbs

case "$backend" in
    mpich)
        echo "[Running] MPICH (default MPI algorithm)..."
        export MPICH_DIR=$HOME/grace_mpich/build/install
        export PATH=$MPICH_DIR/bin:$PATH
        export LD_LIBRARY_PATH=$MPICH_DIR/lib:$LD_LIBRARY_PATH

        unset MPIR_CVAR_ALLREDUCE_INTRA_ALGORITHM
        export MPIR_CVAR_DEVICE_COLLECTIVES=all
        export MPIR_CVAR_VERBOSE=1

        mpiexec -n "$num_ranks" "$MPI_BIN" -m 0:1048576 -i 10000
        ;;

    mpichccl)
        echo "[Running] MPICH + CCL (NOTE: ensure MPICH is built with XCCL support)..."
        export MPICH_DIR=$HOME/grace_mpich/build/install
        export PATH=$MPICH_DIR/bin:$PATH
        export LD_LIBRARY_PATH=$MPICH_DIR/lib:$LD_LIBRARY_PATH
        export LD_LIBRARY_PATH=$HOME/xccl-install/lib:$LD_LIBRARY_PATH

        export MPIR_CVAR_ALLREDUCE_INTRA_ALGORITHM=ccl
        export MPIR_CVAR_DEVICE_COLLECTIVES=none
        export MPIR_CVAR_VERBOSE=1

        mpiexec -n "$num_ranks" "$MPI_BIN" -m 0:1048576 -i 10000
        ;;

    ompiccl)
        echo "[Running] Open MPI + XCCL..."
        export PATH=$HOME/openmpi-xccl-install/bin:$PATH
        export LD_LIBRARY_PATH=$HOME/openmpi-xccl-install/lib:$LD_LIBRARY_PATH
        export LD_LIBRARY_PATH=$HOME/ucx-install/lib:$HOME/xccl-install/lib:$LD_LIBRARY_PATH

        export OMPI_MCA_coll=xcc
        export OMPI_MCA_coll_xccl_verbose=1
        
        mpirun -np "$num_ranks" "$MPI_BIN" -m 0:1048576 -i 10000
        ;;

    rccl)
        echo "[Running] RCCL/XCCL benchmark (no MPI)..."
        export LD_LIBRARY_PATH=$HOME/xccl-install/lib:$LD_LIBRARY_PATH
        export LD_LIBRARY_PATH=$HOME/ucx-install/lib:$LD_LIBRARY_PATH

        MB_DEVICE_TYPE=rocm mpiexec -n "$num_ranks" "$RCCL_BIN" -m 0:1048576 -i 10000
        ;;

    *)
        echo "Error: unknown backend '$backend'. Use: mpich, mpichccl, ompiccl, or rccl"
        exit 1
        ;;
esac