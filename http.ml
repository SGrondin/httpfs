open Core.Std
open Lwt
open Cohttp_lwt_unix

let (<*>) f g x = f (g x)

let locked = Hashtbl.create ~hashable:String.hashable ()

let lock_timeout = 1.5

let get_filename req =
  let path = Uri.path (Request.uri req) in
  Sys.getcwd () ^ path

let unimplemented body = Server.respond_string ~status:`OK ~body ()

let critical_error e =
  let body = Exn.to_string_mach e in
  print_endline body;
  Server.respond_string ~status:`Internal_server_error ~body ()

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
    | [] -> Server.respond_string ~status:`Not_found ~body:"" ()
    | x :: [] -> x
    | xs ->
      Lwt_list.map_p (map (Sexp.to_string <*> Response.sexp_of_t <*> fst)) xs
      >>= fun ls ->
        Server.respond_string ~status:`Internal_server_error ~body:(List.to_string ~f:Fn.id ls) ()
    )

let add_trailing_slash_if_directory root filename =
  Lwt_unix.stat (root ^ "/" ^ filename)
  >|= (fun stats ->
    match stats.Lwt_unix.st_kind with
    | Unix.S_DIR -> filename ^ "/"
    | _ -> filename)

let list_directory_content path =
  Lwt_unix.files_of_directory path
  |> Lwt_stream.map_s (add_trailing_slash_if_directory path)
  |> Fn.flip (Lwt_stream.fold (fun file -> fun acc -> file ^ "\n" ^ acc)) ""
  >>= fun body ->
    Server.respond_string ~headers:(Cohttp.Header.init_with "is-directory" "true") ~status:`OK ~body ()

let get ips req body =
  let fname = get_filename req in
  Lwt_unix.stat fname
  >>= fun stats ->
    match Lwt_unix.(stats.st_kind) with
    | Unix.S_DIR -> list_directory_content fname
    | _ -> Server.respond_file ~fname ()
  >>= (function (r, _) as resp ->
    match Response.status r with
    | `Not_found -> forward_to_others ips `GET req body
    | _ -> return resp)

let lock ips req body =
  let fname = get_filename req in
  try_lwt (
    Lwt_io.with_file ~flags:[Unix.O_RDONLY] ~mode:Lwt_io.input fname (fun _ ->
      Server.respond_string ~status:`Conflict ~body:"" ()
    )
  ) with
  | Unix.Unix_error (Unix.ENOENT, _, _) ->
    (* The file doesn't exist, lock it and return OK *)
    Hashtbl.set locked fname true;
    ignore (Lwt_unix.timeout lock_timeout >|= fun () -> Hashtbl.remove locked fname);
    Server.respond_string ~status:`OK ~body:"" ()
  | e -> critical_error e

let post ips req body =
  let fname = get_filename req in
  match Hashtbl.find locked fname with
  | Some el -> Server.respond_string ~status:`Conflict ~body:"" ()
  | None ->
    forward_to_others ips (`Other "LOCK") (Request.make ~meth:(`Other "LOCK") (Request.uri req)) body
    >>= fun (response, res_body) ->
      match Response.status response with
      | `OK ->
        (try_lwt (
          Lwt_io.with_file ~flags:[Unix.O_WRONLY; Unix.O_CREAT] ~mode:Lwt_io.output fname (fun ch ->
            Lwt_io.write ch ""
            >|= fun () -> (response, res_body)
          )
        ) with
        | e -> critical_error e)
      (* Not_found is returned by forward_to_others when no hosts said OK *)
      | `Conflict | `Not_found -> Server.respond_string ~status:`Conflict ~body:"" ()
      | _ -> Server.respond_string ~status:`Internal_server_error ~body:(Response.sexp_of_t response |> Sexp.to_string) ()

let put req body =
  let filename = get_filename req in
  let flags = [Unix.O_WRONLY; Unix.O_TRUNC] in
  let mode = Lwt_io.output in
  try_lwt (
    Lwt_io.with_file ~flags ~mode filename (Fn.flip Cohttp_lwt_body.write_body body <*> Lwt_io.write)
    >>= fun () ->
        Server.respond_string ~status:`OK ~body:"" ()
  ) with
  | Unix.Unix_error (Unix.ENOENT, _, _) ->
    unimplemented "PUT Forward\n"
  | e -> critical_error e

let delete ips req body =
  unimplemented "DELETE"

let callback ips _ req body =
  try_lwt (
    match Request.meth req with
    | `GET -> get ips req body
    | `Other "LOCK" -> lock ips req body
    | `POST -> Lwt.pick [post ips req body; Lwt_unix.timeout lock_timeout >>= fun () -> critical_error (Failure "Timeout while acquiring lock")]
    | `PUT -> put req body
    | `DELETE -> delete ips req body
    | meth -> unimplemented ("Method unimplemented: " ^ Cohttp.Code.string_of_method meth)
  ) with
  | e -> critical_error e

let make_server ips () =
  let ctx = Cohttp_lwt_unix_net.init () in
  let mode = `TCP (`Port 2020) in
  let config_tcp = Server.make ~callback:(callback ips) () in
  Server.create ~ctx ~mode config_tcp
