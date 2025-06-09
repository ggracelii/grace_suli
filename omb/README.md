# OSU Benchmark Automation
This directory automates building, running, and plotting results for the OSU Allreduce latency benchmark across MPI and RCCL backends.
---
##  Scripts Overview
### `build.sh`
Compiles the OSU Micro-Benchmarks by running `./configure` with appropriate flags, then building the benchmark using `make`.
- **Usage:**
  ```bash
  ./build.sh
  ```
---
### `run.sh`
Runs a single instance of the Allreduce benchmark with the specified backend and number of ranks.
- **Usage:**
  ```bash
  ./run.sh <backend> <num_ranks>
  ```
  - `<backend>`: Either `mpi` or `rccl`
  - `<num_ranks>`: Number of processes to launch using `mpiexec`
---
### `plot.sh`
Runs multiple trials of both MPI and RCCL benchmarks, averages the results, saves results to `data.csv`, and generates a plot saved in `graph.png`.
- **Usage:**
  ```bash
  ./plot.sh <num_trials> <num_ranks>
  ```
  - `<num_trials>`: Number of repetitions per backend to average
  - `<num_ranks>`: Number of ranks to use during the run
---
##  Output Artifacts
A sample of each is included.
- `data.csv`: Raw per-trial latency results by size and backend.
- `graph.png`: Log-scale plot of average latency per size.