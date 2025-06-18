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
df['size'] = pd.to_numeric(df['size'], errors='coerce')
df = df.dropna(subset=['size']).sort_values('size')

avg_df = df.groupby(['size', 'backend'])['latency'].mean().reset_index()
pivot_df = avg_df.pivot(index='size', columns='backend', values='latency')
plt.figure(figsize=(10, 10))
for backend in pivot_df.columns:
      plt.plot(
          pivot_df.index,
          pivot_df[backend],
          marker='o',
          linewidth=2,
          label=backend.upper(),
      )

plt.xscale('log')
plt.yscale('log')
plt.xlabel('Message Size (Bytes)', fontsize=13)
plt.ylabel('Latency (µs)', fontsize=13)
legend = plt.legend(title='Backend')
legend.get_title().set_fontsize(12)

from matplotlib.ticker import MultipleLocator
ax = plt.gca()
ax.yaxis.set_major_locator(MultipleLocator(500))
ax.yaxis.set_minor_locator(MultipleLocator(100))

plt.grid(True, which='both', linestyle='--', alpha=0.5)

plt.text(
    0.5, 1.05,
    'Allreduce Latency (avg of 10 trials)',
    fontsize=20,
    horizontalalignment='center',
    transform=plt.gca().transAxes
)

plt.subplots_adjust(top=0.8) 
plt.tight_layout()
plt.savefig("${PLOT_FILE}")
print(f"Saved plot to ${PLOT_FILE}")
EOF