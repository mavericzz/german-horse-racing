#!/usr/bin/env python3
"""
Benter-style combiner for Indian racing.
Combines prior probabilities with market odds using geometric mean.
"""

import numpy as np
import pandas as pd
from typing import Dict, Any

def normalize(x: np.ndarray) -> np.ndarray:
    """
    Normalize probabilities to sum to 1.
    
    Args:
        x: Array of probabilities
        
    Returns:
        Normalized probabilities
    """
    s = x.sum()
    return x / s if s > 0 else np.ones_like(x) / len(x)

def prior_row(r: pd.Series) -> float:
    """
    Calculate prior probability for a horse based on features.
    
    Args:
        r: Row containing horse features
        
    Returns:
        Prior probability
    """
    # Base prior from rating
    base = 0.20 + 0.006 * r["rating"]
    
    # Weight penalty (heavier horses are disadvantaged)
    if r["dist_m"] >= 1600:  # Route race
        base -= 0.010 * (r["weight_kg"] - 55.0)
    else:  # Sprint race
        base -= 0.006 * (r["weight_kg"] - 55.0)
    
    # Age bonus for 3-year-olds in route races
    if r["age"] == 3 and r["dist_m"] >= 1600:
        base += 0.02
    
    return max(0.01, base)

def posterior_for_race(df: pd.DataFrame, use: str = "p_opening") -> pd.DataFrame:
    """
    Calculate posterior probabilities for a race using Benter method.
    
    Args:
        df: DataFrame with horse features and market odds
        use: Which market odds to use ('p_night', 'p_morning', 'p_opening')
        
    Returns:
        DataFrame with market, prior, and posterior probabilities
    """
    df = df.copy()
    
    # Get market probabilities, fallback to morning then night
    pmkt = (df[use]
            .fillna(df["p_morning"])
            .fillna(df["p_night"])
            .fillna(0.08)
            .to_numpy())
    
    # Normalize market probabilities
    pmkt = normalize(pmkt)
    
    # Calculate prior probabilities
    ppri = np.array([prior_row(r) for _, r in df.iterrows()])
    ppri = normalize(ppri)
    
    # Combine using geometric mean (Benter method)
    post = normalize(np.sqrt(pmkt * ppri))
    
    # Add all probabilities to DataFrame
    df["p_market"] = pmkt
    df["p_prior"] = ppri
    df["p_posterior"] = post
    
    return df

def calculate_kelly_stakes(df: pd.DataFrame, 
                          confidence_threshold: float = 0.15,
                          max_stake: float = 0.10) -> pd.DataFrame:
    """
    Calculate Kelly criterion stakes for betting.
    
    Args:
        df: DataFrame with posterior probabilities
        confidence_threshold: Minimum probability to consider betting
        max_stake: Maximum stake as fraction of bankroll
        
    Returns:
        DataFrame with Kelly stakes
    """
    df = df.copy()
    
    # Calculate Kelly stakes
    stakes = []
    for _, row in df.iterrows():
        if row["p_posterior"] > confidence_threshold:
            # Kelly formula: (bp - q) / b
            # where b = odds-1, p = our probability, q = 1-p
            market_odds = 1 / row["p_market"]
            b = market_odds - 1
            p = row["p_posterior"]
            q = 1 - p
            
            if b > 0:
                kelly = (b * p - q) / b
                kelly = max(0, min(kelly, max_stake))  # Cap at max_stake
            else:
                kelly = 0
        else:
            kelly = 0
            
        stakes.append(kelly)
    
    df["kelly_stake"] = stakes
    return df
