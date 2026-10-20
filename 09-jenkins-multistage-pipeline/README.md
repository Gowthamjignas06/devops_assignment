# Exercise 9: Jenkins Multi-Stage Pipeline (Build → Test → Deploy)

Original: [Exercises/9-Jenkins-Multi-Stage-Pipeline.md](https://github.com/SunagP/DevOps-Lab/blob/main/Exercises/9-Jenkins-Multi-Stage-Pipeline.md)

> **You need your own GitHub repo.** The job uses *Pipeline script from SCM*,
> so Jenkins clones `Jenkinsfile`, `app.py` and the tests from your GitHub repo.

## What it does

A small Flask app with a unit test goes through a declarative Jenkins pipeline
read from your repo: **Build** (create a venv, install requirements) →
**Test** (`unittest`) → **Deploy** (copy to `python-app-deploy/`) →
**Run Application** (start it, check it answers on :5000) →
**Test Application** (run `test_app.py` against the deployed copy).

This folder is the `python-flask-app/` directory from the original.

## Prerequisites

- Jenkins running ([`jenkins/run-jenkins.sh`](../jenkins/README.md)). This
  image already has `python3` + `venv`, so the original's Step 8
  ("Handling build errors": `apt install` inside the container) isn't needed.
- The `devops-sample-code` GitHub repo from [Exercise 8](../08-jenkins-hello-world/README.md) (or any new public repo)
- A GitHub PAT for `git push`. Paste it when prompted; never commit it.

## Files

| File | Purpose |
|---|---|
| `app.py` | Flask app, `GET /` → `Hello, Jenkins Multi-Stage Pipeline!` |
| `requirements.txt` | `flask==2.1.2` + `Werkzeug==2.1.2` |
| `test_app.py` | `unittest` test for `/` |
| `Jenkinsfile` | The five-stage pipeline |
| `.gitignore` | Keeps `venv/`, `__pycache__/` and `python-app-deploy/` out of your repo |

## Run it

### 1. Try the tests locally (optional)

```bash
source ../.venv/bin/activate         # root venv has the same Flask/Werkzeug pins
python -m unittest discover -s .
```

### 2. Push to your GitHub repo

Reusing `~/devops-sample-code` from Exercise 8:

```bash
# from this folder (09-jenkins-multistage-pipeline)
cp app.py requirements.txt test_app.py Jenkinsfile .gitignore ~/devops-sample-code/
cd ~/devops-sample-code
git add .
git commit -m "Add Flask app, tests and Jenkinsfile"
git push
```

Starting from scratch instead? Create an empty public repo on GitHub, then:

```bash
mkdir -p ~/devops-sample-code && cp app.py requirements.txt test_app.py Jenkinsfile .gitignore ~/devops-sample-code/
cd ~/devops-sample-code
git init -b main
git add .
git commit -m "Initial commit"
git remote add origin https://github.com/<your-GitHub-username>/devops-sample-code.git
git push -u origin main
```

### 3. Create the pipeline job

1. <http://localhost:8080> → **New Item** → `Python-MultiStage-Pipeline` → **Pipeline** → OK.
2. **Pipeline → Definition: Pipeline script from SCM**
   - SCM: **Git**
   - Repository URL: `https://github.com/<your-GitHub-username>/devops-sample-code.git`
   - Credentials: none (public repo)
   - **Branch Specifier: `*/main`** (default is `*/master`)
   - Script Path: `Jenkinsfile`
3. **Save** → **Build Now**. Open the build → **Console Output** (or **Pipeline Overview**) to watch each stage.

Expected end of the log:

```
Hello, Jenkins Multi-Stage Pipeline!
...
Ran 1 test in 0.00Xs
OK
Pipeline completed successfully!
Finished: SUCCESS
```

### Optional: code-quality stage

To add the original's "Additional Enhancements" `flake8` stage, add `flake8`
to `requirements.txt` and insert this after `Test`:

```groovy
stage('Code Quality') {
    steps {
        echo 'Running code quality checks...'
        sh '${WORKSPACE}/venv/bin/flake8 --exclude=venv .'
    }
}
```

## Cleanup

- Jenkins: open the job → **Delete Pipeline**.
- Locally: nothing to clean up (the local test run only creates `__pycache__/`, which is git-ignored).

## Screenshots

Capture these from **your own run** and save them in [`screenshots/`](screenshots/) with these names:

| File | What to capture |
|---|---|
| `screenshots/01-pipeline-stages.png` | Pipeline stage view with Build, Test, Deploy, Run Application, Test Application green |
| `screenshots/02-console-output.png` | Console Output with `Ran 1 test ... OK` and `Finished: SUCCESS` |

## Changes from the original / gotchas

- **`flask==2.1.2` alone is broken today.** pip pulls the latest Werkzeug
  (3.x), and `import flask` fails with
  `ImportError: cannot import name 'url_quote' from 'werkzeug.urls'`.
  Pinned `Werkzeug==2.1.2`.
- **Build stage did nothing.** It only `echo`ed "Creating virtual environment
  and installing dependencies...". It now does that. A venv is required
  because Debian's Python (in the Jenkins image) blocks system-wide
  `pip install` (PEP 668). Later stages use `venv/bin/python`.
- **Step 8 workaround removed.** The original has you `docker exec -u root`
  into Jenkins and `apt install python3 pip python3-flask` by hand. The lab
  Jenkins image already has python3/venv, and Flask comes from the venv.
- **Run Application:** Jenkins kills background processes when a `sh` step
  ends, so the original's `nohup ... &` app died before anything used it. The
  stage now curls `http://127.0.0.1:5000/` in the same step, so it shows the
  app actually starts.
- **`git push -u origin main`** needs `git init -b main` (see Exercise 8), and
  the Jenkins job's branch must be `*/main`.
- The original's "Expected Outcome" says the app is copied to
  `/tmp/python-app-deploy`. The pipeline actually uses
  `$WORKSPACE/python-app-deploy`.
