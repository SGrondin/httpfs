HTTPFS
======

HTTPS provides a REST interface that exposes a distributed filesystem as if it were a single server.

***The servers must be free of conflicts on startup.***

Starting a server:

```
./httpfs [-p PORT] [list of remote servers]
```

The system will guarantee that files only exist on a single server.

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
