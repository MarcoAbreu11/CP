#!/bin/bash
#SBATCH -A f202500010hpcvlabuminhoa
#SBATCH -p normal-arm
#SBATCH -t 1:30:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=48
#SBATCH --output=results/%x.o%j
#SBATCH --error=results/%x.e%j
# Uso: sbatch -J <job> scripts/scaling.sh <fonte.cpp> <nome> "<flags>" ["lista de threads"] [repetições]
SRC=$1; NAME=$2; FLAGS=$3
TLIST=${4:-"1 2 4 8 12 16 24 32 48"}; REPS=${5:-3}

ml GCC/15.2.0
OUT=results/scaling_$NAME; W=tmp_scal_$NAME
mkdir -p $OUT $W
echo "fonte=$SRC flags=$FLAGS threads=$TLIST reps=$REPS" > $OUT/config.txt
gcc $FLAGS -fopenmp $SRC -lm -o $W/md
cd $W

echo "versao,threads,tempo_s,erro_s,validacao" > ../$OUT/scaling.csv
for t in $TLIST; do
  export OMP_NUM_THREADS=$t
  perf stat -r $REPS sh -c './md < ../inputdata.txt > /dev/null' 2> ../$OUT/perf_t$t.txt
  mkdir -p ../$OUT/t$t && mv cp_output.txt cp_average.txt ../$OUT/t$t/
  if ../scripts/compare.sh ../reference/full ../$OUT/t$t > ../$OUT/valid_t$t.txt; then V=OK; else V=FALHA; fi
  read T E <<< "$(grep 'time elapsed' ../$OUT/perf_t$t.txt | awk '{print $1, $3}')"
  echo "$NAME,$t,$T,$E,$V" >> ../$OUT/scaling.csv
done

# Resumo: speedup e eficiência face a 1 thread (1.ª linha de dados)
awk -F, 'NR==2{t1=$3} NR>1{printf "%3s threads  T=%8.2f s  S=%6.2f  E=%5.2f  %s\n",$2,$3,t1/$3,t1/$3/$2,$5}' \
  ../$OUT/scaling.csv > ../$OUT/resumo.txt
