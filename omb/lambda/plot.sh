#!/bin/bash
set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <csv_file_base>"
    exit 1
fi

CSV_BASE="$1"
CSV_FILE="${CSV_BASE}.csv"
PLOT_FILE="${CSV_BASE}.png"

cat <<EOF | $HOME/.local/bin/python3
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.ticker import FuncFormatter
import os

csv_file = "${CSV_FILE}"
plot_file = "${PLOT_FILE}"
base_name = os.path.splitext(os.path.basename(csv_file))[0]

# === Load CSV ===
df = pd.read_csv(csv_file)
df['composition'] = base_name
df['size'] = pd.to_numeric(df['size'], errors='coerce')
df['latency'] = pd.to_numeric(df['latency'], errors='coerce')
df = df.dropna(subset=['size', 'latency'])
df = df[df['latency'] > 0]

# Optionally include og_beta.csv
if base_name != "og_beta" and os.path.exists("og_beta.csv"):
    og_df = pd.read_csv("og_beta.csv")
    og_df['composition'] = 'og_beta'
    og_df['size'] = pd.to_numeric(og_df['size'], errors='coerce')
    og_df['latency'] = pd.to_numeric(og_df['latency'], errors='coerce')
    og_df = og_df.dropna(subset=['size', 'latency'])
    og_df = og_df[og_df['latency'] > 0]
    df = pd.concat([df, og_df], ignore_index=True)

# === Group and pivot ===
avg_df = df.groupby(['size', 'composition'])['latency'].mean().reset_index()
pivot_df = avg_df.pivot(index='size', columns='composition', values='latency')

# === Plot ===
plt.figure(figsize=(10, 10))
for label in pivot_df.columns:
    plt.plot(pivot_df.index, pivot_df[label], marker='o', linewidth=2, label=label)

plt.xscale('log')
plt.yscale('log')
plt.xlabel('Message Size (Bytes)', fontsize=13)
plt.ylabel('Latency (µs)', fontsize=13)
plt.title(f'Allreduce Latency: {base_name}', fontsize=16)

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
plt.savefig(plot_file)
print(f"Saved plot to {plot_file}")
EOF