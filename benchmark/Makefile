HIPCC := /soft/compilers/rocm/rocm-6.3.2/bin/hipcc
MPICC := $(HOME)/grace_mpich/build/install/bin/mpicc

RCCL_SRC := allreduce_benchmark_rccl.c
RCCL_OUT := allreduce_benchmark_rccl

MPI_SRC := allreduce_benchmark_mpi.c
MPI_OUT := allreduce_benchmark_mpi

MPI_FLAGS := $(shell $(MPICC) -show)
MPI_INCLUDES := $(filter -I%,$(MPI_FLAGS))
MPI_LIBS := $(filter -l%,$(MPI_FLAGS))

HIP_INCLUDES := -I/soft/compilers/rocm/rocm-6.3.2/include
HIP_LIBS := -L/soft/compilers/rocm/rocm-6.3.2/lib -L$(HOME)/grace_mpich/build/install/lib -lrccl -lamdhip64 -lhiprtc -lmpi
CXXFLAGS := -D__HIP_PLATFORM_AMD__ $(HIP_INCLUDES) $(MPI_INCLUDES)

.PHONY: all clean

all: $(RCCL_OUT) $(MPI_OUT)

$(RCCL_OUT): $(RCCL_SRC)
	$(HIPCC) -x c++ $(CXXFLAGS) $(HIP_LIBS) $(MPI_LIBS) $< -o $@

$(MPI_OUT): $(MPI_SRC)
	$(MPICC) $< -o $@

clean:
	find . -maxdepth 1 -type f ! -name 'Makefile' ! -name '$(RCCL_SRC)' ! -name '$(MPI_SRC)' ! -name 'run.sh' ! -name 'README.md' -exec rm -f {} +
