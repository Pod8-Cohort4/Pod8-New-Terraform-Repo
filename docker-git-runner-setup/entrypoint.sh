#!/bin/bash
set -e

# --- Environment Variables ---
# Make sure these are set in your .env file or export here
: "${REPO:?Need to set REPO like 'username/repo'}"
: "${RUNNER_NAME:?Need to set RUNNER_NAME}"
: "${GITHUB_PAT:?Need to set GitHub personal access token}"

cd /home/runner

echo "Fixing permissions for /home/runner/_work..."
mkdir -p /home/runner/_work
chown -R runner:runner /home/runner/_work

# Only configure the runner if it’s not already configured
if [ ! -f /home/runner/.runner ]; then
  echo "Runner not configured yet, registering..."

  # Get registration token from GitHub
  TOKEN_URL="https://api.github.com/repos/${REPO}/actions/runners/registration-token"
  echo "Requesting registration token for $REPO..."
  RUNNER_TOKEN=$(curl -s -X POST \
    -H "Authorization: token ${GITHUB_PAT}" \
    "${TOKEN_URL}" | jq -r .token)

  echo "Registering runner: $RUNNER_NAME"
  ./config.sh --unattended \
    --url "https://github.com/${REPO}" \
    --token "${RUNNER_TOKEN}" \
    --name "${RUNNER_NAME}" \
    --labels self-hosted,docker,terraform \
    --work _work \
    --replace
else
  echo "Runner already configured. Skipping registration..."
fi

echo "Starting runner..."
exec ./run.sh
