Git-fs
======

Distributed filesystem ala FTP using Git as a backend.

Discoverability: Give a single IP on startup and let it use Git to discover the other nodes.

Protocol beetween nodes: git
Protocol between clients and nodes: http

## Currently implemented

Command line:
`./server ls -la`

## Install

`opam switch 4.02.1`

`opam install core lwt cohttp`
