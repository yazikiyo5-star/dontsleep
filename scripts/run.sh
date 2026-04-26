#!/bin/bash
# Build and run the DontSleep prototype.
# Usage: ./scripts/run.sh
set -e
cd "$(dirname "$0")/.."
swift build -c release
.build/release/DontSleep
