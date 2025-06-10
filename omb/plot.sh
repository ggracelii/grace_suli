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
    local tmp=$(mktemp)

    for ((i=1; i<=TRIALS; i++)); do
        echo "Running ${backend^^} trial $i..."
        ./run.sh "$backend" "$NUM_RANKS" > "$tmp"

        if [ "$backend" == "auto" ]; then
            awk -v trial="$i" '
                BEGIN { mode = "" }
                /^\[AUTO-MPI\]/ { mode = "auto-mpi"; next }
                /^\[AUTO-RCCL\]/ { mode = "auto-rccl"; next }
                /^[[:digit:]]/ && mode != "" {
                    printf "%s,%s,%s,%.4f\n", $1, mode, trial, $2
                }
            ' "$tmp" >> "$CSV_FILE"
        else
            awk -v backend="$backend" -v trial="$i" '/^[[:digit:]]/ {
                printf "%s,%s,%s,%.4f\n", $1, backend, trial, $2
            }' "$tmp" >> "$CSV_FILE"
        fi
    done

    echo "Extracted data for ${backend^^} into $CSV_FILE"
    rm "$tmp"
}

extract mpich &
pid1=$!

extract mpichccl &
pid2=$!

extract rccl &
pid3=$!

extract auto &
pid4=$!

wait $pid1
wait $pid2
wait $pid3
wait $pid4

cat <<EOF | $HOME/.local/bin/python3.12
import pandas as pd
import matplotlib.pyplot as plt

df = pd.read_csv("$CSV_FILE")

df['backend'] = df['backend'].replace({'auto-mpi': 'auto', 'auto-rccl': 'auto'})

avg_df = df.groupby(['size', 'backend'])['latency'].mean().reset_index()

all_sizes = sorted(df['size'].unique())
pivot_df = avg_df.pivot(index='size', columns='backend', values='latency')
pivot_df = pivot_df.sort_index()

plt.figure(figsize=(10, 6))
for backend in sorted(pivot_df.columns):
    if backend != 'auto':
        plt.plot(pivot_df.index, pivot_df[backend], marker='o', linestyle='-', label=backend.upper())
if 'auto' in pivot_df.columns:
    plt.plot(pivot_df.index, pivot_df['auto'], marker='o', linestyle='-', linewidth=2.5, label='AUTO')

plt.suptitle("Latency across ${NUM_RANKS} ranks", fontsize=14)
plt.title("(Avg of ${TRIALS} trials)", fontsize=10)
plt.xlabel("Size (bytes)")
plt.ylabel("Avg Latency (μs)")
plt.xscale("log")
plt.grid(True)
plt.legend()
plt.tight_layout()
plt.savefig("${PLOT_FILE}")
print(f"Saved plot to ${PLOT_FILE}")
EOF
