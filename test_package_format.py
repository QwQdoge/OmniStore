#!/usr/bin/env python3
"""Test script to verify the standardized package information format."""

import sys
import json
sys.path.insert(0, '/home/shekong/Projects/OmniArch/backend')

from bauh.gems.arch import pacman

def test_package_format():
    """Test the standardized package format."""
    
    # Test the _create_package_info helper function
    pkg_info = pacman._create_package_info(
        name="google-chrome",
        version="122.0.6261.94-1",
        description="The web browser from Google",
        source="aur",
        installed=False
    )
    
    print("标准化包信息格式:")
    print(json.dumps(pkg_info, indent=2))
    
    # Verify the format
    assert pkg_info["name"] == "google-chrome"
    assert pkg_info["version"] == "122.0.6261.94-1"
    assert pkg_info["description"] == "The web browser from Google"
    assert pkg_info["source"] == "aur"
    assert pkg_info["installed"] == False
    
    print("\n✅ 格式验证通过!")
    
    # Test with installed package
    installed_pkg = pacman._create_package_info(
        name="vim",
        version="9.0.1234-1",
        description="Advanced text editor",
        source="extra",
        installed=True
    )
    
    print("\n已安装包示例:")
    print(json.dumps(installed_pkg, indent=2))

if __name__ == "__main__":
    test_package_format()
