#!/usr/bin/env bash
# Build the paper with the same pinned toolchain as CI.
#
# Usage:
#   ./build.sh                            # build ms.pdf
#   ./build.sh src/tex/figures/spread.pdf # build one file (any Snakemake target)
#   ./build.sh --regenerate               # also recompute cached results in src/data/
#   ./build.sh --dry-run                  # list what would run, and why
#   ./build.sh --verbose                  # print the raw showyourwork log
#
# Other arguments pass through to `showyourwork build`. build_report.py turns
# the showyourwork log into the progress report and explains failures; the
# full log of the last run is in .showyourwork/build.log. NO_COLOR=1 turns the
# colors off.
#
# The script downloads uv and Tectonic into .cache/ unless matching versions
# are already on PATH, so it needs only bash, curl, tar and git.
#
# Keep it bash 3.2 compatible (the macOS default): no associative arrays, no
# ${var,,}, and expand every possibly-empty array as ${arr[@]+"${arr[@]}"}.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
STARTED=${SECONDS}

TECTONIC_VERSION="0.17.0"
UV_VERSION="$(sed -n 's/^required-version = "==\([^"]*\)"$/\1/p' pyproject.toml)"
TOOL_CACHE=".cache"
LOG=".showyourwork/build.log"

# Build against this repository's .venv, even if another virtualenv is active.
unset VIRTUAL_ENV UV_PROJECT_ENVIRONMENT

# Cached results are read, never recomputed, unless --regenerate is given.
# The Snakefile defines the rules that write src/data/ only when this is true.
export PAPER_REGENERATE=false
VERBOSE=false
DRY_RUN=false
BUILD_ARGS=()
for arg in "$@"; do
  case "${arg}" in
    --regenerate) PAPER_REGENERATE=true ;;
    --verbose) VERBOSE=true ;;
    --dry-run|-n) DRY_RUN=true; BUILD_ARGS+=(--dry-run) ;;
    *) BUILD_ARGS+=("${arg}") ;;
  esac
done

# Colors on a terminal and in GitHub Actions. NO_COLOR turns them off.
if [[ ( -t 1 || "${GITHUB_ACTIONS:-}" == "true" ) && -z "${NO_COLOR:-}" ]]; then
  BOLD=$'\033[1m' DIM=$'\033[2m' RED=$'\033[31m' GREEN=$'\033[32m' CYAN=$'\033[36m' OFF=$'\033[0m'
else
  BOLD="" DIM="" RED="" GREEN="" CYAN="" OFF=""
fi
SPINNER=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)

# ok LABEL DETAIL: print one finished setup step.
ok() {
  printf '  %s✓%s %-38s %s%s%s\n' "${GREEN}" "${OFF}" "$1" "${DIM}" "$2" "${OFF}"
}

# step LABEL COMMAND...: run a setup step behind a spinner, then print one line
# with the last line of its output. On failure, print all of it and stop.
step() {
  local label="$1" started=${SECONDS} output pid status=0 frame=0
  shift
  output="$(mktemp)"
  "$@" >"${output}" 2>&1 &
  pid=$!
  trap 'kill "${pid}" 2>/dev/null; printf "\r\033[K\033[?25h"; exit 130' INT TERM
  if [[ -t 1 ]]; then
    printf '\033[?25l'
    while kill -0 "${pid}" 2>/dev/null; do
      printf '\r  %s%s%s %-38s %s%ss%s' "${CYAN}" "${SPINNER[frame % 10]}" "${OFF}" \
        "${label}" "${DIM}" "$((SECONDS - started))" "${OFF}"
      frame=$((frame + 1))
      sleep 0.1
    done
    printf '\r\033[K\033[?25h'
  fi
  wait "${pid}" || status=$?
  trap - INT TERM
  if (( status != 0 )); then
    printf '  %s✗ %-38s failed%s\n' "${RED}" "${label}" "${OFF}"
    sed 's/^/    /' "${output}"
    rm -f "${output}"
    exit "${status}"
  fi
  # The last summary line, skipping uv's indented per-package lines.
  ok "${label}" "$(grep -v '^[[:space:]+~-]' "${output}" | tail -n 1)"
  rm -f "${output}"
}

NAME="$(sed -n 's/^name = "\(.*\)"$/\1/p' pyproject.toml | head -n 1)"
CORES="${BUILD_CORES:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)}"
RESULTS="cached results"
if [[ "${PAPER_REGENERATE}" == "true" ]]; then
  RESULTS="regenerating results"
fi
printf '%s%s▸ %s%s %s· %s cores · %s%s\n' "${BOLD}" "${CYAN}" "${NAME}" "${OFF}" \
  "${DIM}" "${CORES}" "${RESULTS}" "${OFF}"

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
UV_DIR="${TOOL_CACHE}/uv-${UV_VERSION}"
download_uv() {
  mkdir -p "${UV_DIR}"
  curl -fsSL "https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/uv-${HOST_TRIPLE}.tar.gz" \
    | tar -xz -C "${UV_DIR}" --strip-components 1
  echo "downloaded into ${UV_DIR}"
}
UV_BIN="uv"
if [[ "$(uv --version 2>/dev/null | awk '{print $2}')" == "${UV_VERSION}" ]]; then
  ok "uv ${UV_VERSION}" "on PATH"
else
  UV_BIN="${PWD}/${UV_DIR}/uv"
  if [[ -x "${UV_BIN}" ]]; then
    ok "uv ${UV_VERSION}" "cached in ${UV_DIR}"
  elif [[ -n "${HOST_TRIPLE}" ]]; then
    step "uv ${UV_VERSION}" download_uv
  else
    echo "Install uv ${UV_VERSION}: https://docs.astral.sh/uv/getting-started/installation/" >&2
    exit 1
  fi
fi

# Tectonic: the LaTeX engine. It fetches the TeX packages it needs on first
# use, so no TeX Live install is needed. A matching tectonic on PATH is reused.
TECTONIC_DIR="${TOOL_CACHE}/tectonic-${TECTONIC_VERSION}"
download_tectonic() {
  mkdir -p "${TECTONIC_DIR}"
  curl -fsSL "https://github.com/tectonic-typesetting/tectonic/releases/download/tectonic%40${TECTONIC_VERSION}/tectonic-${TECTONIC_VERSION}-${HOST_TRIPLE}.tar.gz" \
    | tar -xz -C "${TECTONIC_DIR}"
  echo "downloaded into ${TECTONIC_DIR}"
}
if [[ "$(tectonic --version 2>/dev/null | sed 's/^Tectonic //')" == "${TECTONIC_VERSION}" ]]; then
  ok "Tectonic ${TECTONIC_VERSION}" "on PATH"
else
  if [[ -x "${TECTONIC_DIR}/tectonic" ]]; then
    ok "Tectonic ${TECTONIC_VERSION}" "cached in ${TECTONIC_DIR}"
  elif [[ -n "${HOST_TRIPLE}" ]]; then
    step "Tectonic ${TECTONIC_VERSION}" download_tectonic
  else
    echo "Install Tectonic ${TECTONIC_VERSION}: https://tectonic-typesetting.github.io/en-US/install.html" >&2
    exit 1
  fi
  export PATH="${PWD}/${TECTONIC_DIR}:${PATH}"
fi

# Install exactly the locked Python packages into .venv/.
step "Python packages" "${UV_BIN}" sync --frozen

# Figure scripts run as `python <script>` (see showyourwork.yml), so the
# locked .venv must come first on PATH.
export PATH="${PWD}/.venv/bin:${PATH}"
export MPLCONFIGDIR="${PWD}/${TOOL_CACHE}/matplotlib"
mkdir -p "${MPLCONFIGDIR}" .showyourwork

# --force-use-threads runs showyourwork's own steps (such as the LaTeX compile)
# in threads instead of new Snakemake processes, which saves a few seconds.
# Figure scripts still run as separate processes.
SYW_ARGS=(build --no-conda --force-use-threads --cores "${CORES}" --verbose)
REPORT_FLAGS=()
if [[ "${DRY_RUN}" == "true" ]]; then
  REPORT_FLAGS+=(--dry-run)
fi
STATUS=0
if [[ "${VERBOSE}" == "true" ]]; then
  showyourwork "${SYW_ARGS[@]}" ${BUILD_ARGS[@]+"${BUILD_ARGS[@]}"} 2>&1 | tee "${LOG}" || STATUS=$?
else
  showyourwork "${SYW_ARGS[@]}" ${BUILD_ARGS[@]+"${BUILD_ARGS[@]}"} 2>&1 \
    | python build_report.py "${LOG}" ${REPORT_FLAGS[@]+"${REPORT_FLAGS[@]}"} || STATUS=$?
fi

ELAPSED="$((SECONDS - STARTED))s"
if (( STATUS == 130 )); then
  printf '%s%s✗ build stopped%s after %s\n' "${BOLD}" "${RED}" "${OFF}" "${ELAPSED}" >&2
  exit 130
fi
# The error explanation on failure, or the LaTeX warnings on success.
python build_report.py --after "${LOG}" "${STATUS}" ${REPORT_FLAGS[@]+"${REPORT_FLAGS[@]}"}
if (( STATUS != 0 )); then
  printf '%s%s✗ build failed%s after %s %s· full log: %s%s\n' "${BOLD}" "${RED}" "${OFF}" \
    "${ELAPSED}" "${DIM}" "${LOG}" "${OFF}" >&2
  if grep -A 4 "Missing input files" "${LOG}" | grep -q "src/data/"; then
    echo "  A cached result in src/data/ is missing. Restore it from git, or run ./build.sh --regenerate." >&2
  fi
  exit "${STATUS}"
fi
if [[ "${DRY_RUN}" == "true" ]]; then
  printf '%s%s○ dry run%s, nothing was built %s(%s)%s\n' "${BOLD}" "${CYAN}" "${OFF}" \
    "${DIM}" "${ELAPSED}" "${OFF}"
  exit 0
fi
TARGET="ms.pdf"
for arg in ${BUILD_ARGS[@]+"${BUILD_ARGS[@]}"}; do
  if [[ "${arg}" != -* && -e "${arg}" ]]; then
    TARGET="${arg}"
  fi
done
printf '%s%s✓ %s%s ready %sin %s%s\n' "${BOLD}" "${GREEN}" "${TARGET}" "${OFF}" \
  "${DIM}" "${ELAPSED}" "${OFF}"
