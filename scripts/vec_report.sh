#!/bin/bash
#SBATCH -A f202500010hpcvlabuminhoa
#SBATCH -p normal-arm
#SBATCH -t 5:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=48
#SBATCH --output=results/%x.o%j
#SBATCH --error=results/%x.e%j
# Uso: sbatch -J <job> scripts/vec_report.sh <fonte.cpp> <nome>
SRC=$1; NAME=$2

ml GCC/15.2.0
OUT=profiling/vec_$NAME; mkdir -p $OUT
gcc -O3 -ffast-math -fopenmp \
    -fopt-info-vec-optimized=$OUT/ok_base.txt -fopt-info-vec-missed=$OUT/missed_base.txt \
    $SRC -lm -o $OUT/md_base
gcc -O3 -ffast-math -march=native -fopenmp \
    -fopt-info-vec-optimized=$OUT/ok_native.txt -fopt-info-vec-missed=$OUT/missed_native.txt \
    $SRC -lm -o $OUT/md_native
rm -f $OUT/md_base $OUT/md_native
