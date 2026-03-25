#!/bin/bash
# setup.sh — Runmatic Learning Environment Setup
# Run once after placing the repo on your machine
# Usage: chmod +x setup.sh && ./setup.sh

set -e

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Runmatic — Learning Environment Setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ── OS Check ──────────────────────────────────────
if [[ "$OSTYPE" == "darwin"* ]]; then
  echo "✅ macOS detected"
else
  echo "⚠️  Non-macOS detected. This setup is written for Mac."
  echo "   Paths and Docker Desktop steps may differ on Linux."
fi

# ── Claude Code ───────────────────────────────────
echo ""
echo "Checking Claude Code..."
if ! command -v claude &> /dev/null; then
  echo "❌ Claude Code not found."
  echo ""
  echo "   Install it:"
  echo "   npm install -g @anthropic-ai/claude-code"
  echo ""
  echo "   Requires Node.js 18+. Check: node --version"
  echo "   If Node isn't installed: brew install node"
  echo ""
  exit 1
else
  CLAUDE_VERSION=$(claude --version 2>/dev/null || echo "installed")
  echo "✅ Claude Code: $CLAUDE_VERSION"
fi

# ── Docker ─────────────────────────────────────────
echo ""
echo "Checking Docker..."
if ! command -v docker &> /dev/null; then
  echo "❌ Docker not found."
  echo ""
  echo "   Install Docker Desktop for Mac:"
  echo "   https://www.docker.com/products/docker-desktop/"
  echo ""
  echo "   After installing, start Docker Desktop, then run this script again."
  exit 1
else
  echo "✅ Docker CLI: $(docker --version)"
fi

if ! docker info &> /dev/null 2>&1; then
  echo "❌ Docker daemon not running."
  echo "   Start Docker Desktop (whale icon in menu bar) then run this script again."
  exit 1
else
  echo "✅ Docker daemon: running"
fi

# ── Docker Compose ─────────────────────────────────
echo ""
echo "Checking Docker Compose..."
if docker compose version &> /dev/null 2>&1; then
  echo "✅ Docker Compose: $(docker compose version --short 2>/dev/null || echo 'v2')"
else
  echo "❌ Docker Compose v2 not found."
  echo "   It's bundled with Docker Desktop. Make sure Docker Desktop is up to date."
  exit 1
fi

# ── Git ─────────────────────────────────────────────
echo ""
echo "Checking Git..."
if ! command -v git &> /dev/null; then
  echo "❌ Git not found."
  echo "   Install: brew install git"
  exit 1
else
  echo "✅ Git: $(git --version)"
fi

# ── Directory Structure ─────────────────────────────
echo ""
echo "Verifying directory structure..."

REQUIRED_DIRS=(
  "app/api"
  "app/worker"
  "app/frontend"
  "app/db"
  "infra/docker"
  "infra/k8s/manifests"
  "infra/k8s/argocd"
  "infra/cloud/terraform"
  "infra/cloud/scripts"
)

ALL_DIRS_OK=true
for dir in "${REQUIRED_DIRS[@]}"; do
  if [ -d "$dir" ]; then
    echo "  ✅ $dir"
  else
    mkdir -p "$dir"
    echo "  ✅ $dir (created)"
  fi
done

# ── Key Files ──────────────────────────────────────
echo ""
echo "Verifying key files..."

REQUIRED_FILES=(
  "CLAUDE.md"
  "SPRINTS.md"
  "PROGRESS.md"
  "RUNMATIC.md"
  "SESSION_0A_PROMPT.md"
  "ARCHITECTURE_REVIEW.md"
  "CHANGELOG.md"
  "README.md"
  ".gitignore"
)

ALL_FILES_OK=true
for file in "${REQUIRED_FILES[@]}"; do
  if [ -f "$file" ]; then
    echo "  ✅ $file"
  else
    echo "  ❌ Missing: $file"
    ALL_FILES_OK=false
  fi
done

# ── Git Init ──────────────────────────────────────
#echo ""
#if [ ! -d ".git" ]; then
#  echo "Initializing git repository..."
#  git init -b main
#  git add .
#  git commit -m "init: runmatic learning os — 32 sprints, 3 acts, docker through aws"
#  echo "✅ Git repository initialized with initial commit"
#else
#  echo "✅ Git repository already initialized"
#  COMMIT_COUNT=$(git rev-list --count HEAD 2>/dev/null || echo "0")
#  echo "   Commits so far: $COMMIT_COUNT"
#fi

# ── Summary ───────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$ALL_FILES_OK" = true ]; then
  echo ""
  echo "  ✅ Environment ready."
  echo ""
  echo "  WHAT'S NEXT:"
  echo ""
  echo "  Step 1 — Generate the application (Session 0A)"
  echo "    Run: claude"
  echo "    Paste the contents of: SESSION_0A_PROMPT.md"
  echo "    Wait ~20 min for app generation."
  echo ""
  echo "  Step 2 — Architecture review (Session 0B)"
  echo "    Read RUNMATIC.md and app/ directory"
  echo "    Fill in ARCHITECTURE_REVIEW.md"
  echo "    Tell Claude you're ready for the 5 exit questions"
  echo "    Pass 4/5 → Sprint 01 unlocks"
  echo ""
  echo "  Step 3 — Begin sprints"
  echo "    Run: claude"
  echo "    Say: go"
  echo "    35 minutes. Score. Commit. Repeat."
  echo ""
  echo "  Your reference guide: ~/Documents/runmatic-reference.md"
  echo "  (Move REFERENCE.md there — it should live outside the repo)"
  echo ""
else
  echo ""
  echo "  ⚠️  Setup completed with missing files. Check above."
  echo "  Re-download the repository and try again."
  echo ""
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
