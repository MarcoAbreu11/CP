#!/bin/bash
#SBATCH -A f202500010hpcvlabuminhoa
#SBATCH -p normal-arm
#SBATCH -t 40:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=48
#SBATCH --output=results/base_a_5x.o%j
#SBATCH --error=results/base_a_5x.e%j

ml GCC/15.2.0
mkdir -p tmp_a5 && cd tmp_a5
gcc -O3 -ffast-math ../src/MD.cpp -lm -o md_a
perf stat -r 5 sh -c './md_a < ../inputdata.txt > /dev/null' 2> ../results/perf_a.txt
