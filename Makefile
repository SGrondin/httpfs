SHELL := /bin/bash
all: build

clean:
	@rm -f *.cmi
	@rm -f *.cmo
	@rm -f *.cmx
	@rm -rf _build
	@rm -f out*.txt

build: clean stop
	corebuild -pkg unix,lwt,lwt.syntax,lwt.unix,lwt.preemptive,cohttp.lwt main.native
	@cp _build/main.native httpfs
	@unlink main.native

dist: build
	patchelf --set-rpath '$$ORIGIN/' httpfs

sandbox:
	mkdir sandbox1
	touch sandbox1/file1.txt
	echo 'This is file number one' > sandbox1/file1.txt
	touch sandbox1/file2.txt
	echo 'This is file number one' > sandbox1/file2.txt
	mkdir sandbox1/dir1
	touch sandbox1/dir1/file3.txt
	echo 'This is file number three' > sandbox1/dir1/file3.txt
	mkdir sandbox1/dir2
	mkdir sandbox1/dir2/dir3

	mkdir sandbox2
	touch sandbox2/a.txt
	touch sandbox2/b.txt
	echo 'This is file a' > sandbox2/a.txt
	echo 'This is file b' > sandbox2/b.txt

run: stop
	pushd sandbox1 && ../httpfs -p 2020 127.0.0.1:2021 > ../out1.txt &
	pushd sandbox2 && ../httpfs -p 2021 127.0.0.1:2020 > ../out2.txt &

stop:
	killall httpfs || echo ''

setup:
	opam update
	opam install core lwt cohttp utop

compile:
	ocamlfind ocamlc -c -thread -package lwt,core,lwt.syntax,lwt.unix,cohttp.lwt -syntax camlp4o http.mli
	ocamlfind ocamlc -c -thread -package lwt,core,lwt.syntax,lwt.unix,cohttp.lwt -syntax camlp4o http.ml
