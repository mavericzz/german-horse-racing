#!/usr/bin/env python3
"""
Calculate performance metrics for the Benter model.
Includes logloss, hit rate, and ROI calculations.
"""

import pandas as pd
import numpy as np
import sys
from typing import Dict, Any

def calculate_logloss(group: pd.DataFrame) -> float:
    """
    Calculate logloss for a race.
    
    Args:
        group: DataFrame for a single race
        
    Returns:
        Logloss value
    """
    y = (group["pos"] == 1).astype(int).to_numpy()
    p = group["p_posterior"].to_numpy()
    
    # Find winner probability
    winner_probs = p[y == 1]
    if len(winner_probs) > 0:
        return -np.log(winner_probs[0])
    else:
        return 0.0

def calculate_roi(group: pd.DataFrame, stake_col: str = "kelly_stake") -> float:
    """
    Calculate ROI for a race.
    
    Args:
        group: DataFrame for a single race
        stake_col: Column name for stake amounts
        
    Returns:
        ROI value
    """
    if stake_col not in group.columns:
        return 0.0
    
    total_stake = group[stake_col].sum()
    if total_stake == 0:
        return 0.0
    
    # Calculate returns (assuming 1 unit stake)
    winner_row = group[group["pos"] == 1]
    if len(winner_row) == 0:
        return -total_stake
    
    winner_stake = winner_row[stake_col].iloc[0]
    market_odds = 1 / winner_row["p_market"].iloc[0]
    
    # Return = (odds - 1) * stake - total_stake
    returns = (market_odds - 1) * winner_stake - total_stake
    roi = returns / total_stake if total_stake > 0 else 0
    
    return roi

def calculate_calibration(df: pd.DataFrame, n_bins: int = 10) -> Dict[str, Any]:
    """
    Calculate probability calibration metrics.
    
    Args:
        df: DataFrame with predictions and outcomes
        n_bins: Number of probability bins
        
    Returns:
        Dictionary with calibration metrics
    """
    # Create probability bins
    df_binned = df.copy()
    df_binned["prob_bin"] = pd.cut(df_binned["p_posterior"], 
                                   bins=n_bins, 
                                   labels=False)
    
    calibration_data = []
    
    for bin_idx in range(n_bins):
        bin_data = df_binned[df_binned["prob_bin"] == bin_idx]
        if len(bin_data) == 0:
            continue
            
        avg_pred = bin_data["p_posterior"].mean()
        actual_wins = (bin_data["pos"] == 1).sum()
        total_runners = len(bin_data)
        actual_rate = actual_wins / total_runners if total_runners > 0 else 0
        
        calibration_data.append({
            "bin": bin_idx,
            "avg_predicted": avg_pred,
            "actual_rate": actual_rate,
            "count": total_runners
        })
    
    return {"calibration_data": calibration_data}

def main():
    """Main function to calculate and display metrics."""
    if len(sys.argv) != 2:
        print("Usage: python metrics.py <results_csv>")
        sys.exit(1)
    
    results_file = sys.argv[1]
    
    try:
        # Read results
        df = pd.read_csv(results_file)
        
        print("=== Benter Model Performance Metrics ===\n")
        
        # Calculate logloss
        logloss_by_race = df.groupby("race_no").apply(calculate_logloss)
        avg_logloss = logloss_by_race.mean()
        print(f"Average Logloss: {avg_logloss:.3f}")
        
        # Calculate top-pick hit rate
        top_picks = (df.sort_values(["race_no", "p_posterior"], 
                                   ascending=[True, False])
                    .groupby("race_no")
                    .head(1))
        hit_rate = (top_picks["pos"] == 1).mean()
        print(f"Top-Pick Hit Rate: {hit_rate*100:.1f}%")
        
        # Calculate ROI (if Kelly stakes available)
        if "kelly_stake" in df.columns:
            roi_by_race = df.groupby("race_no").apply(calculate_roi)
            avg_roi = roi_by_race.mean()
            print(f"Average ROI: {avg_roi*100:.2f}%")
        
        # Race-level statistics
        print(f"\nTotal Races: {df['race_no'].nunique()}")
        print(f"Total Runners: {len(df)}")
        
        # Distance analysis
        if "dist_m" in df.columns:
            print(f"\nDistance Analysis:")
            for dist in sorted(df["dist_m"].unique()):
                dist_data = df[df["dist_m"] == dist]
                dist_hit_rate = (dist_data.sort_values("p_posterior", ascending=False)
                               .groupby("race_no")
                               .head(1)["pos"] == 1).mean()
                print(f"  {dist}m: {dist_hit_rate*100:.1f}% hit rate")
        
        # Calibration analysis
        calibration = calculate_calibration(df)
        print(f"\nCalibration Analysis:")
        for bin_data in calibration["calibration_data"]:
            print(f"  Bin {bin_data['bin']}: Pred={bin_data['avg_predicted']:.3f}, "
                  f"Actual={bin_data['actual_rate']:.3f}, Count={bin_data['count']}")
        
    except Exception as e:
        print(f"Error calculating metrics: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
