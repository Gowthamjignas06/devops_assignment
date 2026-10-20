# Exercise 2: Deploy a Flask App on Minikube with kubectl and YAML

Original: [Exercises/2-Minikube-Kubectl-Flask.md](https://github.com/SunagP/DevOps-Lab/blob/main/Exercises/2-Minikube-Kubectl-Flask.md)

## What it does

Builds a small Flask app (port 15000) straight into Minikube's Docker daemon,
deploys it with a `Deployment` (`imagePullPolicy: Never`, so Kubernetes uses
the local image and never pulls from Docker Hub), shows that it isn't reachable
from outside yet, then adds a `NodePort` Service and reaches it through
`minikube service --url`.

## Prerequisites

- Docker running, plus `kubectl` and `minikube` (`setup/verify.sh`)
- Optional reading: [The Illustrated Children's Guide to Kubernetes](https://www.cncf.io/phippy/the-childrens-illustrated-guide-to-kubernetes/)

## Files

| File | From step |
|---|---|
| `app.py` | Step 2 |
| `Dockerfile`, `requirements.txt` | Step 3 |
| `flask-deployment.yaml` | Step 5 (Deployment only) |
| `flask-deployment-with-service.yaml` | Step 13 (Deployment + Service) |

## Run it

Run everything from this folder.

```bash
# Step 1: start the cluster
minikube start

# Step 4: point your docker CLI at Minikube's Docker daemon, then build there
minikube docker-env              # just shows the variables that will be set
eval $(minikube docker-env)
docker build -t flask-app .

# Steps 5-6: deploy
kubectl apply -f flask-deployment.yaml

# Steps 7-10: inspect
kubectl get deployments
kubectl get pods -l app=flask-app
kubectl describe deployment flask-app
kubectl logs deployment/flask-app        # no need to copy the pod name

# Steps 11-12: there is no Service yet, so this is EXPECTED to fail
kubectl get services
curl http://127.0.0.1:15000              # -> "Failed to connect" (expected)

# Step 13: add the Service
kubectl apply -f flask-deployment-with-service.yaml
#   deployment.apps/flask-app unchanged
#   service/flask-app-service created

# Get a URL. Keep this terminal open; it's a tunnel on macOS/WSL.
minikube service flask-app-service --url
```

In a **second terminal**, curl the URL it printed (the port is random):

```bash
curl http://127.0.0.1:<port>
# Hello from Flask on Kubernetes!
```

## Cleanup

```bash
kubectl delete -f flask-deployment-with-service.yaml
eval $(minikube docker-env -u)   # point docker back at your normal daemon
minikube stop                    # or: minikube delete
```

## Screenshots

Capture these from **your own run** and save them in [`screenshots/`](screenshots/) with these names:

| File | What to capture |
|---|---|
| `screenshots/01-docker-build.png` | `eval $(minikube docker-env)` + `docker build -t flask-app .` succeeding |
| `screenshots/02-deployment-pods.png` | `kubectl get deployments` and `kubectl get pods -l app=flask-app` |
| `screenshots/03-curl-fails.png` | Step 12: `curl http://127.0.0.1:15000` failing (expected) |
| `screenshots/04-service-curl.png` | `minikube service flask-app-service --url` + `curl` returning "Hello from Flask on Kubernetes!" |

## Changes from the original / gotchas

- **Base image:** `python:3.8-slim` (end-of-life) → `python:3.12-slim`.
- **Pinned deps:** `pip install flask` → `requirements.txt` with
  `Flask==3.1.3` / `Werkzeug==3.1.9`. The Dockerfile copies only `app.py` and
  `requirements.txt` instead of `COPY . /app`, so README/YAML edits don't
  rebuild the image.
- **Two YAML files:** Step 13 in the original overwrites `flask-deployment.yaml`.
  It's split into `flask-deployment-with-service.yaml` here so both steps work as written.
- **`eval $(minikube docker-env)` only lasts for the current terminal.** If you
  rebuild in a new terminal, run it again, or the image lands in your normal
  Docker daemon and the Pod shows `ErrImageNeverPull`.
- **Cheat sheet:** `minikube start --kubernetes-version=v1.21.2` in the
  original is too old for current Minikube releases. Use plain `minikube start`.
- `kubectl logs deployment/flask-app` replaces copying a pod name like
  `flask-app-b8cd75b6f-tpdpr` from the original.
