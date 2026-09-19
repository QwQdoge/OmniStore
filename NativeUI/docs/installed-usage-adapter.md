# Installed-usage adapter contract

## Phase-0 input

The native shell's only production input is the zero-argument executable:

```text
/usr/bin/omnistore-apps-export
```

It must return one UTF-8 JSON object with all of these fields:

```json
{
  "schema": "org.meo.omnistore.installed-usage",
  "version": 1,
  "status": "success",
  "generatedAt": "2026-09-17T00:00:00Z",
  "applicationCount": 1,
  "knownSizeBytes": 1048576,
  "unknownSizeCount": 0,
  "sources": [],
  "applications": []
}
```

The adapter rejects an invalid schema/version/status, malformed JSON, negative
counts or sizes, invalid source/application records, a count mismatch, a
document larger than 4 MiB, a process that cannot start, a non-zero exit, or a
process that does not finish within 45 seconds. The UI then displays only a
controlled unavailable state.

## Safety boundary

The adapter uses `QProcess::setProgram()` and an explicit empty argument list;
it does not invoke a shell. It never runs package actions. In particular, this
phase must not consume `--list-installed --json`, search/details/install flags,
the `127.0.0.1:9081` daemon, FastAPI, PySide6, credentials, or an undocumented
JSON response as though it were a stable public interface.

## Next contracts

1. Define and test `org.meo.omnistore.catalog` version 1 for discovery and
   detail data.
2. Define a consented, versioned external-install handoff with source,
   package/version, expected size, permissions, cancellation, and recovery.
3. Keep package mutation in the existing authority; QML must never acquire
   privileged package-management ownership.
