#!/bin/bash

# Usage: ./plot.sh <num_trials>

set -e

TRIALS=$1

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

if [ -z "$TRIALS" ]; then
    echo "Usage: $0 <num_trials>"
    exit 1
fi

echo "size,backend,trial,latency" > "$CSV_FILE"

extract() {
    local script=$1
    local label=$2
    local tmp=$(mktemp)

    for ((i=1; i<=TRIALS; i++)); do
        echo "Running ${label^^} trial $i..."
        "./$script" > "$tmp"

        awk -v backend="$label" -v trial="$i" '/^[[:digit:]]/ {
            printf "%s,%s,%s,%.4f\n", $1, backend, trial, $2
        }' "$tmp" >> "$CSV_FILE"
    done

    echo "Extracted data for ${label^^} into $CSV_FILE"
    rm "$tmp"
}

# Run backends in parallel
extract run_mpich_single.sh     mpich      &
pid1=$!

extract run_mpich_multi.sh      mpich_n    &
pid2=$!

extract run_mpichccl_single.sh  mpichccl   &
pid3=$!

extract run_mpichccl_multi.sh   mpichccl_n &
pid4=$!

extract run_rccl_single.sh      rccl       &
pid5=$!

extract run_rccl_multi.sh       rccl_n     &
pid6=$!

# Optional auto backend (commented out)
# extract run_auto_single.sh      auto       &
# extract run_auto_multi.sh       auto_n     &

wait $pid1 $pid2 $pid3 $pid4 $pid5 $pid6

# Plotting
cat <<EOF | $HOME/.local/bin/python3.12
import pandas as pd
import matplotlib.pyplot as plt

df = pd.read_csv("$CSV_FILE")
avg_df = df.groupby(['size', 'backend'])['latency'].mean().reset_index()

pivot_df = avg_df.pivot(index='size', columns='backend', values='latency')
pivot_df = pivot_df.sort_index()

plt.figure(figsize=(10, 6))
for backend in sorted(pivot_df.columns):
    label = backend.upper().replace("_N", " (Multi)") if "_n" in backend else backend.upper()
    plt.plot(pivot_df.index, pivot_df[backend], marker='o', linestyle='-', label=label)

plt.suptitle("Allreduce Latency (log-scale size)", fontsize=14)
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