#!/bin/bash
#SBATCH -A f202500010hpcvlabuminhoa
#SBATCH -p normal-arm
#SBATCH -t 15:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=48
#SBATCH --output=results/smoke.o%j
#SBATCH --error=results/smoke.e%j

ml GCC/15.2.0
lscpu > results/lscpu.txt
gcc --version | head -1 > results/gcc_version.txt
{ which perf; ml av Score-P; } > results/tools.txt 2>&1

make clean && make
export OMP_NUM_THREADS=1
time ./md < inputdata.txt > results/smoke_stdout.txt