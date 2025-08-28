#!/usr/bin/env python3
"""
Test script to verify the India module setup.
Run this to check that all components are working correctly.
"""

import sys
import pathlib
import importlib

def test_imports():
    """Test that all required modules can be imported."""
    print("Testing imports...")
    
    try:
        import pandas as pd
        print("✓ pandas imported successfully")
    except ImportError as e:
        print(f"✗ pandas import failed: {e}")
        return False
    
    try:
        import numpy as np
        print("✓ numpy imported successfully")
    except ImportError as e:
        print(f"✗ numpy import failed: {e}")
        return False
    
    try:
        import matplotlib.pyplot as plt
        print("✓ matplotlib imported successfully")
    except ImportError as e:
        print(f"✗ matplotlib import failed: {e}")
        return False
    
    try:
        import seaborn as sns
        print("✓ seaborn imported successfully")
    except ImportError as e:
        print(f"✗ seaborn import failed: {e}")
        return False
    
    return True

def test_india_modules():
    """Test that India-specific modules can be imported."""
    print("\nTesting India modules...")
    
    # Add parent directory to path
    parent_dir = pathlib.Path(__file__).parent.parent
    sys.path.insert(0, str(parent_dir))
    
    try:
        from india.model.combiner_india import posterior_for_race, normalize
        print("✓ combiner_india imported successfully")
    except ImportError as e:
        print(f"✗ combiner_india import failed: {e}")
        return False
    
    try:
        from india.backtest.metrics import calculate_logloss
        print("✓ metrics imported successfully")
    except ImportError as e:
        print(f"✗ metrics import failed: {e}")
        return False
    
    return True

def test_functionality():
    """Test basic functionality of the modules."""
    print("\nTesting functionality...")
    
    try:
        from india.model.combiner_india import normalize
        import numpy as np
        
        # Test normalization
        test_array = np.array([1, 2, 3, 4, 5])
        normalized = normalize(test_array)
        
        if np.isclose(normalized.sum(), 1.0, atol=1e-10):
            print("✓ normalize function works correctly")
        else:
            print("✗ normalize function failed")
            return False
            
    except Exception as e:
        print(f"✗ functionality test failed: {e}")
        return False
    
    return True

def test_directory_structure():
    """Test that the directory structure is correct."""
    print("\nTesting directory structure...")
    
    current_dir = pathlib.Path(__file__).parent
    required_dirs = [
        "config",
        "ingestion", 
        "features",
        "model",
        "backtest",
        "notebooks"
    ]
    
    for dir_name in required_dirs:
        dir_path = current_dir / dir_name
        if dir_path.exists() and dir_path.is_dir():
            print(f"✓ {dir_name}/ directory exists")
        else:
            print(f"✗ {dir_name}/ directory missing")
            return False
    
    return True

def test_config_files():
    """Test that configuration files exist."""
    print("\nTesting configuration files...")
    
    current_dir = pathlib.Path(__file__).parent
    required_files = [
        "config/settings.yaml",
        "README.md"
    ]
    
    for file_path in required_files:
        full_path = current_dir / file_path
        if full_path.exists():
            print(f"✓ {file_path} exists")
        else:
            print(f"✗ {file_path} missing")
            return False
    
    return True

def main():
    """Run all tests."""
    print("=== India Module Setup Test ===\n")
    
    tests = [
        test_imports,
        test_india_modules,
        test_functionality,
        test_directory_structure,
        test_config_files
    ]
    
    passed = 0
    total = len(tests)
    
    for test in tests:
        if test():
            passed += 1
        print()
    
    print("=== Test Results ===")
    print(f"Passed: {passed}/{total}")
    
    if passed == total:
        print("🎉 All tests passed! The India module is ready to use.")
        return True
    else:
        print("❌ Some tests failed. Please check the errors above.")
        return False

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
