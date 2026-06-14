#!/bin/bash
set -euo pipefail

# Coverage report generator for NinjaView
#
# Usage:
#   ./scripts/generate_coverage.sh           # Full rebuild + coverage
#   ./scripts/generate_coverage.sh --quick   # Skip rebuild, just re-run tests + report

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
BUILD_DIR="build-coverage"
REPORT_DIR="coverage_report"
MIN_LINE_COVERAGE=80  # Fail if any source file falls below this threshold

# Intermediate files are kept inside the build dir to avoid polluting the root
COVERAGE_RAW="$BUILD_DIR/coverage_raw.info"
COVERAGE_FILTERED="$BUILD_DIR/coverage_filtered.info"
COVERAGE_SRC="$BUILD_DIR/coverage_src_only.info"

# Colours (disabled when stdout is not a terminal)
if [ -t 1 ]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; RESET='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; BOLD=''; RESET=''
fi

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
die()  { echo -e "${RED}Error: $*${RESET}" >&2; exit 1; }
info() { echo -e "${BOLD}==> $*${RESET}"; }

cpu_count() {
    if command -v nproc &>/dev/null; then
        nproc
    elif command -v sysctl &>/dev/null; then
        sysctl -n hw.ncpu
    else
        echo 4
    fi
}

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------
[ -f "CMakeLists.txt" ] || die "This script must be run from the project root."

for tool in cmake ctest lcov genhtml; do
    command -v "$tool" &>/dev/null || die "'$tool' is not installed or not in PATH."
done

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
QUICK=0
for arg in "$@"; do
    case "$arg" in
        --quick) QUICK=1 ;;
        *) die "Unknown argument: $arg" ;;
    esac
done

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------
if [ "$QUICK" -eq 0 ]; then
    info "Configuring build with coverage flags..."
    cmake -S . -B "$BUILD_DIR" \
        -DCMAKE_BUILD_TYPE=Debug \
        -DCMAKE_CXX_FLAGS="--coverage" \
        -DCMAKE_EXE_LINKER_FLAGS="--coverage"

    info "Building project..."
    cmake --build "$BUILD_DIR" -j"$(cpu_count)"
fi

# ---------------------------------------------------------------------------
# Clear stale profiling data
#
# Old .gcda files from previous runs can corrupt the results, causing coverage
# numbers to be wildly inaccurate. Always start from a clean slate.
# ---------------------------------------------------------------------------
info "Clearing stale coverage data..."
find "$BUILD_DIR" -name '*.gcda' -delete

# ---------------------------------------------------------------------------
# Run tests
# ---------------------------------------------------------------------------
info "Running tests..."
if ! ctest --test-dir "$BUILD_DIR" --output-on-failure; then
    die "Some tests failed. Fix them before generating coverage."
fi

# ---------------------------------------------------------------------------
# Capture & filter
# ---------------------------------------------------------------------------
info "Capturing coverage data..."
lcov --capture \
    --directory "$BUILD_DIR" \
    --output-file "$COVERAGE_RAW" \
    --ignore-errors inconsistent,gcov,unsupported,mismatch,format \
    --quiet

info "Filtering out external and generated code..."
lcov --remove "$COVERAGE_RAW" \
    '/usr/*' \
    '*/3rdparty/*' \
    '*/tests/*' \
    '*/Qt/*' \
    '*/Kaakao/*' \
    '*/v1/*' \
    '*/moc_*' \
    '*/.qt/*' \
    '*/.rcc/*' \
    --output-file "$COVERAGE_FILTERED" \
    --ignore-errors unused,inconsistent,format \
    --quiet

# Extract only src/ files for the summary
lcov --extract "$COVERAGE_FILTERED" '*/src/*' \
    --output-file "$COVERAGE_SRC" \
    --ignore-errors inconsistent,unused,format \
    --quiet

# ---------------------------------------------------------------------------
# HTML report
# ---------------------------------------------------------------------------
info "Generating HTML report..."
genhtml "$COVERAGE_FILTERED" \
    --output-directory "$REPORT_DIR" \
    --ignore-errors inconsistent,format,unused,source,category \
    --quiet

# ---------------------------------------------------------------------------
# Console summary
# ---------------------------------------------------------------------------
echo ""
echo "=========================================================="
echo " COVERAGE SUMMARY (src/)"
echo "=========================================================="
lcov --list "$COVERAGE_SRC" --ignore-errors inconsistent,format 2>/dev/null
echo "=========================================================="
echo " HTML Report: $REPORT_DIR/index.html"
echo "=========================================================="

# ---------------------------------------------------------------------------
# Threshold check
#
# Parse the per-file summary and fail if any source file is below the minimum.
# ---------------------------------------------------------------------------
info "Checking per-file threshold (>= ${MIN_LINE_COVERAGE}% lines)..."

BELOW_THRESHOLD=0
# lcov --list prints lines like:  path/to/file.cpp  | 85.0%   120| ...
# We parse the line-rate percentage for each src/ file.
lcov --list "$COVERAGE_SRC" --ignore-errors inconsistent,format 2>/dev/null \
    | grep -E '^\S.*\|' \
    | grep -v '^Filename' \
    | grep -v '^===' \
    | grep -v '^\[' \
    | grep -v 'Total:' \
    | while IFS='|' read -r filename rest; do
        # rest looks like " 85.0%   120| 90.0%  15"
        rest_clean=$(echo "$rest" | tr '|' ' ')
        pct=$(echo "$rest_clean" | awk '{print $1}' | tr -d '%')
        fname=$(echo "$filename" | xargs)  # trim whitespace

        # Skip autogen files and native platform wrappers
        case "$fname" in
            *_autogen*|*_init.*|*_qmltyperegistrations*|*.moc|*.mm) continue ;;
        esac

        # Extract line count
        num_lines=$(echo "$rest_clean" | awk '{print $2}')
        if [ -n "$num_lines" ] && [ "$num_lines" -lt 10 ] 2>/dev/null; then
            echo -e "  ${YELLOW}SKIP${RESET}  ${fname}: ${pct}% (only ${num_lines} lines)"
            continue
        fi

        if [ -n "$pct" ] && (( $(echo "$pct < $MIN_LINE_COVERAGE" | bc -l) )); then
            echo -e "  ${RED}FAIL${RESET}  ${fname}: ${pct}% < ${MIN_LINE_COVERAGE}%"
            # Signal failure via a temp file since we're in a pipe subshell
            touch "$BUILD_DIR/.coverage_fail"
        else
            echo -e "  ${GREEN}OK${RESET}    ${fname}: ${pct}%"
        fi
    done

if [ -f "$BUILD_DIR/.coverage_fail" ]; then
    rm -f "$BUILD_DIR/.coverage_fail"
    echo ""
    die "One or more source files are below the ${MIN_LINE_COVERAGE}% line coverage threshold."
fi

# Print overall rate
OVERALL=$(lcov --summary "$COVERAGE_SRC" --ignore-errors inconsistent,format 2>&1 \
    | grep 'lines' | awk '{print $2}')
echo ""
echo -e "${GREEN}All source files meet the ${MIN_LINE_COVERAGE}% threshold.${RESET}"
echo -e "Overall line coverage: ${BOLD}${OVERALL}${RESET}"
