open Core.Std
open Lwt
open Cohttp_lwt_unix

let (<*>) f g x = f (g x)

let get_filename req =
  let path = Uri.path (Request.uri req) in
  Sys.getcwd () ^ path

let unimplemented body = Server.respond_string ~status:`OK ~body ()

let forward_to_others ips req body =
  List.map ~f:(fun ip ->
    let headers = Cohttp.Header.init_with "forwarded" "true" in
    Client.get ~headers (Uri.with_host (Request.uri req) (Some ip))
  ) ips
  |> Lwt_list.filter_p (fun task ->
    task >|= fun (res, _) -> Response.status res <> `Not_found
  )
  >>= (function
  | [] -> Server.respond_string ~status:`Not_found ~body:"" ()
  | x :: [] -> x
  | xs ->
    Lwt_list.map_p (map (Sexp.to_string <*> Response.sexp_of_t <*> fst)) xs
    >>= fun ls ->
      Server.respond_string ~status:`Internal_server_error ~body:(List.to_string ~f:Fn.id ls) ()
  )

let get ips req body =
  let fname = get_filename req in
  Server.respond_file ~fname ()
  >>= (function (r, _) as resp ->
    match Response.status r with
    | `Not_found -> forward_to_others ips req body
    | _ -> Lwt.return resp)

let post = unimplemented "POST\n"

let put req body =
  let filename = get_filename req in
  let flags = [Unix.O_WRONLY; Unix.O_TRUNC] in
  let mode = Lwt_io.output in
  Lwt.catch
    (function () -> Lwt_io.with_file ~flags ~mode filename
      (Fn.flip Cohttp_lwt_body.write_body body <*> Lwt_io.write)
      >>= function () -> Server.respond_string ~status:`OK ~body:"" ())
    (function Unix.Unix_error (ENOENT, _, _) ->
      unimplemented "PUT Forward\n"
    | _ -> unimplemented "Unknown exception\n")

let callback ips _ req body =
  match Request.meth req with
  | `GET -> get ips req body
  | `POST -> post
  | `PUT -> put req body
  | _ -> unimplemented "oops\n"

let make_server ips () =
  let ctx = Cohttp_lwt_unix_net.init () in
  let mode = `TCP (`Port 2020) in
  let config_tcp = Server.make ~callback:(callback ips) () in
  Server.create ~ctx ~mode config_tcp
