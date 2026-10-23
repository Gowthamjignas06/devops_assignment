# Exercise 8: Jenkins "Hello World" Job

Original: [Exercises/8-Jenkins-Hello-World-Job.md](https://github.com/SunagP/DevOps-Lab/blob/main/Exercises/8-Jenkins-Hello-World-Job.md)
(the GitHub part is at the end of [Exercises/7-Jenkins-CI-Automation.md](https://github.com/SunagP/DevOps-Lab/blob/main/Exercises/7-Jenkins-CI-Automation.md#creating-hello-world-jenkins-job))

> **You need your own GitHub repo.** Jenkins clones `hello-world.sh` from
> GitHub, so you push this file to a public repo of your own first.

## What it does

You push a one-line shell script to a public GitHub repo
(`devops-sample-code`), then create a Jenkins **Freestyle** job that clones the
repo and runs the script. The console output shows `Hello, Jenkins!`.

## Prerequisites

- Jenkins running and set up ([Exercise 7](../07-jenkins-ci/README.md) / `jenkins/run-jenkins.sh`)
- A GitHub account and a **fine-grained Personal Access Token** with
  *Contents: Read and write* on the repo
  ([GitHub docs](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-fine-grained-personal-access-token)).
  Paste it only when `git push` asks for a password. **Never save it in a
  file or commit it.**

## Files

| File | Purpose |
|---|---|
| `hello-world.sh` | `echo "Hello, Jenkins!"` (already executable) |

## Run it

### 1. Create the GitHub repo

On github.com: **+ → New repository** → name **`devops-sample-code`**,
Visibility **Public**, *don't* add a README → **Create repository**.

### 2. Push `hello-world.sh` to it

Use a separate folder **outside this workspace repo**, so you don't nest one
git repo inside another:

```bash
# from this folder (08-jenkins-hello-world)
mkdir -p ~/devops-sample-code
cp hello-world.sh ~/devops-sample-code/
cd ~/devops-sample-code

# one-time git identity, if you haven't set it before
git config --global user.name  "Your Name"
git config --global user.email "your-email@example.com"

git init -b main
git add hello-world.sh
git status
git commit -m "Add hello-world.sh"
git remote add origin https://github.com/<your-GitHub-username>/devops-sample-code.git
git push -u origin main
#   Username: <your-GitHub-username>
#   Password: <paste your PAT here; it is not echoed>
```

Check it at `https://github.com/<your-GitHub-username>/devops-sample-code`.

### 3. Create the Jenkins job

1. <http://localhost:8080> → **New Item** → name `HelloWorld` → **Freestyle project** → OK.
2. **Description:** `Hello World! Jenkins job.`
3. **Source Code Management → Git**
   - Repository URL: `https://github.com/<your-GitHub-username>/devops-sample-code.git`
   - Credentials: *none* (the repo is public)
   - **Branch Specifier: change `*/master` to `*/main`**
4. **Build Steps → Add build step → Execute shell:**
   ```
   sh hello-world.sh
   ```
5. **Save** → **Build Now**.

### 4. Check the output

**Build History → #1 → Console Output**:

```
+ sh hello-world.sh
Hello, Jenkins!
Finished: SUCCESS
```

## Cleanup

- Jenkins: open the job → **Delete Project**.
- Keep `devops-sample-code` on GitHub; Exercise 9 can reuse it.

## Screenshots

Capture these from **your own run** and save them in [`screenshots/`](screenshots/) with these names:

| File | What to capture |
|---|---|
| `screenshots/01-github-repo.png` | Your `devops-sample-code` repo on GitHub showing `hello-world.sh` |
| `screenshots/02-job-config.png` | HelloWorld job config: Git URL, branch `*/main`, Execute shell step |
| `screenshots/03-console-output.png` | Console Output showing `Hello, Jenkins!` and `Finished: SUCCESS` |

### My run

**`hello-world.sh` pushed to `devops-sample-code` on GitHub**

![`hello-world.sh` pushed to `devops-sample-code` on GitHub](screenshots/01-github-repo.png)

**`Helloworld` Freestyle job created in Jenkins**

![`Helloworld` Freestyle job created in Jenkins](screenshots/02-job-config.png)

## Changes from the original / gotchas

- **`git push -u origin main` fails as written.** `git init` creates a `master`
  branch on most setups (the original's own output shows "On branch master"),
  so the push errors with `src refspec main does not match any`. Fixed with
  `git init -b main`. For an existing repo, use `git branch -M main`.
- **Jenkins' default branch is `*/master`.** Leaving it gives
  `Couldn't find any revision to build`. Set it to `*/main`.
- **Typos fixed:** repo URL `.../repo.git` → `.../devops-sample-code.git`;
  verify URL `.../DevOps` → `.../devops-sample-code`.
- GitHub no longer accepts your account password for `git push`. Use the PAT,
  or set up `gh auth login` / Git Credential Manager so you aren't prompted.
