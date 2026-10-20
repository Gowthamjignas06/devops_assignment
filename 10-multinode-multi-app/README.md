# Exercise 10: Multi-Node Minikube Cluster with Multiple Apps

Original: [Exercises/10-Minikube-Multi-Node-Multi-App-Minikube-Deployment.md](https://github.com/SunagP/DevOps-Lab/blob/main/Exercises/10-Minikube-Multi-Node-Multi-App-Minikube-Deployment.md)

## What it does

Creates a **3-node** Minikube cluster (profile `devops-multinode`) and deploys
two Flask microservices for an e-commerce store:

- **Product Catalog** (`GET /products`): 2 replicas
- **Shopping Cart** (`GET/POST /cart`): 3 replicas

`podAntiAffinity` forces each replica of a service onto a *different node*, so
losing one node doesn't take a whole service down. Both are exposed as
`NodePort` Services and tested with `curl`.

## Prerequisites

- Docker running, plus `kubectl` and `minikube` (`setup/verify.sh`)
- **Resources:** 3 nodes × 2 CPU / 2 GB. On Docker Desktop give it at least
  **6 CPUs and 8 GB RAM** (Settings → Resources; on WSL also check `.wslconfig`).
- Not root. Run as your normal user (see `--force` below).

## Files

| File | Purpose |
|---|---|
| `product_catalog.py`, `Dockerfile.product` | Product Catalog app and image |
| `shopping_cart.py`, `Dockerfile.shopping` | Shopping Cart app and image |
| `requirements.txt` | Flask/Werkzeug pins shared by both images |
| `product_catalog_deployment.yaml` | Deployment, 2 replicas, anti-affinity |
| `shopping_cart_deployment.yaml` | Deployment, 3 replicas, anti-affinity |
| `product_catalog_service.yaml`, `shopping_cart_service.yaml` | NodePort Services |

## Run it

Run everything from this folder.

```bash
# Step 0: clean up. If an earlier exercise ran `eval $(minikube docker-env)` in
# this terminal, undo it so images are built in your normal Docker.
eval $(minikube docker-env -u) 2>/dev/null
minikube stop; minikube delete                        # removes the old default cluster

# Step 1a: 3-node cluster. kubectl switches to this profile automatically.
minikube start --nodes 3 -p devops-multinode --cpus=2 --memory=2g
kubectl get nodes                                    # devops-multinode, -m02, -m03

# Step 4: build both images with your normal Docker
docker build -t product-catalog:latest -f Dockerfile.product .
docker build -t shopping-cart:latest  -f Dockerfile.shopping .

# Step 5: copy the images into ALL cluster nodes
minikube -p devops-multinode image load product-catalog:latest
minikube -p devops-multinode image load shopping-cart:latest
minikube -p devops-multinode image ls | grep -E 'product-catalog|shopping-cart'

# Step 6-7: deploy and expose
kubectl apply -f product_catalog_deployment.yaml -f shopping_cart_deployment.yaml
kubectl apply -f product_catalog_service.yaml -f shopping_cart_service.yaml

# Step 8: every replica of a service should be on a DIFFERENT node
kubectl get pods -o wide
```

**Step 9: get the URLs.** Each command opens a tunnel, so use a separate
terminal for each and leave them open:

```bash
minikube -p devops-multinode service product-catalog-service --url   # terminal 2
minikube -p devops-multinode service shopping-cart-service --url     # terminal 3
```

**Step 10: test** (replace the ports with the ones printed above):

```bash
curl http://127.0.0.1:<catalog-port>/products

curl http://127.0.0.1:<cart-port>/cart
curl -X POST http://127.0.0.1:<cart-port>/cart \
     -H "Content-Type: application/json" \
     -d '{"id": 1, "name": "Laptop", "quantity": 1}'
curl http://127.0.0.1:<cart-port>/cart          # run it a few times (see note below)
```

> **Why the cart "loses" items:** each Shopping Cart Pod keeps its own
> in-memory `cart` list, and the Service spreads requests across the 3 Pods.
> A `GET` after your `POST` may return `[]` from a different Pod. That's a
> useful lesson: stateless replicas need shared storage (Redis, a database)
> for state.

Try fault tolerance:

```bash
minikube -p devops-multinode node stop devops-multinode-m02
kubectl get pods -o wide        # services keep answering from the other nodes
minikube -p devops-multinode node start devops-multinode-m02
```

## Cleanup

```bash
kubectl delete -f product_catalog_service.yaml -f shopping_cart_service.yaml
kubectl delete -f product_catalog_deployment.yaml -f shopping_cart_deployment.yaml
minikube delete -p devops-multinode
docker rmi product-catalog:latest shopping-cart:latest
```

## Screenshots

Capture these from **your own run** and save them in [`screenshots/`](screenshots/) with these names:

| File | What to capture |
|---|---|
| `screenshots/01-nodes.png` | `kubectl get nodes` with 3 nodes Ready |
| `screenshots/02-pods-wide.png` | `kubectl get pods -o wide` with replicas on different nodes |
| `screenshots/03-curl-tests.png` | `curl` for `/products`, POST `/cart` and GET `/cart` |

## Changes from the original / gotchas

- **Shopping Cart namespace:** `namespace: devops-exercise` was never created,
  so `kubectl apply` failed with `namespaces "devops-exercise" not found`, and
  the Service (in `default`) couldn't select those Pods anyway. Changed to `default`.
- **`--force` removed.** It's only needed when running Minikube's Docker
  driver as root, which you shouldn't do. Run as your normal user.
- **Registry add-on (Step 1b) skipped.** The original enables it, then never
  uses it. Step 5's `minikube image load` already copies images to every node.
- **Image check:** `minikube ssh -- docker images` only shows the control-plane
  node. `minikube image ls` lists images across the cluster.
- **Base image:** `python:3.9-slim` (end-of-life) → `python:3.12-slim`, and
  `pip install flask` → pinned `requirements.txt`.
- **Typo:** "Step ba" → Step 9b.
- `--cpus=2 --memory=2g` added so three nodes fit on a laptop.
- `podAntiAffinity` is *required*, so a 3-replica cart needs 3 schedulable
  nodes. With a node stopped, the replacement Pod stays `Pending` until the node returns.
