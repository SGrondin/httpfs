open Core.Std
open Lwt
open Cohttp_lwt_unix

let callback (ch, _) req client_body =
	let fname = Request.uri req |> Uri.path in
	let body = match Request.meth req with
	| `GET -> "GET\n"
	| `POST -> "POST\n"
	| `PUT -> "PUT\n"
	| _ -> "oops\n"
	in
	(* Server.respond_string ~status:(Cohttp.Code.status_of_code 200) ~body:filename () *)
	Server.respond_file ~fname ()

let make_server () =
	let ctx = Cohttp_lwt_unix_net.init () in
	let mode = `TCP (`Port 80) in
	let config_tcp = Server.make ~callback () in
	Server.create ~ctx ~mode config_tcp
