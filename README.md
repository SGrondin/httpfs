HTTPFS
======

HTTPFS provides a REST interface that exposes a distributed filesystem as if it were a single server.

***The servers must be free of conflicts on startup.***

The system will then guarantee that files only exist on a single server.

Starting a server:

```
./httpfs [-p PORT] [[list of remote servers] | [-d REMOTE_SERVER]
```

###### Arguments

- ***-p*** Override the default port (2020)
- ***-d*** Instead of a list of all the servers, the server will contact a single remote server and ask for its list of known servers. It'll then join the cluster.

### Joining and leaving a cluster

A server can be added to a cluster by using the `-d` command line switch.

A server can leave a cluster by sending it a DISCONNECT HTTP request.

When starting in discovery mode, the server will try to join a cluster. If it fails to join because not all the hosts accepted it, it'll then attempt to disconnect cleanly as to not leave the cluster in an inconsistent state.

### API reference

#### GET

Read.

On a file: returns the contents of the file.

On a directory: returns the contents of the directory. The `is-directory` header will be `true`.

#### PUT

Write.

On a file: overwrites the contents of the file.

On a directory: error.

#### POST

Create.

Without the `is-directory` header: creates an empty file.

With the `is-directory` header: creates an empty directory.

#### DELETE

Delete.

On a file: deletes the file.

On a directory: deletes the directory. The directory must be empty. The `is-directory` header must be set.

#### DISCONNECT

Leave the cluster.
