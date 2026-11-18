#!/usr/bin/env python3
"""
Gráficos para o relatório IEEE (WA Fase 1 - Computação Paralela).

Uso (na raiz do repositório):
    python3 scripts/plots.py

Lê:
    data/scaling_final.csv   (scaling.sh da versão final: omp_final, -march=native, dynamic,64)
    data/scaling_v1.csv      (scaling.sh da omp_v1: schedule(static))
Escreve em figures/:
    fig_speedup.pdf/.png     speedup vs threads (final, v1, ideal, Amdahl)
    fig_eficiencia.pdf/.png  eficiência vs threads (final, v1)
    fig_versoes.pdf/.png     tempo por versão (escala log) com o ganho face ao original
"""
import csv
import os

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

# ---------------------------------------------------------------------------
# Parâmetros (todos medidos; origem indicada)
# ---------------------------------------------------------------------------
F_AMDAHL = 0.9992          # profiling/omp_v2_seq/flat.txt: computeAccelerations = 99.92 %
P_ESCOLHIDO = 44           # OMP_NUM_THREADS final (Makefile)

# Tempos por versão (s) para a fig_versoes
VERSOES = [
    ("Original (a)\n1 thread",             325.24),   # results/perf_a.txt
    ("seq_opt (c)\n1 thread",               82.12),   # results/c/perf.txt
    ("OpenMP v1\n48 threads, static",        3.655),  # results/scaling_omp_v1/resumo.txt
    ("Final\n44 threads, make run",          0.722), # results/make_run/tempos.txt (mediana de 10)
]

# ---------------------------------------------------------------------------
# Estilo: fonte pequena e figuras com a largura de uma coluna IEEE (3.5 in)
# ---------------------------------------------------------------------------
INK = "#0b0b0b"          # texto principal
INK_2 = "#52514e"        # texto secundário / eixos
GRID = "#e4e3df"         # grelha recessiva
REF = "#8a8984"          # linhas de referência (ideal, Amdahl)
C_FINAL = "#2a78d6"      # série 1 (azul)
C_V1 = "#eb6834"         # série 2 (laranja)

plt.rcParams.update({
    "font.family": "serif",
    "font.size": 8,
    "axes.titlesize": 8,
    "axes.labelsize": 8,
    "xtick.labelsize": 7,
    "ytick.labelsize": 7,
    "legend.fontsize": 7,
    "axes.edgecolor": INK_2,
    "axes.labelcolor": INK,
    "xtick.color": INK_2,
    "ytick.color": INK_2,
    "axes.spines.top": False,
    "axes.spines.right": False,
    "axes.grid": True,
    "grid.color": GRID,
    "grid.linewidth": 0.6,
    "lines.linewidth": 1.4,
    "savefig.bbox": "tight",
    "savefig.pad_inches": 0.02,
})
LARGURA, ALTURA = 3.5, 2.3


def ler_scaling(caminho):
    """Devolve listas (threads, tempo, erro) ordenadas por threads."""
    linhas = []
    with open(caminho, newline="") as f:
        for r in csv.DictReader(f):
            linhas.append((int(r["threads"]), float(r["tempo_s"]), float(r["erro_s"])))
    linhas.sort()
    p = [l[0] for l in linhas]
    t = [l[1] for l in linhas]
    e = [l[2] for l in linhas]
    return p, t, e


def speedup(p, t):
    t1 = t[p.index(1)]
    return [t1 / x for x in t]


def guardar(fig, nome):
    os.makedirs("figures", exist_ok=True)
    for ext in ("pdf", "png"):
        fig.savefig(f"figures/{nome}.{ext}", dpi=300)
    plt.close(fig)
    print(f"figures/{nome}.pdf e .png")


def main():
    pf, tf, ef = ler_scaling("data/scaling_final.csv")
    pv, tv, ev = ler_scaling("data/scaling_v1.csv")
    sf, sv = speedup(pf, tf), speedup(pv, tv)
    effin = [s / p for s, p in zip(sf, pf)]
    effv1 = [s / p for s, p in zip(sv, pv)]
    pmax = max(pf + pv)
    pref = list(range(1, pmax + 1))
    amdahl = [1 / ((1 - F_AMDAHL) + F_AMDAHL / p) for p in pref]

    # ------------------------------------------------------------- speedup
    fig, ax = plt.subplots(figsize=(LARGURA, ALTURA))
    ax.plot(pref, pref, ls="--", lw=1.0, color=REF, label="Ideal (S = p)")
    ax.plot(pref, amdahl, ls=":", lw=1.2, color=REF, label=f"Amdahl (f = {F_AMDAHL})")
    ax.plot(pv, sv, marker="s", ms=4, color=C_V1, label="v1 (static)")
    ax.plot(pf, sf, marker="o", ms=4, color=C_FINAL, label="Final (dynamic,64, SVE, close)")
    i = pf.index(P_ESCOLHIDO)
    ax.annotate(f"{P_ESCOLHIDO} threads: S = {sf[i]:.1f}",
                xy=(pf[i], sf[i]), xytext=(33, 24.5),
                fontsize=7, color=INK,
                arrowprops=dict(arrowstyle="-", color=INK_2, lw=0.6))
    ax.set_xlabel("Threads (p)")
    ax.set_ylabel("Speedup S(p) = T(1)/T(p)")
    ax.set_xlim(0, pmax + 1)
    ax.set_ylim(0, pmax + 1)
    ax.set_xticks([1, 8, 16, 24, 32, 40, 48])
    ax.legend(loc="upper left", frameon=False)
    guardar(fig, "fig_speedup")

    # ------------------------------------------------------------- eficiência
    fig, ax = plt.subplots(figsize=(LARGURA, ALTURA))
    ax.plot(pv, effv1, marker="s", ms=4, color=C_V1, label="v1 (static)")
    ax.plot(pf, effin, marker="o", ms=4, color=C_FINAL, label="Final (dynamic,64, SVE, close)")
    ax.annotate(f"{P_ESCOLHIDO} threads: E = {effin[i]:.2f}",
                xy=(pf[i], effin[i]), xytext=(29, 0.97),
                fontsize=7, color=INK,
                arrowprops=dict(arrowstyle="-", color=INK_2, lw=0.6))
    ax.set_xlabel("Threads (p)")
    ax.set_ylabel("Eficiência E(p) = S(p)/p")
    ax.set_xlim(0, pmax + 1)
    ax.set_ylim(0, 1.05)
    ax.set_xticks([1, 8, 16, 24, 32, 40, 48])
    ax.legend(loc="lower left", frameon=False)
    guardar(fig, "fig_eficiencia")

    # ------------------------------------------------------------- versões
    fig, ax = plt.subplots(figsize=(LARGURA, ALTURA))
    nomes = [v[0] for v in VERSOES][::-1]
    tempos = [v[1] for v in VERSOES][::-1]
    t0 = VERSOES[0][1]
    y = range(len(nomes))
    ax.barh(y, tempos, height=0.5, color=C_FINAL)
    for yi, t in zip(y, tempos):
        txt = f"{t:.3g} s" if t == t0 else f"{t:.3g} s  ({t0 / t:.0f}×)"
        ax.text(t * 1.15, yi, txt, va="center", fontsize=7, color=INK)
    ax.set_xscale("log")
    ax.set_xlim(0.3, 4000)
    ax.set_yticks(list(y))
    ax.set_yticklabels(nomes)
    ax.set_xlabel("Tempo de execução (s, escala log)")
    ax.grid(axis="y", visible=False)
    guardar(fig, "fig_versoes")


if __name__ == "__main__":
    main()
