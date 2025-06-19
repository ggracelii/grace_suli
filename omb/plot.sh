#!/bin/bash

# Usage: ./plot.sh <csv_file> <num_nodes>

set -e

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <csv_file> <num_nodes>"
    exit 1
fi

CSV_FILE=$1
if [ ! -f "$CSV_FILE" ]; then
    echo "CSV file not found: $CSV_FILE"
    exit 1
fi

NODES=$2

PLOT_FILE_BASE="graph"
PLOT_FILE="${PLOT_FILE_BASE}.png"
i=1
while [ -f "$PLOT_FILE" ]; do
    PLOT_FILE="${PLOT_FILE_BASE}_$i.png"
    ((i++))
done

cat <<EOF | $HOME/.local/bin/python3.12
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from matplotlib.ticker import LogLocator, LogFormatter, FuncFormatter

df = pd.read_csv("$CSV_FILE")
df['size'] = pd.to_numeric(df['size'], errors='coerce')
df['latency'] = pd.to_numeric(df['latency'], errors='coerce')
df = df.dropna(subset=['size', 'latency'])
df = df[df['latency'] > 0]
df = df.sort_values('size')

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
plt.ylim(auto=True)
plt.xlabel('Message Size (Bytes)', fontsize=13)
plt.ylabel('Latency (µs)', fontsize=13)
legend = plt.legend(title='Backend')
legend.get_title().set_fontsize(12)

ax = plt.gca()
lat_min = df['latency'].min()
lat_max = df['latency'].max()
decades = int(np.floor(np.log10(lat_min)))
decades_end = int(np.ceil(np.log10(lat_max)))
tick_locs = []
for exp in range(decades, decades_end + 1):
    tick_locs.extend([i * 10**exp for i in range(1, 10)])
tick_locs = [t for t in tick_locs if lat_min <= t <= lat_max]
def sci_notation(x, _):
    if x == 0:
        return "0"
    exponent = int(np.floor(np.log10(x)))
    base = x / 10**exponent
    return fr"\${int(base)} \times 10^{exponent}\$"
formatter = FuncFormatter(sci_notation)
ax.set_yscale('log')
ax.set_yticks(tick_locs)
ax.yaxis.set_major_formatter(formatter)
plt.grid(True, which='both', linestyle='--', alpha=0.5)

plt.text(
    0.5, 1.05,
    'Allreduce Latency for $NODES node(s) - avg of 10 trials',
    fontsize=20,
    horizontalalignment='center',
    transform=plt.gca().transAxes
)

plt.subplots_adjust(top=0.8) 
plt.tight_layout()
plt.savefig("${PLOT_FILE}")
print(f"Saved plot to ${PLOT_FILE}")
EOF