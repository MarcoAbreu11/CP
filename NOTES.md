# CP — WA Fase 1 · Notas do projeto 

Grupo: Marco António, pg64003 · Cláudio, pgXXXXX

---

## 1. Regras acordadas

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

## 9. OpenMP v2 (omp_v2_vec) e configuração final

### Nomes
- A nossa tag/pastas "omp_v2" = omp_v2_vec do Cláudio (dynamic + variáveis locais).
  Tag omp_v2_vec criada no mesmo commit.
- O omp_v2 do Cláudio (só dynamic, sem variáveis locais) foi medido como
  v1 + OMP_SCHEDULE=dynamic,1 (results/sched_omp_v1) e v1 com 1 thread (results/scaling_omp_v1).

### Alterações
- schedule(dynamic) (= dynamic,1) no ciclo de pares — escolhido com base no teste de escalonamento da v1.
- Posição de i em variáveis locais (rix, riy, riz); força sobre i acumulada em aix, aiy, aiz e escrita
  em a[i] uma vez por linha → dentro do ciclo j só há escritas em a[j] (+ Pot) → permite vetorizar.

### Revisão
- Sem data races: variáveis locais privadas; a[] e Pot com reduction.
- Equivalente à v1, a menos da ordem das somas.

### Vetorização (scripts/vec_report.sh, GCC 15.2.0 no nó ARM, -fopt-info-vec-optimized)
- -O3 -ffast-math: linha 489 (ciclo j) "loop vectorized using 16 byte vectors" → NEON, 2 doubles/instrução.
- + -march=native: linha 489 "loop vectorized using variable length vectors" → SVE, 8 doubles no A64FX.
- v1: ciclo j não vetorizado ("complicated access pattern" na escrita em a[i], segundo o E2).

### Validação
- Sem -fopenmp vs seq_opt: idêntico (P 6e-15, informativo).
- N=200, 1–48 threads × 3 rep., base e native: 44/44 OK, erro 0.
- N=5000, scaling 12 p × base e native: 24/24 OK.
- Afinamento, escalonamentos e teste final: todos OK.

### omp_v2 (só dynamic) vs omp_v2_vec
| Threads | omp_v2 base | vec base (NEON) | vec native (SVE) | vec base / v2 | vec native / v2 |
|---|---|---|---|---|---|
| 1 | 82.157 s | 34.539 s | 24.898 s | 2.38× | 3.30× |
| 12 | 6.969 s | 2.988 s | 2.149 s | 2.33× | 3.24× |
| 48 | 2.053 s | 1.151 s | 0.988 s | 1.78× | 2.08× |
- Jobs diferentes (variação entre jobs ~4%), irrelevante face a 1.8–3.3×.
- omp_v2 + native não medido: ciclo não vetorizado; native foi pior nas versões não vetorizadas (seq_opt, v1).
- Conclusão: a vec fica.

### Scaling (scaling.sh, N=5000, 5 rep., código omp_v2_vec com schedule(dynamic))
| p | T base (s) | S | E | I/I1 | T native (s) | S | E | I/I1 |
|---|---|---|---|---|---|---|---|---|
| 1 | 34.539 | 1.00 | 1.00 | 1.00 | 24.898 | 1.00 | 1.00 | 1.00 |
| 2 | 17.337 | 1.99 | 1.00 | 1.00 | 12.528 | 1.99 | 0.99 | 1.01 |
| 4 | 8.722 | 3.96 | 0.99 | 1.01 | 6.299 | 3.95 | 0.99 | 1.03 |
| 8 | 4.406 | 7.84 | 0.98 | 1.05 | 3.192 | 7.80 | 0.97 | 1.08 |
| 12 | 2.988 | 11.56 | 0.96 | 1.09 | 2.149 | 11.59 | 0.97 | 1.15 |
| 16 | 2.274 | 15.19 | 0.95 | 1.15 | 1.643 | 15.16 | 0.95 | 1.25 |
| 24 | 1.619 | 21.33 | 0.89 | 1.37 | 1.145 | 21.75 | 0.91 | 1.52 |
| 32 | 1.305 | 26.46 | 0.83 | 1.61 | 0.931 | 26.75 | 0.84 | 2.06 |
| 36 | 1.196 | 28.87 | 0.80 | 1.74 | 0.878 | 28.37 | 0.79 | 2.47 |
| 40 | 1.154 | 29.92 | 0.75 | 1.94 | 0.828 | 30.07 | 0.75 | 2.86 |
| 44 | 1.106 | 31.23 | 0.71 | 2.18 | 0.769 | 32.36 | 0.74 | 2.98 |
| 48 | 1.151 | 30.02 | 0.63 | 2.79 | 0.988 | 25.20 | 0.53 | 7.04 |
- Native ~1.4× mais rápida em todos os p (SVE). Inverte a decisão da Fase 3 (sem vetorização não ajudava).
- E ≥ 0.95 até 16 threads: o dynamic eliminou o desequilíbrio da v1 (v1: E 0.52 a 12 thr).
- Erros a 48 threads muito maiores (±0.097 base, ±0.196 native) do que a 44 (±0.025 / ±0.014).

### Equação de desempenho (1 thread; Texe = #I × CPI × Tcc)
| | #I | ciclos | CPI | T (s) |
|---|---|---|---|---|
| seq_opt (c) | 101.1e9 | 164.2e9 | 1.62 | 82.12 |
| vec base (NEON) | 35.57e9 | 69.05e9 | 1.94 | 34.54 |
| vec native (SVE) | 11.24e9 | 49.70e9 | 4.42 | 24.90 |
- seq_opt → vec base: #I 2.84× menos × CPI 0.84 = 2.38×.
- base → native: #I 3.17× menos × CPI 0.44 = 1.39× (SVE: 8 doubles/instrução, mas instruções mais caras:
  divisão vetorial, acessos espalhados a a[j]).
- Custo por par (2 524 495 000 pares): base 13.7 ns (27 ciclos), native 9.9 ns (20 ciclos)
  vs seq_opt 32.5 ns e original 43.1 ns.

### Significância (diferença > soma dos erros)
- native 44 vs 40: 0.059 s > 0.019 → significativo.
- native 44 vs 48: 0.219 s vs 0.210 → no limite; erro a 48 = ±0.196 s (≈20%) vs ±0.014 s a 44 (≈1.8%).
- native vs base a 44: 0.336 s ≫ 0.039 → 1.44× (significativo).

### Decomposição da eficiência: E(p) = [C(1)/C(p)] × [C(p)/(p·T·2 GHz)]
(C = ciclos totais de todas as threads; 1.º fator = trabalho extra; 2.º = utilização)
| | C1/Cp | U | E calc. | E medido |
|---|---|---|---|---|
| native 24 | 0.932 | 0.971 | 0.905 | 0.91 |
| native 44 | 0.793 | 0.926 | 0.734 | 0.74 |
| native 48 | 0.614 | 0.853 | 0.524 | 0.53 |
| base 44 | 0.772 | 0.919 | 0.709 | 0.71 |
| base 48 | 0.699 | 0.894 | 0.625 | 0.63 |
- 44 thr: perda sobretudo por ciclos extra de sincronização (~21%), pouca inatividade (~7%).
- 48 thr: ciclos extra 39% (instruções 33.5e9 → 79.1e9: espera ativa) + utilização 85%.

### Afinamento do número de threads (native, 5 rep., outro job)
| p | 40 | 41 | 42 | 43 | 44 | 45 | 46 | 47 | 48 |
|---|---|---|---|---|---|---|---|---|---|
| T (s) | 0.834 | 0.795 | 0.845 | 0.763 | 0.799 | 0.751 | 0.774 | 0.800 | 1.075 |
| ± | 0.024 | 0.012 | 0.024 | 0.017 | 0.026 | 0.008 | 0.030 | 0.035 | 0.211 |
- Entre 40 e 47: curva sem padrão → ruído. O mesmo p (44) deu 0.769 e 0.799 em jobs diferentes
  → variação entre jobs ~4% > ± do perf stat dentro de um job.
- Robusto: 48 threads com dynamic é mau e instável (2.º job a confirmar; I/I1 = 8.44).

### Escalonamento (diagnóstico com schedule(runtime))
Base: 24 thr — static,1 1.597 · dyn,1 1.598 · dyn,4 1.583 · dyn,16 1.577 · dyn,64 1.627 · guided 2.888
      48 thr — static,1 1.052 · dyn,1 1.132 · dyn,4 1.158 · dyn,16 1.121 · dyn,64 1.112 · guided 1.650
Native: 42 — static,1 0.812 · dyn,1 0.770 · dyn,16 0.825 · dyn,64 0.798
        44 — static,1 0.825 · dyn,1 0.768 · dyn,16 0.800 · dyn,64 0.763
        46 — static,1 0.737 · dyn,1 0.774 · dyn,16 0.730 · dyn,64 0.892
        48 — static,1 0.741 · dyn,1 0.911 (±0.136) · dyn,16 0.766 · dyn,64 1.019 (±0.137)
- 42–46: sem vencedor consistente (ruído). guided mau (1.º bloco apanha as linhas pesadas).
- 48: static,1 rápido e estável nos dois testes (base e native); dynamic instável.

### Teste final lado a lado (final_compare.sh: intercalado, 10 rep., 2 nós, native)
| Candidato | Mediana A / B | Máx. A / B | Média das médias | Desvio A / B | > 0.85 s |
|---|---|---|---|---|---|
| 48:static,1 | 0.729 / 0.754 | 0.922 / 1.217 | 0.781 | 0.076 / 0.154 | 3/20 |
| 45:dynamic,1 | 0.800 / 0.743 | 0.942 / 0.841 | 0.790 | 0.073 / 0.042 | 4/20 |
| 46:static,1 | 0.740 / 0.809 | 0.951 / 0.946 | 0.791 | 0.078 / 0.061 | 3/20 |
| 44:dynamic,64 | 0.788 / 0.786 | 0.845 / 0.867 | 0.792 | 0.031 / 0.046 | 1/20 |
| 44:dynamic,1 | 0.825 / 0.827 | 0.948 / 1.022 | 0.846 | 0.058 / 0.088 | 6/20 |
| 48:dynamic,1 | 0.787 / 0.845 | 1.752 / 1.805 | 1.039 | 0.356 / 0.477 | 8/20 |
- 48:dynamic,1 (= vec + Makefile anterior) é a pior: caudas até 1.8 s, 40% de execuções lentas.
- Os 4 melhores empatam na média (0.781–0.792, Δ 1.4%, não significativo).
- Diferença na distribuição: static,1/48 melhor mediana mas com caudas; dynamic,64/44 o mais estável.
- Hipótese: dynamic,1 faz ~5000 operações atómicas por chamada (disputa a 48 thr); dynamic,64 ~79
  (compensa atrasos com pouca disputa); static,1 sem coordenação, mas sem compensação de atrasos.

### Profiling
- 1 thread (sem -fopenmp): computeAccelerations 99.92% → f = 0.9992.
  Amdahl: Smax(12) 11.90 · Smax(24) 23.57 · Smax(32) 31.23 · Smax(44) 42.5 · Smax(48) 46.3.
  Medido native / Amdahl: 0.97 (12) · 0.92 (24) · 0.86 (32) · 0.76 (44) · 0.54 (48).
- Observação: o perfil sem -fopenmp teve 87.5e9 ciclos (≈43.8 s) vs 34.5 s da versão OpenMP com 1 thread
  → a confirmar (measure.sh sem -fopenmp); não afeta o strong scaling (baseline = T_omp(1)).
- 48 threads (base): computeAccelerations 76.92% · mutex 7.85% · barreiras 11.42% · atómicas 2.83% ·
  gomp_iter_dynamic_next 0.19% → sincronização ≈ 22%.
  v1 a 48 thr: mutex 0.30% → a junção da reduction de a (com lock) passou a pesar porque o cálculo
  ficou ~3× mais rápido.

### Ajuste de portabilidade
- reduction(+:a[0:N][0:3], Pot) → reduction(+:a, Pot).
- Motivo: a secção de array 2D de tamanho variável dá erro no Clang 18 (Windows); o array completo
  compila em GCC e Clang → código mais simples e portável. A avaliação usa só GCC 15.2.0 (ARM).
- Correção: cada thread privatiza a[MAXPART][3] (5001 linhas) inicializado a 0; a linha extra a[5000]
  fica a 0 e não altera o resultado. Sem novas data races.
- Custo: +1 linha em 5001 (≈0.02%) com N=5000 → desprezável. Com N=200 privatiza o array todo
  (só afeta o tempo dos testes de correção, não as medições).

### Decisão
Escolha: 44 threads + schedule(dynamic,64)
- Tempo esperado igual ao melhor (média 0.792 vs 0.781 s; Δ 1.4% não significativo).
- Menor risco: 5% de execuções lentas (vs 15% do static,1/48); pior caso 0.87 s (vs 1.22 s).
- dynamic,64: ~79 pedidos de trabalho por chamada (vs ~5000 com dynamic,1) → menos disputa,
  mantendo a compensação de threads atrasadas.
- 44 threads: deixa 4 cores livres; a 48 thr a utilização caía para 85% e I/I1 subia para 7–8.

Configuração final:
- CFLAGS = -O3 -ffast-math -march=native -fopenmp
- OMP_NUM_THREADS ?= 44
- Código: schedule(dynamic,64) reduction(+:a, Pot) → tag omp_final

### Verificação final (omp_final + Makefile final) — a preencher
| Verificação | Script | Resultado |
|---|---|---|
| Vetorização do ciclo j (SVE) | vec_report.sh | |
| Correção N=200, 1–48 thr × 3 rep. | validate_threads.sh | |
| Correção N=5000 + scaling final (5 rep.) | scaling.sh | |
| make run (5×), condições de avaliação | make_run.sh | tempos: … · validação: … |

### Ganhos (com o tempo final do make run a confirmar)
- vs original (a): 325.24 / … ≈ …× (referência: 0.79 s → ≈ 410×)
- vs seq_opt (c): 82.12 / … ≈ …× (referência: 0.79 s → ≈ 104×)
- Melhor v1 (3.655 s) → final: ≈ …× (referência: 0.79 s → ≈ 4.6×)

---
