#!/usr/bin/env python3

import os
import time

INPUT_PATH = "data/input.txt"
OFFSET = 500
READ_SIZE = 300 * 1024 * 1024

fd = os.open(INPUT_PATH, os.O_RDONLY)

try:
    os.lseek(fd, OFFSET, os.SEEK_SET)
    data = os.read(fd, READ_SIZE)
finally:
    os.close(fd)

print(f"Read {len(data)} bytes from offset {OFFSET}")
time.sleep(45)
