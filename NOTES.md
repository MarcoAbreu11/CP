# CP — WA Fase 1 · Notas do projeto

Grupo: Marco António, pg64003 · Cláudio, pgXXXXX

---

## 1. Regras acordadas (Marco + Cláudio)

> Estado: proposta do E1 — falta confirmação do E2.

| Decisão | Valor |
|---|---|
| Configuração de profiling | N=200 (linha 214) — `tools/MD_N200.cpp` |
| Configuração de avaliação | N=5000, `inputdata.txt` original (`cp / Ar / 100 / 35000`) |
| Saídas a comparar | `cp_output.txt` (por passo) e `cp_average.txt` (médias) |
| Repetições por medição | 5 (`perf stat -r 5 sh -c './md < inputdata.txt'`), média ± desvio |
| Flags de partida | `-O3 -ffast-math -march=native -fopenmp` |
| Tolerância | *(definir na secção 4, com base na diferença Ref vs (a))* |
| Branches | `main` (estável) · `marco` · `claudio` |
| Integração | Merge para `main` só depois de compilar, validar e revisão do outro elemento |

### Baselines

| Id | Descrição | Compilação | Para quê |
|---|---|---|---|
| Ref | Original | `gcc -O2` (sem fast-math) | Só correção |
| (a) | Original | `-O3 -ffast-math` (Makefile fornecido) | Ponto de partida |
| (b) | Original | (a) + `-march=native` | Efeito da flag |
| (c) | `seq_opt` (E2) | flags finais | Separar otimização sequencial de paralelismo |
| (d) | OpenMP com 1 thread | flags finais | Referência do strong scaling |

### Métricas

- Speedup: S(p) = T_omp(1) / T_omp(p)
- Eficiência: E(p) = S(p) / p
- Ganho total face a (a), indicado à parte
- Amdahl: Smax(p) = 1 / ((1 − f) + f/p), com f obtido do profiling
- Equação de desempenho: Texe = #I × CPI × Tcc (`perf stat`)

---

## 2. Deucalion

### Procedimento

```bash
cd /projects/F202500010HPCVLABUMINHO/2026-2027cp/$USER/CP
git pull
mkdir -p results
sbatch scripts/smoke.sh      # teste rápido + tempo de 1 execução
sbatch scripts/ref.sh        # referências + baseline (a)
squeue --me
```

Regras:
- Nunca compilar nem correr no login (é x86); tudo dentro de jobs ARM.
- Não usar a home para o trabalho; usar `/projects`.
- Preferir `sbatch`; `srun --pty` é faturado como 48 cores.
- Medições de tempo só com `ml GCC/15.2.0` (o Score-P pode trocar a versão do GCC).

---

## 3. O programa (resumo)

- N = 5000 (linha 214), 200 passos → 201 iterações; `rand()` sem `srand` → determinístico.
- Por passo: `VelocityVerlet` (posições O(N) → `computeAccelerations` O(N²/2) → velocidades O(N) → paredes O(N), soma `psum`), depois `MeanSquaredVelocity` e `Kinetic` (O(N)) e `Potential` (O(N²), ciclo completo).
- Não alterar a semântica: `Potential` conta cada par duas vezes; médias dividem por 200 com 201 iterações.

---

## 4. Correção e tolerância

## 4. Correção e tolerância

| Comparação | Resultado | Observação |
|---|---|---|
| Ref vs (a) — `cp_average.txt` | Idêntico | `diff` vazio |
| Ref vs (a) — `cp_output.txt` | 119/201 linhas diferem, a partir do passo 79 | Erro relativo máximo: T 0 · KE 0 · P 2.6e-14 · PE 1.9e-13 · Etot 2.3e-13 |

Interpretação:
- As diferenças estão no último dígito impresso (PE ≈ 5e4 com 8 casas decimais → resolução ≈ 2e-13).
- Resultam da reordenação das somas `psum` (pressão) e `Pot` (energia potencial) com `-O3 -ffast-math`.
- São erros de arredondamento aceitáveis, não erros de execução (PL05).

Tolerância proposta (a confirmar com o E2):

| O que comparar | Tolerância relativa |
|---|---|
| `cp_output.txt` — T, KE, PE, Etot (por passo) | ≤ 1e-6 |
| `cp_output.txt` — P (por passo) | Só informativo |
| `cp_average.txt` — T médio e PV/nT | ≤ 1e-6 |
| `cp_average.txt` — P médio | ≤ 1e-4 |

Justificação:
- Margem acima dos 1e-13 observados, porque as versões OpenMP reordenam somas maiores
  (≈25 M termos em `Potential` por passo) e a dinâmica amplifica pequenas diferenças ao longo dos passos.
- A pressão por passo depende de colisões com as paredes (eventos discretos): um átomo que bate
  um passo mais cedo altera P nesse passo, mesmo com código correto. Por isso compara-se a média.

Critério de validação das versões OpenMP:
- Testar com 1, 2, 4, 8, 16 e 48 threads e repetir cada configuração várias vezes.
- Diferenças pequenas, estáveis e dentro da tolerância → arredondamento (aceitável).
- Diferenças grandes, ou que mudam de execução para execução → suspeita de data race.
- Resultados repetíveis não provam ausência de data races: rever também o código
  (escritas em `a[j]`, somas partilhadas, variáveis temporárias privadas).

Comando usado para medir o erro relativo máximo por coluna:
paste reference/full/cp_output.txt results/a/cp_output.txt | awk 'NR>1{
  for(c=2;c<=6;c++){a=$c;b=$(c+6);d=a-b;if(d<0)d=-d;s=(a<0?-a:a);r=(s>0)?d/s:d;if(r>m[c])m[c]=r}}
  END{split("T P KE PE Etot",n," ");for(c=2;c<=6;c++)printf "%-5s max rel = %.3e\n",n[c-1],m[c]}'

---

## 5. Registo de experiências

| Data | Commit | Variante | N | Threads | Flags | Tempo (s) | Validação | Notas |
|---|---|---|---|---|---|---|---|---|
| 15/11 | | smoke | 5000 | 1 | Makefile | *(T)* | — | teste de execução |
| 15/11 | | (a) | 5000 | — | -O3 -ffast-math | *(média ± desvio)* | ref | perf stat -r 5 |

---
