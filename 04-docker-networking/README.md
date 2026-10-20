# Exercise 4: Docker Networking with Multiple Containers

Original: [Exercises/4-Docker-Networking.md](https://github.com/SunagP/DevOps-Lab/blob/main/Exercises/4-Docker-Networking.md)

## What it does

Creates a user-defined bridge network `my-bridge-net` and starts three
containers on it: a Flask REST API, MySQL and Redis. From inside the Flask
container you `ping mysql` and `ping redis` by name, which shows Docker's
built-in DNS on user-defined networks.

## Prerequisites

- Docker running (`setup/verify.sh`)
- A root `.env` with `MYSQL_ROOT_PASSWORD` set. From the repo root:
  `cp .env.example .env`, then edit it. Any throwaway value works.

## Files

| File | Purpose |
|---|---|
| `app.py` | Flask API with `GET /about` on port 5001 |
| `requirements.txt` | `Flask==2.0.1` + `Werkzeug==2.0.3` |
| `Dockerfile` | Image `flask-api` |

## Run it

Run everything from this folder.

```bash
# Task 1-3: create and inspect the bridge network
docker network create --driver bridge my-bridge-net
docker network ls
docker network inspect my-bridge-net

# Task 4: build the Flask image
docker build -t flask-api .

# Load MYSQL_ROOT_PASSWORD from the root .env into this shell
set -a; source ../.env; set +a

# Launch the three containers (-d = detached / in the background).
# "-e MYSQL_ROOT_PASSWORD" with no value passes it from your shell environment,
# so the password never appears in the command line.
docker run -d --name mysql --net=my-bridge-net -e MYSQL_ROOT_PASSWORD mysql:8.4
docker run -d --name redis --net=my-bridge-net redis:7.4
docker run -d --name flask --net=my-bridge-net -p 5001:5001 flask-api

docker ps                                   # all three should be "Up"
curl http://localhost:5001/about            # the API answers from your machine

# Task 5: test name-based connectivity from inside the Flask container
docker exec -it flask bash
#   ping -c 3 mysql
#   ping -c 3 redis
#   exit

# Bonus: see all three containers attached to the network
docker network inspect my-bridge-net --format '{{range .Containers}}{{.Name}} {{.IPv4Address}}{{"\n"}}{{end}}'
```

## Cleanup (Task 6)

```bash
docker stop mysql redis flask && docker rm mysql redis flask
docker network rm my-bridge-net
docker rmi flask-api        # optional
```

## Screenshots

Capture these from **your own run** and save them in [`screenshots/`](screenshots/) with these names:

| File | What to capture |
|---|---|
| `screenshots/01-network-inspect.png` | `docker network ls` and `docker network inspect my-bridge-net` |
| `screenshots/02-containers-running.png` | `docker ps` with mysql, redis and flask Up |
| `screenshots/03-about-api.png` | `curl http://localhost:5001/about` JSON response |
| `screenshots/04-ping.png` | `ping mysql` and `ping redis` from inside the flask container |

## Changes from the original / gotchas

- **MySQL exits immediately as written.** `mysql:latest` with no
  `MYSQL_ROOT_PASSWORD` (or `MYSQL_ALLOW_EMPTY_PASSWORD` /
  `MYSQL_RANDOM_ROOT_PASSWORD`) refuses to start, and then `ping mysql` fails.
  Now pinned to `mysql:8.4` (LTS) with the password from `.env`.
- **Images pinned:** `redis:latest` → `redis:7.4`.
- **Flask 2.0.1 needs `Werkzeug==2.0.3`**, or the container crashes on start
  with `ImportError: cannot import name 'url_quote' from 'werkzeug.urls'`.
- **`app.run(...)` binds to 127.0.0.1 by default**, so `-p 5001:5001` couldn't
  reach it. Added `host='0.0.0.0'`.
- **No `ping` in `python:*-slim`.** The Dockerfile installs `iputils-ping`.
- **Base image:** `python:3.9-slim` (end-of-life) → `python:3.12-slim`.
- **Port 5001 already in use?** (`Bind for 0.0.0.0:5001 failed: port is already allocated`)
  Something else, often a local Docker registry, has it. Use another host
  port: `-p 5002:5001`, then `curl http://localhost:5002/about`.
- MySQL takes ~20–30 s to initialise. `ping` works straight away, but SQL
  connections don't until `docker logs mysql` shows `ready for connections`.
- Answer 4 in the original is cut off (`-p 500`). It means
  `-p <host-port>:<container-port>`, e.g. `-p 5001:5001`.
