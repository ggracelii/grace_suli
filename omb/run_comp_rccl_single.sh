#!/bin/bash
set -euo pipefail

# Usage: ./run_comp_rccl_single.sh

N=1
PPN=4
NUM_PROCS=$((N * PPN))
BIN="./install/libexec/osu-micro-benchmarks/mpi/collective/osu_allreduce"

CSV_FILE_BASE="comp_rccl_single_data"
CSV_FILE="${CSV_FILE_BASE}.csv"
i=1
while [ -f "$CSV_FILE" ]; do
    CSV_FILE="${CSV_FILE_BASE}_$i.csv"
    ((i++))
done

PLOT_FILE_BASE="comp_rccl_single_graph"
PLOT_FILE="${PLOT_FILE_BASE}.png"
i=1
while [ -f "$PLOT_FILE" ]; do
    PLOT_FILE="${PLOT_FILE_BASE}_$i.png"
    ((i++))
done

echo "size,composition,latency" > "$CSV_FILE"

echo "Running rccl composition none (dc-none)..."
mpiexec -n $NUM_PROCS -ppn $PPN \
     -genv RUN_MODE=rccl \
    -genv LD_LIBRARY_PATH="$HOME/rccl/build/lib:/soft/compilers/rocm/rocm-6.3.2/lib:/soft/compilers/rocm/rocm-6.3.2/lib64:$HOME/grace_mpich/build/install/lib:$LD_LIBRARY_PATH" \
    -genv MPIR_CVAR_DEVICE_COLLECTIVES=none \
    -genv MPIR_CVAR_ALLREDUCE_INTRA_ALGORITHM=ccl \
    -genv MPIR_CVAR_ALLREDUCE_CCL=rccl \
    -genv UCX_TLS=sm,self,rocm \
    -genv UCX_WARN_UNUSED_ENV_VARS=n \
    -genv MPIR_CVAR_COLLECTIVE_FALLBACK=error \
    "$BIN" -m 0:1048576 -d rocm > tmp_rccl_none.txt
awk -v label="dc-none" '/^[[:digit:]]/ {
    printf "%s,%s,%.6f\n", $1, label, $2
}' tmp_rccl_none.txt >> "$CSV_FILE"
rm tmp_rccl_none.txt

# RCCL - composition 2 (beta)
echo "Running rccl composition 2 (beta)..."
mpiexec -n $NUM_PROCS -ppn $PPN \
    -genv RUN_MODE=rccl \
    -genv LD_LIBRARY_PATH="$HOME/rccl/build/lib:/soft/compilers/rocm/rocm-6.3.2/lib:/soft/compilers/rocm/rocm-6.3.2/lib64:$HOME/grace_mpich/build/install/lib:$LD_LIBRARY_PATH" \
    -genv MPIR_CVAR_DEVICE_COLLECTIVES=percoll \
    -genv MPIR_CVAR_ALLREDUCE_INTRA_ALGORITHM=ccl \
    -genv MPIR_CVAR_ALLREDUCE_CCL=rccl \
    -genv MPIR_CVAR_ALLREDUCE_DEVICE_COLLECTIVE=1 \
    -genv UCX_TLS=sm,self,rocm \
    -genv UCX_WARN_UNUSED_ENV_VARS=n \
    -genv MPIR_CVAR_COLLECTIVE_FALLBACK=error \
    -genv MPIR_CVAR_ALLREDUCE_COMPOSITION 2 \
    "$BIN" -m 0:1048576 -d rocm > tmp_rccl_2.txt
awk -v label="beta" '/^[[:digit:]]/ {
    printf "%s,%s,%.6f\n", $1, label, $2
}' tmp_rccl_2.txt >> "$CSV_FILE"
rm tmp_rccl_2.txt

# RCCL - composition 3 (gamma)
echo "Running rccl composition 3 (gamma)..."
mpiexec -n $NUM_PROCS -ppn $PPN \
    -genv RUN_MODE=rccl \
    -genv LD_LIBRARY_PATH="$HOME/rccl/build/lib:/soft/compilers/rocm/rocm-6.3.2/lib:/soft/compilers/rocm/rocm-6.3.2/lib64:$HOME/grace_mpich/build/install/lib:$LD_LIBRARY_PATH" \
    -genv MPIR_CVAR_DEVICE_COLLECTIVES=percoll \
    -genv MPIR_CVAR_ALLREDUCE_INTRA_ALGORITHM=ccl \
    -genv MPIR_CVAR_ALLREDUCE_CCL=rccl \
    -genv MPIR_CVAR_ALLREDUCE_DEVICE_COLLECTIVE=1 \
    -genv UCX_TLS=sm,self,rocm \
    -genv UCX_WARN_UNUSED_ENV_VARS=n \
    -genv MPIR_CVAR_COLLECTIVE_FALLBACK=error \
    -genv MPIR_CVAR_ALLREDUCE_COMPOSITION 3 \
    "$BIN" -m 0:1048576 -d rocm > tmp_rccl_3.txt
awk -v label="gamma" '/^[[:digit:]]/ {
    printf "%s,%s,%.6f\n", $1, label, $2
}' tmp_rccl_3.txt >> "$CSV_FILE"
rm tmp_rccl_3.txt

echo "All runs completed. Output saved to $CSV_FILE"

cat <<EOF | $HOME/.local/bin/python3
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.ticker import FuncFormatter

df = pd.read_csv("$CSV_FILE")
df['size'] = pd.to_numeric(df['size'], errors='coerce')
df['latency'] = pd.to_numeric(df['latency'], errors='coerce')
df = df.dropna(subset=['size', 'latency'])
df = df[df['latency'] > 0]

avg_df = df.groupby(['size', 'composition'])['latency'].mean().reset_index()
pivot_df = avg_df.pivot(index='size', columns='composition', values='latency')

plt.figure(figsize=(10, 10))
for comp in pivot_df.columns:
    plt.plot(pivot_df.index, pivot_df[comp], marker='o', linewidth=2, label=comp.upper())

plt.xscale('log')
plt.yscale('log')
plt.xlabel('Message Size (Bytes)', fontsize=13)
plt.ylabel('Latency (µs)', fontsize=13)
plt.title('Allreduce Latency by Composition (RCCL for single node)', fontsize=16)

def sci_notation(x, _):
    if x == 0:
        return "0"
    exponent = int(np.floor(np.log10(x)))
    base = x / 10**exponent
    return fr"\${int(base)} \times 10^{exponent}\$"
formatter = FuncFormatter(sci_notation)
plt.gca().yaxis.set_major_formatter(formatter)

plt.grid(True, which='both', linestyle='--', alpha=0.5)
plt.legend(title='Composition')
plt.tight_layout()
plt.savefig("${PLOT_FILE}")
print(f"Saved plot to ${PLOT_FILE}")
EOF