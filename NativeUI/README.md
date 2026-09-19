# OmniStore NativeUI — Phase 0

This is an isolated Qt/QML preview for the future MeoArch-native OmniStore
frontend. It is deliberately not packaged, registered as the desktop launcher,
or connected to the current Flutter client. Those boundaries keep the existing
Flutter work and its uncommitted changes intact while the native UI is proven.

## What it can do

- Render a borderless, dynamic-MeoUI library and storage overview.
- Read the versioned, zero-argument `/usr/bin/omnistore-apps-export` contract
  (`org.meo.omnistore.installed-usage`, version 1) with a 45-second deadline
  and a 4 MiB document limit.
- Display a controlled unavailable state when that read-only contract is not
  present or invalid.

## What it intentionally cannot do

- Discover, search, detail, install, remove, update, or execute packages.
- Call the unversioned JSON CLI flags, the loopback daemon, FastAPI, or any
  privileged package-manager command.
- Read credentials, contact an account service, or make network requests.

The source-bound adapter contract is in
[`docs/installed-usage-adapter.md`](docs/installed-usage-adapter.md). A
versioned catalog contract and explicit installation handoff are required
before this can replace the current Flutter application.

## Language and accessibility

The native preview has no Account connection or persistent application
preferences, so its language follows the system locale. It ships Simplified
Chinese and English; every Chinese system locale resolves to the Simplified
Chinese catalog, while other locales use English until their own catalog is
added. `--ui-language=zh_CN` and `--ui-language=en_US` are validation-only
overrides and never alter the system, Plasma session, or an Account setting.

The navigation controls retain normal keyboard button semantics, and the
library and discovery surfaces describe their read-only availability rather
than presenting a disabled package action as a selectable feature.

## Local build

```bash
cmake -S NativeUI -B /home/shekong/Projects/outputs/omni-store/build/native-ui \
  -DCMAKE_BUILD_TYPE=Debug
cmake --build /home/shekong/Projects/outputs/omni-store/build/native-ui --parallel
ctest --test-dir /home/shekong/Projects/outputs/omni-store/build/native-ui \
  --output-on-failure
```

For a deterministic, non-user-data preview, pass a test fixture:

```bash
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
  /home/shekong/Projects/outputs/omni-store/build/native-ui/OmniStoreNativePreview \
  --fixture tests/fixtures/installed-usage-v1.json --screenshot preview.png
```
