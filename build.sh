#!/bin/sh

coffee -w -c -o js/ -- src/ &
coffee -w -c -o test/spec/ -- test/src/ &
