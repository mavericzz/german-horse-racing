#!/usr/bin/env python3
"""
Parse Indian race card PDF text into structured JSON data.
Extracts race information, horse details, ratings, weights, etc.
"""

import re
import json
import sys
import pathlib
from typing import List, Dict, Any

def parse_racecard(txt: str) -> List[Dict[str, Any]]:
    """
    Parse race card text and extract structured data.
    
    Args:
        txt: Raw text from PDF conversion
        
    Returns:
        List of dictionaries containing race and horse information
    """
    out = []
    race_no = 0
    race_name = None
    dist = None
    
    for line in txt.splitlines():
        # Match race headers like "THE KOLKATA CUP"
        m_race = re.match(r"\s*THE\s+(.+)", line)
        if m_race:
            race_no += 1
            race_name = m_race.group(1).strip()
            
            # Extract distance from the same line if present
            m_dist = re.search(r"\((\d+)m\)", line)
            if m_dist:
                dist = int(m_dist.group(1))
            continue
            
        # Match horse entries like "1  SPEED DEMON, 3y R-45 55.5"
        m = re.match(r"\s*(\d+)\s+([A-Za-z'(). -]+),\s*(\d+)y\s+R-(\d+)\s+(\d+\.\d{1,2})", line)
        if m and race_name and dist:
            _, horse, age, rating, wt = m.groups()
            out.append({
                "race_no": race_no,
                "race_name": race_name,
                "dist_m": dist,
                "horse": horse.strip(),
                "age": int(age),
                "rating": int(rating),
                "weight_kg": float(wt)
            })
    
    return out

def main():
    """Main function to parse command line arguments and process file."""
    if len(sys.argv) != 3:
        print("Usage: python parse_racecard_india.py <input_txt> <output_json>")
        sys.exit(1)
    
    input_file = sys.argv[1]
    output_file = sys.argv[2]
    
    try:
        # Read input text file
        txt = pathlib.Path(input_file).read_text(errors="ignore")
        
        # Parse the race card
        parsed_data = parse_racecard(txt)
        
        # Write output JSON
        pathlib.Path(output_file).write_text(json.dumps(parsed_data, indent=2))
        
        print(f"Successfully parsed {len(parsed_data)} horse entries")
        print(f"Output saved to: {output_file}")
        
    except Exception as e:
        print(f"Error processing file: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
