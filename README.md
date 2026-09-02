# MPICH-RCCL Integration

An RCCL backend for MPICH's `MPI_Allreduce` (contributed to upstream MPICH,
PR [pmodels/mpich#7493](https://github.com/pmodels/mpich/pull/7493)) and its
performance evaluation at scale on OLCF Frontier (AMD MI250X, Slingshot-11).

## What this is

MPICH normally reduces GPU data on the CPU, staging buffers device↔host. This work
offloads `MPI_Allreduce` to RCCL so the reduction runs on the GPUs directly (XGMI
intra-node, libfabric/CXI inter-node). The current effort measures that backend on
Frontier against:

- **Cray MPICH** — the production GPU-aware MPI on Frontier (plotted as the
  `MPICH_GPU_ALLREDUCE_BLK_SIZE=128MB`-tuned configuration: the default configuration
  crashes above 4 MiB at ≥1024 nodes, unfixed through cray-mpich 9.0.0 — see
  `frontier/docs/NOTES.md`),
- **MPICH's own CPU path** — host buffers, and device buffers staged through host.

(`rccl-tests`, a no-MPI pure-RCCL ceiling, was only measured at N=1 early on and is
kept as archived evidence, not a completed comparison axis — see `results_1gib_archive/`.)

Sweeping message size (4 B → 4 GiB, OSU patched from 32-bit to `size_t` sizes) and node
count (1 → 8,192 — 87% of Frontier, 65,536 GPUs) to map where the RCCL backend wins, by
how much, and how the crossover moves with scale.

**Flagship result:** one 4 GiB Allreduce across all 65,536 GPUs completes in **146 ms**
with the RCCL backend vs **354 ms** for Cray MPICH — **2.4× faster** — with per-step
BERT-Large gradient sync (1.36 GB) at **52 ms vs 111 ms (2.1×)** at the same scale.

## Where things are

- **`frontier/`** — the current Frontier evaluation (active work). See `frontier/README.md` for the full how-to.
  - `build/` — build MPICH+RCCL, OSU, rccl-tests, the validator on Frontier
  - `run/` — the A–E sweep job + `submit_scaling.sh`
  - `check/` — correctness + mechanism gates, queue/result monitors
  - `docs/` — `NOTES.md` (build recipe, fix log, findings), `ML_EXPERIMENT.md`
  - `plots/` — `plot.ipynb` (parses `results_sweep/` + `results_ml/` + `results_crayblk128/`
    → latency / speedup / scaling / crossover / headline figures)
  - `results_sweep/`, `results_ml/`, `results_crayblk128/`, `results_crayknob/`, ... —
    committed sweep + ML + tuned-Cray + mechanism-confirmation data (see `frontier/README.md`
    for the full list of `results_*/` categories)
  - `archive/` — preservation tarballs + retired job logs from the Frontier allocation
  - `out/` — captured job stdout logs
- **`mpich/`** — submodule: MPICH fork with the RCCL backend (since merged upstream).
- **`benchmark/`** — small allreduce correctness/latency programs (C + HIP).
- **`omb/`** — OSU Micro-Benchmarks automation from earlier work.

## Key implementation changes - MPICH

**Switched from CUDA to HIP** (port to AMD GPUs):
- `cudaStreamCreate` → `hipStreamCreate`
- `cudaSetDevice` → `hipSetDevice`
- `cudaStreamSynchronize` → `hipStreamSynchronize`
- CUDA error types and pointer-attribute APIs replaced with HIP equivalents

**Switched from NCCL to RCCL** (GPU collective backend on AMD hardware):
- Retained NCCL constant/function names (`ncclRedOp_t`, `ncclDataType_t`, `ncclCommInitRank`, …) since RCCL is API-compatible with NCCL — avoids conditional compilation or wrapper macros for most symbols

**Preserved and adjusted the NCCL implementation:**
- Kept `nccl.c` with a minor fix: added a `break` to the `float16` switch case to avoid fall-through

(A later upstream-API change — `MPIR_Errflag_t` removal — is handled by building from upstream MPICH; see `frontier/docs/NOTES.md`.)

## Key notes - Frontier (evaluation complete)

*The sweep ran 1 → 8,192 nodes (65,536 GPUs, 87% of Frontier); the allocation has since
ended and results are frozen. Numbers below are final.*

- **Build:** upstream MPICH built with **amdclang + system libfabric/CXI** (not the Cray `cc` wrapper, which links Cray MPI into it); `--disable-weak-symbols`; `module unload cray-mpich` at runtime so our `libmpi` isn't shadowed.
- **RCCL needs the OFI plugin:** without OLCF's `rccl-net-plugin` (aws-ofi-rccl), RCCL falls back to TCP and runs ~4× *slower* than Cray inter-node; with it (CXI), RCCL is competitive/faster.
- **GPU binding:** under Hydra (`mpiexec -bootstrap slurm`) pin GPUs via `MPI_LOCALRANKID`, not `SLURM_LOCALID` (which is 0 for every rank → RCCL "duplicate GPU" crash); single-node jobs also need `--network=single_node_vni` for CXI.
- **Intra-node (1 node, 8 GCDs):** the RCCL backend beats MPICH's CPU path by up to **~58× at 32 MiB**.
- **Inter-node is a crossover surface (message size × node count):** RCCL wins large messages (**2–4× vs Cray at GB scale**, holding across the whole ladder to 8,192 nodes) but loses small messages to Cray; the crossover slides to smaller sizes as node count grows.
- **Flagship: one 4 GiB Allreduce at 8,192 nodes (65,536 GPUs) — 146 ms (RCCL) vs 354 ms (Cray MPICH), 2.4× faster**, scaling nearly flat from 4,096 → 8,192 nodes.

See `frontier/docs/NOTES.md` for the full build recipe, fix log, and evidence.

## Background

Originally developed during a 2025 SULI internship at Argonne National Laboratory; the
allreduce backend was merged into upstream MPICH and is now being evaluated at exascale
on Frontier. Full build recipe, fix log, and findings are in `frontier/docs/NOTES.md`.
