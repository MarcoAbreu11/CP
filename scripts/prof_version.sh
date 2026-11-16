#!/bin/bash
#SBATCH -A f202500010hpcvlabuminhoa
#SBATCH -p normal-arm
#SBATCH -t 20:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=48
#SBATCH --output=results/%x.o%j
#SBATCH --error=results/%x.e%j
# Uso: sbatch -J <job> scripts/prof_version.sh <fonte.cpp> <nome> "<flags>"
SRC=$1; NAME=$2; FLAGS=$3

ml GCC/15.2.0
OUT=profiling/$NAME; W=tmp_prof_$NAME
mkdir -p $OUT $W
gcc $FLAGS -g -fno-omit-frame-pointer $SRC -lm -o $W/md
cd $W
perf record -g -F 1000 -o perf.data ./md < ../inputdata.txt > /dev/null
perf report -i perf.data -n --stdio --no-children -g none --sort dso,symbol > ../$OUT/flat.txt 2>&1
for s in computeAccelerations VelocityVerlet main; do
  perf annotate -i perf.data --stdio $s > ../$OUT/annotate_$s.txt 2>&1
done
