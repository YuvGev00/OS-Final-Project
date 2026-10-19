# Text Processing Pipeline with Dynamic Plugins

[![build](https://github.com/YuvGev00/OS-Final-Project/actions/workflows/build.yml/badge.svg)](https://github.com/YuvGev00/OS-Final-Project/actions/workflows/build.yml)

## Overview
A modular text processing system that chains plugins together to transform input text. Each plugin runs in its own thread with a bounded queue, and the entire pipeline is dynamically configurable at runtime using shared libraries (.so files).

## Features
- **Dynamic Plugin Loading**: Load plugins at runtime using `dlopen`/`dlsym`
- **Multi-threaded Processing**: Each plugin runs in its own thread
- **Producer-Consumer Pattern**: Thread-safe queues with configurable capacity
- **Plugin Chaining**: Connect plugins in sequence to create processing pipelines
- **Graceful Shutdown**: Proper cleanup and resource management

## Available Plugins
- **logger** - Logs all strings that pass through
- **typewriter** - Simulates typewriter effect with delays
- **uppercaser** - Converts strings to uppercase
- **rotator** - Moves every character to the right (last character moves to beginning)
- **flipper** - Reverses the order of characters
- **expander** - Expands each character with spaces

## Building
```bash
make          # or: ./build.sh
```
This compiles the main analyzer program and all plugins as shared libraries into `output/`.
Targets Linux (glibc, pthreads, `dlopen`); `make test` builds and runs the test suite.

## Usage
```bash
./output/analyzer <queue_size> <plugin1> <plugin2> ... <pluginN>
```

### Parameters
- `queue_size`: Maximum number of items in each plugin's queue
- `plugin1..N`: Names of plugins to load (without .so extension)

### Examples
```bash
# Single plugin
echo 'hello world' | ./output/analyzer 20 uppercaser
echo '<END>' | ./output/analyzer 20 uppercaser

# Plugin chain: uppercase -> rotate -> log
echo 'hello' | ./output/analyzer 20 uppercaser rotator logger
echo '<END>' | ./output/analyzer 20 uppercaser rotator logger

# Complex chain
echo 'test' | ./output/analyzer 10 flipper uppercaser expander logger
echo '<END>' | ./output/analyzer 10 flipper uppercaser expander logger
```

### Input Termination
Send `<END>` to gracefully terminate the pipeline.

## Testing
```bash
./test.sh
```
Runs comprehensive tests including individual plugins and chain combinations.

## Architecture
- **Main Program**: Loads plugins, creates pipeline, processes input
- **Plugin Interface**: Standardized API (init, fini, place_work, attach, wait_finished)
- **Thread Safety**: Mutex-protected queues with condition variables
- **Memory Management**: Proper cleanup with error handling

