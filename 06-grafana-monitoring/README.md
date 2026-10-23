# Exercise 6: Real-Time Monitoring and Alerting (Prometheus + Grafana + Jenkins)

Original: [Exercises/6-Grafana-Realtime-Monitoring-of-Quick-Commerce-App.md](https://github.com/SunagP/DevOps-Lab/blob/main/Exercises/6-Grafana-Realtime-Monitoring-of-Quick-Commerce-App.md)

## What it does

A Python script simulates delivery metrics for a quick-commerce service
(total, pending and on-the-way deliveries, average delivery time) and exposes
them at `:8000/metrics` with `prometheus_client`. Prometheus scrapes them and
evaluates two alert rules, and Grafana shows them on a dashboard. Finally a
Jenkins pipeline builds and runs the whole stack in Docker.

This folder is the `delivery_monitoring/` directory from the original.

## Prerequisites

- Docker running, and the repo `.venv` (Python 3.10+ with `prometheus-client`)
- For Part B: the shared Jenkins from [`../jenkins`](../jenkins/README.md). It
  helps to do Exercise 7 first; that's where Jenkins is introduced.

## Files

| File | Purpose |
|---|---|
| `delivery_metrics.py` | Metrics simulator on port 8000 |
| `prometheus.yml` | Scrape config (original filename typo `prometheus.ym` fixed) |
| `alert_rules.yml` | `HighPendingDeliveries`, `HighAverageDeliveryTime` (the original's tree says `alerts_rules.yml`; the config uses `alert_rules.yml`) |
| `Dockerfile`, `requirements.txt` | Image for the Jenkins pipeline (missing in the original) |
| `Jenkinsfile` | Step 5 pipeline |

## Part A: Run it by hand

Run everything from this folder. You need **two terminals**.

**Terminal 1: the metrics app**

```bash
source ../.venv/bin/activate
python delivery_metrics.py
```

**Terminal 2: Prometheus and Grafana**

```bash
curl -s http://localhost:8000/metrics | grep -E '^(total|pending|on_the_way|average)_'

# Prometheus and Grafana share a network so Grafana can reach "prometheus" by name.
docker network create monitoring

docker run -d --name prometheus --network monitoring -p 9090:9090 \
  --add-host=host.docker.internal:host-gateway \
  -v "$PWD/prometheus.yml:/etc/prometheus/prometheus.yml:ro" \
  -v "$PWD/alert_rules.yml:/etc/prometheus/alert_rules.yml:ro" \
  prom/prometheus:v3.13.4

docker run -d --name grafana --network monitoring -p 3000:3000 grafana/grafana:13.2.4
```

1. **Prometheus:** <http://localhost:9090>. Under **Status → Targets**, both
   jobs should be **UP**. Under **Alerts**, `HighPendingDeliveries` goes
   *pending* → *firing* after 15 s.
2. **Grafana:** <http://localhost:3000>. Log in with Grafana's built-in
   default `admin` / `admin` and set a new password when prompted (or skip).
3. **Add data source:** Connections → Data sources → Add → Prometheus.
   URL: **`http://prometheus:9090`**. Then Save & test.
4. **Dashboard:** New dashboard → add four panels:
   - `total_deliveries`
   - `pending_deliveries`
   - `on_the_way_deliveries`
   - `average_delivery_time_sum / average_delivery_time_count`

**Step 6: simulate alerts.** In `delivery_metrics.py`, change the `pending =`
line to `pending = random.randint(50, 100)`, restart the script (Ctrl+C, then
run it again), and watch both Prometheus Alerts and Grafana.

Cleanup for Part A:

```bash
# Ctrl+C the script in terminal 1, then:
docker rm -f prometheus grafana
docker network rm monitoring
```

## Part B: Jenkins pipeline

The pipeline builds `delivery_metrics` into an image and runs it with
Prometheus and Grafana. **Do Part A's cleanup first**, because the pipeline
uses the same container names and ports.

```bash
../jenkins/run-jenkins.sh       # from this folder; prints the initial admin password
```

1. Open <http://localhost:8080>, finish the setup wizard (Install suggested plugins).
2. **New Item** → name `delivery-monitoring` → **Pipeline** → OK.
3. Under **Pipeline**, keep **Pipeline script**, paste the contents of
   `Jenkinsfile`, then Save → **Build Now**.
4. When it's green: metrics at <http://localhost:8000/metrics>, Prometheus at
   <http://localhost:9090>, Grafana at <http://localhost:3000> (add the data
   source as in Part A, URL `http://prometheus:9090`).

Cleanup for Part B:

```bash
docker rm -f delivery_metrics prometheus grafana
docker network rm monitoring
docker rmi delivery_metrics
# Jenkins itself: see ../jenkins/README.md
```

## Screenshots

Capture these from **your own run** and save them in [`screenshots/`](screenshots/) with these names:

| File | What to capture |
|---|---|
| `screenshots/01-metrics-endpoint.png` | `curl http://localhost:8000/metrics` (or the browser) showing the delivery metrics |
| `screenshots/02-prometheus-targets.png` | Prometheus Status → Targets with both jobs UP |
| `screenshots/03-prometheus-alerts.png` | Prometheus Alerts with HighPendingDeliveries pending/firing |
| `screenshots/04-grafana-dashboard.png` | Grafana dashboard with the four panels |
| `screenshots/05-jenkins-pipeline.png` | Jenkins pipeline run with all stages green |

### My run

**Step 1: delivery metrics exposed on `:8000/metrics`**

![Step 1: delivery metrics exposed on `:8000/metrics`](screenshots/01-metrics-endpoint.png)

**Prometheus Target health: `delivery_service` UP**

![Prometheus Target health: `delivery_service` UP](screenshots/02-prometheus-targets.png)

**Prometheus Alerts: `delivery_alerts` rules loaded from `alert_rules.yml`**

![Prometheus Alerts: `delivery_alerts` rules loaded from `alert_rules.yml`](screenshots/03-prometheus-alerts.png)

**Grafana running at `localhost:3000`**

![Grafana running at `localhost:3000`](screenshots/04-grafana-dashboard.png)

## Changes from the original / gotchas

- **Filename typos:** `prometheus.ym` → `prometheus.yml`; `alerts_rules.yml` → `alert_rules.yml`.
- **Scrape target:** `172.17.0.1:8000` only works on native Linux. Now
  `host.docker.internal:8000`, with Prometheus started with
  `--add-host=host.docker.internal:host-gateway`, which works on macOS,
  WSL2 and Linux.
- **`--network=host` dropped** in favour of `-p 9090:9090`. Host networking
  doesn't expose ports on Docker Desktop (macOS/Windows) by default.
- **Grafana data source:** `http://172.17.0.1:9090` → `http://prometheus:9090`
  (shared `monitoring` network).
- **Relative bind mounts:** `-v ./prometheus.yml:...` → `-v "$PWD/prometheus.yml:..."`,
  quoted so paths with spaces work.
- **Images pinned:** `prom/prometheus:v3.13.4`, `grafana/grafana:13.2.4`.
- **Alert rule:** `HighAverageDeliveryTime` had no `for:` although its
  description says "for the last 15 seconds". Added `for: 15s`.
- **Jenkinsfile:**
  - The stock Jenkins image has no Docker, so `Pre-check Docker` always failed.
    Use `../jenkins/run-jenkins.sh`.
  - `localSourcePath = '/path/to/your/local/files'` → `/labs/06-grafana-monitoring`
    (the repo is mounted there).
  - It ran `docker build` with no Dockerfile. Added `Dockerfile`.
  - `-v $WORKSPACE/prometheus.yml:...` doesn't work when Jenkins drives the
    host's Docker (the host can't see the Jenkins container's files). It now
    uses `docker create` + `docker cp` + `docker start`.
  - It now removes old `delivery_metrics` / `prometheus` / `grafana` containers
    first, so re-runs don't fail with "name already in use".
- **Initial Jenkins password path** in the original (`/var/lib/jenkins/...`)
  is wrong for the Docker image. Use
  `docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword`.
- On native Linux with `ufw` enabled, allow port 8000 from the Docker bridge,
  or Prometheus can't scrape the script running on the host.
