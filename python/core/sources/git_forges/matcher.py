import re
from typing import Dict, Any, List
from .models import Asset

class AssetMatcher:
    """Intelligent asset matching for different platforms and architectures."""

    @staticmethod
    def identify_asset(asset_name: str) -> Dict[str, str]:
        name = asset_name.lower()
        platform = "unknown"
        asset_type = "unknown"
        channel = "stable"

        # Identify Channel
        if any(x in name for x in ("beta", "preview", "pre")): channel = "beta"
        elif "nightly" in name: channel = "nightly"

        # Identify Type
        if name.endswith(".apk"): asset_type = "apk"; platform = "android"
        elif name.endswith(".deb"): asset_type = "deb"; platform = "linux"
        elif name.endswith(".rpm"): asset_type = "rpm"; platform = "linux"
        elif name.endswith(".appimage"): asset_type = "appimage"; platform = "linux"
        elif name.endswith(".exe") or name.endswith(".msi"): asset_type = "exe"; platform = "windows"
        elif name.endswith(".dmg") or name.endswith(".pkg"): asset_type = "dmg"; platform = "macos"
        elif name.endswith(".zip") or name.endswith(".tar.gz") or name.endswith(".tgz"): asset_type = "archive"

        # Identify Platform from name if not already identified
        if platform == "unknown":
            if "android" in name: platform = "android"
            elif "linux" in name: platform = "linux"
            elif "win" in name or "windows" in name: platform = "windows"
            elif "mac" in name or "darwin" in name: platform = "macos"

        return {"platform": platform, "type": asset_type, "channel": channel}

    @staticmethod
    def filter_assets_for_platform(assets_data: List[Dict[str, Any]], target_platform: str) -> List[Asset]:
        filtered = []
        for data in assets_data:
            meta = AssetMatcher.identify_asset(data["name"])
            if meta["platform"] == target_platform or meta["platform"] == "unknown":
                filtered.append(Asset(
                    name=data["name"],
                    download_url=data["browser_download_url"],
                    size=data["size"],
                    content_type=data["content_type"],
                    platform=meta["platform"],
                    type=meta["type"]
                ))
        return filtered
