help:
	@echo "Comandos:"
	@echo "run: Roda código (compila e executa para debug local)"

run:
	@as Coprocessador_lib.s -o Coprocessador_lib.o
	@gcc main.c Coprocessador_lib.o -z noexecstack -std=c99 -lm -o exe
	@./exe
	@rm exe Coprocessador_lib.o

