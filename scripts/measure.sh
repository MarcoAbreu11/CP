#!/bin/bash
#SBATCH -A f202500010hpcvlabuminhoa
#SBATCH -p normal-arm
#SBATCH -t 45:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=48
#SBATCH --output=results/%x.o%j
#SBATCH --error=results/%x.e%j
# Uso: sbatch -J <job> scripts/measure.sh <fonte.cpp> <nome> "<flags>" [threads]
SRC=$1; NAME=$2; FLAGS=$3; THREADS=${4:-1}

ml GCC/15.2.0
OUT=results/$NAME; W=tmp_$NAME
mkdir -p $OUT/n200 $OUT/n5000 $W
echo "fonte=$SRC flags=$FLAGS threads=$THREADS" > $OUT/config.txt

# Variante N=200 (procura o texto, não o número da linha)
sed 's/N = 5000;/N = 200;/' $SRC > $W/MD_N200.cpp
grep -q "N = 200;" $W/MD_N200.cpp || { echo "ERRO: 'N = 5000;' não encontrado em $SRC"; exit 1; }

gcc $FLAGS $SRC -lm -o $W/md
gcc $FLAGS $W/MD_N200.cpp -lm -o $W/md200
export OMP_NUM_THREADS=$THREADS
cd $W

# 1) Validação rápida N=200
./md200 < ../inputdata.txt > /dev/null
mv cp_output.txt cp_average.txt ../$OUT/n200/
../scripts/compare.sh ../reference/n200 ../$OUT/n200 > ../$OUT/valid_n200.txt

# 2) Medição N=5000 (5 repetições) + validação da última execução
perf stat -r 5 sh -c './md < ../inputdata.txt > /dev/null' 2> ../$OUT/perf.txt
mv cp_output.txt cp_average.txt ../$OUT/n5000/
../scripts/compare.sh ../reference/full ../$OUT/n5000 > ../$OUT/valid_n5000.txt
