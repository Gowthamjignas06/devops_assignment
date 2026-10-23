# DevOps Lab Workspace

Ready-to-run files for the 10 exercises in
[SunagP/DevOps-Lab › Exercises](https://github.com/SunagP/DevOps-Lab/tree/main/Exercises)
(built from commit `e15c863`, Sept 2026).

Each exercise folder has every file the exercise asks you to create (apps,
Dockerfiles, manifests, configs, Jenkinsfiles, tests), with typos fixed and
versions pinned. Its `README.md` has the exact commands in order, cleanup, and
a **"Changes from the original"** list explaining every fix.

## Exercises

| # | Folder | What you learn | Tools needed | Runs on |
|---|---|---|---|---|
| 1 | [`01-k8s-getting-started`](01-k8s-getting-started/) | First Pod (nginx) + NodePort Service | Docker, kubectl, Minikube | macOS, WSL2, Linux |
| 2 | [`02-minikube-flask`](02-minikube-flask/) | Build into Minikube, Deployment + Service in YAML | Docker, kubectl, Minikube | macOS, WSL2, Linux |
| 3 | [`03-minikube-replicasets`](03-minikube-replicasets/) | ReplicaSets, scaling, self-healing, probes | Docker, kubectl, Minikube | macOS, WSL2, Linux |
| 4 | [`04-docker-networking`](04-docker-networking/) | Bridge networks, Flask + MySQL + Redis | Docker | macOS, WSL2, Linux |
| 5 | [`05-docker-apparmor`](05-docker-apparmor/) | AppArmor profiles, Docker SDK for Python | Docker, Python, apparmor-utils | **Native Linux only** |
| 6 | [`06-grafana-monitoring`](06-grafana-monitoring/) | Prometheus metrics + alerts, Grafana, Jenkins pipeline | Docker, Python, Jenkins | macOS, WSL2, Linux |
| 7 | [`07-jenkins-ci`](07-jenkins-ci/) | CI concepts, install and unlock Jenkins | Docker, Jenkins | macOS, WSL2, Linux |
| 8 | [`08-jenkins-hello-world`](08-jenkins-hello-world/) | Freestyle job pulling from GitHub | Docker, Jenkins, git, **GitHub** | macOS, WSL2, Linux |
| 9 | [`09-jenkins-multistage-pipeline`](09-jenkins-multistage-pipeline/) | Pipeline-from-SCM: build → test → deploy | Docker, Jenkins, git, Python, **GitHub** | macOS, WSL2, Linux |
| 10 | [`10-multinode-multi-app`](10-multinode-multi-app/) | 3-node cluster, anti-affinity, 2 services | Docker, kubectl, Minikube | macOS, WSL2, Linux |

**Screenshots:** each exercise folder has a `screenshots/` folder, and a
"Screenshots" table in its README lists what to capture and the file names to
use. Add them from your own runs as you complete each exercise.

**Guided runs:** `./lab.sh <number>` (e.g. `./lab.sh 4`) walks you through an
exercise. It runs the commands in order, clears the screen before each screenshot
point, waits while you take the screenshot, then moves it into that exercise's
`screenshots/` folder with the right name. `./lab.sh status` shows what's still
missing.

### Recommended order

Docker basics first, then Kubernetes, then CI/CD, then monitoring (which uses Jenkins):

1. **4** Docker networking
2. **1 → 2 → 3 → 10** Kubernetes, from a single Pod to a multi-node cluster
3. **7 → 8 → 9** Jenkins: install, first job, multi-stage pipeline
4. **6** Monitoring with Prometheus/Grafana, deployed by Jenkins
5. **5** AppArmor, whenever you have a native Linux machine or VM

## Important notes

> **Exercise 5 (AppArmor) needs native Linux.** It won't work properly on
> macOS (no AppArmor; Docker Desktop's VM doesn't enable it) or WSL2 (the
> default kernel doesn't enforce it). Use a native Ubuntu install or an Ubuntu
> VM (Multipass, UTM, VirtualBox, cloud VM).

> **Exercises 8 and 9 need your own GitHub repo.** Jenkins clones the code from
> GitHub, so you push `hello-world.sh` (Exercise 8) and the Flask app +
> `Jenkinsfile` (Exercise 9) to a public repo of your own (`devops-sample-code`).
> Pushing needs a GitHub Personal Access Token. Paste it only when `git push`
> prompts; never put it in a file.

> **Jenkins (Exercises 6–9)** runs from [`jenkins/`](jenkins/README.md):
> `jenkins/run-jenkins.sh`. The stock `jenkins/jenkins:lts` image has no Docker
> CLI or Python, so the course's pipelines fail on it.

## Setup

### 1. Install the tools

| Your OS | Run |
|---|---|
| macOS | `setup/install-macos.sh` |
| Ubuntu 22.04/24.04 (native) | `setup/install-ubuntu.sh` |
| Windows | Set up WSL2 first (see [Using on Windows](#using-on-windows-wsl2)), then `setup/install-ubuntu.sh` inside Ubuntu |

These install Docker (Docker Desktop on macOS; Docker Engine on native Ubuntu),
kubectl, Minikube, Python 3.10+, git, apparmor-utils (Linux only), and a
Python virtual env `.venv` with the packages from [`requirements.txt`](requirements.txt)
(Flask, prometheus-client, docker SDK). **They're safe to re-run**: anything
already installed is skipped.

### 2. Verify

```bash
setup/verify.sh
```

Prints `PASS` / `FAIL` / `WARN` and the version for each tool, and exits
non-zero if anything required is missing.

```
PASS  docker (daemon)              server 29.8.2
PASS  kubectl                      Client Version: v1.37.1
PASS  minikube                     v1.39.0
PASS  python 3.10+                 Python 3.12.15 (/opt/homebrew/bin/python3.12)
PASS    flask (.venv)              2.1.2
SKIP  apparmor_parser              Linux only; Exercise 5 needs native Linux

12 passed, 0 failed, 0 warnings
```

### 3. Secrets / personal values

```bash
cp .env.example .env      # .env is git-ignored. Edit it with your own values.
```

`.env` holds the MySQL root password for Exercise 4 and your GitHub / Docker
Hub usernames. No real passwords or tokens are committed in this repo.
Grafana's `admin`/`admin` is Grafana's built-in first-login default, and it
asks you to change it.

### 4. Python

```bash
source .venv/bin/activate     # in each new terminal where you run Python scripts
```

Only Exercises 5, 6 and 9 (local test run) run Python on your machine.
Everything else runs inside containers with its own pinned `requirements.txt`.

## Using on Windows (WSL2)

1. **Install WSL2 + Ubuntu.** In PowerShell **as Administrator**:
   ```powershell
   wsl --install -d Ubuntu
   ```
   Reboot if asked, open **Ubuntu** from the Start menu, and create your Linux user.
   Check it's WSL **2**: `wsl -l -v` (VERSION column = 2).
2. **Install Docker Desktop for Windows** (<https://www.docker.com/products/docker-desktop/>),
   then in Docker Desktop: **Settings → General → "Use the WSL 2 based engine"**
   and **Settings → Resources → WSL integration → enable your Ubuntu distro**.
   Check from the Ubuntu terminal: `docker info` should work without sudo.
3. **Clone the repo inside the WSL home folder (`~/`), not under `/mnt/c`:**
   ```bash
   cd ~
   git clone https://github.com/<your-GitHub-username>/devops-lab-workspace.git
   cd devops-lab-workspace
   setup/install-ubuntu.sh
   setup/verify.sh
   ```
   `/mnt/c` is the Windows filesystem. It's much slower for Docker builds,
   doesn't keep Linux file permissions (scripts lose their executable bit), and
   can break file watching.
4. **Resources:** for Exercise 10 (3 nodes) give WSL enough memory. Create
   `%UserProfile%\.wslconfig` with:
   ```ini
   [wsl2]
   memory=8GB
   processors=6
   ```
   Then run `wsl --shutdown` and reopen Ubuntu.
5. **Line endings:** [`.gitattributes`](.gitattributes) forces LF for `*.sh`,
   `*.py`, `Dockerfile*`, `Jenkinsfile`, `*.yml` and `*.yaml`, so even a
   Windows-side checkout won't produce `/bin/bash^M: bad interpreter`. If you
   edit files from Windows, use an editor that keeps LF (VS Code with the WSL
   extension does).
6. Browser URLs like `http://localhost:8080` (Jenkins) and `http://localhost:3000`
   (Grafana) work from Windows. `minikube service ... --url` tunnels must stay
   open in the Ubuntu terminal while you use them.

## Repo layout

```
.
├── README.md               this file
├── requirements.txt        Python packages for .venv (Flask, prometheus-client, docker SDK)
├── .env.example            template for .env (git-ignored)
├── .gitattributes          LF line endings for scripts/configs
├── setup/
│   ├── install-macos.sh    Homebrew-based installer
│   ├── install-ubuntu.sh   Ubuntu / WSL2 installer
│   ├── setup-python-venv.sh  creates .venv (called by both installers)
│   ├── verify.sh           PASS/FAIL tool check
│   └── common.sh           shared helpers
├── jenkins/                Jenkins image + start script for Exercises 6-9
└── 01-... 10-...           one folder per exercise
```

## What was fixed across the board

Every exercise README lists its own fixes. The big ones:

- **Flask 2.0/2.1 + Werkzeug:** unpinned `Flask==2.0.1` / `flask==2.1.2` now
  crash at import (`ImportError: url_quote`) because pip pulls Werkzeug 3.
  Pinned `Werkzeug==2.0.3` / `2.1.2` (Exercises 4, 9). Tested on Python 3.12 and 3.13.
- **MySQL** exits immediately without `MYSQL_ROOT_PASSWORD`. Now `mysql:8.4`
  with the password from `.env` (Exercise 4).
- **`:latest` images pinned:** nginx `1.30`, mysql `8.4`, redis `7.4`,
  prometheus `v3.13.4`, grafana `13.2.4`, Jenkins `2.580.1-lts-jdk21`.
  End-of-life `python:3.8/3.9-slim` → `python:3.12-slim`.
- **Exercise 3** didn't run: wrong filename in the Dockerfile, wrong image
  name, wrong resource name, and the image was built after it was needed.
- **Exercise 5** AppArmor profile didn't compile (`rmix` in deny rules), and
  Docker couldn't use it anyway (wrong profile declaration, and default-deny
  blocked Python itself).
- **Exercise 6** pipeline: no Dockerfile, no Docker inside Jenkins,
  placeholder paths, bind mounts that can't work from Jenkins, and Linux-only
  `172.17.0.1` addresses.
- **Exercises 8/9:** `git init` + `git push origin main` mismatch, and the
  Jenkins `*/master` default branch.
- **Exercise 10:** Shopping Cart deployed into a namespace that doesn't exist.
