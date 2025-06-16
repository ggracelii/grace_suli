#!/bin/bash

# Usage: ./plot.sh <csv_file>

set -e

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <csv_file>"
    exit 1
fi

CSV_FILE=$1
if [ ! -f "$CSV_FILE" ]; then
    echo "CSV file not found: $CSV_FILE"
    exit 1
fi

PLOT_FILE_BASE="graph"
PLOT_FILE="${PLOT_FILE_BASE}.png"
i=1
while [ -f "$PLOT_FILE" ]; do
    PLOT_FILE="${PLOT_FILE_BASE}_$i.png"
    ((i++))
done

cat <<EOF | $HOME/.local/bin/python3.12
import pandas as pd
import matplotlib.pyplot as plt

df = pd.read_csv("$CSV_FILE")
avg_df = df.groupby(['size', 'backend'])['latency'].mean().reset_index()

pivot_df = avg_df.pivot(index='size', columns='backend', values='latency')
pivot_df = pivot_df.sort_index()

plt.figure(figsize=(10, 6))
for backend in sorted(pivot_df.columns):
    label = backend.upper()
    plt.plot(pivot_df.index, pivot_df[backend], marker='o', label=label)

plt.suptitle("Allreduce Latency (log-scale size)", fontsize=14)
plt.title("Averaged Latency over Trials", fontsize=10)
plt.xlabel("Size (bytes)")
plt.ylabel("Avg Latency (μs)")
plt.xscale("log")
plt.grid(True)
plt.legend()
plt.tight_layout()
plt.savefig("${PLOT_FILE}")
print(f"Saved plot to ${PLOT_FILE}")
EOF