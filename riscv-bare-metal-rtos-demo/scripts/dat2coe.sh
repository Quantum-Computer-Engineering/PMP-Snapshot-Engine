#!/bin/bash

echo -e "memory_initialization_radix=16;\nmemory_initialization_vector=" > ./build/img/code_and_data.coe128

input="./build/img/code_and_data.dat"
while IFS= read -r line
do
  echo "$line," >> ./build/img/code_and_data.coe128
done < "$input"


# For BRAM only SoC
/usr/bin/python3 scripts/coe128_to_coe32.py 
