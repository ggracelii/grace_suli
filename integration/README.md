# RCCL Integration – MPICH Source Edits

This folder contains all source modifications made to enable RCCL (Radeon Collective Communications Library) support within MPICH for the `Allreduce` collective operation. These changes were developed as part of Grace's 2025 SULI project at Argonne National Laboratory.

## Structure

- **MPICH Source Files**  
  Located in this directory. These contain the core integration logic—adding support for HIP and RCCL while preserving compatibility with the existing MPICH architecture.

- **`test/` Directory**  
  Contains testing files adapted from the upstream MPICH repository. These were modified to validate RCCL-based collective behavior, especially for `Allreduce`.

## Key Changes

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
