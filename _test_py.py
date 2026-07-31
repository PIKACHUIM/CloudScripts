#!/usr/bin/env python3
import sys, unicodedata
s = sys.argv[1] if len(sys.argv) > 1 else ''
print("input:", repr(s))
print("len chars:", len(s))
w = sum(2 if unicodedata.east_asian_width(c) in ('W', 'F') else 1 for c in s)
print("width:", w)
