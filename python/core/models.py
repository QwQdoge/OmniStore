from pydantic import BaseModel, Field
from typing import List, Dict, Any, Optional

class PackageVariant(BaseModel):
    source: str
    id: Optional[str] = None
    name: Optional[str] = None
    version: Optional[str] = "Unknown"
    installed: bool = False
    managed: bool = True
    download_size: Optional[str] = None
    installed_size: Optional[str] = None
    disk_size: Optional[int] = None
    size_confidence: Optional[str] = None
    size_source: Optional[str] = None
    depends: Optional[List[str]] = None
    url: Optional[str] = None

class AppPackage(BaseModel):
    name: str
    id: str
    description: str = ""
    installed: bool = False
    version: str = "N/A"
    primary_source: str = "Native"
    developer: Optional[str] = None
    icon: Optional[str] = None
    screenshots: List[str] = Field(default_factory=list)
    variants: List[PackageVariant] = Field(default_factory=list)
    score: int = 0
    is_exact_match: bool = False
    install_location: Optional[str] = None
    uninstall_string: Optional[str] = None
    size_confidence: Optional[str] = None
    size_source: Optional[str] = None
    disk_size: Optional[int] = None
    installed_size: Optional[str] = None
    managed: bool = True
    license: Optional[str] = None

class SearchResults(BaseModel):
    query: str
    results: List[AppPackage]

class AppDetails(AppPackage):
    # Details might have more fields or just be a more populated AppPackage
    pass

class RecommendationResponse(BaseModel):
    featured: List[AppPackage] = Field(default_factory=list)
    trending: List[AppPackage] = Field(default_factory=list)
    for_you: List[AppPackage] = Field(default_factory=list)

class InstallationDecision(BaseModel):
    """Validated, non-blocking advice displayed before an installation starts."""
    recommendedVariant: Optional[str] = None
    reasons: List[str] = Field(default_factory=list, max_length=5)
    risks: List[str] = Field(default_factory=list, max_length=5)
    alternatives: List[str] = Field(default_factory=list, max_length=5)
    preflightChecks: List[str] = Field(default_factory=list, max_length=5)

class UpdateInfo(BaseModel):
    name: str
    source: str
    current_version: Optional[str] = None
    new_version: str
    description: Optional[str] = None

class CommandResponse(BaseModel):
    status: str = "success"
    message: Optional[str] = None
    error: Optional[str] = None
    context: Optional[str] = None
    response: Any = None
    stdout: Optional[str] = None
    traceback: Optional[str] = None
