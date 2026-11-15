#!/bin/bash
#SBATCH -A f202500010hpcvlabuminhoa
#SBATCH -p normal-arm
#SBATCH -t 20:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=48
#SBATCH --output=results/prof_scorep.o%j
#SBATCH --error=results/prof_scorep.e%j

ml purge
ml Score-P                    # carrega o seu próprio GCC: serve para profiling, não para medir tempos
OUT=../profiling/scorep
mkdir -p tmp_scorep && cd tmp_scorep

scorep gcc -O3 -ffast-math ../tools/MD_N200.cpp -lm -o md200_sp
export SCOREP_EXPERIMENT_DIRECTORY=scorep_n200
./md200_sp < ../inputdata.txt > /dev/null
scorep-score -r scorep_n200/profile.cubex > $OUT/score_n200.txt 2>&1

scorep gcc -O3 -ffast-math ../src/MD.cpp -lm -o md5000_sp
export SCOREP_EXPERIMENT_DIRECTORY=scorep_n5000
./md5000_sp < ../inputdata.txt > /dev/null
scorep-score -r scorep_n5000/profile.cubex > $OUT/score_n5000.txt 2>&1
