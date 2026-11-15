#!/bin/bash
#SBATCH -A f202500010hpcvlabuminhoa
#SBATCH -p normal-arm
#SBATCH -t 1:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=48
#SBATCH --output=results/base_a_1x.o%j
#SBATCH --error=results/base_a_1x.e%j

ml GCC/15.2.0
mkdir -p results/a tmp_a && cd tmp_a
gcc -O3 -ffast-math ../src/MD.cpp -lm -o md_a
time ./md_a < ../inputdata.txt > /dev/null
mv cp_output.txt cp_average.txt ../results/a/
