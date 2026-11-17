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
| `cp_average.txt` — T médio | ≤ 1e-6 |
| `cp_average.txt` — P médio, PV/nT e Z | ≤ 1e-4 (PV/nT e Z são calculados a partir da pressão) |

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

## 6. Profiling inicial (código original, flags da baseline (a): -O3 -ffast-math)

Comandos: scripts/prof_perf.sh, scripts/prof_scorep.sh, scripts/scale_n.sh
Saídas: profiling/perf/, profiling/scorep/, profiling/scaleN/

### Ranking
| Função | perf N=200 | perf N=5000 | Score-P N=5000 | Visits | Tempo/chamada |
|---|---|---|---|---|---|
| Potential | 65.4% | 66.6% | 66.5% (216.4 s) | 201 | 1.077 s |
| computeAccelerations | 33.4% | 33.4% | 33.4% (108.8 s) | 202 | 0.538 s |
| VelocityVerlet (parte O(N)) | 0.14% | 0.01% | 0.0% | 201 | 86 µs |
| Kinetic + MeanSquaredVelocity | — | — | 0.0% | 201+201 | ~12 µs |
| Resto | — | ~0.01% | 0.0% | — | — |

- Os dois ciclos O(N²) = 99.98% do tempo. Score-P total 325.21 s ≈ perf stat 325.24 s (overhead desprezável).
- Custo por par igual nas duas funções: ~43 ns ≈ 86 ciclos. Potential pesa 2× porque percorre 2× os pares (ciclo completo, N(N−1)).

### -O2 vs (a)
- -O2: ~95% do tempo na libm (__pow_finite 67%, __exp1 26.5%, __pow + pow@plt ~2%).
- (a): as chamadas a pow desaparecem (-ffast-math → multiplicações). Ciclos 11.05e9 → 1.06e9 = 10.4×.

### Dentro de Potential (perf annotate, N=5000)
- Cadeia dependente: fsub/fmadd (r²) → fsqrt → fdiv (sigma/rnorm) → fmul ×4 (quot², ³, ⁶, ¹²) → fsub/fmadd (Pot).
- A 1.ª fmul após o fdiv acumula 30% das amostras: espera pela latência de fsqrt + fdiv.
- O ciclo está limitado pela latência das operações dependentes → explica CPI ≈ 3 (IPC 0.33).

### Complexidade
| N | Tempo (s) | Razão | Esperado O(N²) |
|---|---|---|---|
| 200 | 0.545 | — | — |
| 1000 | 13.05 | 23.9 | 25 |
| 2000 | 52.12 | 3.99 | 4 |
| 5000 | 325.24 | 6.24 | 6.25 |

### Amdahl (código original)
f ≈ 0.9998 → Smax(12) = 11.97 · Smax(24) = 23.89 · Smax(48) = 47.5.
Amdahl não é o limite; desvios reais vêm de sincronização (a[j]), desequilíbrio (ciclo triangular) e memória (PL06).
Recalcular f após a seq_opt.

---

## 7. Validação e medição da seq_opt (tag seq_opt)

### Alterações
- Potential() removida: energia potencial calculada dentro de computeAccelerations (mesmas posições:
  entre as duas chamadas só mudam velocidades) e guardada em Epot.
- 1 divisão por par (inv = 1/r²), sem sqrt nem pow:
  inv6 = inv³ · f = 24·inv·inv6·(2·inv6 − 1) · Pot += 4·(inv6² − inv6).
- Epot = 2·Pot mantém a semântica original (soma sobre (i,j) e (j,i)).
- Pares por passo: 37.5 M → 12.5 M.

### Validação (scripts/compare.sh, tolerância 1e-6; P, PV/nT e Z 1e-4)
| Versão | N | PE máx. rel. | Etot máx. rel. | T, KE | Resultado |
|---|---|---|---|---|---|
| (b) | 5000 | 1.9e-13 | 2.3e-13 | 0 | OK |
| (c) | 200 | 0 | 0 | 0 | OK |
| (c) | 5000 | 5.8e-13 | 7.9e-13 | 0 | OK |
| (c_native) | 5000 | 5.8e-13 | 7.9e-13 | 0 | OK |

### Medição (scripts/measure.sh, perf stat -r 5, 1 thread)
| Versão | Código | Flags | Tempo (s) | #I | Ciclos | IPC | CPI |
|---|---|---|---|---|---|---|---|
| (a) | original | -O3 -ffast-math | 325.24 ± 0.005 | 216.8e9 | 650.4e9 | 0.33 | 3.00 |
| (b) | original | + -march=native | 325.58 ± 0.011 | 216.8e9 | 651.1e9 | 0.33 | 3.00 |
| (c) | seq_opt | -O3 -ffast-math | 82.12 ± 0.005 | 101.1e9 | 164.2e9 | 0.62 | 1.62 |
| (c_native) | seq_opt | + -march=native | 85.25 ± 0.029 | 101.1e9 | 170.5e9 | 0.59 | 1.69 |

### Ganhos
- Código (a → c): 3.96×
- Flag -march=native no original (a → b): 0.999× (sem ganho; mesmo #I → código praticamente igual)
- Flag -march=native na seq_opt (c → c_native): 0.96× (3.8% mais lento; mesmo #I, mais ciclos)
- Melhor sequencial: (c) 82.12 s

### Explicação (Texe = #I × CPI × Tcc, Tcc = 0.5 ns)
- #I: 216.8e9 → 101.1e9 = 2.14×
- CPI: 3.00 → 1.62 = 1.85×
- Total: 2.14 × 1.85 = 3.96× ✓

| Por par | Instruções | Ciclos | Tempo |
|---|---|---|---|
| Original (≈7.55e9 pares) | 28.7 | 86 | 43 ns |
| seq_opt (≈2.52e9 pares) | 40.0 | 65 | 32.5 ns |

- 3× menos pares; cada par tem mais instruções (força + energia), mas menos ciclos
  (sem sqrt, 1 só divisão → cadeia de dependências mais curta).

### Novo perfil (scripts/prof_version.sh, perf, N=5000, -O3 -ffast-math)
| Função | % tempo |
|---|---|
| computeAccelerations | 99.97% |
| VelocityVerlet (parte O(N)) | 0.01% |
| main (inclui Kinetic e MeanSquaredVelocity por inlining) | 0.00% |
| Resto (kernel, libc) | ~0.02% |

Ciclos no perf record (164.6e9) ≈ perf stat (164.2e9).

### Amdahl (conservador: tudo fora de computeAccelerations como sequencial)
f ≈ 0.9997 → Smax(12) = 11.96 · Smax(24) = 23.84 · Smax(48) = 47.3 (≈ 1.7 s mínimo teórico).
Limite real esperado dentro de computeAccelerations: conflito de escrita em a[j],
reduction de Pot e desequilíbrio de carga do ciclo triangular (PL06).

---

## 8. OpenMP v1 (tag omp_v1)

### Implementação
- parallel for em todos os ciclos: MeanSquaredVelocity, Kinetic (reduction escalar),
  computeAccelerations, 3 ciclos de VelocityVerlet (paredes com reduction de psum).
- computeAccelerations: schedule(static), reduction(+:a[0:N][0:3], Pot) — cópia privada de a
  por thread (120 KB), somada no fim → resolve o conflito em a[j] sem critical/atomic.
- Variáveis temporárias declaradas dentro dos ciclos → privadas.
- 6 regiões paralelas por passo (~1200 fork-join no total).

### Revisão
- Sem data races encontradas na leitura do código.
- Previsão: schedule(static) num ciclo triangular → thread 0 com ≈(2−1/p)× o trabalho médio
  → S_static(p) ≈ p/(2−1/p).

### Validação
- Sem -fopenmp vs seq_opt: idêntico (erro 0 em tudo).
- N=200: 1, 2, 4, 8, 16, 32, 48 threads × 3 repetições → todas OK, erro 0 em T, KE, PE, Etot.
- N=5000: 1–48 threads (scaling) → todas OK.
- Conclusão: sem sinais de data races (revisão do código + testes).

### Scaling (N=5000, -O3 -ffast-math -fopenmp, schedule(static), 3 rep.)
| p | T (s) | S(p) | E(p) | I/I1 | Limite static | S / limite | Amdahl |
|---|---|---|---|---|---|---|---|
| 1 | 82.157 | 1.00 | 1.00 | 1.00 | 1.00 | — | 1.00 |
| 2 | 61.614 | 1.33 | 0.67 | 1.00 | 1.33 | 1.00 | 2.0 |
| 4 | 35.965 | 2.28 | 0.57 | 1.01 | 2.29 | 1.00 | 4.0 |
| 8 | 19.299 | 4.26 | 0.53 | 1.03 | 4.27 | 1.00 | 8.0 |
| 12 | 13.186 | 6.23 | 0.52 | 1.05 | 6.26 | 0.99 | 11.96 |
| 16 | 10.033 | 8.19 | 0.51 | 1.07 | 8.26 | 0.99 | 15.9 |
| 24 | 6.804 | 12.07 | 0.50 | 1.11 | 12.25 | 0.99 | 23.8 |
| 32 | 5.197 | 15.81 | 0.49 | 1.17 | 16.25 | 0.97 | 31.7 |
| 48 | 3.655 | 22.48 | 0.47 | 1.42 | 24.25 | 0.93 | 47.3 |

- O speedup segue o modelo do desequilíbrio (≤1.5% de diferença até 24 threads) → causa demonstrada.
- Acima de 32 threads, overhead extra: I/I1 até 1.42 (spin-wait nas barreiras + reduction do array).
- T_v1(1) = 82.157 s vs seq_opt 82.12 s → overhead OpenMP com 1 thread ≈ 0.05%.
- Ganho total vs (a): 325.24 / 3.655 = 89×.
- -march=native: 1 thr +3.0%, 12 thr +1.5%, 48 thr +5.6% (sempre pior) → retirar.

### Escalonamento (diagnóstico: schedule(runtime) + OMP_SCHEDULE; S face a T_v1(1) = 82.157 s)
| p | static | static,1 | dynamic,1 | dynamic,16 | guided |
|---|---|---|---|---|---|
| 12 | 13.22 s (S 6.2) | 6.96 s (S 11.8) | 6.97 s (S 11.8) | 6.94 s (S 11.85, E 0.99) | 13.19 s (S 6.2) |
| 48 | 3.73 s (S 22.0) | 2.13 s (S 38.6) | 2.05 s (S 40.0, E 0.83) | 2.08 s (S 39.5) | 3.65 s (S 22.5) |
- Todos validados OK.
- static,1 e dynamic equilibram o ciclo triangular → 1.8–1.9× mais rápido do que static.
- guided ≈ static: o 1.º bloco (~5000/48 linhas) apanha as linhas mais pesadas.
- Com 48 threads, E ≈ 0.83: ~17% de overhead restante (já não é desequilíbrio).
- Ganho total possível: 325.24 / 2.053 ≈ 158×.

### Profiling (48 threads, perf, evento cycles)
- computeAccelerations 90.45% · barreiras libgomp ≈ 8.1% · atómicas + mutex (reductions) ≈ 1.05% · resto < 0.5%.
- O perfil sub-representa a espera: threads paradas há muito tempo adormecem e não geram
  amostras de cycles; a evidência do desequilíbrio é o modelo + o teste de escalonamento.

### Prioridades para a v2
1. Escalonamento do ciclo triangular: static,1 / dynamic,1 / dynamic,16 (decisão E2).
2. Depois, medir o overhead restante (reduction de a, 6 regiões por passo).
3. Flags: -O3 -ffast-math -fopenmp (sem -march=native).
4. Ciclos O(N) < 0.1%: não prioritários.

---
