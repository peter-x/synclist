#!/bin/sh

mkdir js 2>/dev/null
mkdir test/spec 2>/dev/null

coffee -w -c -o js/ -- src/ &
coffee -w -c -o test/spec/ -- test/src/ &
