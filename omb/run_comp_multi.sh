#!/bin/bash
set -euo pipefail

N=2
PPN=4
NUM_PROCS=$((N * PPN))
BIN="./install/libexec/osu-micro-benchmarks/mpi/collective/osu_allreduce"

CSV_FILE_BASE="comp_multi_data"
CSV_FILE="${CSV_FILE_BASE}.csv"
i=1
while [ -f "$CSV_FILE" ]; do
    CSV_FILE="${CSV_FILE_BASE}_$i.csv"
    ((i++))
done

PLOT_FILE_BASE="comp_multi_graph"
PLOT_FILE="${PLOT_FILE_BASE}.png"
i=1
while [ -f "$PLOT_FILE" ]; do
    PLOT_FILE="${PLOT_FILE_BASE}_$i.png"
    ((i++))
done

echo "size,composition,latency" > "$CSV_FILE"

# RCCL - composition none
echo "Running rccl composition none (rccl-dc-none)..."
mpiexec -n $NUM_PROCS -ppn $PPN -hostfile hosts.txt \
    -genv LD_LIBRARY_PATH "$HOME/rccl/build/lib:/soft/compilers/rocm/rocm-6.3.2/lib:/soft/compilers/rocm/rocm-6.3.2/lib64:$HOME/grace_mpich/build/install/lib:$LD_LIBRARY_PATH" \
    -genv MPIR_CVAR_COLLECTIVE_FALLBACK error \
    -genv MPIR_CVAR_DEVICE_COLLECTIVES none \
    -genv MPIR_CVAR_ALLREDUCE_INTRA_ALGORITHM ccl \
    -genv MPIR_CVAR_ALLREDUCE_CCL rccl \
    -genv MPIR_CVAR_CH4_GPU_COLL_SWAP_BUFFER_SZ 32768 \
    -genv UCX_TLS=tcp,sm,self,rocm \
    "$BIN" -m 0:1048576 -d rocm > tmp_rccl_none.txt
awk -v label="rccl-dc-none" '/^[[:digit:]]/ {
    printf "%s,%s,%.6f\n", $1, label, $2
}' tmp_rccl_none.txt >> "$CSV_FILE"
rm tmp_rccl_none.txt

# RCCL - composition 1 (alpha)
echo "Running rccl composition 1 (rccl-alpha)..."
mpiexec -n $NUM_PROCS -ppn $PPN -hostfile hosts.txt \
    -genv LD_LIBRARY_PATH "$HOME/rccl/build/lib:/soft/compilers/rocm/rocm-6.3.2/lib:/soft/compilers/rocm/rocm-6.3.2/lib64:$HOME/grace_mpich/build/install/lib:$LD_LIBRARY_PATH" \
    -genv MPIR_CVAR_COLLECTIVE_FALLBACK error \
    -genv MPIR_CVAR_DEVICE_COLLECTIVES percoll \
    -genv MPIR_CVAR_ALLREDUCE_DEVICE_COLLECTIVE 1 \
    -genv MPIR_CVAR_ALLREDUCE_INTRA_ALGORITHM ccl \
    -genv MPIR_CVAR_ALLREDUCE_CCL rccl \
    -genv MPIR_CVAR_ALLREDUCE_COMPOSITION 1 \
    -genv MPIR_CVAR_CH4_GPU_COLL_SWAP_BUFFER_SZ 32768 \
    -genv UCX_TLS=tcp,sm,self,rocm \
    "$BIN" -m 0:1048576 -d rocm > tmp_rccl_1.txt
awk -v label="rccl-alpha" '/^[[:digit:]]/ {
    printf "%s,%s,%.6f\n", $1, label, $2
}' tmp_rccl_1.txt >> "$CSV_FILE"
rm tmp_rccl_1.txt

# RCCL - composition 2 (beta)
echo "Running rccl composition 2 (rccl-beta)..."
mpiexec -n $NUM_PROCS -ppn $PPN -hostfile hosts.txt \
    -genv LD_LIBRARY_PATH "$HOME/rccl/build/lib:/soft/compilers/rocm/rocm-6.3.2/lib:/soft/compilers/rocm/rocm-6.3.2/lib64:$HOME/grace_mpich/build/install/lib:$LD_LIBRARY_PATH" \
    -genv MPIR_CVAR_COLLECTIVE_FALLBACK error \
    -genv MPIR_CVAR_DEVICE_COLLECTIVES percoll \
    -genv MPIR_CVAR_ALLREDUCE_DEVICE_COLLECTIVE 1 \
    -genv MPIR_CVAR_ALLREDUCE_INTRA_ALGORITHM ccl \
    -genv MPIR_CVAR_ALLREDUCE_CCL rccl \
    -genv MPIR_CVAR_ALLREDUCE_COMPOSITION 2 \
    -genv MPIR_CVAR_CH4_GPU_COLL_SWAP_BUFFER_SZ 32768 \
    -genv UCX_TLS=tcp,sm,self,rocm \
    "$BIN" -m 0:1048576 -d rocm > tmp_rccl_2.txt
awk -v label="rccl-beta" '/^[[:digit:]]/ {
    printf "%s,%s,%.6f\n", $1, label, $2
}' tmp_rccl_2.txt >> "$CSV_FILE"
rm tmp_rccl_2.txt

# MPI - composition none
echo "Running mpi composition none (mpi-dc-none)..."
mpiexec -n $NUM_PROCS -ppn $PPN -hostfile hosts.txt \
    -genv LD_LIBRARY_PATH "$HOME/grace_mpich/build/install/lib:$LD_LIBRARY_PATH" \
    -genv MPIR_CVAR_COLLECTIVE_FALLBACK error \
    -genv MPIR_CVAR_DEVICE_COLLECTIVES none \
    -genv MPIR_CVAR_CH4_GPU_COLL_SWAP_BUFFER_SZ 32768 \
    -genv UCX_TLS=tcp,sm,self,rocm \
    "$BIN" -m 0:1048576 -d rocm > tmp_mpi_none.txt
awk -v label="mpi-dc-none" '/^[[:digit:]]/ {
    printf "%s,%s,%.6f\n", $1, label, $2
}' tmp_mpi_none.txt >> "$CSV_FILE"
rm tmp_mpi_none.txt

# MPI - composition 1 (alpha)
echo "Running mpi composition 1 (mpi-alpha)..."
mpiexec -n $NUM_PROCS -ppn $PPN -hostfile hosts.txt \
    -genv LD_LIBRARY_PATH "$HOME/grace_mpich/build/install/lib:$LD_LIBRARY_PATH" \
    -genv MPIR_CVAR_COLLECTIVE_FALLBACK error \
    -genv MPIR_CVAR_DEVICE_COLLECTIVES percoll \
    -genv MPIR_CVAR_ALLREDUCE_DEVICE_COLLECTIVE 1 \
    -genv MPIR_CVAR_ALLREDUCE_COMPOSITION 1 \
    -genv MPIR_CVAR_CH4_GPU_COLL_SWAP_BUFFER_SZ 32768 \
    -genv UCX_TLS=tcp,sm,self,rocm \
    "$BIN" -m 0:1048576 -d rocm > tmp_mpi_1.txt
awk -v label="mpi-alpha" '/^[[:digit:]]/ {
    printf "%s,%s,%.6f\n", $1, label, $2
}' tmp_mpi_1.txt >> "$CSV_FILE"
rm tmp_mpi_1.txt

# MPI - composition 2 (beta)
echo "Running mpi composition 2 (mpi-beta)..."
mpiexec -n $NUM_PROCS -ppn $PPN -hostfile hosts.txt \
    -genv LD_LIBRARY_PATH "$HOME/grace_mpich/build/install/lib:$LD_LIBRARY_PATH" \
    -genv MPIR_CVAR_COLLECTIVE_FALLBACK error \
    -genv MPIR_CVAR_DEVICE_COLLECTIVES percoll \
    -genv MPIR_CVAR_ALLREDUCE_DEVICE_COLLECTIVE 1 \
    -genv MPIR_CVAR_ALLREDUCE_COMPOSITION 2 \
    -genv MPIR_CVAR_CH4_GPU_COLL_SWAP_BUFFER_SZ 32768 \
    -genv UCX_TLS=tcp,sm,self,rocm \
    "$BIN" -m 0:1048576 -d rocm > tmp_mpi_2.txt
awk -v label="mpi-beta" '/^[[:digit:]]/ {
    printf "%s,%s,%.6f\n", $1, label, $2
}' tmp_mpi_2.txt >> "$CSV_FILE"
rm tmp_mpi_2.txt

# CH4 JSON tuning-based composition
echo "Running ch4 tuning composition (ch4-tuning)..."
mpiexec -n "$NUM_PROCS" -ppn "$PPN" -hostfile hosts.txt \
    -genv LD_LIBRARY_PATH "$HOME/rccl/build/lib:/soft/compilers/rocm/rocm-6.3.2/lib:/soft/compilers/rocm/rocm-6.3.2/lib64:$HOME/grace_mpich/build/install/lib:$LD_LIBRARY_PATH" \
    -genv MPIR_CVAR_COLLECTIVE_FALLBACK error \
    -genv MPIR_CVAR_DEVICE_COLLECTIVES percoll \
    -genv MPIR_CVAR_ALLREDUCE_DEVICE_COLLECTIVE 1 \
    -genv MPIR_CVAR_ALLREDUCE_INTRA_ALGORITHM ccl \
    -genv MPIR_CVAR_ALLREDUCE_CCL auto \
    -genv MPIR_CVAR_ALLREDUCE_COMPOSITION 0 \
    -genv MPIR_CVAR_CH4_GPU_COLL_SWAP_BUFFER_SZ 32768 \
    -genv MPIR_CVAR_CH4_COLL_SELECTION_TUNING_JSON_FILE ch4_tuning.json \
    -genv UCX_TLS tcp,sm,self,rocm \
    "$BIN" -m 0:1048576 -d rocm > tmp_ch4_tuning.txt
awk -v label="ch4-tuning" '/^[[:digit:]]/ {
    printf "%s,%s,%.6f\n", $1, label, $2
}' tmp_ch4_tuning.txt >> "$CSV_FILE"
rm tmp_ch4_tuning.txt

cat <<EOF | $HOME/.local/bin/python3
import pandas as pd
import subprocess
import time

expected_sizes = [
    4, 8, 16, 32, 64, 128, 256, 512, 1024,
    2048, 4096, 8192, 16384, 32768,
    65536, 131072, 262144, 524288, 1048576
]

expected_compositions = [
    "rccl-dc-none", "rccl-alpha", "rccl-beta",
    "mpi-dc-none", "mpi-alpha", "mpi-beta",
    "ch4-tuning"
]

csv_file = "$CSV_FILE"
for attempt in range(5):
    df = pd.read_csv(csv_file)
    df['latency'] = pd.to_numeric(df['latency'], errors='coerce')

    failed_rows = df[df['latency'].isnull() | (df['latency'] == 0.0)]
    failed_keys = set(failed_rows[['size', 'composition']].itertuples(index=False, name=None))

    existing_keys = set(df[['size', 'composition']].itertuples(index=False, name=None))
    missing_keys = [
        (size, comp)
        for size in expected_sizes
        for comp in expected_compositions
        if (size, comp) not in existing_keys
    ]

    failed = list(failed_keys.union(missing_keys))

    if not failed:
        print("No missing or invalid latency rows remain.")
        break

    print(f"Attempt {attempt+1}: Found {len(failed)} zero-latency rows. Retrying...")

    replacements = []
    new_fails = []

    for (size, comp) in failed:
        label = comp.lower()
        comp_id = {
            "rccl-alpha": 1, "rccl-beta": 2, "rccl-gamma": 3, "rccl-delta": 4,
            "mpi-alpha": 1, "mpi-beta": 2, "mpi-gamma": 3, "mpi-delta": 4,
            "ch4-tuning": 0
        }.get(label, None)
        dc_flag = "none" if "dc-none" in label else "percoll"

        tmpfile = f"tmp_retry_{label}_{size}.out"
        cmd = [
            "mpiexec", "-n", str(8), "-ppn", str(4), "-hostfile", "hosts.txt",
            "-genv", "LD_LIBRARY_PATH=$HOME/rccl/build/lib:/soft/compilers/rocm/rocm-6.3.2/lib:/soft/compilers/rocm/rocm-6.3.2/lib64:$HOME/grace_mpich/build/install/lib:$LD_LIBRARY_PATH",
            "-genv", "UCX_TLS=tcp,sm,self,rocm"
        ]
        if label == "ch4-tuning":
            cmd += [
                "-genv", "MPIR_CVAR_DEVICE_COLLECTIVES", "percoll",
                "-genv", "MPIR_CVAR_ALLREDUCE_DEVICE_COLLECTIVE", "1",
                "-genv", "MPIR_CVAR_ALLREDUCE_INTRA_ALGORITHM", "ccl",
                "-genv", "MPIR_CVAR_ALLREDUCE_CCL", "auto",
                "-genv", "MPIR_CVAR_ALLREDUCE_COMPOSITION", "0",
                "-genv", "MPIR_CVAR_CH4_COLL_SELECTION_TUNING_JSON_FILE", "ch4_tuning.json"
            ]
        elif dc_flag == "none":
            cmd += ["-genv", "MPIR_CVAR_DEVICE_COLLECTIVES", "none",
                    "-genvnone", "MPIR_CVAR_CH4_COLL_SELECTION_TUNING_JSON_FILE"]
        else:
            cmd += [
                "-genv", "MPIR_CVAR_DEVICE_COLLECTIVES", "percoll",
                "-genv", "MPIR_CVAR_ALLREDUCE_DEVICE_COLLECTIVE", "1",
                "-genv", "MPIR_CVAR_ALLREDUCE_COMPOSITION", str(comp_id),
                "-genvnone", "MPIR_CVAR_CH4_COLL_SELECTION_TUNING_JSON_FILE"            
            ]

        cmd += ["./install/libexec/osu-micro-benchmarks/mpi/collective/osu_allreduce", "-m", f"{size}:{size}", "-d", "rocm"]

        print(f"Retrying {label} @ {size}...")
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

    # Remove old bad rows and insert good ones
    df = df[~df[['size', 'composition']].apply(tuple, axis=1).isin(failed)]
    retry_df = pd.DataFrame(replacements, columns=["size", "composition", "latency"])
    new_df = pd.concat([df, retry_df]).drop_duplicates(subset=["size", "composition"], keep="last")
    new_df = new_df.sort_values(by=["composition", "size"])
    new_df.to_csv(csv_file, index=False)

    if not new_fails:
        print("All retries successful.")
        break
EOF

rm *.out

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

avg_df = df.groupby(['size', 'composition'])['latency'].mean().reset_index()
pivot_df = avg_df.pivot(index='size', columns='composition', values='latency')

plt.figure(figsize=(12, 12))

ordered_comps = [
    "mpi-dc-none",
    "mpi-alpha",
    "mpi-beta",
    "rccl-dc-none",
    "rccl-alpha",
    "rccl-beta"
]

color_map = {
    "mpi-dc-none": "blue",
    "mpi-alpha": "green",
    "mpi-beta": "orange",
    "rccl-dc-none": "brown",
    "rccl-alpha": "purple",
    "rccl-beta": "pink"
}

for comp in ordered_comps:
    if comp in pivot_df.columns:
        plt.plot(
            pivot_df.index,
            pivot_df[comp],
            marker='o',
            linewidth=1.5,
            label=comp,
            color=color_map[comp]
        )

if "ch4-tuning" in pivot_df.columns:
    plt.plot(
        pivot_df.index,
        pivot_df["ch4-tuning"],
        marker='o',
        linewidth=4.5,
        label="ch4-tuning",
        color="red"
    )

plt.axvline(x=32768, color='black', linestyle='--', label='threshold = 32768')

plt.xscale('log')
plt.yscale('log')
plt.xlabel('Message Size (Bytes)', fontsize=13)
plt.ylabel('Latency (µs)', fontsize=13)
plt.title('Allreduce Latency by Composition (2 nodes)', fontsize=16)

def sci_notation(x, _):
    if x == 0:
        return "0"
    exponent = int(np.floor(np.log10(x)))
    base = x / 10**exponent
    return rf"\${{{int(base)}}} \times 10^{{{exponent}}}\$"

formatter = FuncFormatter(sci_notation)
plt.gca().yaxis.set_major_formatter(formatter)

plt.grid(True, which='both', linestyle='--', alpha=0.5)
plt.legend(title='Composition')
plt.tight_layout()
plt.savefig(plot_file)
print(f"Saved plot to {plot_file}")
EOF
