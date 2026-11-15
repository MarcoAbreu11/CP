#!/bin/bash
#SBATCH -A f202500010hpcvlabuminhoa
#SBATCH -p normal-arm
#SBATCH -t 30:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=48
#SBATCH --output=results/ref.o%j
#SBATCH --error=results/ref.e%j

ml GCC/15.2.0
mkdir -p reference/full reference/n200 results/a

# 1) Referência de correção: original, -O2, sem fast-math
gcc -O2 src/MD.cpp -lm -o md_ref
./md_ref < inputdata.txt > reference/full/stdout.txt
mv cp_output.txt cp_average.txt reference/full/

# 2) Referência N=200
gcc -O2 tools/MD_N200.cpp -lm -o md_ref200
./md_ref200 < inputdata.txt > reference/n200/stdout.txt
mv cp_output.txt cp_average.txt reference/n200/

# 3) Baseline (a): flags do Makefile fornecido, 5 repetições
gcc -O3 -ffast-math src/MD.cpp -lm -o md_a
perf stat -r 5 sh -c './md_a < inputdata.txt > /dev/null' 2> results/perf_a.txt
mv cp_output.txt cp_average.txt results/a/