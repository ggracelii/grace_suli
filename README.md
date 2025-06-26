# Grace's SULI Summer 2025 Work

Welcome! This repository contains my work for the 2025 SULI internship at Argonne National Laboratory, focusing on integrating RCCL with MPICH and benchmarking collective performance.

## Directory Structure

- `benchmark/`  
  - Contains updated benchmark programs for evaluating MPI and RCCL collectives. These include tests for the `Allreduce` collective operation.  
  
→ See the `README.md` inside this folder for build and run instructions.
go
- `mpich/`  
  - Submodule pointing to my fork of the original MPICH repo
  - Contains modified MPICH source files that enable RCCL backend support
  - Use this to rebuild MPICH & run tests  

This folder contains all source modifications made to enable RCCL support within MPICH for the `Allreduce` collective operation.

- `omb/`
	- Contains automation scripts and support files for running and plotting OSU Allreduce latency benchmarks across MPICH and RCCL backends
  
→ See the README.md inside this folder for details on scripts, usage examples, and output artifacts.
 
### Key Changes

- **Switched from CUDA to HIP**  
  - `cudaStreamCreate` → `hipStreamCreate`  
  - `cudaSetDevice` → `hipSetDevice`  
  - `cudaStreamSynchronize` → `hipStreamSynchronize`  
  - CUDA error types and pointer attribute APIs replaced with HIP equivalents

- **Switched from NCCL to RCCL**  
  - RCCL was used as the backend for GPU collectives on AMD hardware
  - Retained NCCL constants and function names (`ncclRedOp_t`, `ncclDataType_t`, `ncclCommInitRank`, etc.) because RCCL maintains API-level compatibility with NCCL
  - This approach avoids the need for conditional compilation or wrapper macros for most symbols

- **Preserved and Adjusted NCCL Implementation**  
  - Included the `nccl.c` implementation with a minor fix: added a `break` to the `float16` switch case to avoid fall-through


## Build & Usage

Each folder contains build instructions specific to its content. 
