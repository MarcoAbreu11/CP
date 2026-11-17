#!/bin/bash
#SBATCH -A f202500010hpcvlabuminhoa
#SBATCH -p normal-arm
#SBATCH -t 15:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=48
#SBATCH --output=results/%x.o%j
#SBATCH --error=results/%x.e%j
# Uso: sbatch -J <job> scripts/validate_threads.sh <fonte.cpp> <nome> "<flags>"
SRC=$1; NAME=$2; FLAGS=$3

ml GCC/15.2.0
OUT=results/validate_$NAME; W=tmp_val_$NAME
mkdir -p $OUT $W
sed 's/N = 5000;/N = 200;/' $SRC > $W/MD_N200.cpp
grep -q "N = 200;" $W/MD_N200.cpp || { echo "ERRO: 'N = 5000;' não encontrado"; exit 1; }
gcc $FLAGS -fopenmp $W/MD_N200.cpp -lm -o $W/md_omp    # com OpenMP
gcc $FLAGS          $W/MD_N200.cpp -lm -o $W/md_seq    # sem -fopenmp: diretivas ignoradas
cd $W

echo "versao,threads,repeticao,T,KE,PE,Etot,resultado" > ../$OUT/summary.csv
corre () {   # $1=binário  $2=etiqueta  $3=threads  $4=repetição
  export OMP_NUM_THREADS=$3
  ./$1 < ../inputdata.txt > /dev/null
  D=../$OUT/$2_t$3_r$4; mkdir -p $D; mv cp_output.txt cp_average.txt $D/
  ../scripts/compare.sh ../reference/n200 $D > $D/valid.txt
  linha="$2,$3,$4"
  for g in T KE PE Etot; do
    linha="$linha,$(awk -v g=$g '$1=="cp_output" && $2==g {print $6}' $D/valid.txt)"
  done
  echo "$linha,$(awk '/RESULTADO/{print $2}' $D/valid.txt)" >> ../$OUT/summary.csv
}

corre md_seq sem_omp 1 1
for t in 1 2 4 8 16 32 48; do
  for rep in 1 2 3; do corre md_omp omp $t $rep; done
done

# Sem -fopenmp deve ser igual à seq_opt (mesmas flags)
../scripts/compare.sh ../results/c/n200 ../$OUT/sem_omp_t1_r1 > ../$OUT/sem_omp_vs_seqopt.txt
