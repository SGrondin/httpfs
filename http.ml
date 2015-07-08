open Core.Std
open Lwt
open Cohttp_lwt_unix

let message body = Server.respond_string ~status:`OK ~body ()

let forward_to_others req body = message "Forward request to other servers.\n"

let get req body =
	let path = Uri.path (Request.uri req) in
  let fname = Sys.getcwd () ^ path in
  let (>>=) = Lwt.(>>=) in
    Server.respond_file ~fname () >>= (function (r, body) as resp ->
    match Response.status r with
    | `Not_found -> forward_to_others req body
    | _ -> Lwt.return resp)

let post = message "POST\n"

let put = message "PUT\n"

let callback (ch, _) req body =
	match Request.meth req with
	| `GET -> get req body
	| `POST -> post
	| `PUT -> put
	| _ -> message "oops\n"

let make_server () =
	let ctx = Cohttp_lwt_unix_net.init () in
	let mode = `TCP (`Port 2020) in
	let config_tcp = Server.make ~callback () in
	Server.create ~ctx ~mode config_tcp
