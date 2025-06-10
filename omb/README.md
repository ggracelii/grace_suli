# OSU Benchmark Automation

This directory automates building, running, and plotting results for the OSU Allreduce latency benchmark across MPI and RCCL backends.

##  Scripts Overview
### `build.sh`
Compiles the OSU Micro-Benchmarks by running `./configure` with appropriate flags, then building the benchmark using `make`.
- **Usage:**
  ```bash
  ./build.sh
  ```

### `run.sh`
Runs a single instance of the Allreduce benchmark with the specified backend and number of ranks.
- **Usage:**
  ```bash
  ./run.sh <backend> <num_ranks>
  ```
  - `<backend>`:
    - mpich — Run MPICH backend
    - mpichccl - Run MPICH-CCL backend
    - rccl — Run RCCL backend
    - auto - Runs the composite backend
    
  - `<num_ranks>`: Number of processes to launch with `mpiexec`.

  **Composite backend (`auto`) Overview**  
  Uses MPICH with a message-size-based switch between MPI and RCCL.
  - For messages smaller than 44106 bytes: `MPIR_CVAR_DEVICE_COLLECTIVES=all`, runs with default MPI.  
  - For larger messages: `MPIR_CVAR_DEVICE_COLLECTIVES=none`, runs with RCCL and `--accelerator=rocm`.

  This threshold (44106 bytes) was selected based on a previous latency comparison graph across 2 ranks, averaged over 10 trials. It can be adjusted by modifying the threshold in `allreduce_intra_ccl.c` in the MPICH source.

  **Note:** Since the OSU benchmark does not support switching algorithms at runtime, `run.sh` splits execution into two separate calls for small and large message sizes.

### `plot.sh`
Runs multiple trials of both MPI and RCCL benchmarks, averages the results, saves results to `data.csv`, and generates a plot saved in `graph.png`.
- **Usage:**
  ```bash
  ./plot.sh <num_trials> <num_ranks>
  ```
  - `<num_trials>`: Number of repetitions per backend to average
  - `<num_ranks>`: Number of ranks to use during the run
**Note:** This script does not overwrite existing `data.csv` or `graph.png` files. Instead, it saves them as `data_N.csv` and `graph_N.png` using the next available number.

##  Output Artifacts
A sample of each is included.
- `data.csv`: Raw per-trial latency results by size and backend.
- `graph.png`: Log-scale plot of average latency per size.