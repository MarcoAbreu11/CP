#!/bin/bash
#SBATCH -A f202500010hpcvlabuminhoa
#SBATCH -p normal-arm
#SBATCH -t 20:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=48
#SBATCH --output=results/%x.o%j
#SBATCH --error=results/%x.e%j
# Uso: sbatch -J makerun scripts/make_run.sh   (usa src/, Makefile e inputdata.txt atuais)
ml GCC/15.2.0
OUT=results/make_run; W=tmp_makerun
rm -rf $W $OUT; mkdir -p $W $OUT
cp -r src Makefile inputdata.txt $W/
cd $W
echo "Ambiente do job: OMP_NUM_THREADS=${OMP_NUM_THREADS:-não definido} OMP_PROC_BIND=${OMP_PROC_BIND:-não definido} OMP_PLACES=${OMP_PLACES:-não definido}" > ../$OUT/info.txt
unset OMP_NUM_THREADS                 # para o Makefile usar o seu valor (?=)
make clean > /dev/null 2>&1
make > ../$OUT/build.txt 2>&1
TIMEFORMAT=%R
for k in 1 2 3 4 5 6 7 8 9 10; do
  { time make run > /dev/null 2>&1; } 2>> ../$OUT/tempos.txt
done
mkdir -p ../$OUT/out && mv cp_output.txt cp_average.txt ../$OUT/out/
../scripts/compare.sh ../reference/full ../$OUT/out > ../$OUT/valid.txt
