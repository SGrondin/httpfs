SHELL := /bin/bash
all: build

clean:
	@rm -f *.cmi
	@rm -f *.cmo
	@rm -f *.cmx
	@rm -rf _build

build: clean
	corebuild -pkg unix,lwt,lwt.syntax,lwt.unix main.native
	@cp _build/main.native server
	@unlink main.native

compile:
	ocamlfind ocamlc -c -thread -package lwt,core,lwt.syntax,lwt.unix cli.ml -syntax camlp4o
