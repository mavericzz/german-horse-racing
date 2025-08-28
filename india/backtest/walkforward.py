#!/usr/bin/env python3
"""
Walkforward backtesting for the Benter model.
Splits data by time periods and evaluates performance across folds.
"""

import pandas as pd
import numpy as np
import json
import pathlib
import sys
from typing import List, Dict, Any, Tuple
from india.model.combiner_india import posterior_for_race, calculate_kelly_stakes

def split_data_by_date(df: pd.DataFrame, 
                       date_col: str = "meeting_date",
                       n_folds: int = 5) -> List[Tuple[pd.DataFrame, pd.DataFrame]]:
    """
    Split data into training and validation folds by date.
    
    Args:
        df: DataFrame with racing data
        date_col: Column name for date
        n_folds: Number of folds
        
    Returns:
        List of (train, validation) DataFrame pairs
    """
    if date_col not in df.columns:
        # If no date column, split by race number
        unique_races = sorted(df["race_no"].unique())
        fold_size = len(unique_races) // n_folds
        
        folds = []
        for i in range(n_folds):
            start_idx = i * fold_size
            end_idx = start_idx + fold_size if i < n_folds - 1 else len(unique_races)
            
            val_races = unique_races[start_idx:end_idx]
            train_races = [r for r in unique_races if r not in val_races]
            
            train_df = df[df["race_no"].isin(train_races)]
            val_df = df[df["race_no"].isin(val_races)]
            
            folds.append((train_df, val_df))
    else:
        # Split by date
        unique_dates = sorted(df[date_col].unique())
        fold_size = len(unique_dates) // n_folds
        
        folds = []
        for i in range(n_folds):
            start_idx = i * fold_size
            end_idx = start_idx + fold_size if i < n_folds - 1 else len(unique_dates)
            
            val_dates = unique_dates[start_idx:end_idx]
            train_dates = [d for d in unique_dates if d not in val_dates]
            
            train_df = df[df[date_col].isin(train_dates)]
            val_df = df[df[date_col].isin(val_dates)]
            
            folds.append((train_df, val_df))
    
    return folds

def evaluate_fold(val_df: pd.DataFrame) -> Dict[str, float]:
    """
    Evaluate performance on a validation fold.
    
    Args:
        val_df: Validation DataFrame
        
    Returns:
        Dictionary with performance metrics
    """
    # Apply Benter model
    results = []
    for rno, group in val_df.groupby("race_no"):
        df = posterior_for_race(group, use="p_opening")
        df = calculate_kelly_stakes(df)
        results.append(df)
    
    if not results:
        return {"logloss": 0.0, "hit_rate": 0.0, "roi": 0.0}
    
    combined = pd.concat(results, ignore_index=True)
    
    # Calculate metrics
    logloss_by_race = combined.groupby("race_no").apply(
        lambda g: -np.log(g[g["pos"] == 1]["p_posterior"].iloc[0]) 
        if len(g[g["pos"] == 1]) > 0 else 0.0
    )
    avg_logloss = logloss_by_race.mean()
    
    top_picks = (combined.sort_values(["race_no", "p_posterior"], 
                                     ascending=[True, False])
                .groupby("race_no")
                .head(1))
    hit_rate = (top_picks["pos"] == 1).mean()
    
    # Calculate ROI
    roi_by_race = combined.groupby("race_no").apply(
        lambda g: calculate_roi_for_race(g)
    )
    avg_roi = roi_by_race.mean()
    
    return {
        "logloss": avg_logloss,
        "hit_rate": hit_rate,
        "roi": avg_roi
    }

def calculate_roi_for_race(group: pd.DataFrame) -> float:
    """Calculate ROI for a single race."""
    total_stake = group["kelly_stake"].sum()
    if total_stake == 0:
        return 0.0
    
    winner_row = group[group["pos"] == 1]
    if len(winner_row) == 0:
        return -1.0  # Lost entire stake
    
    winner_stake = winner_row["kelly_stake"].iloc[0]
    market_odds = 1 / winner_row["p_market"].iloc[0]
    
    returns = (market_odds - 1) * winner_stake - total_stake
    roi = returns / total_stake if total_stake > 0 else 0
    
    return roi

def walkforward_backtest(features_file: str, 
                         results_file: str,
                         output_file: str,
                         n_folds: int = 5) -> None:
    """
    Perform walkforward backtesting.
    
    Args:
        features_file: Path to features Parquet file
        results_file: Path to results JSON file
        output_file: Path to output results file
        n_folds: Number of folds for cross-validation
    """
    # Read data
    features = pd.read_parquet(features_file)
    
    with open(results_file, 'r') as f:
        results = json.load(f)
    
    # Add results to features
    res_map = {}
    for r in results:
        race_no = r["race_no"]
        horse_positions = {}
        for p in r["placings"]:
            horse_positions[p["horse"].lower()] = p["pos"]
        res_map[race_no] = horse_positions
    
    features["pos"] = (features["horse"]
                      .str.lower()
                      .map(lambda x: res_map.get(features.loc[features["horse"] == x, "race_no"].iloc[0], {}).get(x, 99))
                      .fillna(99)
                      .astype(int))
    
    # Perform walkforward validation
    folds = split_data_by_date(features, n_folds=n_folds)
    
    fold_results = []
    for i, (train_df, val_df) in enumerate(folds):
        print(f"Processing fold {i+1}/{len(folds)}")
        print(f"  Train: {len(train_df)} entries, {train_df['race_no'].nunique()} races")
        print(f"  Validation: {len(val_df)} entries, {val_df['race_no'].nunique()} races")
        
        metrics = evaluate_fold(val_df)
        metrics["fold"] = i + 1
        fold_results.append(metrics)
        
        print(f"  Logloss: {metrics['logloss']:.3f}")
        print(f"  Hit Rate: {metrics['hit_rate']*100:.1f}%")
        print(f"  ROI: {metrics['roi']*100:.2f}%")
        print()
    
    # Aggregate results
    results_df = pd.DataFrame(fold_results)
    
    print("=== Walkforward Backtest Results ===")
    print(f"Average Logloss: {results_df['logloss'].mean():.3f} ± {results_df['logloss'].std():.3f}")
    print(f"Average Hit Rate: {results_df['hit_rate'].mean()*100:.1f}% ± {results_df['hit_rate'].std()*100:.1f}%")
    print(f"Average ROI: {results_df['roi'].mean()*100:.2f}% ± {results_df['roi'].std()*100:.2f}%")
    
    # Save results
    results_df.to_csv(output_file, index=False)
    print(f"\nDetailed results saved to: {output_file}")

def main():
    """Main function to run walkforward backtesting."""
    if len(sys.argv) < 4:
        print("Usage: python walkforward.py <features_parquet> <results_json> <output_csv> [n_folds]")
        sys.exit(1)
    
    features_file = sys.argv[1]
    results_file = sys.argv[2]
    output_file = sys.argv[3]
    n_folds = int(sys.argv[4]) if len(sys.argv) > 4 else 5
    
    try:
        walkforward_backtest(features_file, results_file, output_file, n_folds)
    except Exception as e:
        print(f"Error during walkforward backtesting: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
