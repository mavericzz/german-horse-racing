import os
import json
import pandas as pd
from pathlib import Path
from flask import Flask, render_template, jsonify, request
from flask_cors import CORS
import plotly.graph_objects as go
import plotly.utils

app = Flask(__name__)
CORS(app)  # Enable CORS for frontend

# Configuration
DATA_ROOT = Path(__file__).parent.parent.parent / "data"
INDIA_ROOT = Path(__file__).parent.parent.parent / "india"

# Get port from environment variable (for Railway)
PORT = int(os.environ.get('PORT', 8000))

print("🏇 Starting Indian Racing Benter Model Web Interface...")
print(f"📁 Data root: {DATA_ROOT}")
print(f"🌐 Web interface will be available at: http://localhost:{PORT}")

@app.route('/')
def index():
    """Main dashboard page."""
    return render_template('index.html')

@app.route('/meeting/<meeting_id>')
def meeting_detail(meeting_id):
    """Meeting detail page."""
    return render_template('meeting.html', meeting_id=meeting_id)

@app.route('/api/meetings')
def api_meetings():
    """API endpoint to get list of available meetings."""
    try:
        meetings = get_available_meetings()
        return jsonify(meetings)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/meeting/<meeting_id>/summary')
def api_meeting_summary(meeting_id):
    """API endpoint to get meeting summary data."""
    try:
        data = load_meeting_data(meeting_id)
        if data is None:
            return jsonify({'error': 'Meeting data not found'}), 404
        
        # Create summary
        summary = create_meeting_summary(data, meeting_id)
        return jsonify(summary)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/meeting/<meeting_id>/race/<int:race_no>')
def api_race_detail(meeting_id, race_no):
    """API endpoint to get detailed race data."""
    try:
        data = load_meeting_data(meeting_id)
        if data is None:
            return jsonify({'error': 'Meeting data not found'}), 404
        
        race_data = data[data['race_no'] == race_no]
        if race_data.empty:
            return jsonify({'error': 'Race not found'}), 404
        
        # Create race chart data
        chart_data = create_race_chart(race_data)
        return jsonify({
            'race_data': race_data.to_dict('records'),
            'chart_data': chart_data
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

def get_available_meetings():
    """Get list of available meetings from data directory."""
    meetings = []
    
    # Check silver directory for processed data
    silver_dir = DATA_ROOT / "silver"
    if silver_dir.exists():
        for file_path in silver_dir.glob("*-features.parquet"):
            meeting_name = file_path.stem.replace("-features", "")
            
            # Check if we have all required data
            features_file = silver_dir / f"{meeting_name}-features.parquet"
            card_file = DATA_ROOT / "bronze" / f"{meeting_name}-card.json"
            odds_file = DATA_ROOT / "bronze" / f"{meeting_name}-odds.json"
            
            if features_file.exists():
                meetings.append({
                    'id': meeting_name,
                    'name': meeting_name.replace('-', ' ').title(),
                    'date': meeting_name.split('-')[:3] if '-' in meeting_name else [meeting_name],
                    'has_data': True
                })
            else:
                meetings.append({
                    'id': meeting_name,
                    'name': meeting_name.replace('-', ' ').title(),
                    'date': meeting_name.split('-')[:3] if '-' in meeting_name else [meeting_name],
                    'has_data': False
                })
    
    return sorted(meetings, key=lambda x: x['id'], reverse=True)

def load_meeting_data(meeting_id):
    """Load all data for a specific meeting."""
    try:
        # Load features
        features_file = DATA_ROOT / "silver" / f"{meeting_id}-features.parquet"
        # Also check for the alternative naming convention
        if not features_file.exists():
            features_file = DATA_ROOT / "silver" / f"{meeting_id.split('-')[-1]}-features.parquet"
        
        if not features_file.exists():
            return None
        
        features = pd.read_parquet(features_file)
        
        # Load results if available
        results_file = DATA_ROOT / "bronze" / f"{meeting_id}-results.json"
        if results_file.exists():
            with open(results_file, 'r') as f:
                results = json.load(f)
            
            # Create results mapping
            res_map = {}
            for r in results:
                race_no = r["race_no"]
                horse_positions = {}
                for p in r["placings"]:
                    horse_positions[p["horse"].lower()] = p["pos"]
                res_map[race_no] = horse_positions
            
            # Add results to features
            features["pos"] = (features["horse"]
                             .str.lower()
                             .map(lambda x: res_map.get(features.loc[features["horse"] == x, "race_no"].iloc[0], {}).get(x, 99))
                             .fillna(99)
                             .astype(int))
        
        return features
    except Exception as e:
        print(f"Error loading meeting data: {e}")
        return None

def create_race_chart(race_data):
    """Create an interactive chart for a race."""
    # Sort by posterior probability
    race_data = race_data.sort_values('p_posterior', ascending=False)
    
    # Create bar chart
    fig = go.Figure()
    
    # Add market probabilities
    fig.add_trace(go.Bar(
        x=race_data['horse'],
        y=race_data['p_market'],
        name='Market Probability',
        marker_color='lightblue',
        opacity=0.7
    ))
    
    # Add prior probabilities
    fig.add_trace(go.Bar(
        x=race_data['horse'],
        y=race_data['p_prior'],
        name='Prior Probability',
        marker_color='lightgreen',
        opacity=0.7
    ))
    
    # Add posterior probabilities
    fig.add_trace(go.Bar(
        x=race_data['horse'],
        y=race_data['p_posterior'],
        name='Posterior Probability',
        marker_color='gold',
        opacity=0.9
    ))
    
    # Update layout
    fig.update_layout(
        title=f"Race {race_data['race_no'].iloc[0]}: {race_data['race_name'].iloc[0]} ({race_data['dist_m'].iloc[0]}m)",
        xaxis_title="Horse",
        yaxis_title="Probability",
        barmode='group',
        height=500,
        showlegend=True
    )
    
    return json.loads(plotly.utils.PlotlyJSONEncoder().encode(fig))

def create_meeting_summary(data, meeting_id):
    """Create summary statistics for a meeting."""
    try:
        # Group by race
        races = data.groupby('race_no').agg({
            'horse': 'count',
            'p_posterior': ['max', 'min', 'mean'],
            'p_market': ['max', 'min', 'mean'],
            'p_prior': ['max', 'min', 'mean']
        }).round(4)
        
        # Flatten column names
        races.columns = ['_'.join(col).strip() for col in races.columns.values]
        races = races.reset_index()
        
        # Add race names
        race_names = data.groupby('race_no')['race_name'].first()
        races['race_name'] = races['race_no'].map(race_names)
        
        # Add distances
        distances = data.groupby('race_no')['dist_m'].first()
        races['distance'] = races['race_no'].map(distances)
        
        return {
            'meeting_id': meeting_id,
            'total_races': len(races),
            'total_horses': len(data),
            'races': races.to_dict('records')
        }
    except Exception as e:
        print(f"Error creating meeting summary: {e}")
        return {'error': str(e)}

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=PORT)
