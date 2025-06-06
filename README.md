# Grace's SULI Summer 2025 Work

Welcome! This repository contains my work for the 2025 SULI internship at Argonne National Laboratory, focusing on integrating RCCL with MPICH and benchmarking collective performance.

## Directory Structure

- `benchmark/`  
  - Contains updated benchmark programs for evaluating MPI and RCCL collectives. These include tests for the `Allreduce` collective operation.  
  
→ See the `README.md` inside this folder for build and run instructions.

- `integration/`  
  - Contains modified MPICH source files that enable RCCL backend support. Changes include:
  - Collective algorithm dispatch hooks for RCCL
  - GPU buffer checking logic
  - RCCL-specific communicator initialization and teardown  

→ See the `README.md` in this folder for implementation details and integration notes.


## Build & Usage

Each folder contains build instructions specific to its content.
