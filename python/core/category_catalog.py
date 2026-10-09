"""Read native application categories from the distribution's AppStream data."""
from functools import lru_cache
import gzip
import logging
from pathlib import Path
import xml.etree.ElementTree as ET


@lru_cache(maxsize=4)
def _catalog(signature: tuple) -> tuple:
    entries = []
    for filename, _, _ in signature:
        path = Path(filename)
        try:
            opener = gzip.open if path.suffix == ".gz" else open
            with opener(path, "rb") as stream:
                for _, component in ET.iterparse(stream, events=("end",)):
                    if component.tag != "component":
                        continue
                    package = component.findtext("pkgname")
                    if package and component.get("type") in ("desktop", "desktop-application"):
                        name = component.findtext("name") or package
                        summary = component.findtext("summary") or ""
                        categories = tuple(element.text for element in component.findall("categories/category"))
                        entries.append((package, name, summary, categories))
                    component.clear()
        except (OSError, ET.ParseError, EOFError) as error:
            logging.warning("Cannot read application catalog %s: %s", path, error)
    return tuple(entries)


def native_category_apps(category: str, directory: Path = Path("/usr/share/swcatalog/xml")) -> list[dict]:
    signature = []
    for pattern in ("*.xml", "*.xml.gz"):
        for path in sorted(directory.glob(pattern)):
            try:
                stat = path.stat()
                signature.append((str(path), stat.st_mtime_ns, stat.st_size))
            except OSError:
                continue
    rows = {}
    for package, name, summary, categories in _catalog(tuple(signature)):
        if category not in categories or package in rows:
            continue
        rows[package] = {"id": package, "name": name, "description": summary,
                         "source": "Pacman", "primary_source": "Pacman",
                         "categories": list(categories), "installed": False,
                         "variants": [{"id": package, "source": "Pacman", "installed": False}]}
    return sorted(rows.values(), key=lambda row: row["name"].casefold())
