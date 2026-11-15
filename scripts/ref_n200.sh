#!/bin/bash
#SBATCH -A f202500010hpcvlabuminhoa
#SBATCH -p normal-arm
#SBATCH -t 10:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=48
#SBATCH --output=results/ref_n200.o%j
#SBATCH --error=results/ref_n200.e%j

ml GCC/15.2.0
mkdir -p reference/n200 tmp_n200 && cd tmp_n200
gcc -O2 ../tools/MD_N200.cpp -lm -o md_ref200
./md_ref200 < ../inputdata.txt > ../reference/n200/stdout.txt
mv cp_output.txt cp_average.txt ../reference/n200/
