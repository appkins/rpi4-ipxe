#!/usr/bin/env python3

import sys
import os

# Add current directory to path
sys.path.insert(0, '.')

try:
    from RpiPlatformBuild import RpiSettingsManager
    
    # Create settings manager
    settings = RpiSettingsManager()
    
    print("✓ RpiPlatformBuild import successful")
    print(f"✓ Workspace root: {settings.GetWorkspaceRoot()}")
    print(f"✓ Packages path: {settings.GetPackagesPath()}")
    print(f"✓ Packages supported: {settings.GetPackagesSupported()}")
    print(f"✓ Required submodules: {[str(sm) for sm in settings.GetRequiredSubmodules()]}")
    print(f"✓ Architectures supported: {settings.GetArchitecturesSupported()}")
    
    # Check if directories exist
    for path in settings.GetPackagesPath():
        if os.path.exists(path):
            print(f"✓ Directory exists: {path}")
        else:
            print(f"✗ Directory missing: {path}")
    
    print("\n🎉 Configuration appears to be correct!")
    
except Exception as e:
    print(f"✗ Error: {e}")
    sys.exit(1)
