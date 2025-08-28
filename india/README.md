# Indian Racing Benter Model

This module adapts the German Benter methodology to Indian horse racing, providing a complete pipeline for data processing, feature engineering, and model evaluation.

## Overview

The Benter method combines prior probabilities (based on horse characteristics) with market odds to create more accurate win probability estimates. This implementation is specifically designed for Indian racing data formats and regulations.

## Directory Structure

```
india/
├── config/           # Configuration files
├── ingestion/        # PDF parsing and data extraction
├── features/         # Feature engineering
├── model/           # Benter model implementation
├── backtest/        # Performance evaluation
├── notebooks/       # Analysis notebooks
└── README.md        # This file
```

## Quick Start

### 1. Setup Environment

```bash
# Create Python virtual environment
python -m venv .venv
source .venv/bin/activate  # On Windows: .venv\Scripts\activate

# Install dependencies
pip install pandas numpy scikit-learn statsmodels jupyterlab matplotlib pyarrow
```

### 2. Prepare Data

Place your PDF files in the following structure:
```
data/raw/2025-08-27-kolkata/
├── racecard.pdf
├── odds_morning.pdf
├── odds_opening.pdf
└── results.pdf
```

### 3. Run Pipeline

```bash
# Convert PDFs to text
bash india/ingestion/to_text.sh 2025-08-27-kolkata

# Parse data
python india/ingestion/parse_racecard_india.py data/txt/2025-08-27-kolkata/racecard.txt data/bronze/2025-08-27-card.json
python india/ingestion/parse_odds_india.py data/txt/2025-08-27-kolkata/odds_opening.txt data/bronze/2025-08-27-odds.json
python india/ingestion/parse_results_india.py data/txt/2025-08-27-kolkata/results.txt data/bronze/2025-08-27-results.json

# Create features
python india/features/make_features_india.py data/bronze/2025-08-27-card.json data/bronze/2025-08-27-odds.json data/silver/2025-08-27-features.parquet

# Run backtesting
python india/backtest/replay_snapshots.py data/silver/2025-08-27-features.parquet data/bronze/2025-08-27-results.json data/reports/2025-08-27-meeting.csv

# Calculate metrics
python india/backtest/metrics.py data/reports/2025-08-27-meeting.csv
```

## Model Components

### Prior Probability Calculation

The model calculates prior probabilities based on:
- **Rating**: Higher ratings increase win probability
- **Weight**: Heavier horses are penalized (more for route races)
- **Age**: 3-year-olds get a bonus in route races
- **Distance**: Different weight penalties for sprint vs route races

### Market Integration

Market odds are converted from fractional format (e.g., "3/1") to implied probabilities and combined with priors using the geometric mean method.

### Kelly Criterion

The model calculates optimal bet sizes using the Kelly criterion, with configurable confidence thresholds and maximum stake limits.

## Performance Metrics

- **Logloss**: Measures probability prediction accuracy
- **Hit Rate**: Percentage of top picks that win
- **ROI**: Return on investment based on Kelly stakes
- **Calibration**: How well predicted probabilities match actual outcomes

## Configuration

Edit `config/settings.yaml` to adjust:
- Rating weights and penalties
- Age bonuses
- Distance thresholds
- Default probabilities
- Kelly criterion parameters

## Extending the Model

### Adding New Features

1. Modify `parse_racecard_india.py` to extract additional data
2. Update `make_features_india.py` to include new features
3. Enhance `prior_row()` function in `combiner_india.py`

### Implementing MNL Priors

For more sophisticated priors, implement multinomial logit regression:
1. Create `india/model/mnl.py` with proper statistical modeling
2. Replace the simple prior calculation with learned coefficients
3. Add cross-validation for parameter tuning

### Multi-Venue Analysis

Extend the pipeline to handle multiple venues:
1. Aggregate data across venues
2. Add venue-specific features
3. Implement venue-specific model calibration

## Data Formats

### Input PDFs

- **Race Card**: Horse details, ratings, weights, ages
- **Odds**: Morning, opening, and night prices in fractional format
- **Results**: Finishing positions and horse names

### Output Files

- **Bronze**: Parsed JSON data
- **Silver**: Feature-engineered Parquet files
- **Reports**: Performance metrics and analysis results

## Troubleshooting

### Common Issues

1. **PDF Conversion Fails**: Ensure `pdftotext` is installed
2. **Parsing Errors**: Check PDF format matches expected structure
3. **Import Errors**: Verify Python path includes parent directory
4. **Memory Issues**: Process large datasets in chunks

### Debug Mode

Add debug prints to parser functions:
```python
print(f"Processing line: {line}")
print(f"Matched groups: {m.groups()}")
```

## Contributing

1. Fork the repository
2. Create feature branch
3. Add tests for new functionality
4. Submit pull request with description

## License

This module is part of the German Horse Racing repository and follows the same license terms.

## References

- Benter, W. F. (1994). Computer Based Horse Race Handicapping and Wagering Systems
- Kelly, J. L. (1956). A New Interpretation of Information Rate
- Modern Portfolio Theory and Horse Racing
