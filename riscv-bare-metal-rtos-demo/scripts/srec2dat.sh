#!/bin/bash

/usr/bin/python3 scripts/srec_to_dat.py ./build/img/firmware.srec -o ./build/img/code_and_data.dat -b 0x80000000 -s 0x7fff0 -f
