#!/bin/bash
#SBATCH -A f202500010hpcvlabuminhoa
#SBATCH -p normal-arm
#SBATCH -t 1:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=48
#SBATCH --output=results/%x.o%j
#SBATCH --error=results/%x.e%j
# Uso: sbatch -J <job> scripts/scaling.sh <fonte.cpp> <nome> "<flags>" ["threads"] [repetições]
SRC=$1; NAME=$2; FLAGS=$3
TLIST=${4:-"1 2 4 8 12 16 24 32 48"}; REPS=${5:-3}

ml GCC/15.2.0
OUT=results/scaling_$NAME; W=tmp_scal_$NAME
mkdir -p $OUT $W
echo "fonte=$SRC flags=$FLAGS -fopenmp threads=$TLIST reps=$REPS" > $OUT/config.txt
gcc $FLAGS -fopenmp $SRC -lm -o $W/md
cd $W

echo "versao,threads,tempo_s,erro_s,instrucoes,ciclos,validacao" > ../$OUT/scaling.csv
for t in $TLIST; do
  export OMP_NUM_THREADS=$t
  P=../$OUT/perf_t$t.txt
  perf stat -r $REPS sh -c './md < ../inputdata.txt > /dev/null' 2> $P
  mkdir -p ../$OUT/t$t && mv cp_output.txt cp_average.txt ../$OUT/t$t/
  if ../scripts/compare.sh ../reference/full ../$OUT/t$t > ../$OUT/valid_t$t.txt; then V=OK; else V=FALHA; fi
  T=$(awk '/time elapsed/{print $1}' $P)
  E=$(awk '/time elapsed/{print $3}' $P)
  I=$(awk '$2=="instructions"{gsub(",","",$1); print $1}' $P)
  C=$(awk '$2=="cycles"{gsub(",","",$1); print $1}' $P)
  echo "$NAME,$t,$T,$E,$I,$C,$V" >> ../$OUT/scaling.csv
done

# Resumo: S(p) = T(1)/T(p), E(p) = S(p)/p, I(p)/I(1)
awk -F, 'NR==2{t1=$3; i1=$5}
  NR>1{printf "%3s threads  T=%8.3f s  S=%6.2f  E=%5.2f  I/I1=%5.2f  %s\n",$2,$3,t1/$3,t1/$3/$2,$5/i1,$7}' \
  ../$OUT/scaling.csv > ../$OUT/resumo.txt
