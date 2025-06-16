#!/bin/bash

# Usage: ./trials.sh <1|2> <num_trials>

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

echo "Saving results to $CSV_FILE"
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

echo "All trials completed. Output: $CSV_FILE"