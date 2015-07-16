open Core.Std
open Lwt
open Cohttp_lwt_unix

let (<*>) f g x = f (g x)

let get_filename req =
  let path = Uri.path (Request.uri req) in
  Sys.getcwd () ^ path

let unimplemented body = Server.respond_string ~status:`OK ~body ()

let forward_to_others ips meth req body =
  match Cohttp.Header.get (Request.headers req) "forwarded" with
  | Some _ -> Server.respond_string ~status:`Bad_request ~body:"" ()
  | None ->
    List.map ~f:(fun ip ->
      let headers = Cohttp.Header.init_with "forwarded" "true" in
      let uri = Request.uri req
      |> fun u -> Uri.with_scheme u (Some "http")
      |> fun u -> Uri.with_host u (Some ip)
      in
      Client.call ~headers ~body ~chunked:false meth uri
    ) ips
    |> Lwt_list.filter_p (fun task ->
      task >|= fun (res, _) -> Response.status res = `OK
    )
    >>= (function
    | [] -> Server.respond_string ~status:`Bad_request ~body:"" ()
    | x :: [] -> x
    | xs ->
      Lwt_list.map_p (map (Sexp.to_string <*> Response.sexp_of_t <*> fst)) xs
      >>= fun ls ->
        Server.respond_string ~status:`Internal_server_error ~body:(List.to_string ~f:Fn.id ls) ()
    )

let list_directory_content path =
  Lwt_stream.fold (fun file -> fun acc -> acc ^ "\n" ^ file)
    (Lwt_unix.files_of_directory path) ""
  >>= fun body -> Server.respond_string ~status:`OK ~body ()

let get ips req body =
  let fname = get_filename req in
  Lwt_unix.stat fname
  >>= fun stats ->
    match stats.st_kind with
    | S_DIR -> list_directory_content fname
    | _ -> Server.respond_file ~fname ()
  >>= (function (r, _) as resp ->
    match Response.status r with
    | `Not_found -> forward_to_others ips `GET req body
    | _ -> return resp)

let post = unimplemented "POST\n"

let put req body =
  let filename = get_filename req in
  let flags = [Unix.O_WRONLY; Unix.O_TRUNC] in
  let mode = Lwt_io.output in
  try_lwt (
    Lwt_io.with_file ~flags ~mode filename (Fn.flip Cohttp_lwt_body.write_body body <*> Lwt_io.write)
    >>= function () ->
        Server.respond_string ~status:`OK ~body:"" ()
  ) with
  | Unix.Unix_error (Unix.ENOENT, _, _) ->
    unimplemented "PUT Forward\n"
  | e ->
    unimplemented (Exn.to_string_mach e)

let callback ips _ req body =
  try_lwt (
    match Request.meth req with
    | `GET -> get ips req body
    | `POST -> post
    | `PUT -> put req body
    | _ -> unimplemented "oops\n"
  ) with
  | e ->
    print_endline (Exn.to_string_mach e);
    unimplemented ("An exception occured: \n" ^ (Exn.to_string_mach e))

let make_server ips () =
  let ctx = Cohttp_lwt_unix_net.init () in
  let mode = `TCP (`Port 2020) in
  let config_tcp = Server.make ~callback:(callback ips) () in
  Server.create ~ctx ~mode config_tcp
