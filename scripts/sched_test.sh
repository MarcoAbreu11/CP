#!/bin/bash
#SBATCH -A f202500010hpcvlabuminhoa
#SBATCH -p normal-arm
#SBATCH -t 30:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=48
#SBATCH --output=results/%x.o%j
#SBATCH --error=results/%x.e%j
# Uso: sbatch -J <job> scripts/sched_test.sh <fonte.cpp> <nome> "<flags>"
# Diagnóstico (não é código para entrega): schedule(static) -> schedule(runtime),
# para testar vários escalonamentos com OMP_SCHEDULE sem recompilar.
SRC=$1; NAME=$2; FLAGS=$3

ml GCC/15.2.0
OUT=results/sched_$NAME; W=tmp_sched_$NAME
mkdir -p $OUT $W
sed 's/schedule(static)/schedule(runtime)/' $SRC > $W/md_rt.cpp
grep -q 'schedule(runtime)' $W/md_rt.cpp || { echo "ERRO: schedule(static) não encontrado"; exit 1; }
gcc $FLAGS -fopenmp $W/md_rt.cpp -lm -o $W/md
cd $W

echo "threads,schedule,tempo_s,erro_s,validacao" > ../$OUT/sched.csv
for t in 12 48; do
  for s in "static" "static,1" "dynamic,1" "dynamic,16" "guided"; do
    export OMP_NUM_THREADS=$t OMP_SCHEDULE="$s"
    tag=t${t}_${s//,/_}
    P=../$OUT/perf_$tag.txt
    perf stat -r 3 sh -c './md < ../inputdata.txt > /dev/null' 2> $P
    mkdir -p ../$OUT/$tag && mv cp_output.txt cp_average.txt ../$OUT/$tag/
    if ../scripts/compare.sh ../reference/full ../$OUT/$tag > ../$OUT/valid_$tag.txt; then V=OK; else V=FALHA; fi
    echo "$t,\"$s\",$(awk '/time elapsed/{print $1}' $P),$(awk '/time elapsed/{print $3}' $P),$V" >> ../$OUT/sched.csv
  done
done
