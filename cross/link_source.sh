#!/bin/sh

exec ln "$CROSS_SOURCES/$(basename "$1")" "$1"
