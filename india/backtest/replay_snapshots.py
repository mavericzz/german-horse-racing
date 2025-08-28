#!/usr/bin/env python3
"""
Replay historical snapshots using the Benter model.
Applies the model to historical data and records predictions vs actual results.
"""

import pandas as pd
import numpy as np
import json
import pathlib
import sys

# Add parent directory to path for imports
sys.path.insert(0, str(pathlib.Path(__file__).parent.parent.parent))
from india.model.combiner_india import posterior_for_race

def replay_meeting(features_file: str, results_file: str, output_file: str) -> None:
    """
    Replay a meeting using the Benter model.
    
    Args:
        features_file: Path to features Parquet file
        results_file: Path to results JSON file
        output_file: Path to output CSV file
    """
    # Read features
    features = pd.read_parquet(features_file)
    
    # Read results
    with open(results_file, 'r') as f:
        results = json.load(f)
    
    # Create mapping of race number to horse positions
    res_map = {}
    for r in results:
        race_no = r["race_no"]
        horse_positions = {}
        for p in r["placings"]:
            horse_positions[p["horse"].lower()] = p["pos"]
        res_map[race_no] = horse_positions
    
    rows = []
    
    # Process each race
    for rno, group in features.groupby("race_no"):
        # Apply Benter model
        df = posterior_for_race(group, use="p_opening")
        
        # Add actual finishing positions
        h2pos = res_map.get(rno, {})
        df["pos"] = (df["horse"]
                    .str.lower()
                    .map(h2pos)
                    .fillna(99)
                    .astype(int))
        
        rows.append(df)
    
    # Combine all races
    out = pd.concat(rows, ignore_index=True)
    
    # Save results
    out.to_csv(output_file, index=False)
    
    print(f"Replay complete for {len(out)} horse entries")
    print(f"Results saved to: {output_file}")

def main():
    """Main function to parse command line arguments and process files."""
    if len(sys.argv) != 4:
        print("Usage: python replay_snapshots.py <features_parquet> <results_json> <output_csv>")
        sys.exit(1)
    
    features_file = sys.argv[1]
    results_file = sys.argv[2]
    output_file = sys.argv[3]
    
    try:
        replay_meeting(features_file, results_file, output_file)
    except Exception as e:
        print(f"Error during replay: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
