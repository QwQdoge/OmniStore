# Third-party notices

OmniStore's own code is licensed under GPL-3.0-only (see `LICENSE`). The
components below keep their upstream licenses. Packages install this file to
`/usr/share/licenses/omnistore-bin/`, where the About page reads it.

## Platform

These libraries are dynamically linked from the system and are not bundled.

- **Qt 6** (Qt Base, Qt Declarative) — https://www.qt.io/ — LGPL-3.0-only
- **MeoUI** — shared QML design system, including its fonts and Material
  Symbols — https://github.com/QwQdoge/MeoUI — MIT; bundled assets are listed
  in MeoUI's own `THIRD_PARTY_NOTICES.md`
- **Meo.System / meo-kde runtime** — https://github.com/QwQdoge/meo-kde

## Bundled Python backend

The release bundle contains a self-contained Python backend
(`backends/python_server`, built with PyInstaller). It includes the Python
runtime and the direct dependencies listed in `python/requirements.txt`:

| Component | Use | License |
| --- | --- | --- |
| CPython | Backend runtime | PSF-2.0 |
| PyInstaller bootloader | Starts the bundled backend | GPL-2.0-or-later with the PyInstaller bootloader exception |
| FastAPI | Local backend API | MIT |
| Uvicorn | ASGI server | BSD-3-Clause |
| websockets | Task progress streaming | BSD-3-Clause |
| python-multipart | Form parsing | Apache-2.0 |
| aiohttp | Asynchronous HTTP client | Apache-2.0 |
| HTTPX | HTTP client | BSD-3-Clause |
| psutil | System and storage information | BSD-3-Clause |
| PyYAML | Configuration files | MIT |
| packaging | Version comparison | Apache-2.0 OR BSD-2-Clause |
| lxml | XML parsing | BSD-3-Clause |
| Requests | HTTP client | Apache-2.0 |
| Rich | Console output | MIT |
| materialyoucolor | Material color utilities | MIT |

These packages pull in further transitive dependencies, each under its own
license; their metadata is shipped inside the bundled backend.

Development and test tools that are not shipped (for example pytest, CMake)
are not listed here.
