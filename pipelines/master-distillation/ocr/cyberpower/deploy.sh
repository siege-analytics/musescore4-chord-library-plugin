#!/usr/bin/env bash
# Deploy the cyberpower-side OCR runner. One-shot setup; idempotent.
#
# Usage:  ./deploy.sh [user@host]
#         Default host: dheerajchand@cyberpower
#
# Copies run.sh + ocr_runner.py to ~/jazz-ocr/bin/ on the remote, makes
# them executable, creates inbox/ and outbox/ subdirs, and reports
# tesseract + ollama versions on the remote for confirmation.

set -euo pipefail

REMOTE="${1:-dheerajchand@cyberpower}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Deploying OCR runner to $REMOTE"
ssh "$REMOTE" 'mkdir -p ~/jazz-ocr/bin ~/jazz-ocr/inbox ~/jazz-ocr/outbox'
scp "$SCRIPT_DIR/run.sh" "$SCRIPT_DIR/ocr_runner.py" "$REMOTE:~/jazz-ocr/bin/"
ssh "$REMOTE" 'chmod +x ~/jazz-ocr/bin/run.sh ~/jazz-ocr/bin/ocr_runner.py'

echo "==> Sanity checks on $REMOTE"
ssh "$REMOTE" 'tesseract --version 2>&1 | head -1; pdftoppm -v 2>&1 | head -1; ollama list 2>&1 | head -5'

echo "==> Deployment complete. Run dir: ~/jazz-ocr/{inbox,outbox}/"
