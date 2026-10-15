#!/usr/bin/env bash
# Build the paper with the same pinned toolchain as CI.
#
# Usage:
#   ./build.sh                            # build ms.pdf
#   ./build.sh src/tex/figures/spread.pdf # build one file (any Snakemake target)
#   ./build.sh --regenerate               # also recompute cached results in src/data/
#   ./build.sh --dry-run                  # show what would run, run nothing
#
# Other arguments pass through to `showyourwork build`. The full log of the
# last run is in .showyourwork/build.log.
#
# The script downloads uv and Tectonic into .cache/ unless matching versions
# are already on PATH, so it needs only bash, curl, tar and git.
#
# Keep it bash 3.2 compatible (the macOS default): no associative arrays, no
# ${var,,}, and expand every possibly-empty array as ${arr[@]+"${arr[@]}"}.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

TECTONIC_VERSION="0.17.0"
UV_VERSION="$(sed -n 's/^required-version = "==\([^"]*\)"$/\1/p' pyproject.toml)"
TOOL_CACHE=".cache"

# Build against this repository's .venv, even if another virtualenv is active.
unset VIRTUAL_ENV UV_PROJECT_ENVIRONMENT

# Cached results are read, never recomputed, unless --regenerate is given.
# The Snakefile defines the rules that write src/data/ only when this is true.
export PAPER_REGENERATE=false
BUILD_ARGS=()
for arg in "$@"; do
  case "${arg}" in
    --regenerate) PAPER_REGENERATE=true ;;
    *) BUILD_ARGS+=("${arg}") ;;
  esac
done

# Release name of the uv and Tectonic downloads for this machine. Empty means
# no pinned download exists, so the tools must already be on PATH.
case "$(uname -s)/$(uname -m)" in
  Linux/x86_64)              HOST_TRIPLE="x86_64-unknown-linux-musl" ;;
  Linux/aarch64|Linux/arm64) HOST_TRIPLE="aarch64-unknown-linux-musl" ;;
  Darwin/arm64)              HOST_TRIPLE="aarch64-apple-darwin" ;;
  Darwin/x86_64)             HOST_TRIPLE="x86_64-apple-darwin" ;;
  *)                         HOST_TRIPLE="" ;;
esac

# uv: a different uv version refuses to run against uv.lock, so use exactly the
# pinned one. A matching uv on PATH is reused.
UV_BIN="uv"
if [[ "$(uv --version 2>/dev/null | awk '{print $2}')" != "${UV_VERSION}" ]]; then
  UV_BIN="${PWD}/${TOOL_CACHE}/uv-${UV_VERSION}/uv"
  if [[ ! -x "${UV_BIN}" ]]; then
    if [[ -z "${HOST_TRIPLE}" ]]; then
      echo "[build] Install uv ${UV_VERSION}: https://docs.astral.sh/uv/getting-started/installation/" >&2
      exit 1
    fi
    echo "[build] Downloading uv ${UV_VERSION} into ${TOOL_CACHE}/"
    mkdir -p "$(dirname "${UV_BIN}")"
    curl -fsSL "https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/uv-${HOST_TRIPLE}.tar.gz" \
      | tar -xz -C "$(dirname "${UV_BIN}")" --strip-components 1
  fi
fi

# Tectonic: the LaTeX engine. It fetches the TeX packages it needs on first
# use, so no TeX Live install is needed. A matching tectonic on PATH is reused.
if [[ "$(tectonic --version 2>/dev/null | sed 's/^Tectonic //')" != "${TECTONIC_VERSION}" ]]; then
  TECTONIC_DIR="${PWD}/${TOOL_CACHE}/tectonic-${TECTONIC_VERSION}"
  if [[ ! -x "${TECTONIC_DIR}/tectonic" ]]; then
    if [[ -z "${HOST_TRIPLE}" ]]; then
      echo "[build] Install Tectonic ${TECTONIC_VERSION}: https://tectonic-typesetting.github.io/en-US/install.html" >&2
      exit 1
    fi
    echo "[build] Downloading Tectonic ${TECTONIC_VERSION} into ${TOOL_CACHE}/"
    mkdir -p "${TECTONIC_DIR}"
    curl -fsSL "https://github.com/tectonic-typesetting/tectonic/releases/download/tectonic%40${TECTONIC_VERSION}/tectonic-${TECTONIC_VERSION}-${HOST_TRIPLE}.tar.gz" \
      | tar -xz -C "${TECTONIC_DIR}"
  fi
  export PATH="${TECTONIC_DIR}:${PATH}"
fi

# Install exactly the locked Python packages into .venv/.
"${UV_BIN}" sync --frozen

# Figure scripts run as `python <script>` (see showyourwork.yml), so the
# locked .venv must come first on PATH.
export PATH="${PWD}/.venv/bin:${PATH}"
export MPLCONFIGDIR="${PWD}/${TOOL_CACHE}/matplotlib"
mkdir -p "${MPLCONFIGDIR}" .showyourwork

echo "[build] uv $("${UV_BIN}" --version | awk '{print $2}'), $(tectonic --version), regenerate=${PAPER_REGENERATE}"
CORES="${BUILD_CORES:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)}"
showyourwork build --no-conda --cores "${CORES}" ${BUILD_ARGS[@]+"${BUILD_ARGS[@]}"} 2>&1 \
  | tee .showyourwork/build.log
