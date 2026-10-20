# Exercise 5: Docker Security with AppArmor and Python

Original: [Exercises/5-Docker-Security-AppArmor.md](https://github.com/SunagP/DevOps-Lab/blob/main/Exercises/5-Docker-Security-AppArmor.md)

> **Native Linux only.** AppArmor is a Linux kernel security module. It doesn't
> exist on macOS, and Docker Desktop's VM doesn't enable it. WSL2's default
> kernel doesn't enforce it either. Use a native Ubuntu machine or an Ubuntu VM
> (e.g. Multipass, UTM, VirtualBox, or a cloud VM). On macOS/WSL the
> `--security-opt apparmor=...` option is ignored or rejected, so you can't see
> the restrictions working.

## What it does

Containerises a Flask app, writes an AppArmor profile that denies reading
`/etc`, writing `/var`, and executing anything in `/bin` or `/usr/bin`, loads
it into the kernel, and runs the container under it. You do this from the CLI
and with the Docker SDK for Python. Then you try restricted actions
(`cat /etc/passwd`, `/bin/bash`) inside the container and see them blocked.

## Prerequisites

- Native Ubuntu with AppArmor enabled: `sudo aa-status` should print "apparmor module is loaded"
- Docker Engine, `apparmor-utils` (both installed by `setup/install-ubuntu.sh`)
- The repo's `.venv` with the `docker` SDK: `source ../.venv/bin/activate`

## Files

| File | Purpose |
|---|---|
| `app.py`, `requirements.txt`, `Dockerfile` | Flask app image `flask-apparmor` |
| `my-apparmor-profile` | AppArmor profile, installed to `/etc/apparmor.d/` |
| `apply_apparmor.py` | Task 4: builds and runs the container via the Docker SDK and prints the applied profile |
| `test_restricted_actions.py` | Task 5: runs the container and tries restricted commands |

## Run it

Run everything from this folder.

```bash
# Task 2: build the image
docker build -t flask-apparmor .

# Task 3: install and load the profile
sudo cp my-apparmor-profile /etc/apparmor.d/my-apparmor-profile
sudo apparmor_parser -r /etc/apparmor.d/my-apparmor-profile
sudo aa-status | grep my-apparmor-profile          # should be listed in enforce mode

# Run the container under the profile (Ctrl+C to stop)
docker run --rm --security-opt="apparmor=my-apparmor-profile" -p 5000:5000 flask-apparmor
# in another terminal:  curl http://localhost:5000

# Task 4: apply the profile with the Docker SDK
source ../.venv/bin/activate
python apply_apparmor.py

# Task 5: test restricted actions
python test_restricted_actions.py
```

Expected for Task 5: both attempts fail, typically with **exit code 126**
(permission denied when exec'ing `/usr/bin/cat` and `/bin/bash`, because the
profile denies executing anything in `/bin` and `/usr/bin`). The original shows
exit code 1 for `cat`. Either way, the contents of `/etc/passwd` must **not** be printed.

Check denials in the kernel log:

```bash
sudo dmesg | grep 'apparmor="DENIED"' | tail
```

## Cleanup

```bash
docker rm -f $(docker ps -aq --filter ancestor=flask-apparmor) 2>/dev/null
sudo apparmor_parser -R /etc/apparmor.d/my-apparmor-profile   # unload
sudo rm /etc/apparmor.d/my-apparmor-profile
docker rmi flask-apparmor
```

## Screenshots

Capture these from **your own run** and save them in [`screenshots/`](screenshots/) with these names:

| File | What to capture |
|---|---|
| `screenshots/01-aa-status.png` | `sudo aa-status | grep my-apparmor-profile` showing the profile in enforce mode |
| `screenshots/02-apply-apparmor.png` | `python apply_apparmor.py` output with the applied profile |
| `screenshots/03-restricted-actions.png` | `python test_restricted_actions.py` showing both attempts blocked |

## Changes from the original / gotchas

> **Tested:** the profile compiles with `apparmor_parser` (Ubuntu 24.04), and
> the image builds and serves the page.
> **Not tested:** enforcement. The repo was built on macOS, where no kernel
> enforces AppArmor. The profile follows the structure of Docker's own
> `docker-default` profile. If the container won't start under it, check
> `sudo dmesg | grep DENIED` for the path being blocked.

- **The original profile doesn't even load.** `deny /bin/** rmix` fails with
  `Invalid perms, in deny rules 'x' must not be preceded by exec qualifier 'i'`.
  Now `deny /bin/** rmx` (same for `/usr/bin`).
- **The original profile can't be used by Docker.** It's declared as
  `/usr/bin/python3 { ... }` (a path-attached profile). Docker looks profiles
  up by *name*, so `--security-opt apparmor=my-apparmor-profile` fails with
  "profile not found". Now declared as `profile my-apparmor-profile ...`.
- **The original profile blocks everything.** AppArmor denies anything not
  explicitly allowed, and the original only allowed `/app/**`, so the container
  couldn't exec Python. Added `file,` (allow by default) plus
  `#include <abstractions/base>`. The `deny` rules still override, so the
  exercise's restrictions are unchanged.
- **Signals:** added `signal` rules so `docker stop` can stop the container.
  Without them `docker stop` hangs until it falls back to SIGKILL, and may fail
  with "permission denied".
- **Networking:** added UDP (`dgram`) alongside TCP. Werkzeug opens a UDP
  socket at startup and would crash without it.
- **Scripts:** both now call `container.remove()` after `stop()`, so re-running
  them doesn't leave stopped containers behind. They also print the progress
  lines the original shows in its expected output.
- **Dockerfile:** `python:3.8-slim` (end-of-life) → `python:3.12-slim`, Flask
  pinned via `requirements.txt`, and only `app.py` is copied (not the scripts/profile).
- **Port 5000 on macOS** is taken by AirPlay Receiver. That doesn't matter here,
  since this exercise needs Linux anyway.
