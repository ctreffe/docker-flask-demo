#!/usr/bin/env bash
# Deploy one verified image onto the hosting runner's Docker host.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Quoted brackets are literal characters, not a shell wildcard character class.
[[ "${CI_COMMIT_MESSAGE:-}" == *"[deploy]"* ]] || fail "The commit message needs literal [deploy]."
require_hosting_context
require_variables APP_IMAGE RELEASE_COMMIT RELEASE_PIPELINE_ID CI_REGISTRY_IMAGE \
    DEPLOY_ROOT DEPLOY_DIR APP_CONTAINER_NAME APP_NETWORK_ALIAS CI_PROJECT_PATH_SLUG
[[ "$RELEASE_COMMIT" == "$CI_COMMIT_SHA" ]] || fail "The image belongs to another commit."
[[ "$RELEASE_PIPELINE_ID" == "$CI_PIPELINE_ID" ]] || fail "The image belongs to another pipeline."
image_digest="${APP_IMAGE#"$CI_REGISTRY_IMAGE"@sha256:}"
[[ "$APP_IMAGE" == "$CI_REGISTRY_IMAGE"@sha256:* && "$image_digest" =~ ^[0-9a-f]{64}$ ]] ||
    fail "APP_IMAGE must be an immutable digest from this project's registry."
[[ "$APP_CONTAINER_NAME" =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]*$ ]] || fail "Invalid container name."
[[ "$APP_NETWORK_ALIAS" =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]*$ ]] || fail "Invalid network alias."

# Admins must create the root and app directory in advance. Resolve existing paths
# before any file writes, so '..' and symbolic links cannot escape the agreed root.
[[ "$DEPLOY_ROOT" == /* && "$DEPLOY_DIR" == /* ]] || fail "Deployment paths must be absolute."
root="$(realpath -e -- "$DEPLOY_ROOT")"
target="$(realpath -e -- "$DEPLOY_DIR")"
[[ -d "$root" && -d "$target" && "$root" != / ]] || fail "Choose an existing dedicated deployment root."
[[ "$target" == "$root/"* ]] || fail "DEPLOY_DIR must be a strict child of DEPLOY_ROOT."
[[ "$target" != "$(realpath -e -- "$CI_PROJECT_DIR")" ]] || fail "Do not deploy into the CI checkout."
[[ ! -L "$target/compose.json" && ! -L "$target/release.txt" ]] || fail "Release files must not be symbolic links."

# A retry may repeat the same pipeline, but an older pipeline must not replace a
# newer successful deployment. GitLab also serializes this job with resource_group.
if [[ -f "$target/release.txt" ]]; then
    read -r deployed_pipeline < "$target/release.txt"
    [[ "$deployed_pipeline" =~ ^[0-9]+$ ]] || fail "Invalid saved deployment metadata."
    (( CI_PIPELINE_ID >= deployed_pipeline )) || fail "A newer pipeline is already deployed."
fi
check_branch_head() {
    local branch_head
    branch_head="$(git ls-remote origin "refs/heads/$CI_DEFAULT_BRANCH" | cut -f1)"
    [[ "$branch_head" == "$CI_COMMIT_SHA" ]] || fail "The default branch moved. Start a new release pipeline."
}
check_branch_head
docker network inspect dockernet >/dev/null

trap cleanup_registry_login EXIT
registry_login
docker pull "$APP_IMAGE"
# Inspect the fetched image itself, not just the artifact's claims about it.
[[ "$(docker image inspect --format '{{index .Config.Labels "org.opencontainers.image.revision"}}' "$APP_IMAGE")" == "$CI_COMMIT_SHA" ]] || fail "Unexpected image revision."
[[ "$(docker image inspect --format '{{index .Config.Labels "org.opencontainers.image.version"}}' "$APP_IMAGE")" == "$CI_PIPELINE_ID" ]] || fail "Unexpected image build."

umask 077
candidate="$(mktemp -d "$target/.candidate-XXXXXXXX")"
# Resolve variables once and save the complete runtime configuration. Compose
# already escapes literal dollar signs in this export for the next read. No app
# code, registry credentials or host data are copied into the deployment directory.
docker compose --project-directory "$CI_PROJECT_DIR" \
    -f "$CI_PROJECT_DIR/compose.hosting.yaml" config --format json > "$candidate/compose.json"
compose=(docker compose --project-name "$CI_PROJECT_PATH_SLUG" -f "$candidate/compose.json")
"${compose[@]}" config --quiet
check_branch_head
if ! "${compose[@]}" up --detach --wait --wait-timeout 90; then
    "${compose[@]}" logs --tail 100 >&2 || true
    fail "Deployment failed. Candidate configuration retained at $candidate; check the live service before retrying."
fi

# Test the backend through dockernet, the same network used by the shared proxy.
# This does not configure or test the public hostname, proxy authentication or TLS.
if ! docker run --rm --network dockernet --read-only --cap-drop ALL \
    --security-opt no-new-privileges:true \
    --env "BACKEND_HOST=$APP_NETWORK_ALIAS" --entrypoint python "$APP_IMAGE" -c \
    'import json, os, urllib.request; base = "http://" + os.environ["BACKEND_HOST"] + ":8000"; health = json.load(urllib.request.urlopen(base + "/health", timeout=5)); assert health == {"status": "ok"}; response = urllib.request.urlopen(base + "/", timeout=5); assert response.status == 200'; then
    fail "Backend verification failed. Candidate configuration retained at $candidate; inspect the live service."
fi

# Publish files only after acceptance. Atomic renames avoid leaving a partially
# written configuration. Existing data, secrets and unrelated files are untouched.
printf '%s\n%s\n%s\n' "$CI_PIPELINE_ID" "$CI_COMMIT_SHA" "$APP_IMAGE" > "$candidate/release.txt"
mv -- "$candidate/compose.json" "$target/compose.json"
mv -- "$candidate/release.txt" "$target/release.txt"
rmdir -- "$candidate"
printf 'Deployment accepted: %s\nSaved configuration: %s/compose.json\n' "$APP_IMAGE" "$target"
