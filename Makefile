SHELL := /bin/bash
all: build

clean:
	@rm -f *.cmi
	@rm -f *.cmo
	@rm -f *.cmx
	@rm -rf _build

build: clean
	corebuild -pkg unix,lwt,lwt.syntax,lwt.unix,cohttp.lwt main.native
	@cp _build/main.native httpfs
	@unlink main.native

dist: build
	patchelf --set-rpath '$$ORIGIN/' httpfs

sandbox:
	mkdir sandbox
	touch sandbox/file1.txt
	echo 'This is file number one' > sandbox/file1.txt
	touch sandbox/file2.txt
	echo 'This is file number one' > sandbox/file2.txt
	mkdir sandbox/dir1
	touch sandbox/dir1/file3.txt
	echo 'This is file number three' > sandbox/dir1/file3.txt
	mkdir sandbox/dir2
	mkdir sandbox/dir2/dir3

run:
	./httpfs -p 2020 127.0.0.1:2021 &
	./httpfs -p 2021 127.0.0.1:2020 &

stop:
	killall httpfs

setup:
	opam update
	opam install core lwt cohttp utop

compile:
	ocamlfind ocamlc -c -thread -package lwt,core,lwt.syntax,lwt.unix,cohttp.lwt -syntax camlp4o http.mli
	ocamlfind ocamlc -c -thread -package lwt,core,lwt.syntax,lwt.unix,cohttp.lwt -syntax camlp4o http.ml
