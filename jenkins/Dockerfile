# Jenkins for Exercises 6-9.
#
# The stock jenkins/jenkins image has no python3, curl, git or docker CLI, so the
# pipelines in Exercises 6 and 9 fail out of the box (Exercise 9 even tells you
# to apt-get install things inside the running container, which is lost when it
# is recreated). This image bakes those tools in.
#
# Pinned to an LTS release. To upgrade later, change JENKINS_VERSION to a newer
# "<version>-lts-jdk21" tag from https://hub.docker.com/r/jenkins/jenkins/tags
ARG JENKINS_VERSION=2.580.1-lts-jdk21
ARG DOCKER_CLI_VERSION=29.9.1-cli

FROM docker:${DOCKER_CLI_VERSION} AS docker-cli

FROM jenkins/jenkins:${JENKINS_VERSION}
USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends python3 python3-venv python3-pip git curl \
    && rm -rf /var/lib/apt/lists/*
# Docker CLI only (plus buildx for `docker build`); it talks to the host's
# Docker daemon through the mounted socket.
COPY --from=docker-cli /usr/local/bin/docker /usr/local/bin/docker
COPY --from=docker-cli /usr/local/libexec/docker/cli-plugins/docker-buildx /usr/local/libexec/docker/cli-plugins/docker-buildx
USER jenkins
