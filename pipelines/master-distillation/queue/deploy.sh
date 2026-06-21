#!/usr/bin/env bash
# Deploy the queue runner to cyberpower.
# Run from the laptop. Sets up ~/jazz-pipeline/ with the scripts + an
# empty state/log/output skeleton.
#
# Usage: ./deploy.sh [user@host]
#   Default: dheerajchand@cyberpower

set -euo pipefail

REMOTE="${1:-dheerajchand@cyberpower}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

echo "==> Deploying queue runner to $REMOTE"
ssh "$REMOTE" 'mkdir -p ~/jazz-pipeline/{state,logs,outputs}'

scp \
    "$SCRIPT_DIR/config.sh" \
    "$SCRIPT_DIR/lib.sh" \
    "$SCRIPT_DIR/process_one.sh" \
    "$SCRIPT_DIR/queue_runner.sh" \
    "$SCRIPT_DIR/manifest_from_configs.py" \
    "$REMOTE:~/jazz-pipeline/"
ssh "$REMOTE" 'chmod +x ~/jazz-pipeline/*.sh ~/jazz-pipeline/manifest_from_configs.py'

# Push the configs/ tree so manifest_from_configs.py has something to read.
# We don't need the full repo on cyberpower — just the configs/ snapshot.
ssh "$REMOTE" 'mkdir -p ~/jazz-pipeline/configs-snapshot'
rsync -a --delete \
    "$REPO_ROOT/pipelines/master-distillation/configs/" \
    "$REMOTE:~/jazz-pipeline/configs-snapshot/"

# Regenerate the manifest from the freshly-rsynced configs.
ssh "$REMOTE" \
    'python3 ~/jazz-pipeline/manifest_from_configs.py --configs ~/jazz-pipeline/configs-snapshot --output ~/jazz-pipeline/manifest.tsv'

echo "==> Deploy complete."
echo "    To start the daemon:"
echo "        ssh $REMOTE 'nohup bash ~/jazz-pipeline/queue_runner.sh \\"
echo "            >>~/jazz-pipeline/logs/daemon.stdout \\"
echo "            2>>~/jazz-pipeline/logs/daemon.stderr & disown'"
echo "    To check status:"
echo "        ssh $REMOTE 'ls ~/jazz-pipeline/state/'"
echo "    To follow daemon log:"
echo "        ssh $REMOTE 'tail -f ~/jazz-pipeline/logs/daemon.stdout'"
