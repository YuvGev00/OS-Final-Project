#!/bin/bash

# MY IMPLEMENTATION ONLY SUPPORTS ONE INSTANCE PER PLUGIN!

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_pass() {
    echo -e "$1: ${GREEN}PASS${NC}"
}

print_fail() {
    echo -e "$1: ${RED}FAIL :(${NC}"
    echo -e "  Expected: $2 || Got: $3"
    FAILED=1
}

print_section() {
    echo ""
    echo -e "${YELLOW}--- $1 --- ${NC}"
}

echo ""
echo "============================"
echo "      Building project"
echo "============================"
echo ""

./build.sh
if [ $? -ne 0 ]; then
    echo "Build failed!"
    exit 1
fi

echo ""
echo "============================"
echo "      Starting tests"
echo "(ONLY SUPPORTS ONE INSTANCE!)"
echo "============================"

FAILED=0


print_section "Build Verification"

# Check analyzer binary
if [ -x ./output/analyzer ]; then
    :   # analyzer exists, do nothing
else
    print_fail "Analyzer binary missing or not executable"
    missing=1
fi

missing=0
for src in plugins/*.c; do
    [ -e "$src" ] || continue
    plugin_name=$(basename "$src" .c)
    if [[ "$plugin_name" == "plugin_common" ]]; then
        continue
    fi

    if [ -f "./output/$plugin_name.so" ]; then
        :   # plugin exists, do nothing
    else
        print_fail "Missing plugin output/$plugin_name.so (from $src)"
        missing=1
    fi
done

if [ $missing -eq 0 ]; then
    print_pass "Build verification"
else
    print_fail "Build verification"
fi


# ====================================
# BASIC PLUGINS
# ====================================

print_section "Basic Plugin Tests"

# Test logger
EXPECTED="[logger] hello"
ACTUAL=$(echo "hello
<END>" | ./output/analyzer 10 logger 2>/dev/null | grep "\[logger\]" || echo "NOTHING")
if [ "$ACTUAL" == "$EXPECTED" ]; then
    print_pass "Logger"
else
    print_fail "Logger" "$EXPECTED" "$ACTUAL"
fi

# Test uppercaser
EXPECTED="[logger] HELLO"
ACTUAL=$(echo "hello
<END>" | ./output/analyzer 10 uppercaser logger 2>/dev/null | grep "\[logger\]" || echo "NOTHING")
if [ "$ACTUAL" == "$EXPECTED" ]; then
    print_pass "Uppercaser"
else
    print_fail "Uppercaser" "$EXPECTED" "$ACTUAL"
fi

# Test rotator
EXPECTED="[logger] ohell"
ACTUAL=$(echo "hello
<END>" | ./output/analyzer 10 rotator logger 2>/dev/null | grep "\[logger\]" || echo "NOTHING")
if [ "$ACTUAL" == "$EXPECTED" ]; then
    print_pass "Rotator"
else
    print_fail "Rotator" "$EXPECTED" "$ACTUAL"
fi

# Test flipper
EXPECTED="[logger] olleh"
ACTUAL=$(echo "hello
<END>" | ./output/analyzer 10 flipper logger 2>/dev/null | grep "\[logger\]" || echo "NOTHING")
if [ "$ACTUAL" == "$EXPECTED" ]; then
    print_pass "Flipper"
else
    print_fail "Flipper" "$EXPECTED" "$ACTUAL"
fi

# Test expander
EXPECTED="[logger] h i"
ACTUAL=$(echo "hi
<END>" | ./output/analyzer 10 expander logger 2>/dev/null | grep "\[logger\]" || echo "NOTHING")
if [ "$ACTUAL" == "$EXPECTED" ]; then
    print_pass "Expander"
else
    print_fail "Expander" "$EXPECTED" "$ACTUAL"
fi

# Test typewriter 
ACTUAL=$(echo "test
<END>" | timeout 3s ./output/analyzer 10 typewriter 2>&1)
if echo "$ACTUAL" | grep -q "\[typewriter\]"; then
    print_pass "Typewriter"
else
    print_fail "Typewriter" "Output with [typewriter]" "No output or timeout"
fi


# ====================================
# PLUGIN CHAINS
# ====================================

print_section "Plugin Chain Tests"

# Upper + rotate
EXPECTED="[logger] OHELL"
ACTUAL=$(echo "hello
<END>" | ./output/analyzer 10 uppercaser rotator logger 2>/dev/null | grep "\[logger\]" || echo "NOTHING")
if [ "$ACTUAL" == "$EXPECTED" ]; then
    print_pass "Chain: upper + rotate"
else
    print_fail "Chain: upper + rotate" "$EXPECTED" "$ACTUAL"
fi

# Flip + upper + expander
EXPECTED="[logger] O L L E H"
ACTUAL=$(echo "hello
<END>" | ./output/analyzer 10 flipper uppercaser expander logger 2>/dev/null | grep "\[logger\]" || echo "NOTHING")
if [ "$ACTUAL" == "$EXPECTED" ]; then
    print_pass "Chain: flip + upper expander"
else
    print_fail "Chain: flip + upper" "$EXPECTED" "$ACTUAL"
fi

# All plugins chain
OUTPUT=$(echo -e "ab\n<END>" | ./output/analyzer 10 uppercaser rotator flipper expander logger typewriter 2>&1 | grep "\[logger\]")
EXPECTED="[logger] A B"  # "ab" -> "AB" -> "BA" -> "AB" -> "A B"
if [[ "$OUTPUT" == "$EXPECTED" ]]; then
    print_pass "All plugins chain transformations"
else
    print_fail "All plugins chain transformations" "$EXPECTED" "$OUTPUT"
fi

# Typewriter traffic jam (should take a few)
OUTPUT=$(echo -e "uno\ndos\n<END>" | ./output/analyzer 1 typewriter logger 2>&1)
COUNT=$(echo "$OUTPUT" | grep -c "\[logger\]")
if [ $COUNT -eq 2 ] && echo "$OUTPUT" | grep -q "Pipeline shutdown complete"; then
    print_pass "Typewriter traffic jam handling"
else
    print_fail "Typewriter traffic jam handling" "2 logger lines + shutdown" "Got $COUNT lines"
fi


# ====================================
# ARGUMENT VALIDATION
# ====================================

print_section "Exit Code and Error Tests"

# No arguments
./output/analyzer >/dev/null 2>&1
ACTUAL=$?
EXPECTED=1
if [ $ACTUAL -eq $EXPECTED ]; then
    print_pass "No arguments"
else
    print_fail "No arguments" "Exit code $EXPECTED" "Exit code $ACTUAL"
fi

# No plugins
./output/analyzer 10 >/dev/null 2>&1
ACTUAL=$?
EXPECTED=1
if [ $ACTUAL -eq $EXPECTED ]; then
    print_pass "No plugins"
else
    print_fail "Exit 1: No plugins" "Exit code $EXPECTED" "Exit code $ACTUAL"
fi

# Multi instance (SHOULD FAIL!!!!!)
printf "x\n<END>\n" | ./output/analyzer 10 logger logger logger >/dev/null 2>&1
RC=$?
if [ $RC -eq 2 ]; then
  print_pass "Multi instance (Checks if failed!!!!!)"
else
  print_fail "Multi instance" "exit 2" "exit $RC"
fi

# Plugin not found
./output/analyzer 10 nonexistent >/dev/null 2>&1
ACTUAL=$?
EXPECTED=1
if [ $ACTUAL -eq $EXPECTED ]; then
    print_pass "Plugin not found"
else
    print_fail "Plugin not found" "Exit code $EXPECTED" "Exit code $ACTUAL"
fi

# Plugin init failure
cat > ./plugins/failinit.c << 'EOF'
const char* plugin_init(int size) { return "Init failed"; }
const char* plugin_fini(void) { return 0; }
const char* plugin_place_work(const char* s) { return 0; }
void plugin_attach(const char* (*f)(const char*)) {}
const char* plugin_wait_finished(void) { return 0; }
const char* plugin_get_name(void) { return "failinit"; }
EOF
gcc -fPIC -shared -o ./output/failinit.so ./plugins/failinit.c 2>/dev/null
./output/analyzer 10 failinit >/dev/null 2>&1
ACTUAL=$?
EXPECTED=2
if [ $ACTUAL -eq $EXPECTED ]; then
    print_pass "Plugin init failure"
else
    print_fail "Plugin init failure" "Exit code $EXPECTED" "Exit code $ACTUAL"
fi
rm -f ./plugins/failinit.c ./output/failinit.so

# Filesystem 
mkdir -p ./output/dirplugin.so 2>/dev/null
./output/analyzer 10 dirplugin >/dev/null 2>&1
ACTUAL=$?
EXPECTED=1
if [ $ACTUAL -eq $EXPECTED ]; then
    print_pass "Plugin is directory"
else
    print_fail "Plugin is directory" "Exit code $EXPECTED" "Exit code $ACTUAL"
fi
rmdir ./output/dirplugin.so 2>/dev/null

# Check usage
OUTPUT=$(./output/analyzer 2>&1)
if echo "$OUTPUT" | grep -q "Usage:" && echo "$OUTPUT" | grep -q "Available plugins:"; then
    print_pass "Usage message"
else
    print_fail "Usage message" "Usage with plugin list" "Missing or incomplete usage"
fi

# String queue size
./output/analyzer abc logger >/dev/null 2>&1
ACTUAL=$?
EXPECTED=1
if [ $ACTUAL -eq $EXPECTED ]; then
    print_pass "String queue size"
else
    print_fail "String queue size" "Exit code $EXPECTED" "Exit code $ACTUAL"
fi

# Negative queue
./output/analyzer -5 logger >/dev/null 2>&1
ACTUAL=$?
EXPECTED=1
if [ $ACTUAL -eq $EXPECTED ]; then
    print_pass "Negative queue size"
else
    print_fail "Negative queue size" "Exit code $EXPECTED" "Exit code $ACTUAL"
fi

# Zero queue
./output/analyzer 0 logger >/dev/null 2>&1
ACTUAL=$?
EXPECTED=1
if [ $ACTUAL -eq $EXPECTED ]; then
    print_pass "Zero queue size"
else
    print_fail "Zero queue size" "Exit code $EXPECTED" "Exit code $ACTUAL"
fi

# Float queue
./output/analyzer 1.5 logger >/dev/null 2>&1
ACTUAL=$?
EXPECTED=1
if [ $ACTUAL -eq $EXPECTED ]; then
    print_pass "Float queue size"
else
    print_fail "Float queue size" "Exit code $EXPECTED" "Exit code $ACTUAL"
fi


# ====================================
# INPUT EDGE CASES
# ====================================

print_section "Input Edge Cases"

# Multiple empty lines
OUTPUT=$(echo -e "\n\n\n<END>" | ./output/analyzer 10 logger 2>/dev/null)
COUNT=$(echo "$OUTPUT" | grep -c "^\[logger\] $")
if [ $COUNT -eq 3 ] && echo "$OUTPUT" | grep -q "Pipeline shutdown complete"; then
    print_pass "Multiple empty lines"
else
    print_fail "Multiple empty lines" "2 blank logger lines + shutdown" "$COUNT blank lines"
fi

# Whitespace preservation
EXPECTED="[logger]    "
ACTUAL=$(echo "   
<END>" | ./output/analyzer 10 logger 2>/dev/null | grep "\[logger\]" || echo "NOTHING")
if [ "$ACTUAL" == "$EXPECTED" ]; then
    print_pass "Whitespace preservation" 
else
    print_fail "Whitespace preservation" "'$EXPECTED'" "'$ACTUAL'"
fi

# Single char rotation
EXPECTED="[logger] x"
ACTUAL=$(echo "x
<END>" | ./output/analyzer 10 rotator logger 2>/dev/null | grep "\[logger\]" || echo "NOTHING")
if [ "$ACTUAL" == "$EXPECTED" ]; then
    print_pass "Single char rotation"
else
    print_fail "Single char rotation" "$EXPECTED" "$ACTUAL"
fi

# Single char expander
EXPECTED="[logger] x"
ACTUAL=$(echo "x
<END>" | ./output/analyzer 10 expander logger 2>/dev/null | grep "\[logger\]" || echo "NOTHING")
if [ "$ACTUAL" == "$EXPECTED" ]; then
    print_pass "Expander single char"
else
    print_fail "Expander single char" "$EXPECTED" "$ACTUAL"
fi

# Tab character
EXPECTED="[logger] hello	world"
ACTUAL=$(echo -e "hello\tworld
<END>" | ./output/analyzer 10 logger 2>/dev/null | grep "\[logger\]" || echo "NOTHING")
if [ "$ACTUAL" == "$EXPECTED" ]; then
    print_pass "Tab character"
else
    print_fail "Tab character" "$EXPECTED" "$ACTUAL"
fi

# Special symbols
EXPECTED="[logger] !@#\$%^&*()"
ACTUAL=$(printf '!@#$%%^&*()\n<END>' | ./output/analyzer 10 logger 2>/dev/null | grep "\[logger\]" || echo "NOTHING")
if [ "$ACTUAL" == "$EXPECTED" ]; then
    print_pass "Special symbols"
else
    print_fail "Special symbols" "$EXPECTED" "$ACTUAL"
fi

# Null byte
printf 'hello\x00world\n<END>' | ./output/analyzer 10 logger 2>&1 | grep -q "\[logger\] hello"
if [ $? -eq 0 ]; then
    print_pass "Null byte handling"
else
    print_fail "Null byte handling" "Line with null truncated at null" "Failed to process"
fi

# Long lines
LONG_LINE=$(printf 'x%.0s' {1..1024})
echo "$LONG_LINE
<END>" | ./output/analyzer 10 logger 2>&1 | grep -q "Pipeline shutdown complete"
if [ $? -eq 0 ]; then
    print_pass "1024 char line"
else
    print_fail "1024 char line" "Pipeline shutdown complete" "Pipeline failed"
fi


# ====================================
# END MARKER BEHAVIOR
# ====================================

print_section "<END> Marker Tests (input cont')"

# Just END
echo "<END>" | ./output/analyzer 10 logger 2>&1 | grep -q "Pipeline shutdown complete"
if [ $? -eq 0 ]; then
    print_pass "Just input"
else
    print_fail "Just input" "Pipeline shutdown complete" "Pipeline failed"
fi

# END stops processing
OUTPUT=$(echo "before
<END>
after" | ./output/analyzer 10 logger 2>&1)
BEFORE=$(echo "$OUTPUT" | grep -c "\[logger\] before")
AFTER=$(echo "$OUTPUT" | grep -c "\[logger\] after")
if [ $BEFORE -eq 1 ] && [ $AFTER -eq 0 ]; then
    print_pass "END stops processing"
else
    print_fail "END stops processing" "1 'before', 0 'after'" "$BEFORE 'before', $AFTER 'after'"
fi

# END as substring
EXPECTED="[logger] test<END>test"
ACTUAL=$(echo "test<END>test
<END>" | ./output/analyzer 10 logger 2>/dev/null | grep "\[logger\]" || echo "NOTHING")
if [ "$ACTUAL" == "$EXPECTED" ]; then
    print_pass "END as substring"
else
    print_fail "END as substring" "$EXPECTED" "$ACTUAL"
fi

# END with spaces should not terminate
OUTPUT=$(echo -e "test\n  <END>  \n<END>" | ./output/analyzer 10 logger 2>&1)
if echo "$OUTPUT" | grep -q "\[logger\]   <END>  "; then
    print_pass "Spaces around END "
else
    print_fail "END with spaces" "Should process as normal line" "Stopped early"
fi

# Multiple END markers - should stop at first
OUTPUT=$(echo -e "line1\n<END>\n<END>\n" | ./output/analyzer 10 logger 2>&1)
COUNT=$(echo "$OUTPUT" | grep -c "\[logger\] <END>")
if [ $COUNT -eq 0 ]; then
    print_pass "Multiple END markers handled"
else
    print_fail "Multiple END" "Should stop at first" "Processed $COUNT ENDs"
fi

# END without newline
printf "test <END>" | timeout 2s ./output/analyzer 10 logger 2>&1 | grep -q "Pipeline shutdown complete"
if [ $? -ne 0 ]; then
    print_pass "END without newline ignored"
else
    print_fail "END without newline ignored" "No shutdown" "Pipeline shutdown occurred"
fi

# Test EOF (no <END> at all)
printf "test line" | timeout 2s ./output/analyzer 10 logger >/dev/null 2>&1
if [ $? -eq 124 ]; then  # 124 is timeout exit code
    print_pass "EOF waits for END (timeout)"
else  
    print_fail "EOF handling" "Should wait for END" "Exited without END"
fi



# ====================================
# QUEUE MANAGEMENT
# ====================================

print_section "Queue Size and Stress Tests"

# Queue size 1
echo "a
b
c
<END>" | ./output/analyzer 1 logger 2>&1 | grep -q "Pipeline shutdown complete"
if [ $? -eq 0 ]; then
    print_pass "Queue size 1"
else
    print_fail "Queue size 1" "Pipeline shutdown complete" "Pipeline failed"
fi

# Queue overflow
seq 1 100 | sed '$a<END>' | ./output/analyzer 10 logger 2>&1 | grep -q "Pipeline shutdown complete"
if [ $? -eq 0 ]; then
    print_pass "Queue overflow handling"
else
    print_fail "Queue overflow handling" "Pipeline shutdown complete" "Pipeline failed"
fi

# Large queue
echo "<END>" | ./output/analyzer 100000 logger >/dev/null 2>&1
ACTUAL=$?
if [ $ACTUAL -eq 0 ] || [ $ACTUAL -eq 1 ] || [ $ACTUAL -eq 2 ]; then
    print_pass "Large queue allocation"
else
    print_fail "Large queue allocation" "Exit code 0, 1, or 2" "Exit code $ACTUAL"
fi

# 100 lines
OUTPUT=$(seq 1 100 | sed '$a<END>' | ./output/analyzer 50 logger 2>&1)
COUNT=$(echo "$OUTPUT" | grep -c "\[logger\] [0-9]")
if [ $COUNT -eq 100 ]; then
    print_pass "100 lines"
else
    print_fail "100 lines" "100 lines processed" "$COUNT lines processed"
fi



# ====================================
# CONCURRENT EXECUTION
# ====================================

print_section "Concurrent Execution Tests"

# Run 5 pipelines
PIDS=""
for i in 1 2 3 4 5; do
    (echo -e "test$i\n<END>" | ./output/analyzer 10 logger >/dev/null 2>&1) &
    PIDS="$PIDS $!"
done
FAILED_COUNT=0
for pid in $PIDS; do
    wait $pid || ((FAILED_COUNT++))
done
if [ $FAILED_COUNT -eq 0 ]; then
    print_pass "5 concurrent pipelines"
else
    print_fail "5 concurrent pipelines" "All 5 succeed" "$FAILED_COUNT failed"
fi

# stress - 20 pipelines with small queue
PIDS=""
for i in {1..20}; do
    (echo -e "test$i\n<END>" | ./output/analyzer 1 logger uppercaser >/dev/null 2>&1) &
    PIDS="$PIDS $!"
done
FAILED_COUNT=0
for pid in $PIDS; do
    wait $pid || ((FAILED_COUNT++))
done
if [ $FAILED_COUNT -eq 0 ]; then
    print_pass "20 concurrent pipelines with queue size 1"
else
    print_fail "Race condition stress test" "All succeed" "$FAILED_COUNT failed"
fi

# Rapid shutdown after start
(echo -e "test\n<END>" | ./output/analyzer 1 typewriter >/dev/null 2>&1) &
PID=$!
wait $PID
if [ $? -eq 0 ]; then
    print_pass "Rapid shutdown"
else
    print_fail "Rapid shutdown" "Process completes normally" "Process failed"
fi



# ====================================
# PLUGIN FLEXIBILITY
# ====================================

print_section "Fizi Dinami Versatilly Agressivi Project"

#Running from output dir
OUT=$(
  cd output && \
  printf "hi\n<END>\n" | ./analyzer 10 uppercaser logger 2>&1
)
if echo "$OUT" | grep -q "^\[logger\] HI$" && echo "$OUT" | grep -q "Pipeline shutdown complete"; then
  print_pass "Running from inside output "
else
  print_fail "Running from inside output" "[logger] HI + shutdown" "$OUT"
fi


# New Plugin Test
cat > plugins/lonaim.c << 'EOF'
#include "plugin_common.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

const char* lonaim_transform(const char* s) {
    if (!s) return NULL;
    
    // Ignore input, always return "LO NAIM..."
    char* result = strdup("LO NAIM...");
    if (!result) {
        fprintf(stderr, "ERROR: lonaim failed to allocate memory\n");
        exit(1);
    }
    return result;
}

const char* plugin_init(int qsize) {
    return common_plugin_init(lonaim_transform, "lonaim", qsize);
}
EOF

gcc -fPIC -shared -o output/lonaim.so \
    plugins/lonaim.c \
    plugins/plugin_common.c \
    plugins/sync/monitor.c \
    plugins/sync/consumer_producer.c \
    -ldl -lpthread 2>/dev/null

EXPECTED="[logger] LO NAIM..."
ACTUAL=$(echo -e "anything\n<END>" | ./output/analyzer 10 lonaim logger 2>/dev/null | grep "\[logger\]" || echo "NOTHING")
if [ "$ACTUAL" == "$EXPECTED" ]; then
    print_pass "New plugin"
else
    print_fail "New plugin" "$EXPECTED" "$ACTUAL"
fi

rm plugins/lonaim.c output/lonaim.so

# renamed plugin
cp output/uppercaser.so output/AniAyef.so
EXPECTED="[logger] TEN LI 100 LO ANI LO ATA"
ACTUAL=$(echo -e "ten li 100 lo ani lo ata\n<END>" | ./output/analyzer 10 AniAyef logger 2>/dev/null | grep "\[logger\]" || echo "NOTHING")
if [ "$ACTUAL" == "$EXPECTED" ]; then
    print_pass "Renamed plugin"
else
    print_fail "Renamed plugin" "$EXPECTED" "$ACTUAL"
fi
rm output/AniAyef.so




# ====================================
# SUMMARY
# ====================================

echo ""
echo "=============================="
if [ $FAILED -eq 0 ]; then
    echo -e " ${GREEN}  All TESTS PASSED!!1 XD${NC}"
    echo ""
    echo -e " ${YELLOW}        NO NERVOUS,${NC}"
    echo -e " ${YELLOW}   PASS PASS ITS A COME${NC}"
    echo "=============================="
    echo ""
    exit 0
else
    echo -e "${RED}Some tests failed. Check expected vs actual output above.${NC}"
    echo "=============================="
    echo ""
    exit 1
fi