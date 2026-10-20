#!/usr/bin/env bash
# Builds the lab Jenkins image and starts it on http://localhost:8080.
# Safe to re-run: an existing "jenkins" container is reused (started if stopped).
#
# The container gets:
#   - the host Docker socket, so pipelines can run `docker build` / `docker run`
#   - this repo mounted read-only at /labs (Exercise 6 copies its files from there)
#   - a named volume "jenkins_home", so jobs and plugins survive restarts
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
IMAGE=devops-lab-jenkins:local
NAME=jenkins

if docker container inspect "$NAME" >/dev/null 2>&1; then
  if [[ "$(docker container inspect -f '{{.State.Running}}' "$NAME")" == "true" ]]; then
    echo "Jenkins is already running."
  else
    echo "Starting existing Jenkins container..."
    docker start "$NAME" >/dev/null
  fi
else
  echo "Building $IMAGE..."
  docker build -t "$IMAGE" "$SCRIPT_DIR"

  # Group that owns docker.sock *as seen inside containers* (0 on Docker Desktop,
  # the host's docker group on native Linux). Adding the jenkins user to it lets
  # pipelines use docker without running Jenkins as root.
  sock_gid="$(docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
    --entrypoint stat "$IMAGE" -c %g /var/run/docker.sock)"

  docker run -d --name "$NAME" \
    --restart unless-stopped \
    -p 8080:8080 -p 50000:50000 \
    -v jenkins_home:/var/jenkins_home \
    -v /var/run/docker.sock:/var/run/docker.sock \
    --group-add "$sock_gid" \
    -v "$REPO_ROOT":/labs:ro \
    "$IMAGE" >/dev/null
fi

echo "Waiting for Jenkins to start..."
for _ in $(seq 1 60); do
  if docker exec "$NAME" test -f /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null; then
    echo
    echo "Jenkins: http://localhost:8080"
    echo "Initial admin password (only needed for the first-time setup wizard):"
    docker exec "$NAME" cat /var/jenkins_home/secrets/initialAdminPassword
    exit 0
  fi
  # The password file is deleted once the setup wizard is finished.
  if docker exec "$NAME" curl -fs -o /dev/null http://localhost:8080/login 2>/dev/null; then
    echo "Jenkins: http://localhost:8080 (setup already done; log in with the admin user you created)"
    exit 0
  fi
  sleep 2
done
echo "Jenkins didn't come up within 2 minutes. Check: docker logs $NAME" >&2
exit 1
