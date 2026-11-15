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

| Ref vs (a) — cp_average.txt | Idêntico | diff vazio |
| Ref vs (a) — cp_output.txt | 119/201 linhas diferem a partir do passo 79 | erro rel. máx.: T 0, KE 0, P 2.6e-14, PE 1.9e-13, Etot 2.3e-13 |

Diferenças no último dígito impresso (PE ≈ 5e4 com 8 casas → resolução ≈ 2e-13):
arredondamento por reordenação das somas (psum, Pot) com -ffast-math, não erro (PL05).

Tolerância proposta: T, KE, PE, Etot por passo e T médio ≤ 1e-6 relativo; P médio ≤ 1e-4;
P por passo informativo (colisões com paredes são eventos discretos).
Margem acima de 1e-13 porque as versões OpenMP reordenam somas maiores e a dinâmica amplifica diferenças.

---

## 5. Registo de experiências

| Data | Commit | Variante | N | Threads | Flags | Tempo (s) | Validação | Notas |
|---|---|---|---|---|---|---|---|---|
| 15/11 | | smoke | 5000 | 1 | Makefile | *(T)* | — | teste de execução |
| 15/11 | | (a) | 5000 | — | -O3 -ffast-math | *(média ± desvio)* | ref | perf stat -r 5 |

---
