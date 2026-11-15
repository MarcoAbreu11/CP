#!/bin/bash
#SBATCH -A f202500010hpcvlabuminhoa
#SBATCH -p normal-arm
#SBATCH -t 15:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=48
#SBATCH --output=results/scale_n.o%j
#SBATCH --error=results/scale_n.e%j

ml GCC/15.2.0
mkdir -p tmp_scale && cd tmp_scale
for n in 200 1000 2000; do
  sed "214s/N = 5000;/N = $n;/" ../src/MD.cpp > MD_$n.cpp
  gcc -O3 -ffast-math MD_$n.cpp -lm -o md_$n
  perf stat -r 3 sh -c "./md_$n < ../inputdata.txt > /dev/null" 2> ../profiling/scaleN/perf_N$n.txt
done
