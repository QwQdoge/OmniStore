from dataclasses import dataclass
from typing import List, Optional

@dataclass
class Asset:
    name: str
    download_url: str
    size: int
    content_type: str
    platform: str  # android, linux, windows, macos, unknown
    type: str      # apk, deb, exe, dmg, zip, unknown

@dataclass
class Release:
    tag_name: str
    name: str
    published_at: str
    assets: List[Asset]
    body: Optional[str] = None

@dataclass
class Repository:
    id: str
    owner: str
    name: str
    full_name: str
    description: str
    stars: int
    forks: int
    url: str
    icon: Optional[str] = None
    license: Optional[str] = None
    host: str = "github.com"
