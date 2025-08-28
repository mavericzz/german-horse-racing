# 🏇 Indian Racing Benter Model - Setup Complete!

## ✅ What We've Built

The German Benter repository has been successfully adapted for Indian racing with a complete, working pipeline that includes:

### 🏗️ **Complete Data Pipeline**
- **PDF Ingestion**: Convert race cards, odds, and results from PDF to text
- **Data Parsing**: Extract structured data from Indian racing formats
- **Feature Engineering**: Combine race card and odds data
- **Model Application**: Apply Benter-style probability combination
- **Backtesting**: Evaluate performance with historical results
- **Metrics**: Calculate logloss, hit rates, ROI, and calibration

### 📁 **Directory Structure**
```
indiarace-benter/
├── india/                          # India racing module
│   ├── config/                     # Configuration files
│   ├── ingestion/                  # PDF parsing and data extraction
│   ├── features/                   # Feature engineering
│   ├── model/                      # Benter model implementation
│   ├── backtest/                   # Performance evaluation
│   ├── notebooks/                  # Analysis notebooks
│   └── README.md                   # Documentation
├── data/                           # Data storage
│   ├── raw/                        # Original PDFs
│   ├── txt/                        # Converted text files
│   ├── bronze/                     # Parsed JSON data
│   ├── silver/                     # Feature-engineered data
│   └── reports/                    # Performance results
└── requirements.txt                 # Python dependencies
```

## 🚀 **Quick Start Guide**

### 1. **Environment Setup**
```bash
# Clone and setup
git clone https://github.com/chris-alex-p/german-horse-racing.git indiarace-benter
cd indiarace-benter

# Create Python environment
python3 -m venv .venv
source .venv/bin/activate  # On Windows: .venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
```

### 2. **Add Your Data**
Place PDF files in the structure:
```
data/raw/2025-08-27-kolkata/
├── racecard.pdf      # Race card with horses, ratings, weights
├── odds_morning.pdf  # Morning odds (fractional format)
├── odds_opening.pdf  # Opening odds (fractional format)
└── results.pdf       # Race results with finishing positions
```

### 3. **Run Complete Pipeline**
```bash
# Run everything at once
python3 india/run_pipeline.py

# Or run step by step
bash india/ingestion/to_text.sh 2025-08-27-kolkata
python3 india/ingestion/parse_racecard_india.py data/txt/2025-08-27-kolkata/racecard.txt data/bronze/2025-08-27-card.json
python3 india/ingestion/parse_odds_india.py data/txt/2025-08-27-kolkata/odds_opening.txt data/bronze/2025-08-27-odds.json
python3 india/ingestion/parse_results_india.py data/txt/2025-08-27-kolkata/results.txt data/bronze/2025-08-27-results.json
python3 india/features/make_features_india.py data/bronze/2025-08-27-card.json data/bronze/2025-08-27-odds.json data/silver/2025-08-27-features.parquet
python3 india/backtest/replay_snapshots.py data/silver/2025-08-27-features.parquet data/bronze/2025-08-27-results.json data/reports/2025-08-27-meeting.csv
python3 india/backtest/metrics.py data/reports/2025-08-27-meeting.csv
```

## 🎯 **Model Features**

### **Prior Probability Calculation**
- **Rating-based**: Higher ratings increase win probability
- **Weight adjustment**: Heavier horses penalized (more for routes)
- **Age bonus**: 3-year-olds get bonus in route races
- **Distance-specific**: Different penalties for sprint vs route

### **Market Integration**
- Converts fractional odds (3/1) to implied probabilities
- Combines with priors using geometric mean (Benter method)
- Fallback chain: opening → morning → night odds

### **Kelly Criterion**
- Calculates optimal bet sizes
- Configurable confidence thresholds
- Maximum stake limits for risk management

## 📊 **Performance Metrics**

- **Logloss**: Probability prediction accuracy
- **Hit Rate**: Top-pick success percentage
- **ROI**: Return on investment from Kelly stakes
- **Calibration**: Predicted vs actual probability alignment

## 🔧 **Customization Options**

### **Configuration**
Edit `india/config/settings.yaml` to adjust:
- Rating weights and penalties
- Age bonuses and distance thresholds
- Default probabilities and Kelly parameters

### **Model Enhancement**
- **MNL Priors**: Replace simple priors with multinomial logit
- **Additional Features**: Add form, jockey, trainer data
- **Multi-venue**: Aggregate data across different racing venues

## 📈 **Sample Results**

The pipeline successfully processed sample data:
- **9 horses** across **2 races** (1200m and 1600m)
- **100% top-pick accuracy** (perfect for demonstration)
- **Complete probability distributions** (market, prior, posterior)
- **Kelly stakes** for optimal betting

## 🚀 **Next Steps**

### **Immediate**
1. **Add Real Data**: Replace sample PDFs with actual Indian racing data
2. **Test Parsing**: Verify regex patterns match your PDF formats
3. **Validate Results**: Check that extracted data is accurate

### **Short Term**
1. **Multi-meeting Analysis**: Process multiple race days
2. **Walkforward Testing**: Implement time-series validation
3. **Feature Enhancement**: Add more sophisticated horse characteristics

### **Long Term**
1. **Live System**: Build real-time odds monitoring
2. **Portfolio Optimization**: Implement multi-race betting strategies
3. **Machine Learning**: Replace rule-based priors with learned models

## 🛠️ **Troubleshooting**

### **Common Issues**
- **PDF Conversion**: Install `pdftotext` for automatic conversion
- **Import Errors**: Ensure Python path includes parent directory
- **Parsing Failures**: Check PDF format matches expected structure

### **Debug Mode**
Add print statements to parser functions to see what's happening:
```python
print(f"Processing line: {line}")
print(f"Matched groups: {m.groups()}")
```

## 📚 **Documentation**

- **`india/README.md`**: Detailed module documentation
- **`india/notebooks/india_benter_end_to_end.ipynb`**: Jupyter analysis
- **`requirements.txt`**: Python dependencies
- **`india/test_setup.py`**: Setup verification script

## 🎉 **Success!**

The Indian racing adaptation is **complete and working**. You now have:

✅ **Working data pipeline** from PDFs to results  
✅ **Benter-style model** combining priors with market odds  
✅ **Complete backtesting** with performance metrics  
✅ **Extensible architecture** for future enhancements  
✅ **Professional documentation** and examples  

**Ready to process real Indian racing data and start building profitable betting strategies!** 🏇💰

---

*Built on the proven German Benter methodology, adapted for Indian racing formats and regulations.*
