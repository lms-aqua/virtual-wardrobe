"""Virtual Wardrobe core package (shared by API and worker)."""

from importlib.metadata import PackageNotFoundError
from importlib.metadata import version as _package_version

try:
    # pyproject.toml is the single source of truth for the API version; this
    # reads whatever was actually installed rather than a second hardcoded copy.
    __version__ = _package_version("wardrobe-core")
except PackageNotFoundError:  # running from a source checkout, not installed
    __version__ = "2.0.0"

__all__ = ["__version__"]
