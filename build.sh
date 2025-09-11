#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' 

print_status()
{
    echo -e "${GREEN}[BUILD]${NC} $1"
}

print_error()
{
    echo -e "${RED}[ERROR]${NC} $1"
}

mkdir -p output
gcc -o output/analyzer main.c -ldl -lpthread

# the build script :
# goes over all the .c files (plugins except common.c) in the plugins dir
# then compiles them (each one with common) to output dir.
# this way there is no need for maintenance when adding new plugins.

for plugin_file in plugins/*.c; do
    [ -e "$plugin_file" ] || continue
    
    if [[ "$plugin_file" == "plugins/plugin_common.c" ]]; then
        continue
    fi
    
    plugin_name=$(basename "$plugin_file" .c)
    
    print_status "Building plugin: $plugin_name"
    
    gcc -fPIC -shared -o output/${plugin_name}.so \
        "$plugin_file" \
        plugins/plugin_common.c \
        plugins/sync/monitor.c \
        plugins/sync/consumer_producer.c \
        -ldl -lpthread || {
        print_error "Failed to build $plugin_name"
        exit 1
    }
done


print_status "Build complete"