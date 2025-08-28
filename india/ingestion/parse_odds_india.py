#!/usr/bin/env python3
"""
Parse Indian odds PDF text into structured JSON data.
Extracts odds for night, morning, and opening prices.
"""

import re
import json
import sys
import pathlib
from typing import List, Dict, Any, Optional

def frac_to_prob(s: str) -> Optional[float]:
    """
    Convert fractional odds to implied probability.
    
    Args:
        s: Fractional odds string like "3/1" or "5/2"
        
    Returns:
        Implied probability as float, or None if invalid
    """
    if not s:
        return None
        
    m = re.match(r"(\d+)\s*/\s*(\d+)", s)
    if not m:
        return None
        
    a, b = map(int, m.groups())
    if b == 0:
        return None
        
    # Implied probability from fractional odds
    return b / (a + b)

def parse_odds(txt: str) -> List[Dict[str, Any]]:
    """
    Parse odds text and extract structured data.
    
    Args:
        txt: Raw text from PDF conversion
        
    Returns:
        List of dictionaries containing race and odds information
    """
    races = []
    cur = None
    
    for line in txt.splitlines():
        # Match race headers like "THE KOLKATA CUP"
        if re.match(r"\s*THE\s+", line):
            cur = {
                "race_no": len(races) + 1,
                "runners": []
            }
            races.append(cur)
            continue
            
        # Match horse odds like "1  HORSE NAME  3/1  5/2  2/1"
        m = re.match(r"\s*(\d+)\s+([A-Za-z'(). -]+)\s+([0-9/]+)\s*([0-9/]+)?\s*([0-9/]+)?", line)
        if m and cur:
            _, name, night, morn, open_ = m.groups()
            
            cur["runners"].append({
                "horse": name.strip(),
                "p_night": frac_to_prob(night),
                "p_morning": frac_to_prob(morn),
                "p_opening": frac_to_prob(open_)
            })
    
    return races

def main():
    """Main function to parse command line arguments and process file."""
    if len(sys.argv) != 3:
        print("Usage: python parse_odds_india.py <input_txt> <output_json>")
        sys.exit(1)
    
    input_file = sys.argv[1]
    output_file = sys.argv[2]
    
    try:
        # Read input text file
        txt = pathlib.Path(input_file).read_text(errors="ignore")
        
        # Parse the odds
        parsed_data = parse_odds(txt)
        
        # Write output JSON
        pathlib.Path(output_file).write_text(json.dumps(parsed_data, indent=2))
        
        print(f"Successfully parsed odds for {len(parsed_data)} races")
        print(f"Output saved to: {output_file}")
        
    except Exception as e:
        print(f"Error processing file: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
