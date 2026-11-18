#!/bin/bash
#SBATCH -A f202500010hpcvlabuminhoa
#SBATCH -p normal-arm
#SBATCH -t 15:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=48
#SBATCH --output=results/%x.o%j
#SBATCH --error=results/%x.e%j
# Uso: sbatch -J <job> scripts/affinity_compare.sh <fonte.cpp> <nome> "<flags>" <reps> "<threads:bind ...>"
# bind = none | close | spread  (com OMP_PLACES=cores). Candidatos intercalados no mesmo nó.
SRC=$1; NAME=$2; FLAGS=$3; REPS=$4; CONFIGS=$5

ml GCC/15.2.0
OUT=results/affinity_$NAME; W=tmp_aff_$NAME
rm -rf $OUT $W; mkdir -p $OUT $W
gcc $FLAGS -fopenmp $SRC -lm -o $W/md
cd $W
echo "nó: $(hostname)  flags: $FLAGS  reps: $REPS" > ../$OUT/config.txt

aplica () {   # $1 = threads:bind
  export OMP_NUM_THREADS=${1%%:*}
  local b=${1#*:}
  if [ "$b" = "none" ]; then unset OMP_PROC_BIND OMP_PLACES
  else export OMP_PROC_BIND=$b OMP_PLACES=cores; fi
}

# 1) Tempos, intercalados
TIMEFORMAT=%R
echo "config;rep;tempo_s" > ../$OUT/raw.csv
for rep in $(seq 1 $REPS); do
  for c in $CONFIGS; do
    aplica $c
    T=$( { time ./md < ../inputdata.txt > /dev/null; } 2>&1 )
    echo "$c;$rep;$T" >> ../$OUT/raw.csv
  done
done

# 2) Migrações de core e trocas de contexto (1 execução por candidato) + validação
echo "config;cpu_migrations;context_switches;validacao" > ../$OUT/migracoes.csv
for c in $CONFIGS; do
  aplica $c
  perf stat -e cpu-migrations,context-switches -o ../$OUT/perf_${c/:/_}.txt ./md < ../inputdata.txt > /dev/null
  mkdir -p ../$OUT/${c/:/_} && mv cp_output.txt cp_average.txt ../$OUT/${c/:/_}/
  if ../scripts/compare.sh ../reference/full ../$OUT/${c/:/_} > /dev/null; then V=OK; else V=FALHA; fi
  M=$(awk '/cpu-migrations/{gsub(",","",$1); print $1}' ../$OUT/perf_${c/:/_}.txt)
  S=$(awk '/context-switches/{gsub(",","",$1); print $1}' ../$OUT/perf_${c/:/_}.txt)
  echo "$c;$M;$S;$V" >> ../$OUT/migracoes.csv
done

# 3) Estatísticas por candidato (ordenadas pela mediana)
tail -n +2 ../$OUT/raw.csv | sort -t';' -k1,1 -k3,3n | awk -F';' '
{ c=$1; k=++n[c]; v[c,k]=$3; s[c]+=$3; ss[c]+=$3*$3; if ($3 > 0.85) l[c]++ }
END { print "config;n;media;desvio;mediana;min;max;acima_0.85"
  for (c in n) { k=n[c]; m=s[c]/k; sd=sqrt((ss[c]-k*m*m)/(k-1))
    med=(k%2) ? v[c,(k+1)/2] : (v[c,k/2]+v[c,k/2+1])/2
    printf "%s;%d;%.4f;%.4f;%.4f;%.4f;%.4f;%d\n", c, k, m, sd, med, v[c,1], v[c,k], l[c]+0 } }' \
  | sort -t';' -k5,5n > ../$OUT/stats.csv
