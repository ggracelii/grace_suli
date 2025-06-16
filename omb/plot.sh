#!/bin/bash

# Usage: ./plot.sh <1|2> <num_trials>

set -e

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <1|2> <num_trials>"
    exit 1
fi

NODE_MODE=$1
TRIALS=$2

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

echo "size,backend,trial,latency" > "$CSV_FILE"

extract() {
    local backend=$1
    local tmp=$(mktemp)

    for ((i=1; i<=TRIALS; i++)); do
        echo "Running ${backend^^} trial $i..."
        ./run.sh "$backend" "$NODE_MODE" > "$tmp"

        awk -v backend="$backend" -v trial="$i" '/^[[:digit:]]/ {
            printf "%s,%s,%s,%.4f\n", $1, backend, trial, $2
        }' "$tmp" >> "$CSV_FILE"
    done

    echo "Extracted data for ${backend^^} into $CSV_FILE"
    rm "$tmp"
}

extract mpich     
extract mpichccl  
extract rccl    
extract auto      

cat <<EOF | $HOME/.local/bin/python3.12
import pandas as pd
import matplotlib.pyplot as plt

df = pd.read_csv("$CSV_FILE")
avg_df = df.groupby(['size', 'backend'])['latency'].mean().reset_index()

pivot_df = avg_df.pivot(index='size', columns='backend', values='latency')
pivot_df = pivot_df.sort_index()

plt.figure(figsize=(10, 6))
for backend in sorted(pivot_df.columns):
    label = backend.upper() + (" (Multi)" if "$NODE_MODE" == "2" else " (Single)")
    plt.plot(pivot_df.index, pivot_df[backend], marker='o', label=label)

plt.suptitle("Allreduce Latency (log-scale size)", fontsize=14)
plt.title(f"(Avg of {TRIALS} trials)", fontsize=10)
plt.xlabel("Size (bytes)")
plt.ylabel("Avg Latency (μs)")
plt.xscale("log")
plt.grid(True)
plt.legend()
plt.tight_layout()
plt.savefig("${PLOT_FILE}")
print(f"Saved plot to ${PLOT_FILE}")
EOF