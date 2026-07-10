## 2025-05-15 - Installed List Subprocess Consolidation

**Learning:** Retrieving package sizes in a loop for installed lists is a massive O(N) bottleneck due to subprocess spawning overhead. Most modern package managers (Flatpak, Pacman) provide ways to retrieve this metadata in bulk.

**Action:** Always prefer batch metadata retrieval (e.g., `flatpak list --columns=...,size` or bulk `pacman -Qi`) over individual per-package queries for list-based UI features.
