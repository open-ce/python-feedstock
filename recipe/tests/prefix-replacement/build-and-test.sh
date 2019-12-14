#!/usr/bin/env bash

${CC} a.c $(python3-config --cflags) $(python3-config --ldflags)
./a.out
