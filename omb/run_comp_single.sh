#!/bin/bash
set -euo pipefail

N=1
PPN=4
NUM_PROCS=$((N * PPN))
BIN="./install/libexec/osu-micro-benchmarks/mpi/collective/osu_allreduce"

CSV_FILE_BASE="comp_single_data"
CSV_FILE="${CSV_FILE_BASE}.csv"
i=1
while [ -f "$CSV_FILE" ]; do
    CSV_FILE="${CSV_FILE_BASE}_$i.csv"
    ((i++))
done

PLOT_FILE_BASE="comp_single_graph"
PLOT_FILE="${PLOT_FILE_BASE}.png"
i=1
while [ -f "$PLOT_FILE" ]; do
    PLOT_FILE="${PLOT_FILE_BASE}_$i.png"
    ((i++))
done

echo "size,composition,latency" > "$CSV_FILE"

# RCCL - composition none
echo "Running rccl composition none (rccl-dc-none)..."
mpiexec -n $NUM_PROCS -ppn $PPN \
    -genv LD_LIBRARY_PATH "$HOME/rccl/build/lib:/soft/compilers/rocm/rocm-6.3.2/lib:/soft/compilers/rocm/rocm-6.3.2/lib64:$HOME/grace_mpich/build/install/lib:$LD_LIBRARY_PATH" \
    -genv MPIR_CVAR_COLLECTIVE_FALLBACK error \
    -genv MPIR_CVAR_DEVICE_COLLECTIVES none \
    -genv MPIR_CVAR_ALLREDUCE_INTRA_ALGORITHM ccl \
    -genv MPIR_CVAR_ALLREDUCE_CCL rccl \
    -genv MPIR_CVAR_CH4_GPU_COLL_SWAP_BUFFER_SZ 32768 \
    -genv UCX_TLS=sm,self,rocm \
    "$BIN" -m 0:1048576 -d rocm > tmp_rccl_none.txt
awk -v label="rccl-dc-none" '/^[[:digit:]]/ {
    printf "%s,%s,%.6f\n", $1, label, $2
}' tmp_rccl_none.txt >> "$CSV_FILE"
rm tmp_rccl_none.txt

# RCCL - composition 2 (beta)
echo "Running rccl composition 2 (rccl-beta)..."
mpiexec -n $NUM_PROCS -ppn $PPN \
    -genv LD_LIBRARY_PATH "$HOME/rccl/build/lib:/soft/compilers/rocm/rocm-6.3.2/lib:/soft/compilers/rocm/rocm-6.3.2/lib64:$HOME/grace_mpich/build/install/lib:$LD_LIBRARY_PATH" \
    -genv MPIR_CVAR_COLLECTIVE_FALLBACK error \
    -genv MPIR_CVAR_DEVICE_COLLECTIVES percoll \
    -genv MPIR_CVAR_ALLREDUCE_DEVICE_COLLECTIVE 1 \
    -genv MPIR_CVAR_ALLREDUCE_INTRA_ALGORITHM ccl \
    -genv MPIR_CVAR_ALLREDUCE_CCL rccl \
    -genv MPIR_CVAR_ALLREDUCE_COMPOSITION 2 \
    -genv MPIR_CVAR_CH4_GPU_COLL_SWAP_BUFFER_SZ 32768 \
    -genv UCX_TLS=sm,self,rocm \
    "$BIN" -m 0:1048576 -d rocm > tmp_rccl_2.txt
awk -v label="rccl-beta" '/^[[:digit:]]/ {
    printf "%s,%s,%.6f\n", $1, label, $2
}' tmp_rccl_2.txt >> "$CSV_FILE"
rm tmp_rccl_2.txt

# RCCL - composition 3 (gamma)
echo "Running rccl composition 3 (rccl-gamma)..."
mpiexec -n $NUM_PROCS -ppn $PPN \
    -genv LD_LIBRARY_PATH "$HOME/rccl/build/lib:/soft/compilers/rocm/rocm-6.3.2/lib:/soft/compilers/rocm/rocm-6.3.2/lib64:$HOME/grace_mpich/build/install/lib:$LD_LIBRARY_PATH" \
    -genv MPIR_CVAR_COLLECTIVE_FALLBACK error \
    -genv MPIR_CVAR_DEVICE_COLLECTIVES percoll \
    -genv MPIR_CVAR_ALLREDUCE_DEVICE_COLLECTIVE 1 \
    -genv MPIR_CVAR_ALLREDUCE_INTRA_ALGORITHM ccl \
    -genv MPIR_CVAR_ALLREDUCE_CCL rccl \
    -genv MPIR_CVAR_ALLREDUCE_COMPOSITION 3 \
    -genv MPIR_CVAR_CH4_GPU_COLL_SWAP_BUFFER_SZ 32768 \
    -genv UCX_TLS=sm,self,rocm \
    "$BIN" -m 0:1048576 -d rocm > tmp_rccl_3.txt
awk -v label="rccl-gamma" '/^[[:digit:]]/ {
    printf "%s,%s,%.6f\n", $1, label, $2
}' tmp_rccl_3.txt >> "$CSV_FILE"
rm tmp_rccl_3.txt

# MPI - composition none
echo "Running mpi composition none (mpi-dc-none)..."
mpiexec -n $NUM_PROCS -ppn $PPN \
    -genv LD_LIBRARY_PATH "$HOME/grace_mpich/build/install/lib:$LD_LIBRARY_PATH" \
    -genv MPIR_CVAR_COLLECTIVE_FALLBACK error \
    -genv MPIR_CVAR_DEVICE_COLLECTIVES none \
    -genv MPIR_CVAR_CH4_GPU_COLL_SWAP_BUFFER_SZ 32768 \
    "$BIN" -m 0:1048576 -d rocm > tmp_mpi_none.txt
awk -v label="mpi-dc-none" '/^[[:digit:]]/ {
    printf "%s,%s,%.6f\n", $1, label, $2
}' tmp_mpi_none.txt >> "$CSV_FILE"
rm tmp_mpi_none.txt

# MPI - composition 2 (beta)
echo "Running mpi composition 2 (mpi-beta)..."
mpiexec -n $NUM_PROCS -ppn $PPN \
    -genv LD_LIBRARY_PATH "$HOME/grace_mpich/build/install/lib:$LD_LIBRARY_PATH" \
    -genv MPIR_CVAR_COLLECTIVE_FALLBACK error \
    -genv MPIR_CVAR_DEVICE_COLLECTIVES percoll \
    -genv MPIR_CVAR_ALLREDUCE_DEVICE_COLLECTIVE 1 \
    -genv MPIR_CVAR_ALLREDUCE_COMPOSITION 2 \
    -genv MPIR_CVAR_CH4_GPU_COLL_SWAP_BUFFER_SZ 32768 \
    "$BIN" -m 0:1048576 -d rocm > tmp_mpi_2.txt
awk -v label="mpi-beta" '/^[[:digit:]]/ {
    printf "%s,%s,%.6f\n", $1, label, $2
}' tmp_mpi_2.txt >> "$CSV_FILE"
rm tmp_mpi_2.txt

# MPI - composition 3 (gamma)
echo "Running mpi composition 3 (mpi-gamma)..."
mpiexec -n $NUM_PROCS -ppn $PPN \
    -genv LD_LIBRARY_PATH "$HOME/grace_mpich/build/install/lib:$LD_LIBRARY_PATH" \
    -genv MPIR_CVAR_COLLECTIVE_FALLBACK error \
    -genv MPIR_CVAR_DEVICE_COLLECTIVES percoll \
    -genv MPIR_CVAR_ALLREDUCE_DEVICE_COLLECTIVE 1 \
    -genv MPIR_CVAR_ALLREDUCE_COMPOSITION 3 \
    -genv MPIR_CVAR_CH4_GPU_COLL_SWAP_BUFFER_SZ 32768 \
    "$BIN" -m 0:1048576 -d rocm > tmp_mpi_3.txt
awk -v label="mpi-gamma" '/^[[:digit:]]/ {
    printf "%s,%s,%.6f\n", $1, label, $2
}' tmp_mpi_3.txt >> "$CSV_FILE"
rm tmp_mpi_3.txt

# CH4 JSON tuning-based composition
echo "Running ch4 tuning composition (ch4-tuning)..."
mpiexec -n "$NUM_PROCS" -ppn "$PPN" \
    -genv LD_LIBRARY_PATH "$HOME/rccl/build/lib:/soft/compilers/rocm/rocm-6.3.2/lib:/soft/compilers/rocm/rocm-6.3.2/lib64:$HOME/grace_mpich/build/install/lib:$LD_LIBRARY_PATH" \
    -genv MPIR_CVAR_COLLECTIVE_FALLBACK error \
    -genv MPIR_CVAR_DEVICE_COLLECTIVES percoll \
    -genv MPIR_CVAR_ALLREDUCE_DEVICE_COLLECTIVE 1 \
    -genv MPIR_CVAR_ALLREDUCE_INTRA_ALGORITHM ccl \
    -genv MPIR_CVAR_ALLREDUCE_CCL auto \
    -genv MPIR_CVAR_ALLREDUCE_COMPOSITION 0 \
    -genv MPIR_CVAR_CH4_GPU_COLL_SWAP_BUFFER_SZ 32768 \
    -genv MPIR_CVAR_CH4_COLL_SELECTION_TUNING_JSON_FILE ch4_tuning.json \
    -genv UCX_TLS sm,self,rocm \
    "$BIN" -m 0:1048576 -d rocm -E -S 32768 > tmp_ch4_tuning.txt
awk -v label="ch4-tuning" '/^[[:digit:]]/ {
    printf "%s,%s,%.6f\n", $1, label, $2
}' tmp_ch4_tuning.txt >> "$CSV_FILE"
rm tmp_ch4_tuning.txt

echo "All runs complete. Data saved to: $CSV_FILE"

cat <<EOF | $HOME/.local/bin/python3
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.ticker import FuncFormatter

csv_file = "$CSV_FILE"
plot_file = "$PLOT_FILE"

df = pd.read_csv(csv_file)
df['size'] = pd.to_numeric(df['size'], errors='coerce')
df['latency'] = pd.to_numeric(df['latency'], errors='coerce')
df = df.dropna(subset=['size', 'latency'])
df = df[df['latency'] > 0]

avg_df = df.groupby(['size', 'composition'])['latency'].mean().reset_index()
pivot_df = avg_df.pivot(index='size', columns='composition', values='latency')

plt.figure(figsize=(12, 12))

ordered_comps = [
    "mpi-dc-none",
    "mpi-beta",
    "mpi-gamma",
    "rccl-dc-none",
    "rccl-beta",
    "rccl-gamma"
]

color_map = {
    "mpi-dc-none": "blue",
    "mpi-beta": "green",
    "mpi-gamma": "orange",
    "rccl-dc-none": "brown",
    "rccl-beta": "purple",
    "rccl-gamma": "pink"
}

for comp in ordered_comps:
    if comp in pivot_df.columns:
        plt.plot(
            pivot_df.index,
            pivot_df[comp],
            marker='o',
            linewidth=1.5,
            label=comp,
            color=color_map[comp]
        )

if "ch4-tuning" in pivot_df.columns:
    plt.plot(
        pivot_df.index,
        pivot_df["ch4-tuning"],
        marker='o',
        linewidth=4.5,
        label="ch4-tuning",
        color="red"
    )

plt.axvline(x=32768, color='black', linestyle='--', label='threshold = 32768')

plt.xscale('log')
plt.yscale('log')
plt.xlabel('Message Size (Bytes)', fontsize=13)
plt.ylabel('Latency (µs)', fontsize=13)
plt.title('Allreduce Latency by Composition (1 node)', fontsize=16)

def sci_notation(x, _):
    if x == 0:
        return "0"
    exponent = int(np.floor(np.log10(x)))
    base = x / 10**exponent
    return rf"\${{{int(base)}}} \times 10^{{{exponent}}}\$"

formatter = FuncFormatter(sci_notation)
plt.gca().yaxis.set_major_formatter(formatter)

plt.grid(True, which='both', linestyle='--', alpha=0.5)
plt.legend(title='Composition')
plt.tight_layout()
plt.savefig(plot_file)
print(f"Saved plot to {plot_file}")
EOF