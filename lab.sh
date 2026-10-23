#!/usr/bin/env bash
# Command strings are single-quoted on purpose: cmd() evals them later.
# shellcheck disable=SC2016,SC2034
# Guided runner for the lab exercises.
#
#   ./lab.sh 4        run Exercise 4 step by step
#   ./lab.sh status   show which screenshots you've captured so far
#   ./lab.sh          list the exercises
#
# It runs each exercise's commands (printing every command first), clears the
# screen before each screenshot so the shot only shows the relevant output, then
# pauses. Take the screenshot, press Enter, and the newest screenshot from your
# screenshot folder is moved into <exercise>/screenshots/ with the right name.
#
# Set LAB_STEP=1 to confirm every command before it runs.
# Set SHOT_DIR=/some/folder if your screenshots are saved somewhere unusual.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_PY="$ROOT/.venv/bin/python"
SAMPLE_REPO="$HOME/devops-sample-code"
# shellcheck source=setup/common.sh
source "$ROOT/setup/common.sh"

if [[ -t 1 ]]; then
  BOLD=$'\e[1m' CYAN=$'\e[36m' GREEN=$'\e[32m' YELLOW=$'\e[33m' RED=$'\e[31m' MAGENTA=$'\e[35m' RESET=$'\e[0m'
else
  BOLD="" CYAN="" GREEN="" YELLOW="" RED="" MAGENTA="" RESET=""
fi

EX_DIR="" EX_TITLE=""
BG_PIDS=()

# ---------------------------------------------------------------- helpers ---

say() { printf '%s%s%s\n' "$GREEN" "$*" "$RESET"; }
note() { printf '%s%s%s\n' "$YELLOW" "$*" "$RESET"; }
ask() { # prompt -> sets REPLY
  read -r -p "$1" REPLY </dev/tty
}
yes_no() { # question default(y|n)
  local hint="[y/N]"
  [[ $2 == y ]] && hint="[Y/n]"
  ask "$1 $hint "
  REPLY="${REPLY:-$2}"
  [[ $REPLY == [yY]* ]]
}

begin() { # dir title
  EX_DIR="$ROOT/$1"
  EX_TITLE="$2"
  mkdir -p "$EX_DIR/screenshots"
  cd "$EX_DIR" || exit 1
}

# Clears the screen and prints a title, so the next screenshot is clean.
section() {
  printf '\033[2J\033[H'
  printf '%s%s%s\n' "$BOLD" "$EX_TITLE" "$RESET"
  printf '%s%s%s\n' "$MAGENTA" "$*" "$RESET"
}

# Prints a command, runs it in this shell, and offers retry on failure.
cmd() {
  local c=$1 rc
  while true; do
    printf '\n%s$ %s%s\n' "$CYAN" "$c" "$RESET"
    if [[ ${LAB_STEP:-0} == 1 ]]; then
      ask "  [Enter] run  [s] skip "
      [[ $REPLY == s ]] && return 0
    fi
    eval "$c"
    rc=$?
    [[ $rc -eq 0 ]] && return 0
    printf '\n%s✗ That command failed (exit %d). Copy the output above and paste it to Claude.%s\n' "$RED" "$rc" "$RESET"
    ask "  [r] retry  [c] continue anyway  [q] quit: "
    case $REPLY in
      r | R) continue ;;
      c | C) return "$rc" ;;
      *) exit 1 ;;
    esac
  done
}

# For steps the exercise expects to fail (e.g. Exercise 2, Step 12).
cmd_expect_fail() {
  printf '\n%s$ %s%s\n' "$CYAN" "$1" "$RESET"
  eval "$1"
  note "(This failure is expected at this step.)"
}

quiet() { "$@" >/dev/null 2>&1; }

todo() { # multi-line instructions for things you do in the browser
  printf '\n%sDo this in the browser:%s\n' "$BOLD" "$RESET"
  printf '%s\n' "$@" | sed 's/^/  /'
  ask "Press Enter when done. "
}

mtime() { stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null; }

screenshot_dir() {
  if [[ -n ${SHOT_DIR:-} ]]; then
    echo "$SHOT_DIR"
  elif [[ "$(uname -s)" == Darwin ]]; then
    local d
    d="$(defaults read com.apple.screencapture location 2>/dev/null || true)"
    d="${d/#\~/$HOME}"
    [[ -d $d ]] && echo "$d" || echo "$HOME/Desktop"
  elif is_wsl; then
    local up
    up="$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')"
    [[ -n $up ]] && echo "$(wslpath "$up")/Pictures/Screenshots" || echo "$HOME/Pictures/Screenshots"
  else
    [[ -d $HOME/Pictures/Screenshots ]] && echo "$HOME/Pictures/Screenshots" || echo "$HOME/Pictures"
  fi
}

shot_hint() {
  if [[ "$(uname -s)" == Darwin ]]; then
    echo "Cmd+Shift+4, then Space, then click the window. Don't click or drag the preview"
    echo "        thumbnail; let it disappear (or turn it off: Cmd+Shift+5 → Options → Show Floating Thumbnail)."
  elif is_wsl; then
    echo "Win+Shift+S (Windows 11 auto-saves to Pictures\\Screenshots) or Win+PrtScn"
  else
    echo "PrtScn / your desktop's screenshot tool"
  fi
}

# Pauses for a screenshot, then moves the newest one into screenshots/<file>.
shot() { # file description
  local dest="$EX_DIR/screenshots/$1" dir since f newest="" newest_t=0 t i
  dir="$(screenshot_dir)"
  since=$(($(date +%s) - 2))
  printf '\n%s📸 SCREENSHOT → screenshots/%s%s\n' "$BOLD$YELLOW" "$1" "$RESET"
  printf '   %s\n   How: %s\n' "$2" "$(shot_hint)"
  while true; do
    ask "   Press Enter after taking it, or drag the screenshot here ([s] skip): "
    if [[ $REPLY == s ]]; then
      note "   skipped"
      return 0
    fi
    if [[ -n $REPLY ]]; then # a dragged/pasted path, possibly quoted or with escaped spaces
      f="${REPLY%"${REPLY##*[![:space:]]}"}"
      f="${f#\'}" f="${f%\'}" f="${f#\"}" f="${f%\"}"
      f="${f//\\ / }"
      if [[ -f $f ]]; then
        cp "$f" "$dest"
        say "   ✓ saved as screenshots/$1"
        return 0
      fi
      note "   That file is gone (macOS deletes the preview's temporary copy). Take it again."
      continue
    fi
    for i in 1 2 3 4 5 6 7 8; do # macOS writes the file a few seconds after the shot
      newest="" newest_t=0
      for f in "$dir"/*.png "$dir"/*.PNG "$dir"/*.jpg; do
        [[ -f $f ]] || continue
        t=$(mtime "$f")
        if [[ $t -ge $since && $t -gt $newest_t ]]; then
          newest=$f newest_t=$t
        fi
      done
      [[ -n $newest ]] && break
      sleep 1
    done
    if [[ -n $newest ]]; then
      mv "$newest" "$dest"
      say "   ✓ saved as screenshots/$1"
      return 0
    fi
    if [[ -f $dest ]]; then
      say "   ✓ screenshots/$1 already exists"
      return 0
    fi
    note "   No new screenshot found in: $dir"
    note "   Take it again, or save it yourself as: $dest  (or set SHOT_DIR)"
  done
}

open_url() {
  if [[ "$(uname -s)" == Darwin ]]; then
    open "$1"
  elif is_wsl; then
    explorer.exe "$1" >/dev/null 2>&1 || true
  else
    xdg-open "$1" >/dev/null 2>&1 &
  fi
  say "Opened $1"
}

clipboard() { # text
  if command -v pbcopy >/dev/null; then
    printf '%s' "$1" | pbcopy
  elif command -v clip.exe >/dev/null; then
    printf '%s' "$1" | clip.exe
  elif command -v xclip >/dev/null; then
    printf '%s' "$1" | xclip -selection clipboard
  else
    return 1
  fi
}

stop_background() {
  local p
  for p in ${BG_PIDS[@]+"${BG_PIDS[@]}"}; do
    kill "$p" 2>/dev/null
  done
  BG_PIDS=()
}
trap stop_background EXIT

# Starts `minikube service --url` in the background (it's a tunnel on macOS/WSL)
# and stores the first URL it prints in the variable named $1.
service_url() { # var "profile args" service
  local log url="" i
  log="$(mktemp)"
  printf '\n%s$ minikube %s service %s --url%s   (kept running in the background)\n' "$CYAN" "$2" "$3" "$RESET"
  # shellcheck disable=SC2086
  minikube $2 service "$3" --url >"$log" 2>&1 &
  BG_PIDS+=($!)
  for i in $(seq 1 90); do
    url="$(grep -m1 -Eo 'http://[0-9.]+:[0-9]+' "$log")"
    [[ -n $url ]] && break
    sleep 1
  done
  cat "$log"
  [[ -n $url ]] || { note "No URL yet; see the output above."; }
  printf -v "$1" '%s' "$url"
}

# `eval $(minikube docker-env)` (Exercises 2 and 3) needs a cluster that runs Docker
# inside. Newer Minikube versions can default to containerd, and an existing cluster
# keeps its runtime, so check before starting and offer to recreate it.
minikube_runtime() { # profile -> prints its container runtime, empty if no such profile
  minikube profile list -o json 2>/dev/null | python3 -c '
import sys, json
for p in json.load(sys.stdin).get("valid") or []:
    if p["Name"] == sys.argv[1]:
        print(p["Config"]["KubernetesConfig"]["ContainerRuntime"])' "$1" 2>/dev/null
}

start_minikube_with_docker() { # extra start args
  local rt
  rt="$(minikube_runtime minikube)"
  if [[ -n $rt && $rt != docker ]]; then
    note "Your Minikube cluster uses the \"$rt\" runtime, so 'eval \$(minikube docker-env)' can't build into it."
    if yes_no "Delete it and recreate it with the Docker runtime?" y; then
      cmd 'minikube delete'
    else
      echo "Stopping: this exercise needs the Docker runtime."
      exit 1
    fi
  fi
  cmd "minikube start --container-runtime=docker $*"
}

# Refuses to clobber containers you might be using for something else.
free_container_names() {
  local n existing=""
  for n in "$@"; do
    quiet docker container inspect "$n" && existing="$existing $n"
  done
  [[ -z $existing ]] && return 0
  note "These containers already exist:$existing"
  if yes_no "Remove them (left over from an earlier run)?" n; then
    # shellcheck disable=SC2086
    docker rm -f $existing >/dev/null
  else
    echo "Stopping so nothing of yours is removed."
    exit 1
  fi
}

port_in_use() {
  if command -v lsof >/dev/null; then
    lsof -iTCP:"$1" -sTCP:LISTEN >/dev/null 2>&1
  else
    (echo >/dev/tcp/127.0.0.1/"$1") >/dev/null 2>&1
  fi
}

ensure_env() {
  if [[ ! -f $ROOT/.env ]]; then
    cp "$ROOT/.env.example" "$ROOT/.env"
    local pw
    pw="$(LC_ALL=C tr -dc 'a-zA-Z0-9' </dev/urandom | head -c 20)"
    sed -i.bak "s/^MYSQL_ROOT_PASSWORD=.*/MYSQL_ROOT_PASSWORD=$pw/" "$ROOT/.env" && rm -f "$ROOT/.env.bak"
    say "Created .env with a random MYSQL_ROOT_PASSWORD (it's git-ignored)."
  fi
  set -a
  # shellcheck disable=SC1091
  source "$ROOT/.env"
  set +a
}

github_user() {
  [[ -n ${GH_USER:-} ]] && return
  [[ -f $ROOT/.env ]] && GH_USER="$(grep -E '^GITHUB_USERNAME=' "$ROOT/.env" | cut -d= -f2-)"
  if [[ -z ${GH_USER:-} || $GH_USER == your-github-username ]]; then
    GH_USER=""
    command -v gh >/dev/null && quiet gh auth status && GH_USER="$(gh api user -q .login 2>/dev/null)"
  fi
  if [[ -z $GH_USER ]]; then
    ask "Your GitHub username: "
    GH_USER=$REPLY
  fi
  say "GitHub user: $GH_USER"
}

jenkins_up() { curl -fs -o /dev/null http://localhost:8080/login; }
jenkins_setup_done() { ! docker exec jenkins test -f /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null; }

need_jenkins() {
  if ! jenkins_up; then
    cmd '"$ROOT/jenkins/run-jenkins.sh"'
  fi
  if ! jenkins_setup_done; then
    note "Jenkins isn't set up yet. Run ./lab.sh 7 first."
    exit 1
  fi
}

# Creates ~/devops-sample-code (local + GitHub) if it doesn't exist yet.
ensure_sample_repo() {
  github_user
  if command -v gh >/dev/null && quiet gh auth status; then
    if ! quiet gh repo view "$GH_USER/devops-sample-code"; then
      if yes_no "Create the public GitHub repo $GH_USER/devops-sample-code with gh?" y; then
        cmd 'gh repo create devops-sample-code --public --description "Jenkins lab sample code"'
      fi
    fi
    quiet gh auth setup-git # lets git push use your gh login instead of asking for a PAT
  else
    todo "Create a public repo named devops-sample-code on github.com (no README)."
  fi
  mkdir -p "$SAMPLE_REPO"
  if [[ ! -d $SAMPLE_REPO/.git ]]; then
    cmd 'git -C "$SAMPLE_REPO" init -b main'
  fi
  if ! quiet git -C "$SAMPLE_REPO" remote get-url origin; then
    cmd 'git -C "$SAMPLE_REPO" remote add origin "https://github.com/$GH_USER/devops-sample-code.git"'
  fi
}

finish() {
  stop_background
  printf '\n%sDone: %s%s\n' "$BOLD$GREEN" "$EX_TITLE" "$RESET"
  status_one "$(basename "$EX_DIR")"
  echo "Commit your screenshots with:"
  echo "  git add $(basename "$EX_DIR")/screenshots && git commit -m \"Add $(basename "$EX_DIR") screenshots\" && git push"
}

# ------------------------------------------------------------- exercises ---

ex1() {
  begin 01-k8s-getting-started "Exercise 1 · Kubernetes Hello Pod"

  section "Step 1: start a local cluster"
  cmd 'minikube start'
  quiet kubectl delete service hello-k8s --ignore-not-found
  quiet kubectl delete pod hello-k8s --ignore-not-found
  shot 01-minikube-start.png "minikube start ending with \"Done! kubectl is now configured\""

  section "Steps 2-3: create the Pod and check it's running"
  cmd 'kubectl run hello-k8s --image=nginx:1.30 --port=80'
  cmd 'kubectl wait --for=condition=Ready pod/hello-k8s --timeout=180s'
  cmd 'kubectl get pods'
  shot 02-pod-running.png "kubectl get pods showing hello-k8s Running"

  section "Steps 4-5: expose the Pod and open it"
  cmd 'kubectl expose pod hello-k8s --type=NodePort --port=80'
  service_url URL "" hello-k8s
  [[ -n $URL ]] && open_url "$URL"
  shot 03-nginx-welcome.png "the browser tab showing \"Welcome to nginx!\" (include the address bar)"

  if yes_no "Clean up (delete the Pod and Service)?" y; then
    cmd 'kubectl delete service hello-k8s && kubectl delete pod hello-k8s'
  fi
  finish
}

ex2() {
  begin 02-minikube-flask "Exercise 2 · Flask on Minikube with kubectl and YAML"

  section "Steps 1-4: start Minikube and build the image inside it"
  start_minikube_with_docker
  quiet kubectl delete -f flask-deployment-with-service.yaml --ignore-not-found
  cmd 'eval $(minikube docker-env)'
  cmd 'docker build -t flask-app .'
  shot 01-docker-build.png "the docker build finishing (\"naming to docker.io/library/flask-app\")"

  section "Steps 5-10: deploy and inspect"
  cmd 'kubectl apply -f flask-deployment.yaml'
  cmd 'kubectl rollout status deployment/flask-app --timeout=180s'
  cmd 'kubectl get deployments'
  cmd 'kubectl get pods -l app=flask-app'
  cmd 'kubectl logs deployment/flask-app'
  shot 02-deployment-pods.png "flask-app 1/1 READY and the Pod Running"

  section "Steps 11-12: no Service yet, so the app isn't reachable"
  cmd 'kubectl get services'
  cmd_expect_fail 'curl --max-time 5 http://127.0.0.1:15000'
  shot 03-curl-fails.png "kubectl get services (no flask service) and curl failing"

  section "Step 13: add the NodePort Service and reach the app"
  cmd 'kubectl apply -f flask-deployment-with-service.yaml'
  service_url URL "" flask-app-service
  cmd "curl -s $URL; echo"
  shot 04-service-curl.png "the service URL and curl printing \"Hello from Flask on Kubernetes!\""

  if yes_no "Clean up (delete the Deployment and Service)?" y; then
    cmd 'kubectl delete -f flask-deployment-with-service.yaml'
  fi
  eval "$(minikube docker-env -u)"
  finish
}

ex3() {
  begin 03-minikube-replicasets "Exercise 3 · Scaling with ReplicaSets"

  section "Steps 1-2: single-node cluster"
  if yes_no "Step 1 deletes your existing Minikube cluster to start fresh. Do it?" n; then
    cmd 'minikube stop; minikube delete'
  fi
  start_minikube_with_docker --nodes=1
  cmd 'kubectl get nodes'
  quiet kubectl delete -f flashsale-replicaset.yaml --ignore-not-found --wait
  quiet kubectl delete pod load --ignore-not-found

  section "Build the flashsale image inside Minikube"
  cmd 'eval $(minikube docker-env)'
  cmd 'docker build -t flashsale:1.0 .'

  section "Steps 3-6: create the ReplicaSet (3 replicas)"
  cmd 'kubectl apply -f flashsale-replicaset.yaml'
  sleep 3
  cmd 'kubectl wait --for=condition=Ready pod -l app=flashsale --timeout=180s'
  cmd 'kubectl get rs'
  cmd 'kubectl get pods -l app=flashsale'
  shot 01-replicaset-3-pods.png "flashsale-rs 3/3 and three Pods Running"

  section "Steps 7-9: scale to 5 replicas"
  cmd 'kubectl scale rs flashsale-rs --replicas=5'
  sleep 3
  cmd 'kubectl wait --for=condition=Ready pod -l app=flashsale --timeout=180s'
  cmd 'kubectl get rs'
  cmd 'kubectl get pods -l app=flashsale'
  shot 02-scaled-to-5.png "DESIRED/CURRENT/READY 5 and five Pods"

  section "Steps 10-11: delete a Pod; the ReplicaSet replaces it"
  POD="$(kubectl get pods -l app=flashsale -o jsonpath='{.items[0].metadata.name}')"
  cmd "kubectl delete pod $POD"
  sleep 3
  cmd 'kubectl wait --for=condition=Ready pod -l app=flashsale --timeout=180s'
  cmd 'kubectl get pods -l app=flashsale -o wide'
  shot 03-self-healing.png "the delete, then 5 Pods again with one brand-new (low AGE)"

  section "Load distribution: 10 /buy requests through the Service"
  cmd 'kubectl run load --rm -i --restart=Never --image=curlimages/curl:8.17.0 -- sh -c "for i in 1 2 3 4 5 6 7 8 9 10; do curl -s http://flashsale-svc/buy; echo; done"'
  shot 04-load-distribution.png "different served_by_pod values across the requests"

  if yes_no "Clean up (delete the ReplicaSet and Service)?" y; then
    cmd 'kubectl delete -f flashsale-replicaset.yaml'
  fi
  eval "$(minikube docker-env -u)"
  finish
}

ex4() {
  begin 04-docker-networking "Exercise 4 · Docker Networking"
  ensure_env
  free_container_names mysql redis flask
  quiet docker network rm my-bridge-net
  PORT=5001
  if port_in_use 5001; then
    PORT=5002
    note "Port 5001 is in use on this machine, so the Flask container uses host port $PORT."
  fi
  cmd 'docker build -t flask-api .'

  section "Tasks 1-3: create, list and inspect the bridge network"
  cmd 'docker network create --driver bridge my-bridge-net'
  cmd 'docker network ls'
  cmd 'docker network inspect my-bridge-net'
  shot 01-network-inspect.png "docker network ls and the inspect output (scroll up if needed)"

  section "Task 4: launch MySQL, Redis and Flask on the network"
  note "(MYSQL_ROOT_PASSWORD comes from your .env)"
  cmd 'docker run -d --name mysql --net=my-bridge-net -e MYSQL_ROOT_PASSWORD mysql:8.4'
  cmd 'docker run -d --name redis --net=my-bridge-net redis:7.4'
  cmd "docker run -d --name flask --net=my-bridge-net -p $PORT:5001 flask-api"
  sleep 3
  cmd 'docker ps --filter network=my-bridge-net'
  shot 02-containers-running.png "mysql, redis and flask all Up"

  section "Call the Flask API from your machine"
  cmd "curl -s http://localhost:$PORT/about"
  shot 03-about-api.png "the /about JSON response"

  section "Task 5: ping the other containers by name from inside flask"
  cmd 'docker exec flask ping -c 3 mysql'
  cmd 'docker exec flask ping -c 3 redis'
  shot 04-ping.png "both pings resolving the container names and getting replies"

  if yes_no "Clean up (Task 6: remove containers and network)?" y; then
    cmd 'docker stop mysql redis flask && docker rm mysql redis flask'
    cmd 'docker network rm my-bridge-net'
  fi
  finish
}

ex5() {
  begin 05-docker-apparmor "Exercise 5 · Docker Security with AppArmor"
  if [[ "$(uname -s)" != Linux ]] || is_wsl; then
    note "Exercise 5 needs native Linux (Ubuntu). AppArmor isn't enforced on macOS or WSL2."
    note "Run ./lab.sh 5 on an Ubuntu machine or VM."
    exit 1
  fi
  [[ -x $VENV_PY ]] || cmd '"$ROOT/setup/setup-python-venv.sh"'

  section "Tasks 2-3: build the image, install and load the profile"
  cmd 'docker build -t flask-apparmor .'
  cmd 'sudo cp my-apparmor-profile /etc/apparmor.d/my-apparmor-profile'
  cmd 'sudo apparmor_parser -r /etc/apparmor.d/my-apparmor-profile'
  cmd 'sudo aa-status | grep -E "profiles are in enforce mode|my-apparmor-profile"'
  shot 01-aa-status.png "my-apparmor-profile listed in enforce mode"

  section "Task 4: apply the profile with the Docker SDK"
  cmd '"$VENV_PY" apply_apparmor.py'
  shot 02-apply-apparmor.png "the script printing the applied AppArmor profile"

  section "Task 5: try restricted actions inside the container"
  cmd '"$VENV_PY" test_restricted_actions.py'
  shot 03-restricted-actions.png "both attempts failing (non-zero exit codes, no /etc/passwd contents)"

  if yes_no "Clean up (unload the profile, remove the image)?" y; then
    cmd 'sudo apparmor_parser -R /etc/apparmor.d/my-apparmor-profile && sudo rm /etc/apparmor.d/my-apparmor-profile'
    cmd 'docker rmi flask-apparmor'
  fi
  finish
}

ex6() {
  begin 06-grafana-monitoring "Exercise 6 · Prometheus + Grafana Monitoring"
  [[ -x $VENV_PY ]] || cmd '"$ROOT/setup/setup-python-venv.sh"'
  free_container_names prometheus grafana delivery_metrics
  quiet docker network rm monitoring

  section "Part A, Step 1: run the metrics simulator and read /metrics"
  printf '\n%s$ python delivery_metrics.py%s   (kept running in the background)\n' "$CYAN" "$RESET"
  "$VENV_PY" delivery_metrics.py >"$(mktemp)" 2>&1 &
  BG_PIDS+=($!)
  sleep 3
  cmd 'curl -s http://localhost:8000/metrics | grep -E "^(# HELP )?(total|pending|on_the_way|average)_"'
  shot 01-metrics-endpoint.png "the delivery metrics from /metrics"

  section "Part A, Steps 2-3: start Prometheus and Grafana"
  cmd 'docker network create monitoring'
  cmd 'docker run -d --name prometheus --network monitoring -p 9090:9090 \
  --add-host=host.docker.internal:host-gateway \
  -v "$PWD/prometheus.yml:/etc/prometheus/prometheus.yml:ro" \
  -v "$PWD/alert_rules.yml:/etc/prometheus/alert_rules.yml:ro" \
  prom/prometheus:v3.13.4'
  cmd 'docker run -d --name grafana --network monitoring -p 3000:3000 grafana/grafana:13.2.4'
  say "Waiting 40 s for the first scrapes..."
  sleep 40

  open_url http://localhost:9090/targets
  shot 02-prometheus-targets.png "Status → Targets with delivery_service and prometheus both UP"

  open_url http://localhost:9090/alerts
  note "If HighPendingDeliveries isn't Pending/Firing yet, wait 30 s and refresh."
  shot 03-prometheus-alerts.png "the Alerts page with HighPendingDeliveries pending or firing"

  open_url http://localhost:3000
  clipboard "http://prometheus:9090" && say "Copied http://prometheus:9090 to your clipboard."
  todo "1. Log in as admin / admin, then set a new password (or Skip)." \
    "2. Connections → Data sources → Add data source → Prometheus." \
    "   URL: http://prometheus:9090  → Save & test (should be green)." \
    "3. Dashboards → New → New dashboard → Add visualization → pick Prometheus." \
    "   Add 4 panels, one query each (Code mode), then Save the dashboard:" \
    "     total_deliveries" \
    "     pending_deliveries" \
    "     on_the_way_deliveries" \
    "     average_delivery_time_sum / average_delivery_time_count"
  shot 04-grafana-dashboard.png "the dashboard with all four panels"

  stop_background
  cmd 'docker rm -f prometheus grafana && docker network rm monitoring'

  if ! yes_no "Run Part B (the Jenkins pipeline) now? Needs Jenkins set up (./lab.sh 7)." y; then
    finish
    return
  fi
  need_jenkins
  clipboard "$(cat Jenkinsfile)" && say "Copied the Jenkinsfile to your clipboard."
  open_url http://localhost:8080/view/all/newJob
  todo "1. Name: delivery-monitoring → Pipeline → OK." \
    "2. Pipeline section: Definition = Pipeline script. Paste (the Jenkinsfile is in your clipboard)." \
    "3. Save → Build Now. Wait until every stage is green." \
    "   (If the job already exists, just open it and click Build Now.)"
  shot 05-jenkins-pipeline.png "the pipeline run with all stages green (Stages / Pipeline Overview)"

  if yes_no "Clean up the containers the pipeline started?" y; then
    cmd 'docker rm -f delivery_metrics prometheus grafana && docker network rm monitoring'
  fi
  finish
}

ex7() {
  begin 07-jenkins-ci "Exercise 7 · CI and Jenkins Installation"

  if jenkins_up && jenkins_setup_done; then
    note "Jenkins is already set up, so the Unlock page won't appear again."
    note "To capture it you'd need a fresh Jenkins, which deletes its jobs and users."
    if yes_no "Reset Jenkins (docker rm -f jenkins + docker volume rm jenkins_home)?" n; then
      cmd 'docker rm -f jenkins && docker volume rm jenkins_home'
    fi
  fi

  section "Install and start Jenkins"
  cmd '"$ROOT/jenkins/run-jenkins.sh"'

  if ! jenkins_setup_done; then
    clipboard "$(docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword)" &&
      say "Copied the initial admin password to your clipboard."
    open_url http://localhost:8080
    shot 01-jenkins-unlock.png "the Unlock Jenkins page"
    todo "1. Paste the password (it's in your clipboard) → Continue." \
      "2. Install suggested plugins (takes a few minutes)." \
      "3. Create First Admin User with your own username/password." \
      "4. Keep http://localhost:8080/ → Save and Finish → Start using Jenkins."
  fi
  open_url http://localhost:8080
  shot 02-jenkins-dashboard.png "the Jenkins dashboard, logged in as your admin user"
  note "Leave Jenkins running for Exercises 8, 9 and 6."
  finish
}

ex8() {
  begin 08-jenkins-hello-world "Exercise 8 · Jenkins Hello World Job"
  need_jenkins

  section "Push hello-world.sh to your GitHub repo"
  ensure_sample_repo
  cmd 'cp hello-world.sh "$SAMPLE_REPO/"'
  cd "$SAMPLE_REPO" || exit 1
  cmd 'git add hello-world.sh'
  cmd 'git status'
  if ! git diff --cached --quiet; then
    cmd 'git commit -m "Add hello-world.sh"'
  fi
  cmd 'git push -u origin main'
  cd "$EX_DIR" || exit 1
  open_url "https://github.com/$GH_USER/devops-sample-code"
  shot 01-github-repo.png "your devops-sample-code repo on GitHub showing hello-world.sh"

  REPO_URL="https://github.com/$GH_USER/devops-sample-code.git"
  clipboard "$REPO_URL" && say "Copied $REPO_URL to your clipboard."
  open_url http://localhost:8080/view/all/newJob
  todo "1. Name: HelloWorld → Freestyle project → OK." \
    "2. Description: Hello World! Jenkins job." \
    "3. Source Code Management → Git → Repository URL: paste ($REPO_URL)." \
    "   Branch Specifier: change */master to */main" \
    "4. Build Steps → Add build step → Execute shell:  sh hello-world.sh" \
    "Don't save yet. Zoom out (Cmd/Ctrl and -) so the Git URL, branch and build step fit."
  shot 02-job-config.png "the job config with the Git URL, */main and the Execute shell step"

  todo "Click Save → Build Now → open build #1 → Console Output."
  shot 03-console-output.png "Console Output with Hello, Jenkins! and Finished: SUCCESS"
  finish
}

ex9() {
  begin 09-jenkins-multistage-pipeline "Exercise 9 · Jenkins Multi-Stage Pipeline"
  need_jenkins
  [[ -x $VENV_PY ]] || cmd '"$ROOT/setup/setup-python-venv.sh"'

  section "Run the tests locally first"
  cmd '"$VENV_PY" -m unittest discover -s .'
  rm -rf __pycache__

  section "Push the app, tests and Jenkinsfile to your GitHub repo"
  ensure_sample_repo
  cmd 'cp app.py requirements.txt test_app.py Jenkinsfile .gitignore "$SAMPLE_REPO/"'
  cd "$SAMPLE_REPO" || exit 1
  cmd 'git add .'
  if ! git diff --cached --quiet; then
    cmd 'git commit -m "Add Flask app, tests and Jenkinsfile"'
  fi
  cmd 'git push -u origin main'
  cd "$EX_DIR" || exit 1

  REPO_URL="https://github.com/$GH_USER/devops-sample-code.git"
  clipboard "$REPO_URL" && say "Copied $REPO_URL to your clipboard."
  open_url http://localhost:8080/view/all/newJob
  todo "1. Name: Python-MultiStage-Pipeline → Pipeline → OK." \
    "2. Pipeline → Definition: Pipeline script from SCM → SCM: Git." \
    "   Repository URL: paste ($REPO_URL)" \
    "   Branch Specifier: */main     Script Path: Jenkinsfile" \
    "3. Save → Build Now. Wait for it to finish (green)."
  shot 01-pipeline-stages.png "the stage view with Build, Test, Deploy, Run Application, Test Application all green"

  todo "Open the build → Console Output, scroll to the end."
  shot 02-console-output.png "Ran 1 test ... OK and Finished: SUCCESS"
  finish
}

ex10() {
  begin 10-multinode-multi-app "Exercise 10 · Multi-Node Minikube, Two Apps"
  local cpus mem_gb
  cpus="$(docker info --format '{{.NCPU}}' 2>/dev/null || echo 0)"
  mem_gb=$(($(docker info --format '{{.MemTotal}}' 2>/dev/null || echo 0) / 1024 / 1024 / 1024))
  if [[ $cpus -lt 6 || $mem_gb -lt 7 ]]; then
    note "Docker has $cpus CPUs / ${mem_gb} GB. 3 nodes need about 6 CPUs / 8 GB."
    note "Raise it in Docker Desktop → Settings → Resources (WSL: .wslconfig) if the start fails."
  fi
  # Build with your normal Docker, not Minikube's (in case an earlier exercise pointed at it).
  unset DOCKER_HOST DOCKER_TLS_VERIFY DOCKER_CERT_PATH MINIKUBE_ACTIVE_DOCKERD

  section "Step 0-1: 3-node cluster"
  if yes_no "Stop and delete the default Minikube cluster first, to free memory (Step 0)?" y; then
    cmd 'minikube stop; minikube delete'
  fi
  cmd 'minikube start --nodes 3 -p devops-multinode --cpus=2 --memory=2g'
  cmd 'kubectl get nodes'
  shot 01-nodes.png "three nodes (devops-multinode, -m02, -m03) Ready"

  section "Steps 4-5: build both images and load them into every node"
  cmd 'docker build -t product-catalog:latest -f Dockerfile.product .'
  cmd 'docker build -t shopping-cart:latest -f Dockerfile.shopping .'
  cmd 'minikube -p devops-multinode image load product-catalog:latest'
  cmd 'minikube -p devops-multinode image load shopping-cart:latest'
  cmd 'minikube -p devops-multinode image ls | grep -E "product-catalog|shopping-cart"'

  section "Steps 6-8: deploy, expose, check Pods are spread across nodes"
  cmd 'kubectl apply -f product_catalog_deployment.yaml -f shopping_cart_deployment.yaml'
  cmd 'kubectl apply -f product_catalog_service.yaml -f shopping_cart_service.yaml'
  cmd 'kubectl rollout status deployment/product-catalog --timeout=180s'
  cmd 'kubectl rollout status deployment/shopping-cart --timeout=180s'
  cmd 'kubectl get pods -o wide'
  shot 02-pods-wide.png "each service's Pods on different NODEs"

  section "Steps 9-10: reach both services and test them with curl"
  service_url CAT "-p devops-multinode" product-catalog-service
  service_url CART "-p devops-multinode" shopping-cart-service
  cmd "curl -s $CAT/products; echo"
  cmd "curl -s $CART/cart; echo"
  cmd "curl -s -X POST $CART/cart -H 'Content-Type: application/json' -d '{\"id\": 1, \"name\": \"Laptop\", \"quantity\": 1}'; echo"
  cmd "curl -s $CART/cart; echo"
  note "A GET may show [] if it hit a different Pod: each Pod keeps its own in-memory cart."
  shot 03-curl-tests.png "the /products list, the POST response and the /cart calls"

  stop_background
  if yes_no "Clean up (delete the devops-multinode cluster)?" y; then
    cmd 'minikube delete -p devops-multinode'
  fi
  finish
}

# ---------------------------------------------------------------- status ---

status_one() { # exercise folder
  local d="$ROOT/$1" f have=0 total=0 missing=""
  for f in $(grep -Eo 'screenshots/[A-Za-z0-9._-]+\.png' "$d/README.md" | sort -u); do
    total=$((total + 1))
    if [[ -f $d/$f ]]; then
      have=$((have + 1))
    else
      missing="$missing ${f#screenshots/}"
    fi
  done
  if [[ $have -eq $total ]]; then
    printf '%s✓ %-32s %d/%d%s\n' "$GREEN" "$1" "$have" "$total" "$RESET"
  else
    printf '%s• %-32s %d/%d%s  missing:%s\n' "$YELLOW" "$1" "$have" "$total" "$RESET" "$missing"
  fi
}

status() {
  local d
  for d in "$ROOT"/[01][0-9]-*/; do
    status_one "$(basename "$d")"
  done
}

usage() {
  cat <<EOF
Usage: ./lab.sh <exercise number> | status

   4  Docker networking            1  Kubernetes Hello Pod
   2  Flask on Minikube            3  ReplicaSets
  10  Multi-node Minikube          7  Jenkins install
   8  Jenkins Hello World job      9  Jenkins multi-stage pipeline
   6  Prometheus + Grafana         5  AppArmor (native Linux only)

(listed in the recommended order)

Screenshots so far:
EOF
  status
}

case "${1:-}" in
  [1-9] | 10) "ex$1" ;;
  status) status ;;
  *) usage ;;
esac
