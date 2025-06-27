#!/bin/bash
set -euo pipefail

# Usage: ./run_comp_mpi_multi.sh

N=2
PPN=4
NUM_PROCS=$((N * PPN))
BIN="./install/libexec/osu-micro-benchmarks/mpi/collective/osu_allreduce"

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

run_composition () {
    local comp=$1
    local label

    case "$comp" in
        1) label="alpha" ;;
        2) label="beta" ;;
        3) label="gamma" ;;
        4) label="delta" ;;
        *) echo "Unsupported composition: $comp" >&2; exit 1 ;;
    esac

    echo "Running Composition $comp (${label})..."
    TMP=$(mktemp)
    mpiexec -n $NUM_PROCS -ppn $PPN -hostfile hosts.txt \
        -genv LD_LIBRARY_PATH=$HOME/grace_mpich/build/install/lib:$LD_LIBRARY_PATH \
        -genv MPIR_CVAR_DEVICE_COLLECTIVES percoll \
        -genv MPIR_CVAR_ALLREDUCE_DEVICE_COLLECTIVE 1 \
        -genv MPIR_CVAR_ALLREDUCE_COMPOSITION $comp \
        -genv UCX_TLS=tcp,self,sm \
        "$BIN" -m 0:1048576 > "$TMP"
    
    awk -v label="$label" '/^[[:digit:]]/ {
        printf "%s,%s,%.6f\n", $1, label, $2
    }' "$TMP" >> "$CSV_FILE"
    rm "$TMP"
}

run_dc_none () {
    local label="dc-none"
    echo "Running Device Collectives None..."
    TMP=$(mktemp)
    mpiexec -n $NUM_PROCS -ppn $PPN -hostfile hosts.txt \
        -genv LD_LIBRARY_PATH=$HOME/grace_mpich/build/install/lib:$LD_LIBRARY_PATH \
        -genv MPIR_CVAR_DEVICE_COLLECTIVES none \
        -genv UCX_TLS=tcp,self,sm \
        "$BIN" -m 0:1048576 > "$TMP"

    awk -v label="$label" '/^[[:digit:]]/ {
        printf "%s,%s,%.6f\n", $1, label, $2
    }' "$TMP" >> "$CSV_FILE"
    rm "$TMP"
}

run_dc_none

for COMP in 1 2; do
    run_composition $COMP
done

echo "Initial run complete. Checking for failed measurements..."

# Retry until no zeros remain
RETRIES=5
cat <<EOF | $HOME/.local/bin/python3
import pandas as pd
import subprocess
import time

csv_path = "$CSV_FILE"

for attempt in range($RETRIES):
    df = pd.read_csv(csv_path)
    failed = df[df['latency'] == 0.0]
    if failed.empty:
        print("No zero-latency rows remain.")
        break

    print(f"Attempt {attempt+1}: Found {len(failed)} zero-latency rows. Retrying...")

    replacements = []
    new_fails = []

    for (size, comp) in failed[['size', 'composition']].drop_duplicates().itertuples(index=False):
        label = comp.lower()
        comp_id = {"alpha": 1, "beta": 2, "gamma": 3, "delta": 4}.get(label, None)
        dc_flag = "none" if label == "dc-none" else "percoll"

        tmpfile = f"tmp_retry_{label}_{size}.out"
        cmd = [
            "mpiexec", "-n", str($NUM_PROCS), "-ppn", str($PPN), "-hostfile", "hosts.txt",
            "-genv", "LD_LIBRARY_PATH=$HOME/grace_mpich/build/install/lib:$LD_LIBRARY_PATH",
            "-genv", "UCX_TLS=tcp,self,sm"
        ]
        if dc_flag == "none":
            cmd += ["-genv", "MPIR_CVAR_DEVICE_COLLECTIVES", "none"]
        else:
            cmd += [
                "-genv", "MPIR_CVAR_DEVICE_COLLECTIVES", "percoll",
                "-genv", "MPIR_CVAR_ALLREDUCE_DEVICE_COLLECTIVE", "1",
                "-genv", "MPIR_CVAR_ALLREDUCE_COMPOSITION", str(comp_id)
            ]
        cmd += ["$BIN", "-m", f"{size}:{size}"]
        print(f"Running retry for {label} at size {size}")
        with open(tmpfile, "w") as f:
            subprocess.run(cmd, stdout=f, stderr=subprocess.DEVNULL)

        with open(tmpfile, "r") as f:
            for line in f:
                if not line.strip() or not line[0].isdigit():
                    continue
                tokens = line.strip().split()
                if len(tokens) < 2 or '*' in tokens:
                    new_fails.append((size, comp))
                    continue
                try:
                    size_parsed = int(tokens[0])
                    latency = float(tokens[1])
                    if latency == 0.0:
                        new_fails.append((size_parsed, comp))
                    else:
                        replacements.append((size_parsed, comp, latency))
                except ValueError:
                    new_fails.append((size, comp))

    # Remove all failed rows from original
    df = df[df['latency'] > 0.0]
    retry_df = pd.DataFrame(replacements, columns=["size", "composition", "latency"])
    new_df = pd.concat([df, retry_df]).drop_duplicates(subset=["size", "composition"], keep="last")
    new_df.to_csv(csv_path, index=False)

    if not new_fails:
        print("All retries successful.")
        break
EOF

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
plt.title('Allreduce Latency by Composition (MPI for 2 nodes)', fontsize=16)

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