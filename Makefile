CC     = gcc
SRC    = src/
CFLAGS = -O3 -ffast-math -march=native -fopenmp

.DEFAULT_GOAL = md

md: $(SRC)MD.cpp
	$(CC) $(CFLAGS) $(SRC)MD.cpp -lm -o md

prof: $(SRC)MD.cpp
	$(CC) $(CFLAGS) -g -fno-omit-frame-pointer $(SRC)MD.cpp -lm -o md_prof

clean:
	rm -f ./md ./md_prof

export OMP_NUM_THREADS ?= 44
export OMP_PROC_BIND ?= close
export OMP_PLACES ?= cores
run: md
	./md < inputdata.txt
