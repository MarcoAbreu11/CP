#!/bin/bash
#SBATCH -A f202500010hpcvlabuminhoa
#SBATCH -p normal-arm
#SBATCH -t 1:30:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=48
#SBATCH --output=results/ref_full.o%j
#SBATCH --error=results/ref_full.e%j

ml GCC/15.2.0
mkdir -p reference/full tmp_full && cd tmp_full
gcc -O2 ../src/MD.cpp -lm -o md_ref
time ./md_ref < ../inputdata.txt > ../reference/full/stdout.txt
mv cp_output.txt cp_average.txt ../reference/full/
