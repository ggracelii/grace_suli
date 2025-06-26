# OSU Benchmark Automation

This directory automates building, running, and plotting results for the OSU Allreduce latency benchmark across MPI and RCCL backends.

## Scripts Overview
### `build.sh`
Compiles the OSU Micro-Benchmarks by running `./configure` with appropriate flags, then building the benchmark using `make`.
**Usage:**
```bash
./build.sh
```
### `run.sh`
Runs a single instance of the Allreduce benchmark with the specified backend and number of nodes.
**Usage:**
```bash
./run.sh <mpich|mpichccl|rccl|auto> <1|2>
```
- `<backend>`:
  - `mpich`  Run MPICH backend
  - `mpichccl`  Run MPICH-CCL backend
  - `rccl`  Run RCCL backend
  - `auto`  Runs the composite backend
- `<1|2>`: Number of nodes to run on
**Composite backend (`auto`) Overview**
Uses MPICH with a message-size-based switch between MPI and RCCL:
- For messages < 44106 bytes: `MPIR_CVAR_DEVICE_COLLECTIVES=all` (default MPI)
- For messages  44106 bytes: `MPIR_CVAR_DEVICE_COLLECTIVES=none` (fallback to RCCL)
This threshold is based on a latency comparison graph across 2 ranks, averaged over 10 trials, and can be adjusted in `allreduce_intra_ccl.c` in the MPICH source. `run.sh` splits execution into two separate calls for small and large messages due to OSU benchmark limitations.

### `plot.sh`
Plots data from a CSV file and accepts the number of nodes for annotation.
**Usage:**
```bash
./plot.sh <csv_file> <num_nodes>
```
- `<csv_file>`: File containing benchmark results
- `<num_nodes>`: Used for labeling the plot
The script does not overwrite existing files. Instead, it saves as `graph_N.png` using the next available number.

### `run_comp.sh`
Runs all composition algorithms (`alpha`, `beta`, `gamma`, `delta`, and `dc-none`) with 10 trials each. Outputs a CSV of results and generates a plot image.

### `trials.sh`
Runs all backends for a given number of trials and either 1 or 2 nodes.
**Usage:**
```bash
./trials.sh <1|2> <num_trials>
```

### Hardcoded Run Scripts
The following scripts run predefined configurations for either 1 or 2 nodes using various backends. They are useful for reproducible benchmarks:
- `run_auto_single.sh`
- `run_auto_multi.sh`
- `run_mpich_single.sh`
- `run_mpich_multi.sh`
- `run_mpichccl_single.sh`
- `run_mpichccl_multi.sh`
- `run_rccl_single.sh`
- `run_rccl_multi.sh`

These use either JSON tuning files or environment variables.

-	`run_comp_rccl_single.sh`
- `run_comp_rccl_multi.sh`
- `run_comp_mpi_single.sh`
- `run_comp_mpi_multi.sh`
-	`trace_comp_rccl_single.sh`
- `trace_comp_rccl_multi.sh`
- `trace_comp_mpi_single.sh`
- `trace_comp_mpi_multi.sh`

The `run_comp_*` and `trace_comp_*` scripts run all composition algorithms—`alpha, beta, gamma, delta`—as well as `MPIR_CVAR_DEVICE_COLLECTIVES=none` for both MPI native and MPICH-CCL backends. They support both single-node and multi-node setups. 
- The run scripts are configured for 10 trials by default with 10,000 iterations for message sizes varying from 0 to 1048576 bytes. These scripts output a CSV of results and generate a corresponding plot.
- The trace scripts run each algorithm once with 1 iteration for a set message size (4 bytes). The output tracing the execution paths are saved to a log.

### JSON Tuning Files
These are MPICH tuning configuration files that influence backend switching logic. They are being customized to improve automatic behavior:
- `test.json`
- `tuning.json`
- `posix_tuning.json`
- `ch4_tuning.json`

### Output Artifacts
Sample output files from actual runs include:
- `single_node_data.csv`
- `multi_node_data.csv`
- `comp_rccl_single_data.csv`
- `comp_mpi_single_data.csv`
- `single_node_graph.png`
- `multi_node_graph.png`
- `comp_mpi_multi_data.csv`
- `comp_rccl_multi_graph.png`

Each CSV contains raw per-trial latency results by size and backend or composition. PNGs are log-scale plots of average latency per message size, averaged over 10 trials.
