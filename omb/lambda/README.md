# Lambda (Stream-parallel Allreduce)

This directory contains data, plots, and benchmark utilities for evaluating stream-parallel Allreduce with multi-stream and multi-communicator implementations.

Make sure to build the `lambda` branch of `grace_mpich`.

## Benchmark Data and Plots

| File                   | Description                                  |
|------------------------|----------------------------------------------|
| `1comm4stream.csv`     | Latency data for **multi-stream** Allreduce (1 communicator, 4 streams) |
| `1comm4stream.png`     | Plot of the above data                       |
| `4comm4stream.csv`     | Latency data for **multi-communicator** Allreduce (4 communicators, 4 streams) |
| `4comm4stream.png`     | Plot of the above data                       |
| `og_beta.csv`          | Latency data for **original beta** implementation |
| `og_beta.png`          | Plot of the above data                       |

## 🧪 Benchmark Utility

### Files:
- `allreduce_benchmark_mpi.c`: C benchmark for verifying correctness of Allreduce with GPU device buffers.
- `allreduce_benchmark_mpi`: Compiled binary.

### Compile:
```bash
hipcc -D__HIP_PLATFORM_AMD__ \
      -I$MPICH_DIR/include \
      -I/soft/compilers/rocm/rocm-6.3.2/include \
      -L$MPICH_DIR/lib -lmpi \
      --offload-arch=gfx90a \
      -O2 -o allreduce_benchmark_mpi allreduce_benchmark_mpi.c
