# Shared Jenkins for Exercises 6–9

Exercises 6, 7, 8 and 9 all use Jenkins. Instead of the bare
`docker run jenkins/jenkins:lts` from the course, use this folder. The stock
image doesn't work for these exercises without manual fixes:

| Problem with stock `jenkins/jenkins:lts` | Fix here |
|---|---|
| No `docker` CLI and no Docker socket, so Exercise 6's `Pre-check Docker` stage fails | Docker CLI baked in, host socket mounted, `jenkins` user added to the socket's group |
| No `python3`, `venv` or `pip`, so Exercise 9 fails (the course has you `apt install` inside the running container, which is lost when it's recreated) | `python3`, `python3-venv`, `python3-pip` baked in |
| No `git` / `curl` on PATH | Installed |
| Exercise 6's `Setup Workspace` stage copies from `/path/to/your/local/files`, which doesn't exist inside the container | This repo is mounted read-only at `/labs` |
| `:lts` tag drifts | Pinned to `2.580.1-lts-jdk21` (change `JENKINS_VERSION` in the `Dockerfile` to upgrade) |

## Start

```bash
jenkins/run-jenkins.sh
```

The script builds `devops-lab-jenkins:local`, starts the container `jenkins`, and
prints the **initial admin password**. Open <http://localhost:8080>, paste it,
choose **Install suggested plugins**, and create your admin user.

To get the password again later:

```bash
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

(The course's `sudo cat /var/lib/jenkins/...` path is wrong for the Docker image.)

## Stop / clean up

```bash
docker stop jenkins                 # stop, keep everything
docker start jenkins                # start again
docker rm -f jenkins                # remove the container (jobs survive in the volume)
docker volume rm jenkins_home       # wipe all Jenkins data (jobs, users, plugins)
docker rmi devops-lab-jenkins:local # remove the image
```

## Security note

Mounting `/var/run/docker.sock` gives Jenkins full control of your Docker
daemon, which is effectively root on the host. That's fine for a local lab.
Don't do it on a shared or internet-facing Jenkins.
