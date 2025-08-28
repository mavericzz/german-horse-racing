#!/bin/bash

echo "🏇 Starting Indian Racing Benter Model Web Interface..."
echo "=================================================="

# Check if we're in the right directory
if [ ! -f "india/web/app.py" ]; then
    echo "❌ Error: Please run this script from the project root directory"
    echo "   Current directory: $(pwd)"
    echo "   Expected: german-horse-racing/"
    exit 1
fi

# Check if Python is available
if ! command -v python3 &> /dev/null; then
    echo "❌ Error: Python 3 is not installed or not in PATH"
    exit 1
fi

# Check if required packages are installed
echo "🔍 Checking dependencies..."
python3 -c "import flask, plotly" 2>/dev/null
if [ $? -ne 0 ]; then
    echo "⚠️  Warning: Some dependencies are missing"
    echo "   Installing required packages..."
    pip3 install Flask plotly
fi

# Start the web application
echo "🚀 Starting web server..."
echo "📱 Web interface will be available at: http://localhost:8000"
echo "🛑 Press Ctrl+C to stop the server"
echo ""

cd india/web
python3 app.py
