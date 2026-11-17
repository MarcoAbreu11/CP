#!/bin/bash
#SBATCH -A f202500010hpcvlabuminhoa
#SBATCH -p normal-arm
#SBATCH -t 20:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=48
#SBATCH --output=results/%x.o%j
#SBATCH --error=results/%x.e%j
# Uso: sbatch -J <job> scripts/prof_omp.sh <fonte.cpp> <nome> "<flags>" <threads>
SRC=$1; NAME=$2; FLAGS=$3; THREADS=$4

ml GCC/15.2.0
OUT=profiling/${NAME}_t$THREADS; W=tmp_profomp_$NAME
mkdir -p $OUT $W
gcc $FLAGS -fopenmp -g -fno-omit-frame-pointer $SRC -lm -o $W/md
cd $W
export OMP_NUM_THREADS=$THREADS
perf record -g -F 1000 -o perf.data ./md < ../inputdata.txt > /dev/null
perf report -i perf.data -n --stdio --no-children -g none --sort dso,symbol > ../$OUT/flat.txt 2>&1
perf report -i perf.data -n --stdio --no-children -g none --sort tid,symbol --percent-limit 0.05 > ../$OUT/by_thread.txt 2>&1
