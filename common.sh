#!/usr/bin/env bash

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log_done() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [Done ] $1"
}

fail() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [Error] $1"
    exit 1
}
