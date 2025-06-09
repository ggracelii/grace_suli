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
    - mpi — Run MPI backend
    - rccl — Run RCCL backend
	- `<num_ranks>`: Number of processes to launch with `mpiexec`.
	- `[ccl]` (optional): Only valid with mpi backend. Enables `MPIR_CVAR_ALLREDUCE_INTRA_ALGORITHM=ccl`.

### `plot.sh`
Runs multiple trials of both MPI and RCCL benchmarks, averages the results, saves results to `data.csv`, and generates a plot saved in `graph.png`.
- **Usage:**
  ```bash
  ./plot.sh <num_trials> <num_ranks>
  ```
  - `<num_trials>`: Number of repetitions per backend to average
  - `<num_ranks>`: Number of ranks to use during the run
Note: This script does not overwrite existing `data.csv` or `graph.png` files. Instead, it saves them as `data_N.csv` and `graph_N.png` using the next available number.

##  Output Artifacts
A sample of each is included.
- `data.csv`: Raw per-trial latency results by size and backend.
- `graph.png`: Log-scale plot of average latency per size.