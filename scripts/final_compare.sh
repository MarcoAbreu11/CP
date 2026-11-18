#!/bin/bash
#SBATCH -A f202500010hpcvlabuminhoa
#SBATCH -p normal-arm
#SBATCH -t 15:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=48
#SBATCH --output=results/%x.o%j
#SBATCH --error=results/%x.e%j
# Uso: sbatch -J <job> scripts/final_compare.sh <fonte.cpp> <nome> "<flags>" <reps> "<threads:schedule ...>"
# Corre os candidatos intercalados (A B C … A B C …) no mesmo nó; calcula média, desvio, mediana, mín., máx.
SRC=$1; NAME=$2; FLAGS=$3; REPS=$4; CONFIGS=$5

ml GCC/15.2.0
OUT=results/final_$NAME; W=tmp_final_$NAME
mkdir -p $OUT $W
sed -E 's/schedule\([^)]*\)/schedule(runtime)/' $SRC > $W/md_rt.cpp
grep -q 'schedule(runtime)' $W/md_rt.cpp || { echo "ERRO: schedule(...) não encontrado"; exit 1; }
gcc $FLAGS -fopenmp $W/md_rt.cpp -lm -o $W/md
cd $W
echo "nó: $(hostname)  flags: $FLAGS  reps: $REPS" > ../$OUT/config.txt

TIMEFORMAT=%R
echo "config;rep;tempo_s" > ../$OUT/raw.csv
for rep in $(seq 1 $REPS); do
  for c in $CONFIGS; do
    export OMP_NUM_THREADS=${c%%:*} OMP_SCHEDULE=${c#*:}
    T=$( { time ./md < ../inputdata.txt > /dev/null; } 2>&1 )
    echo "$c;$rep;$T" >> ../$OUT/raw.csv
  done
done

# Estatísticas por candidato (valores ordenados → mín., mediana, máx.)
tail -n +2 ../$OUT/raw.csv | sort -t';' -k1,1 -k3,3n | awk -F';' '
{ c=$1; k=++n[c]; v[c,k]=$3; s[c]+=$3; ss[c]+=$3*$3 }
END { print "config;n;media;desvio;mediana;min;max"
  for (c in n) { k=n[c]; m=s[c]/k; sd=sqrt((ss[c]-k*m*m)/(k-1))
    med=(k%2) ? v[c,(k+1)/2] : (v[c,k/2]+v[c,k/2+1])/2
    printf "%s;%d;%.4f;%.4f;%.4f;%.4f;%.4f\n", c, k, m, sd, med, v[c,1], v[c,k] } }' \
  | sort -t';' -k5,5n > ../$OUT/stats.csv
