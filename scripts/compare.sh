#!/bin/bash
# Uso: scripts/compare.sh <pasta_referencia> <pasta_teste>
# Compara cp_output.txt (por passo) e cp_average.txt (médias). Saída: 0 = OK, 1 = FALHA.
REF=$1; TST=$2
TOL=1e-6      # T, KE, PE, Etot por passo; T médio
TOLP=1e-4     # P médio, PV/nT e Z (dependem da pressão)

# 1) cp_output.txt: erro relativo máximo por coluna, ao longo dos 201 passos
paste "$REF/cp_output.txt" "$TST/cp_output.txt" | awk -v tol=$TOL '
NR>1 { n++
  for(c=2;c<=6;c++){ a=$c; b=$(c+6); d=a-b; if(d<0)d=-d; s=(a<0?-a:a); r=(s>0)?d/s:d; if(r>m[c])m[c]=r } }
END { split("T P KE PE Etot",nm," "); fail=0
  for(c=2;c<=6;c++){ st="OK"
    if(c==3) st="(informativo)"; else if(m[c]>tol){ st="FALHA"; fail=1 }
    printf "cp_output   %-5s max rel = %.3e   %s\n", nm[c-1], m[c], st }
  if(n!=201){ printf "cp_output   número de passos = %d (esperado 201)   FALHA\n", n; fail=1 }
  exit fail }'
F1=$?

# 2) cp_average.txt: linha 3 (valores)
paste <(sed -n 3p "$REF/cp_average.txt") <(sed -n 3p "$TST/cp_average.txt") | awk -v tol=$TOL -v tolp=$TOLP '
{ split("tempo T P PV/nT Z",nm," "); fail=0
  for(c=2;c<=5;c++){ a=$c; b=$(c+7); d=a-b; if(d<0)d=-d; s=(a<0?-a:a); r=(s>0)?d/s:d
    t=(c==2)?tol:tolp; st=(r<=t)?"OK":"FALHA"; if(r>t)fail=1
    printf "cp_average  %-5s rel = %.3e   (tol %.0e)   %s\n", nm[c], r, t, st }
  exit fail }'
F2=$?

if [ $F1 -eq 0 ] && [ $F2 -eq 0 ]; then echo "RESULTADO: OK"; exit 0
else echo "RESULTADO: FALHA"; exit 1; fi
