#!/bin/bash
set -euo pipefail

> single.log

CSV_FILE_BASE="single_data"
CSV_FILE="${CSV_FILE_BASE}.csv"
i=1
while [ -f "$CSV_FILE" ]; do
    CSV_FILE="${CSV_FILE_BASE}_$i.csv"
    ((i++))
done

PLOT_FILE_BASE="single_graph"
PLOT_FILE="${PLOT_FILE_BASE}.png"
i=1
while [ -f "$PLOT_FILE" ]; do
    PLOT_FILE="${PLOT_FILE_BASE}_$i.png"
    ((i++))
done

BIN="./install/libexec/osu-micro-benchmarks/mpi/collective/osu_allreduce"
N=1
PPN=4
NUM_PROCS=$((N * PPN))

# Optional: Print which tuning file is in use
echo "Running osu_allreduce with ROCm backend..."

stdbuf -o0 mpiexec -n "$NUM_PROCS" -ppn "$PPN" \
    -genv MPIR_CVAR_ALLREDUCE_INTRA_ALGORITHM ccl \
    -genv MPIR_CVAR_DEVICE_COLLECTIVES percoll \
    -genv MPIR_CVAR_ALLREDUCE_DEVICE_COLLECTIVE 1 \
    -genv MPIR_CVAR_COLLECTIVE_FALLBACK error \
    -genv UCX_TLS sm,self,rocm \
    -genv UCX_WARN_UNUSED_ENV_VARS n \
    -genv MPIR_CVAR_VERBOSE 1 \
    -genv MPIR_CVAR_VERBOSE_ALLREDUCE 1 \
    -genv MPIR_CVAR_ALLREDUCE_CCL auto \
    -genv MPIR_CVAR_ALLREDUCE_COMPOSITION 0 \
    -genv MPIR_CVAR_CH4_COLL_SELECTION_TUNING_JSON_FILE ch4_tuning.json \
    -genv MPIR_CVAR_DUMP_PARAMS 1 \
    "$BIN" -m 0:1048576 -d rocm >> single.log 2>&1

echo "size,latency" > "$CSV_FILE"
awk -F'[ \t]+' '
    $1 ~ /^[0-9]+$/ && $2 ~ /^[0-9.]+$/ {
        print $1 "," $2
    }
' single.log >> "$CSV_FILE"

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

avg_df = df.groupby('size')['latency'].mean().reset_index()

plt.figure(figsize=(12, 12))
plt.plot(avg_df['size'], avg_df['latency'], marker='o', linewidth=2)

plt.axvline(x=32768, color='red', linestyle='--', label='x = 32768')

plt.xscale('log')
plt.yscale('log')
plt.xlabel('Message Size (Bytes)', fontsize=13)
plt.ylabel('Latency (µs)', fontsize=13)
plt.title('Allreduce Latency vs Message Size', fontsize=16)

def sci_notation(x, _):
    if x == 0:
        return "0"
    exponent = int(np.floor(np.log10(x)))
    base = x / 10**exponent
    return rf"\${{{int(base)}}} \times 10^{{{exponent}}}\$"

formatter = FuncFormatter(sci_notation)
plt.gca().yaxis.set_major_formatter(formatter)

plt.grid(True, which='both', linestyle='--', alpha=0.5)
plt.tight_layout()
plt.savefig(plot_file)
print(f"Saved plot to {plot_file}")
EOF