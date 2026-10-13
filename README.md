# docker-flask-demo

[Deutsche Fassung](README.de.md)

A minimal Flask application that demonstrates Docker containerization, import
from GitHub into GitLab, and CI/CD deployment through a managed hosting platform.

## Project and goal

The goal is to make the whole path from application source to a running container
understandable. You can run the demo locally, change its greeting through an
environment variable, and follow the same application into a GitLab build and
deployment workflow. The code and configuration files contain English comments
that explain the steps and their purpose.

GitHub is the source of truth for the maintained files. The hosting admins import
the public repository into the **Gemi** group (namespace `gemi`) on
`gitlab.gwdg.de`. Only the hosting admins can create projects in this group.
An optional GitLab job later copies new GitHub commits into the GitLab repository.
The application does not need GitHub Actions or a GitHub container registry.

The demo has one web page and a `/health` endpoint. It deliberately has no login,
database or persistent user data. Hosting admins configure the public hostname,
reverse proxy, TLS and any required access restrictions separately.

## Files

| File | Purpose |
|---|---|
| `app.py` | Flask routes and the greeting read from the environment |
| `templates/index.html` | Web page; the greeting is escaped before it becomes HTML |
| `requirements.txt` | Pinned direct Python dependencies: Flask and Gunicorn |
| `Dockerfile` | Linux image with Gunicorn, a non-root user and an HTTP health check |
| `compose.yaml` | Local build and access through the computer's loopback interface |
| `compose.hosting.yaml` | Hosting configuration with the external `dockernet` network |
| `.env.example` | Harmless local configuration template |
| `.gitignore`, `.dockerignore` | Keep local settings and unnecessary files out of Git and the image |
| `.gitattributes` | Preserve Linux line endings in scripts edited on Windows |
| `.gitlab-ci.yml` | Tests, optional synchronization, image build and release rules |
| `scripts/common.sh` | Shared variable checks and temporary registry login |
| `scripts/build.sh` | Build, start-test and publish an image; record its registry digest |
| `scripts/deploy.sh` | Validate the target, deploy the recorded image and verify the backend |
| `scripts/sync.sh` | Copy GitHub commits to GitLab only when a fast-forward is possible |
| `tests/` | App behavior and CI-script tests without real Git pushes or deployments |
| `TROUBLESHOOTING.md` | A bounded recovery note for the Docker Desktop startup issue encountered during testing |
| `LICENSE` | MIT license |

## Run locally with Docker

You need Docker Desktop using Linux containers, or Docker Engine on Linux, and
Docker Compose v2 supporting `up --wait --wait-timeout` and `config --format json`.
Start Docker before running the commands. Run them from this repository's folder.

1. Copy the example settings. In Windows PowerShell:

   ```powershell
   Copy-Item .env.example .env
   ```

   On Linux or macOS:

   ```sh
   cp .env.example .env
   ```

2. Open `.env` in a text editor. Keep the default greeting or change
   `GREETING_TEXT`. `APP_PORT=5000` selects the local port.

3. Build and start the container:

   ```sh
   docker compose up --build --detach --wait --wait-timeout 90
   ```

4. Open [the local web page](http://localhost:5000) and
   [the health endpoint](http://localhost:5000/health). The page shows the greeting;
   the health endpoint returns `{"status":"ok"}`. If you changed `APP_PORT`, use
   that port in both URLs. You can also check the status and logs:

   ```sh
   docker compose ps
   docker compose logs --tail 100 app
   ```

5. After changing `GREETING_TEXT`, recreate the container:

   ```sh
   docker compose up --detach --force-recreate --wait --wait-timeout 90
   ```

   Refresh the page to see the new text. Changing `.env` does not require an image
   rebuild. Changes to `app.py`, the template or dependencies do require a rebuild.

6. When finished, stop and remove this demo's local container and network:

   ```sh
   docker compose down
   ```

The local port is bound to `127.0.0.1`, so this command does not publish the demo
to other computers. The real `.env` is ignored by Git and excluded from the image.

## How the environment variable works

`.env.example` documents a safe value. Your local `.env` supplies values to Docker
Compose. The `environment` block in `compose.yaml` explicitly passes
`GREETING_TEXT` into the container. Flask reads it when the application starts.

On GitLab, a CI/CD variable supplies the hosting value instead. The deployment
script resolves `compose.hosting.yaml` and saves the runtime configuration on the
host. This saved configuration includes the greeting. Use only public text for
`GREETING_TEXT`; the web page displays it to every visitor. Real secrets belong
in separately reviewed secret configuration, never in this repository or image.

## Optional initial import from GitHub

1. Send the hosting admins this public GitHub URL, the requested project name,
   intended revision and desired visibility:

   ```text
   https://github.com/ctreffe/docker-flask-demo.git
   ```

2. The hosting admins check that URL import is enabled on `gitlab.gwdg.de`. They
   select **New project/repository > Import project > Repository by URL**, import
   the repository into **Gemi**, set the agreed visibility and grant you access.
   The public GitHub source does not require GitHub credentials for this import.
3. Open the imported GitLab project and verify the intended commit and files.
   The pipeline and scripts are already included; no copying of YAML is needed.

The first import is performed by GitLab itself, not by a runner. It copies the
repository once and does not establish continuous synchronization. The hosting
admins review the imported CI code before granting access to deployment runners
or credentials. With the default settings, only the isolated test job runs.

## Hosting setup by the admins

Before enabling hosting, confirm the runner executors, registry and permissions
on the actual GitLab instance. Test and sync jobs expect a suitable Linux
Docker-executor runner. Build and deploy jobs expect a Linux **shell-executor**
runner tagged with both `apps.psych` and `production`, with Bash, Git, `python3`,
Docker Engine, Docker Compose v2 and GNU `realpath` already available. These
jobs use that host's Docker daemon; a job's `image:` does not configure a shell
executor. The tag names alone do not establish these capabilities.

Enable the project's Container Registry and protect the default branch. Configure
who may change it or start its pipelines. Enable **Prevent outdated deployment
jobs** in the GitLab deployment settings. Configure the `production` environment
controls where the installed edition supports them. Create a dedicated app
directory below an existing deployment root and confirm that `dockernet` exists.

Add the following variables under **Settings > CI/CD > Variables**. Hosting and
sync settings must be protected and available to their jobs. Use the **All**
environment scope for this example: build and sync jobs do not declare the
`production` environment. Do not override predefined `CI_*` variables or the
release artifact variables `APP_IMAGE`, `RELEASE_COMMIT`, `RELEASE_PIPELINE_ID`.

| Variable | Value or responsibility |
|---|---|
| `HOSTING_ENABLED` | `true` after the hosting setup has been reviewed; default is `false` |
| `GREETING_TEXT` | Public greeting, for example `Hello from GitLab!`; the app has a default |
| `DEPLOY_ROOT` | Absolute path of an existing, admin-approved deployment root; never `/` |
| `DEPLOY_DIR` | Absolute path of an existing app directory strictly below that root |
| `APP_CONTAINER_NAME` | Unique container name assigned by the admins |
| `APP_NETWORK_ALIAS` | Unique backend name on `dockernet`, assigned by the admins |
| `SYNC_ENABLED` | `true` only if later GitHub updates are wanted; default is `false` |
| `GITLAB_SYNC_TOKEN` | Masked, protected access token with `write_repository`, whose account may push to the protected default branch |

GitLab supplies `CI_REGISTRY`, `CI_REGISTRY_IMAGE`, `CI_REGISTRY_USER` and
`CI_REGISTRY_PASSWORD` for registry access. The scripts keep the job's registry
login temporary. The admins configure the shared proxy to reach
`APP_NETWORK_ALIAS:8000`, and handle DNS, TLS and access restrictions separately.
No host port is published by the hosting Compose file.

For synchronization, prefer a project access token if the instance supports it;
otherwise use a dedicated personal access token with the stated scope and an
appropriate expiry. Do not use `CI_JOB_TOKEN` for this example's push: its pushes
do not trigger the follow-up pipeline. Keep application changes on GitHub.
GitLab-only commits would make the two histories diverge and stop synchronization.

## Optional later updates through a runner

After the admins enable synchronization and configure its token:

1. Review and push the intended changes to the default branch on GitHub.
2. In GitLab, open **Build > Pipelines** and start a new pipeline on the protected
   default branch. Set the pipeline variable `RUN_SYNC` to `true`.
3. The sync job fetches `GITHUB_REPO_URL` and `GITHUB_BRANCH` (this repository and
   `main` by default). If new commits extend GitLab's current history, it pushes
   them without a merge commit or force-push. If the histories match, it does
   nothing. If they diverge, it fails and the admins must resolve the difference.
4. A successful update starts a **new push pipeline** for the imported commit.
   Follow that pipeline for tests, build and any release. The sync pipeline itself
   does not build or deploy the old checkout.

An optional schedule can start the same sync job with `RUN_SYNC=true`. Agree this
separately with the admins. A newly synchronized tip commit containing `[deploy]`
can cause the follow-up pipeline to deploy when hosting is enabled. A schedule
does not bypass review or change the release rule.

The sync job follows one branch. It does not mirror tags, other branches, GitHub
issues, pull requests or deletions. If a push succeeded but the follow-up pipeline
failed to start, start a normal pipeline manually on the imported default-branch
commit, with `RUN_SYNC=false`; do not repeat an unrelated release commit.

## Build and release rule

Ordinary branch pipelines run the tests. With hosting enabled, protected
default-branch push or manually started pipelines also build and smoke-test an
image and publish it in the GitLab Container Registry. Deployment additionally
requires the exact substring **`[deploy]`** in that commit's message. The match is
case-sensitive. `deploy`, `[deployment]`, other branches, tags, merge-request
pipelines and the sync pipeline do not select the deployment job.

For a release, review the complete source, then push a default-branch commit with
a message such as `Release demo [deploy]` to GitHub and start the sync job. The
new GitLab pipeline tests and builds that imported revision before deployment.

The deployment consumes the build's immutable `@sha256:` image reference and
checks its commit and pipeline labels. It rejects an outdated branch head or an
older pipeline than the last successful deployment. The script validates the
existing target path before writes, starts the image through Compose, waits for
its health check and verifies HTTP access from `dockernet`.

After acceptance, `DEPLOY_DIR/compose.json` holds the resolved runtime settings;
`DEPLOY_DIR/release.txt` records pipeline ID, commit and image digest. App code is
inside the image, not mounted from the runner checkout. The script does not delete
host data or secrets. If startup or backend verification fails, the job fails and
retains the candidate configuration for diagnosis. The live container may already
have changed; there is no automatic rollback. The admins inspect the service
before retrying and manage any recovery explicitly.

The files are a teaching implementation. Import, runner compatibility, image
build, deployment, public routing and recovery must be verified on the actual
GWDG/hosting setup before treating it as a working production workflow.

## Tests and troubleshooting

GitLab runs `python -m unittest discover -s tests -v` and shell syntax checks.
You can run the same Python command locally with Python 3.13 and Flask installed;
shell-script tests additionally need Bash (Git for Windows is supported). The
script tests use a fake Git executable and never push or create real repositories.

| Symptom | What to check |
|---|---|
| Docker cannot connect | Start Docker Desktop and select Linux containers |
| Local port is already used | Change `APP_PORT` in `.env` and recreate the container |
| Greeting did not change | Recreate the container after changing `.env` |
| GitLab job remains pending | Confirm runner availability, executor, tags and protected-branch access |
| Only tests run | Hosting is disabled by default; admins must configure and enable it |
| Sync reports diverged histories | Preserve both sides and ask the admins; do not force-push |
| No deploy job appears | Check the exact marker, default/protected branch, hosting flag and pipeline source |
| Deployment fails | Read the job's error and logs; have the admins inspect the live service and candidate configuration |

## References and license

- [Flask deployment with Gunicorn](https://flask.palletsprojects.com/en/stable/deploying/gunicorn/)
- [Docker Compose environment interpolation](https://docs.docker.com/compose/how-tos/environment-variables/variable-interpolation/)
- [GitLab import through a Git URL](https://docs.gitlab.com/user/import/third_party_systems/repo_by_url/)
- [GitLab CI/CD variables](https://docs.gitlab.com/ci/variables/)
- [GitLab job-token push behavior](https://docs.gitlab.com/ci/jobs/ci_job_token/#allow-git-push-requests-to-your-project-repository)
- [GitLab deployment safety](https://docs.gitlab.com/ci/environments/deployment_safety/)

This project is distributed under the [MIT license](LICENSE).
