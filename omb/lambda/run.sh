#!/bin/bash
set -euo pipefail

N=2
PPN=4
NUM_PROCS=$((N * PPN))
BIN="../install/libexec/osu-micro-benchmarks/mpi/collective/osu_allreduce"

CSV_FILE_BASE="data"
CSV_FILE="${CSV_FILE_BASE}.csv"
i=1
while [ -f "$CSV_FILE" ]; do
    CSV_FILE="${CSV_FILE_BASE}_$i.csv"
    ((i++))
done

PLOT_FILE_BASE="graph"
PLOT_FILE="${PLOT_FILE_BASE}.png"
i=1
while [ -f "$PLOT_FILE" ]; do
    PLOT_FILE="${PLOT_FILE_BASE}_$i.png"
    ((i++))
done

echo "size,composition,latency" > "$CSV_FILE"

# for SUBCOMM in 1 2 4 8 16 32 64 128; do
#     echo "Running with n_subcomms=$SUBCOMM"
#     mpiexec -n $NUM_PROCS -ppn $PPN \
#         -genv LD_LIBRARY_PATH="$HOME/rccl/build/lib:/soft/compilers/rocm/rocm-6.3.2/lib:/soft/compilers/rocm/rocm-6.3.2/lib64:$HOME/grace_mpich/build/install/lib:$LD_LIBRARY_PATH" \
#         -genv MPIR_CVAR_DEVICE_COLLECTIVES=percoll \
#         -genv MPIR_CVAR_ALLREDUCE_INTRA_ALGORITHM=ccl \
#         -genv MPIR_CVAR_ALLREDUCE_CCL=rccl \
#         -genv MPIR_CVAR_ALLREDUCE_DEVICE_COLLECTIVE=1 \
#         -genv UCX_TLS=sm,self,rocm \
#         -genv UCX_WARN_UNUSED_ENV_VARS=n \
#         -genv MPIR_CVAR_COLLECTIVE_FALLBACK=error \
#         -genv MPIR_CVAR_ALLREDUCE_COMPOSITION=2 \
#         -genv MPIR_CVAR_N_SUBCOMMS=$SUBCOMM \
#         "$BIN" -m 0:67108864 -d rocm > tmp_rccl_${SUBCOMM}.txt 2>/dev/null

#     awk -v label="${SUBCOMM}_subcomm" '/^[[:digit:]]/ {
#         printf "%s,%s,%.6f\n", $1, label, $2
#     }' tmp_rccl_${SUBCOMM}.txt >> "$CSV_FILE"

#     rm tmp_rccl_${SUBCOMM}.txt
# done

mpiexec -n $NUM_PROCS -ppn $PPN -hostfile hosts.txt \
    -genv LD_LIBRARY_PATH="$HOME/rccl/build/lib:/soft/compilers/rocm/rocm-6.3.2/lib:/soft/compilers/rocm/rocm-6.3.2/lib64:$HOME/grace_mpich/build/install/lib:$LD_LIBRARY_PATH" \
    -genv MPIR_CVAR_DEVICE_COLLECTIVES=percoll \
    -genv MPIR_CVAR_ALLREDUCE_INTRA_ALGORITHM=ccl \
    -genv MPIR_CVAR_ALLREDUCE_CCL=rccl \
    -genv MPIR_CVAR_ALLREDUCE_DEVICE_COLLECTIVE=1 \
    -genv UCX_TLS=tcp,sm,self,rocm \
    -genv UCX_WARN_UNUSED_ENV_VARS=n \
    -genv MPIR_CVAR_COLLECTIVE_FALLBACK=error \
    -genv MPIR_CVAR_ALLREDUCE_COMPOSITION=2 \
    "$BIN" -m 0:67108864 -d rocm > tmp_rccl.txt 2>&1

awk -v label="1comm4streams" '/^[[:digit:]]/ {
    printf "%s,%s,%.6f\n", $1, label, $2
}' tmp_rccl.txt >> "$CSV_FILE"

echo "Data saved to $CSV_FILE"

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

og_df = pd.read_csv("og_beta.csv")
og_df['composition'] = 'old_beta'
og_df['size'] = pd.to_numeric(og_df['size'], errors='coerce')
og_df['latency'] = pd.to_numeric(og_df['latency'], errors='coerce')
og_df = og_df.dropna(subset=['size', 'latency'])
og_df = og_df[og_df['latency'] > 0]

df = pd.concat([df, og_df], ignore_index=True)

avg_df = df.groupby(['size', 'composition'])['latency'].mean().reset_index()
pivot_df = avg_df.pivot(index='size', columns='composition', values='latency')

plt.figure(figsize=(10, 10))

for label in pivot_df.columns:
    plt.plot(pivot_df.index, pivot_df[label], marker='o', linewidth=2, label=label)

plt.xscale('log')
plt.yscale('log')
plt.xlabel('Message Size (Bytes)', fontsize=13)
plt.ylabel('Latency (µs)', fontsize=13)
plt.title('Allreduce Latency Comparison', fontsize=16)

def sci_notation(x, _):
    if x == 0:
        return "0"
    exponent = int(np.floor(np.log10(x)))
    base = x / 10**exponent
    return f"\${int(base)} \\times 10^{{{exponent}}}\$"

formatter = FuncFormatter(sci_notation)
plt.gca().yaxis.set_major_formatter(formatter)

plt.grid(True, which='both', linestyle='--', alpha=0.5)
plt.legend(title='Composition')
plt.tight_layout()
plt.savefig("${PLOT_FILE}")
print(f"Saved plot to ${PLOT_FILE}")
EOF