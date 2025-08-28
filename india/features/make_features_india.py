#!/usr/bin/env python3
"""
Combine race card and odds data to create features for Indian racing.
Merges horse information with market probabilities.
"""

import json
import sys
import pathlib
import pandas as pd
import re
from typing import Dict, Any

def normalize_horse_name(s: str) -> str:
    """
    Normalize horse name for matching between datasets.
    
    Args:
        s: Horse name string
        
    Returns:
        Normalized name (lowercase, alphanumeric only)
    """
    return "".join(ch for ch in s.lower() if ch.isalnum())

def create_features(card_file: str, odds_file: str, output_file: str) -> None:
    """
    Create features by combining race card and odds data.
    
    Args:
        card_file: Path to race card JSON file
        odds_file: Path to odds JSON file
        output_file: Path to output Parquet file
    """
    # Read race card data
    card = pd.read_json(card_file)
    
    # Read odds data
    with open(odds_file, 'r') as f:
        odds = json.load(f)
    
    rows = []
    
    # Process each race
    for race in odds:
        rno = race["race_no"]
        
        # Create mapping of normalized horse names to odds
        odds_map = {normalize_horse_name(r["horse"]): r for r in race["runners"]}
        
        # Get race card data for this race
        race_card = card[card.race_no == rno].copy()
        
        # Combine data for each horse
        for _, entry in race_card.iterrows():
            key = normalize_horse_name(entry.horse)
            odds_entry = odds_map.get(key, {})
            
            rows.append({
                "race_no": rno,
                "race_name": entry.race_name,
                "dist_m": entry.dist_m,
                "horse": entry.horse,
                "age": entry.age,
                "rating": entry.rating,
                "weight_kg": entry.weight_kg,
                "p_night": odds_entry.get("p_night"),
                "p_morning": odds_entry.get("p_morning"),
                "p_opening": odds_entry.get("p_opening")
            })
    
    # Create features DataFrame
    features = pd.DataFrame(rows)
    
    # Save to Parquet
    features.to_parquet(output_file, index=False)
    
    print(f"Created features for {len(features)} horse entries")
    print(f"Features saved to: {output_file}")

def main():
    """Main function to parse command line arguments and process files."""
    if len(sys.argv) != 4:
        print("Usage: python make_features_india.py <card_json> <odds_json> <output_parquet>")
        sys.exit(1)
    
    card_file = sys.argv[1]
    odds_file = sys.argv[2]
    output_file = sys.argv[3]
    
    try:
        create_features(card_file, odds_file, output_file)
    except Exception as e:
        print(f"Error creating features: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
