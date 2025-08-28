#!/usr/bin/env bash
set -euo pipefail

MEET="$1"  # e.g., 2025-08-27-kolkata

# Create output directory if it doesn't exist
mkdir -p "data/txt/$MEET"

# Convert PDFs to text with layout preservation
echo "Converting racecard PDF..."
pdftotext -layout "data/raw/$MEET/racecard.pdf" "data/txt/$MEET/racecard.txt"

echo "Converting morning odds PDF..."
pdftotext -layout "data/raw/$MEET/odds_morning.pdf" "data/txt/$MEET/odds_morning.txt"

echo "Converting opening odds PDF..."
pdftotext -layout "data/raw/$MEET/odds_opening.pdf" "data/txt/$MEET/odds_opening.txt"

echo "Converting results PDF..."
pdftotext -layout "data/raw/$MEET/results.pdf" "data/txt/$MEET/results.txt"

echo "Conversion complete for meeting: $MEET"
echo "Text files saved in: data/txt/$MEET/"
