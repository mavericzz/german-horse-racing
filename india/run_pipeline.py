#!/usr/bin/env python3
"""
Main script to run the complete India racing pipeline.
This demonstrates the end-to-end process from PDF parsing to model evaluation.
"""

import subprocess
import pathlib
import sys
import json
import pandas as pd

def run_command(cmd, description):
    """Run a command and handle errors."""
    print(f"\n{'='*60}")
    print(f"Running: {description}")
    print(f"Command: {' '.join(cmd)}")
    print('='*60)
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        print("✓ Success!")
        if result.stdout:
            print(result.stdout)
        return True
    except subprocess.CalledProcessError as e:
        print(f"✗ Failed with exit code {e.returncode}")
        if e.stderr:
            print(f"Error: {e.stderr}")
        return False

def main():
    """Run the complete pipeline."""
    print("🏇 Indian Racing Benter Model Pipeline")
    print("=" * 60)
    
    # Configuration
    MEETING = "2025-08-27-kolkata"
    DATA_ROOT = pathlib.Path("data")
    INDIA_ROOT = pathlib.Path("india")
    
    # Ensure we're in the right directory
    if not (DATA_ROOT / "raw" / MEETING).exists():
        print(f"❌ Meeting data not found: {DATA_ROOT / 'raw' / MEETING}")
        print("Please ensure the PDF files are in the correct location.")
        return False
    
    print(f"📁 Processing meeting: {MEETING}")
    print(f"📂 Data root: {DATA_ROOT.absolute()}")
    
    # Step 1: PDF to Text Conversion
    if not run_command([
        str(INDIA_ROOT / "ingestion" / "to_text.sh"),
        MEETING
    ], "PDF to Text Conversion"):
        print("⚠️  PDF conversion failed. This is expected if pdftotext is not installed.")
        print("   Using sample text files for demonstration.")
    
    # Step 2: Parse Race Card
    if not run_command([
        "python3", str(INDIA_ROOT / "ingestion" / "parse_racecard_india.py"),
        str(DATA_ROOT / "txt" / MEETING / "racecard.pdf"),
        str(DATA_ROOT / "bronze" / f"{MEETING}-card.json")
    ], "Parse Race Card"):
        return False
    
    # Step 3: Parse Odds
    if not run_command([
        "python3", str(INDIA_ROOT / "ingestion" / "parse_odds_india.py"),
        str(DATA_ROOT / "txt" / MEETING / "odds_opening.pdf"),
        str(DATA_ROOT / "bronze" / f"{MEETING}-odds.json")
    ], "Parse Opening Odds"):
        return False
    
    # Step 4: Parse Results
    if not run_command([
        "python3", str(INDIA_ROOT / "ingestion" / "parse_results_india.py"),
        str(DATA_ROOT / "txt" / MEETING / "results.pdf"),
        str(DATA_ROOT / "bronze" / f"{MEETING}-results.json")
    ], "Parse Race Results"):
        return False
    
    # Step 5: Create Features
    if not run_command([
        "python3", str(INDIA_ROOT / "features" / "make_features_india.py"),
        str(DATA_ROOT / "bronze" / f"{MEETING}-card.json"),
        str(DATA_ROOT / "bronze" / f"{MEETING}-odds.json"),
        str(DATA_ROOT / "silver" / f"{MEETING}-features.parquet")
    ], "Create Features"):
        return False
    
    # Step 6: Run Backtesting
    if not run_command([
        "python3", str(INDIA_ROOT / "backtest" / "replay_snapshots.py"),
        str(DATA_ROOT / "silver" / f"{MEETING}-features.parquet"),
        str(DATA_ROOT / "bronze" / f"{MEETING}-results.json"),
        str(DATA_ROOT / "reports" / f"{MEETING}-meeting.csv")
    ], "Run Backtesting"):
        return False
    
    # Step 7: Calculate Metrics
    if not run_command([
        "python3", str(INDIA_ROOT / "backtest" / "metrics.py"),
        str(DATA_ROOT / "reports" / f"{MEETING}-meeting.csv")
    ], "Calculate Performance Metrics"):
        return False
    
    # Step 8: Display Summary
    print(f"\n{'='*60}")
    print("🎯 PIPELINE COMPLETE!")
    print('='*60)
    
    # Show file sizes
    print("\n📊 Generated Files:")
    for file_path in [
        f"bronze/{MEETING}-card.json",
        f"bronze/{MEETING}-odds.json", 
        f"bronze/{MEETING}-results.json",
        f"silver/{MEETING}-features.parquet",
        f"reports/{MEETING}-meeting.csv"
    ]:
        full_path = DATA_ROOT / file_path
        if full_path.exists():
            size = full_path.stat().st_size
            print(f"  ✓ {file_path} ({size:,} bytes)")
        else:
            print(f"  ✗ {file_path} (missing)")
    
    # Show sample results
    results_file = DATA_ROOT / "reports" / f"{MEETING}-meeting.csv"
    if results_file.exists():
        print(f"\n📈 Sample Results:")
        df = pd.read_csv(results_file)
        print(f"  Total horses: {len(df)}")
        print(f"  Total races: {df['race_no'].nunique()}")
        print(f"  Distance range: {df['dist_m'].min()}m - {df['dist_m'].max()}m")
        
        # Show top picks
        print(f"\n🏆 Top Picks by Race:")
        for race_no in sorted(df['race_no'].unique()):
            race_data = df[df['race_no'] == race_no]
            top_pick = race_data.loc[race_data['p_posterior'].idxmax()]
            print(f"  Race {race_no}: {top_pick['horse']} "
                  f"(Posterior: {top_pick['p_posterior']:.3f}, "
                  f"Position: {top_pick['pos']})")
    
    print(f"\n🚀 Next Steps:")
    print(f"  1. Add more meeting data to data/raw/")
    print(f"  2. Run walkforward backtesting: python3 india/backtest/walkforward.py")
    print(f"  3. Explore the Jupyter notebook: india/notebooks/india_benter_end_to_end.ipynb")
    print(f"  4. Customize the model in india/model/combiner_india.py")
    
    return True

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
