#!/bin/bash

# Usage: ./plot.sh <num_trials> <num_ranks>

set -e

TRIALS=$1
NUM_RANKS=$2

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

if [ -z "$TRIALS" ] || [ -z "$NUM_RANKS" ]; then
    echo "Usage: $0 <num_trials> <num_ranks>"
    exit 1
fi

echo "size,backend,trial,latency" > "$CSV_FILE"

extract() {
    local backend=$1
    local flag=$2
    local tmp=$(mktemp)

    for ((i=1; i<=TRIALS; i++)); do
        echo "Running ${backend^^}${flag:+ +$flag} trial $i..."
        ./run.sh "$backend" "$NUM_RANKS" "$flag" > "$tmp"
        awk -v backend="$backend${flag:+_$flag}" -v trial="$i" '/^[[:digit:]]/ {printf "%s,%s,%s,%.4f\n", $1, backend, trial, $2}' "$tmp" >> "$CSV_FILE"
    done
    echo "Extracted data for ${backend^^}${flag:+ +$flag} into $CSV_FILE"

    rm "$tmp"
}

extract mpi         # default MPI
extract mpi ccl     # MPI + CCL
extract rccl        # RCCL backend

cat <<EOF | $HOME/.local/bin/python3.12
import pandas as pd
import matplotlib.pyplot as plt

df = pd.read_csv("$CSV_FILE")
avg_df = df.groupby(['size', 'backend'])['latency'].mean().reset_index()
pivot_df = avg_df.pivot(index='size', columns='backend', values='latency')
pivot_df.sort_index(inplace=True)

plt.figure(figsize=(10, 6))
for backend in pivot_df.columns:
    plt.plot(pivot_df.index, pivot_df[backend], marker='o', label=backend.upper())

plt.suptitle("Avg Latency across ${NUM_RANKS} ranks", fontsize=14)
plt.title("(Average of ${TRIALS} trials)", fontsize=10)
plt.xlabel("size (bytes)")
plt.ylabel("avg latency (μs)")
plt.xscale("log")
plt.grid(True)
plt.legend()
plt.tight_layout()
plt.savefig("${PLOT_FILE}")
print(f"Saved plot to ${PLOT_FILE}")
EOF
