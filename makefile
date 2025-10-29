help:
	@echo "Comandos:"
	@echo "run: roda código de teste (compila e executa para debug local)"

run:
	@as Coprocessador_lib.s -o lib.o
	@gcc main.c lib.o -z noexecstack -o exe -std=c99
	@rm lib.o
	@./exe
	@rm exe