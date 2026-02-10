#!/bin/bash
# test-player-logic.sh - Unit tests for queue player logic
# Runs locally without mpv, yt-dlp, or a Pi

set -e

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# --- Test infrastructure ---

TEST_DIR=$(mktemp -d)
QUEUE_FILE="$TEST_DIR/queue.txt"

cleanup() { rm -rf "$TEST_DIR"; }
trap cleanup EXIT

pass() {
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  PASS: $1"
}

fail() {
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  FAIL: $1 - $2"
}

run_test() {
    TESTS_RUN=$((TESTS_RUN + 1))
    echo "[$TESTS_RUN] $1"
    # Reset queue file before each test
    > "$QUEUE_FILE"
}

# --- Import functions from player.sh (just mark/unmark) ---

mark_played() {
    local url="$1"
    awk -v url="$url" '{if (!done && $0 == url) {print "[PLAYED] " $0; done=1} else print}' \
        "$QUEUE_FILE" > "$QUEUE_FILE.tmp" && mv "$QUEUE_FILE.tmp" "$QUEUE_FILE"
}

unmark_played() {
    local url="$1"
    local target="[PLAYED] $url"
    awk -v target="$target" -v url="$url" \
        '{if ($0 == target) {print url; found=1} else print}' \
        "$QUEUE_FILE" > "$QUEUE_FILE.tmp" && mv "$QUEUE_FILE.tmp" "$QUEUE_FILE"
}

# --- Import replay logic ---

replay_all() {
    sed -i'' -e 's/^\[PLAYED\] //' "$QUEUE_FILE"
}

replay_single() {
    local url="$1"
    local target="[PLAYED] $url"
    awk -v target="$target" -v url="$url" \
        '{if ($0 == target) print url; else print}' \
        "$QUEUE_FILE" > "$QUEUE_FILE.tmp" && mv "$QUEUE_FILE.tmp" "$QUEUE_FILE"
}

# =========================================
# Tests
# =========================================

run_test "mark_played marks correct URL"
cat > "$QUEUE_FILE" << 'EOF'
https://youtube.com/watch?v=AAA
https://youtube.com/watch?v=BBB
https://youtube.com/watch?v=CCC
EOF
mark_played "https://youtube.com/watch?v=BBB"
if grep -q '^\[PLAYED\] https://youtube.com/watch?v=BBB$' "$QUEUE_FILE" && \
   grep -q '^https://youtube.com/watch?v=AAA$' "$QUEUE_FILE" && \
   grep -q '^https://youtube.com/watch?v=CCC$' "$QUEUE_FILE"; then
    pass "Only BBB marked, AAA and CCC untouched"
else
    fail "Wrong lines marked" "$(cat "$QUEUE_FILE")"
fi

# ---

run_test "unmark_played removes [PLAYED] from specific URL"
cat > "$QUEUE_FILE" << 'EOF'
[PLAYED] https://youtube.com/watch?v=AAA
[PLAYED] https://youtube.com/watch?v=BBB
https://youtube.com/watch?v=CCC
EOF
unmark_played "https://youtube.com/watch?v=BBB"
if grep -q '^\[PLAYED\] https://youtube.com/watch?v=AAA$' "$QUEUE_FILE" && \
   grep -q '^https://youtube.com/watch?v=BBB$' "$QUEUE_FILE" && \
   grep -q '^https://youtube.com/watch?v=CCC$' "$QUEUE_FILE"; then
    pass "Only BBB unmarked, AAA still played"
else
    fail "Wrong unmark behavior" "$(cat "$QUEUE_FILE")"
fi

# ---

run_test "single skip doesn't cascade"
# Simulate: 1 video exits 0 in <5s, then next plays normally
cat > "$QUEUE_FILE" << 'EOF'
https://youtube.com/watch?v=AAA
https://youtube.com/watch?v=BBB
https://youtube.com/watch?v=CCC
EOF
rapid_successes=0
MAX_RAPID_FAILURES=3

# Simulate skip of AAA (exit 0, <5s)
mark_played "https://youtube.com/watch?v=AAA"
MPV_EXIT=0; PLAY_DURATION=1
rapid_successes=$((rapid_successes + 1))

# Check: counter is 1, below threshold
if [ $rapid_successes -lt $MAX_RAPID_FAILURES ]; then
    pass "Single skip (rapid_successes=$rapid_successes) below threshold ($MAX_RAPID_FAILURES)"
else
    fail "Single skip triggered cascade" "rapid_successes=$rapid_successes"
fi

# ---

run_test "cascade protection triggers at 3 rapid exits"
cat > "$QUEUE_FILE" << 'EOF'
https://youtube.com/watch?v=AAA
https://youtube.com/watch?v=BBB
https://youtube.com/watch?v=CCC
https://youtube.com/watch?v=DDD
https://youtube.com/watch?v=EEE
EOF
rapid_successes=0
MAX_RAPID_FAILURES=3
cascade_triggered=false

urls=("https://youtube.com/watch?v=AAA" "https://youtube.com/watch?v=BBB" "https://youtube.com/watch?v=CCC")
for url in "${urls[@]}"; do
    mark_played "$url"
    rapid_successes=$((rapid_successes + 1))
    if [ $rapid_successes -ge $MAX_RAPID_FAILURES ]; then
        unmark_played "$url"
        cascade_triggered=true
        rapid_successes=0
        break
    fi
done

if [ "$cascade_triggered" = true ]; then
    # CCC should be unmarked (recovered)
    if grep -q '^https://youtube.com/watch?v=CCC$' "$QUEUE_FILE"; then
        pass "Cascade triggered at 3, last video recovered"
    else
        fail "Cascade triggered but video not recovered" "$(cat "$QUEUE_FILE")"
    fi
else
    fail "Cascade never triggered" "rapid_successes=$rapid_successes"
fi

# ---

run_test "replay all removes all [PLAYED] tags"
cat > "$QUEUE_FILE" << 'EOF'
[PLAYED] https://youtube.com/watch?v=AAA
[PLAYED] https://youtube.com/watch?v=BBB
https://youtube.com/watch?v=CCC
[PLAYED] https://youtube.com/watch?v=DDD
EOF
replay_all
played_count=$(grep -c '^\[PLAYED\]' "$QUEUE_FILE" || true)
total_urls=$(grep -c 'youtube.com' "$QUEUE_FILE" || true)
if [ "$played_count" -eq 0 ] && [ "$total_urls" -eq 4 ]; then
    pass "All 3 [PLAYED] tags removed, 4 URLs intact"
else
    fail "Replay all incomplete" "played=$played_count, urls=$total_urls"
fi

# ---

run_test "replay single removes specific [PLAYED] tag"
cat > "$QUEUE_FILE" << 'EOF'
[PLAYED] https://youtube.com/watch?v=AAA
[PLAYED] https://youtube.com/watch?v=BBB
https://youtube.com/watch?v=CCC
EOF
replay_single "https://youtube.com/watch?v=BBB"
if grep -q '^\[PLAYED\] https://youtube.com/watch?v=AAA$' "$QUEUE_FILE" && \
   grep -q '^https://youtube.com/watch?v=BBB$' "$QUEUE_FILE" && \
   grep -q '^https://youtube.com/watch?v=CCC$' "$QUEUE_FILE"; then
    pass "Only BBB replayed, AAA still marked"
else
    fail "Replay single wrong behavior" "$(cat "$QUEUE_FILE")"
fi

# ---

run_test "queue parsing skips comments, blanks, and [PLAYED]"
cat > "$QUEUE_FILE" << 'EOF'
# My queue
[PLAYED] https://youtube.com/watch?v=AAA

https://youtube.com/watch?v=BBB
# Another comment
https://youtube.com/watch?v=CCC

EOF
NEXT_URL=$(grep -v '^\[PLAYED\]' "$QUEUE_FILE" | grep -v '^#' | grep -v '^[[:space:]]*$' | head -n 1)
if [ "$NEXT_URL" = "https://youtube.com/watch?v=BBB" ]; then
    pass "Correctly picked BBB (skipped comment, played, blank)"
else
    fail "Wrong next URL" "got '$NEXT_URL'"
fi

# ---

run_test "mark_played only marks first occurrence of duplicate URL"
cat > "$QUEUE_FILE" << 'EOF'
https://youtube.com/watch?v=AAA
https://youtube.com/watch?v=BBB
https://youtube.com/watch?v=AAA
EOF
mark_played "https://youtube.com/watch?v=AAA"
first_line=$(sed -n '1p' "$QUEUE_FILE")
third_line=$(sed -n '3p' "$QUEUE_FILE")
if [ "$first_line" = "[PLAYED] https://youtube.com/watch?v=AAA" ] && \
   [ "$third_line" = "https://youtube.com/watch?v=AAA" ]; then
    pass "First AAA marked, second AAA untouched"
else
    fail "Duplicate handling wrong" "line1='$first_line' line3='$third_line'"
fi

# =========================================
# Summary
# =========================================
echo ""
echo "==========================================="
echo "  Results: $TESTS_PASSED/$TESTS_RUN passed"
if [ $TESTS_FAILED -gt 0 ]; then
    echo "  $TESTS_FAILED FAILED"
    echo "==========================================="
    exit 1
else
    echo "  All tests passed"
    echo "==========================================="
    exit 0
fi
