# Troubleshooting

## KI-0001: Docker Desktop fails at the Windows inference endpoint
- **Recognize:** Startup fails while removing `dockerInference`; the Linux engine is unreachable before this app can be built or started.
- **Fix:** With the machine owner's approval, stop Docker Desktop and its WSL distribution, verify the affected runtime directory contains only confirmed transient endpoints, and rename that directory to a backup before restarting. This restored engine access for the 2026-10-13 tests; verify recovery with `docker version` and an actual container test.
- **Prevent or limit:** Preserve existing images, volumes, settings and data disks. Do not infer a permanent repair from one successful startup. Keep host-specific paths in the ignored `TROUBLESHOOTING.local.md`; get separate approval for another repair scope.
- **Evidence:** [Docker Desktop issue 625](https://github.com/docker/desktop-feedback/issues/625) reports the matching failure and limited runtime-directory recovery, including recurrence on some systems.
