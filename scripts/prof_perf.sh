#!/bin/bash
#SBATCH -A f202500010hpcvlabuminhoa
#SBATCH -p normal-arm
#SBATCH -t 25:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=48
#SBATCH --output=results/prof_perf.o%j
#SBATCH --error=results/prof_perf.e%j

ml GCC/15.2.0
OUT=../profiling/perf
mkdir -p tmp_prof && cd tmp_prof
FL="-O3 -ffast-math -g -fno-omit-frame-pointer"     # flags da baseline (a) + flags de profiling

# Binários
gcc $FL ../tools/MD_N200.cpp -lm -o md200                  # (a), N=200
gcc $FL -fno-inline ../tools/MD_N200.cpp -lm -o md200_ni   # (a) sem inlining, N=200
gcc -O2 -g -fno-omit-frame-pointer ../tools/MD_N200.cpp -lm -o md200_O2   # ref -O2, N=200
gcc $FL ../src/MD.cpp -lm -o md5000                        # (a), N=5000

prof () {   # $1=binário  $2=nome  $3=frequência
  perf record -g -F $3 -o perf_$2.data ./$1 < ../inputdata.txt > /dev/null
  perf report -i perf_$2.data -n --stdio --no-children -g none --sort dso,symbol > $OUT/flat_$2.txt 2>&1
  perf report -i perf_$2.data -n --stdio --no-children > $OUT/callgraph_$2.txt 2>&1
}
prof md200    n200     4000
prof md200_ni n200_ni  4000
prof md200_O2 n200_O2  4000
prof md5000   n5000    1000

for s in main Potential computeAccelerations VelocityVerlet; do
  perf annotate -i perf_n5000.data --stdio $s > $OUT/annotate_n5000_$s.txt 2>&1
done
