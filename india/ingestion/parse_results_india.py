#!/usr/bin/env python3
"""
Parse Indian race results PDF text into structured JSON data.
Extracts finishing positions and horse names.
"""

import re
import json
import sys
import pathlib
from typing import List, Dict, Any

def parse_results(txt: str) -> List[Dict[str, Any]]:
    """
    Parse results text and extract structured data.
    
    Args:
        txt: Raw text from PDF conversion
        
    Returns:
        List of dictionaries containing race results
    """
    out = []
    cur = None
    
    for line in txt.splitlines():
        # Match race headers like "RACE 1" or "RACE 1:"
        if re.match(r"\s*RACE\s*\d+", line):
            cur = {
                "race_no": len(out) + 1,
                "placings": []
            }
            out.append(cur)
            continue
            
        # Match finishing positions like "1st : HORSE NAME" or "1st: HORSE NAME"
        m = re.match(r"\s*(\d)(st|nd|rd|th)\s*:?\s*([A-Za-z'(). -]+)", line)
        if m and cur:
            pos, suffix, horse = m.groups()
            
            cur["placings"].append({
                "pos": int(pos),
                "horse": horse.strip()
            })
    
    return out

def main():
    """Main function to parse command line arguments and process file."""
    if len(sys.argv) != 3:
        print("Usage: python parse_results_india.py <input_txt> <output_json>")
        sys.exit(1)
    
    input_file = sys.argv[1]
    output_file = sys.argv[2]
    
    try:
        # Read input text file
        txt = pathlib.Path(input_file).read_text(errors="ignore")
        
        # Parse the results
        parsed_data = parse_results(txt)
        
        # Write output JSON
        pathlib.Path(output_file).write_text(json.dumps(parsed_data, indent=2))
        
        print(f"Successfully parsed results for {len(parsed_data)} races")
        print(f"Output saved to: {output_file}")
        
    except Exception as e:
        print(f"Error processing file: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
