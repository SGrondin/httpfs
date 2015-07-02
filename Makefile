SHELL := /bin/bash
all: build

clean:
	@rm -f *.cmi
	@rm -f *.cmo
	@rm -f *.cmx
	@rm -rf _build

build: clean
	corebuild -pkg unix,lwt,lwt.syntax,lwt.unix,cohttp.lwt main.native
	@cp _build/main.native server
	@unlink main.native

setup:
	opam update
	opam install core lwt cohttp

compile:
	ocamlfind ocamlc -c -thread -package lwt,core,lwt.syntax,lwt.unix,cohttp.lwt -syntax camlp4o http.ml
