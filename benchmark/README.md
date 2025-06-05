# AllReduce Benchmark (MPI and RCCL)

## Overview
This project provides two benchmark executables for testing AllReduce operations using MPI and RCCL.

**Executables:**
- `allreduce_benchmark_mpi`: Uses standard MPI_Allreduce.
- `allreduce_benchmark_rccl`: Uses HIP + RCCL for GPU-based AllReduce.

## Compilation
To compile both executables, simply run:

```bash
make
```

Adjust the `HIPCC` and `MPICC` variables in the Makefile if your system uses different paths for the HIP and MPI compilers.

## Running
Use the provided `run.sh` script to launch the benchmark.

### Usage
```bash
./run.sh <backend: rccl|mpi> <num_ranks> <message_size_in_bytes> [--int|--double|--float] [--corrupt]
```
You may aso need to modify the `LD_LIBRARY_PATH` environment variable in `run.sh` if your MPI libraries are installed in a different location.

### Flags
- `--int` for int datatype
- `--double` for double dataype
- `--float` for float datatype
- `--corrupt` for manual corruption to ensure validate function works properly

You may combine datatype and corrupt flags.

## Default Behavior
- The default datatype is `int8` if no datatype flag is specified.
- The `--corrupt` flag manually corrupts a random subset of send buffers to test if validation detects errors properly.

## Validation and Timing
Each executable:
- Validates the correctness of the AllReduce result.
- Reports min, max, and average timing across all ranks.