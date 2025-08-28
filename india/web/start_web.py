#!/usr/bin/env python3
"""
Startup script for the Indian Racing Benter Model web interface.
"""

import os
import sys
import subprocess
from pathlib import Path

def main():
    """Start the web application."""
    print("🏇 Starting Indian Racing Benter Model Web Interface...")
    
    # Get the project root directory
    project_root = Path(__file__).parent.parent.parent
    os.chdir(project_root)
    
    print(f"📁 Project root: {project_root.absolute()}")
    print(f"🌐 Web interface will be available at: http://localhost:5000")
    print(f"📱 Press Ctrl+C to stop the server")
    print()
    
    try:
        # Start the Flask application
        subprocess.run([
            sys.executable, 
            "india/web/app.py"
        ], check=True)
    except KeyboardInterrupt:
        print("\n🛑 Server stopped by user")
    except subprocess.CalledProcessError as e:
        print(f"❌ Failed to start server: {e}")
        return 1
    
    return 0

if __name__ == "__main__":
    sys.exit(main())
