# 🏇 German Horse Racing - Indian Racing Adaptation

This repository has been adapted from the original German horse racing analysis to work with **Indian racing data** using the **Benter methodology** for probability modeling.

## 🚀 **Quick Deploy to Production**

### **Option 1: Netlify + Railway (Recommended)**

```bash
# 1. Deploy backend to Railway
npm install -g @railway/cli
railway login
./deploy_railway.sh

# 2. Deploy frontend to Netlify  
npm install -g netlify-cli
netlify login
./deploy_netlify.sh
```

### **Option 2: Local Development**

```bash
# Install dependencies
pip install -r requirements.txt

# Process sample data
python3 india/run_pipeline.py

# Start web interface
python3 india/web/app.py
```

## 🏗️ **Architecture**

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Netlify       │    ┌─────────────────┐    │   Your Data     │
│   (Frontend)    │◄──►│   Railway       │◄──►│   (PDFs/JSON)   │
│                 │    │   (Backend)     │    │                 │
│ • Static HTML   │    │ • Flask API     │    │ • Race Cards    │
│ • Bootstrap     │    │ • Data Pipeline │    │ • Odds Data     │
│ • Plotly.js     │    │ • Benter Model  │    │ • Results      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 📊 **Features**

- **PDF Data Ingestion**: Convert race cards, odds, and results from PDF to structured data
- **Benter Methodology**: Advanced probability modeling using geometric mean combination
- **Feature Engineering**: Automatic extraction of racing features (distance, weight, rating, etc.)
- **Interactive Web Interface**: Beautiful dashboard with Plotly.js charts
- **Backtesting**: Historical performance analysis and walkforward testing
- **Kelly Criterion**: Optimal betting stake calculations
- **Mobile Optimized**: Responsive design for all devices

## 🗂️ **Project Structure**

```
├── india/                    # Indian racing module
│   ├── config/              # Configuration files
│   ├── ingestion/           # PDF parsing and data ingestion
│   ├── features/            # Feature engineering
│   ├── model/               # Benter model implementation
│   ├── backtest/            # Backtesting and metrics
│   └── web/                 # Flask web application
├── netlify-site/            # Static frontend for Netlify
├── data/                    # Data storage (raw, processed, reports)
├── requirements.txt          # Python dependencies
├── railway.json             # Railway deployment config
└── .github/workflows/       # GitHub Actions automation
```

## 🔧 **Data Processing Pipeline**

1. **PDF Input** → `data/raw/YYYY-MM-DD-venue/`
2. **Text Conversion** → `data/txt/YYYY-MM-DD-venue/`
3. **Data Parsing** → `data/bronze/YYYY-MM-DD-venue-*.json`
4. **Feature Engineering** → `data/silver/YYYY-MM-DD-venue-features.parquet`
5. **Model Application** → `data/reports/YYYY-MM-DD-venue-meeting.csv`

## 📱 **Web Interface**

- **Dashboard**: Overview of all available meetings
- **Meeting Details**: Individual race analysis with interactive charts
- **API Endpoints**: RESTful API for data access
- **Real-time Updates**: Automatic data refresh and loading

## 🚀 **Deployment Options**

### **Production (Recommended)**
- **Frontend**: Netlify (free tier, global CDN)
- **Backend**: Railway (free tier, auto-scaling)
- **Automation**: GitHub Actions (automated deployments)

### **Local Development**
- **Frontend**: Static file server
- **Backend**: Flask development server
- **Data**: Local file system

## 📚 **Documentation**

- [📖 Deployment Guide](DEPLOYMENT_GUIDE.md) - Complete deployment instructions
- [🌐 Web Frontend Guide](WEB_FRONTEND_GUIDE.md) - Frontend development guide
- [📊 Feature Definitions](documentation/feature_definitions.md) - Data field descriptions

## 🎯 **Getting Started**

### **1. Clone Repository**
```bash
git clone https://github.com/yourusername/german-horse-racing.git
cd german-horse-racing
```

### **2. Install Dependencies**
```bash
pip install -r requirements.txt
```

### **3. Add Your Data**
```bash
# Create meeting directory
mkdir -p data/raw/2025-09-15-pune

# Add PDF files:
# - racecard.pdf
# - odds_morning.pdf
# - odds_opening.pdf
# - results.pdf
```

### **4. Process Data**
```bash
# Run complete pipeline
python3 india/run_pipeline.py
```

### **5. View Results**
```bash
# Start web interface
python3 india/web/app.py

# Open http://localhost:8000
```

## 🔄 **Adding New Meetings**

```bash
# 1. Add PDFs to data/raw/YYYY-MM-DD-venue/
# 2. Run pipeline: python3 india/run_pipeline.py
# 3. View in web interface
```

## 🌐 **API Endpoints**

- `GET /api/meetings` - List all available meetings
- `GET /api/meeting/{id}/summary` - Meeting summary and statistics
- `GET /api/meeting/{id}/race/{race_no}` - Individual race data and charts

## 📈 **Performance Metrics**

- **Log Loss**: Probability calibration accuracy
- **Hit Rate**: Percentage of correct predictions
- **ROI**: Return on investment analysis
- **Calibration**: Model reliability assessment

## 🤝 **Contributing**

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 **License**

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 **Acknowledgments**

- Original German racing analysis methodology
- Benter probability modeling approach
- Indian racing community for data and feedback

---

**Ready to deploy?** Check out the [Deployment Guide](DEPLOYMENT_GUIDE.md) for step-by-step instructions! 🚀



