# Exercise 1: Kubernetes Getting Started (Hello Pod)

Original: [Exercises/1-Kubernetes-Getting-Started.md](https://github.com/SunagP/DevOps-Lab/blob/main/Exercises/1-Kubernetes-Getting-Started.md)

## What it does

Starts a single-node Minikube cluster, runs an `nginx` container as a Pod
(standing in for Zepto's storefront web app), exposes it as a `NodePort`
Service, and opens it in your browser. You should see the nginx welcome page.

## Prerequisites

- Docker running (`docker info` works)
- `kubectl` and `minikube` installed (`setup/verify.sh` checks both)

There are no files to create. This exercise is commands only.

## Run it

```bash
# 1. Start a local cluster (uses the Docker driver automatically)
minikube start

# 2. Create a Pod from the nginx image (pinned instead of :latest)
kubectl run hello-k8s --image=nginx:1.30 --port=80

# 3. Wait until it's Running
kubectl get pods
kubectl wait --for=condition=Ready pod/hello-k8s --timeout=120s

# 4. Expose the Pod as a NodePort Service
kubectl expose pod hello-k8s --type=NodePort --port=80

# 5. Open it in the browser. On macOS and WSL this opens a tunnel, so keep the
#    terminal open while you look at the page and press Ctrl+C when done.
minikube service hello-k8s
```

Explore a little:

```bash
kubectl describe pod hello-k8s
kubectl get svc hello-k8s
minikube service hello-k8s --url   # just print the URL (keep the terminal open)
```

## Cleanup

```bash
kubectl delete service hello-k8s
kubectl delete pod hello-k8s
minikube stop        # or: minikube delete   (removes the cluster entirely)
```

## Screenshots

Capture these from **your own run** and save them in [`screenshots/`](screenshots/) with these names:

| File | What to capture |
|---|---|
| `screenshots/01-minikube-start.png` | `minikube start` finishing with "Done! kubectl is now configured" |
| `screenshots/02-pod-running.png` | `kubectl get pods` showing `hello-k8s` Running |
| `screenshots/03-nginx-welcome.png` | Browser showing the nginx welcome page from `minikube service hello-k8s` |

## Changes from the original / gotchas

- **Image pinned:** `nginx` (implicitly `:latest`) → `nginx:1.30` (current stable branch).
- **WSL install steps:** the original installs `virtualbox` inside WSL. That
  doesn't work in WSL2 and isn't needed. Minikube uses the Docker driver
  (Docker Desktop with WSL integration). Use `setup/install-ubuntu.sh` instead.
- **Unclosed code blocks:** several steps in the original markdown are missing
  their closing fences. The commands above are the complete list.
- **macOS / WSL with Docker driver:** the NodePort isn't reachable directly from
  your host, so `minikube service` creates a tunnel that only lives while the
  command runs.
