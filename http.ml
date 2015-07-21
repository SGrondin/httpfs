open Core.Std
open Lwt
open Cohttp_lwt_unix

let default_port = 2020

let (<*>) f g x = f (g x)

let locked = Hashtbl.create ~hashable:String.hashable ()

let lock_timeout = 1.5

let get_filename req =
  let path = Uri.path (Request.uri req) in
  Sys.getcwd () ^ path

let unimplemented body = Server.respond_string ~status:`Method_not_allowed ~body ()

let critical_error e =
  let body = Exn.to_string_mach e in
  print_endline body;
  Server.respond_string ~status:`Internal_server_error ~body ()

let conflict () = Server.respond_string ~status:`Conflict ~body:"" ()

let forward_to_others ips meth req body =
  match Cohttp.Header.get (Request.headers req) "forwarded" with
  | Some _ ->
    Lwt.map (Fn.flip List.cons []) (Server.respond_string ~status:`Bad_request ~body:"" ())
  | None ->
    Lwt_list.map_p (fun uri ->
      let headers = Cohttp.Header.init_with "forwarded" "true" in
      Client.call ~headers ~body ~chunked:false meth uri
    ) ips
    >|= List.filter ~f:(function (resp, _) -> Response.status resp = `OK)

let only_one_response = function
  | [] -> Server.respond_string ~status:`Not_found ~body:"" ()
  | x :: [] -> return x
  | xs ->
    let xs' = List.map ~f:(Sexp.to_string <*> Response.sexp_of_t <*> fst) xs in
    critical_error (Failure (List.to_string ~f:Fn.id xs'))

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
    | `Not_found -> forward_to_others ips `GET req body >>= only_one_response
    | _ -> return resp)

let lock ips req body =
  let fname = get_filename req in
  try_lwt (
    Lwt_io.with_file ~flags:[Unix.O_RDONLY] ~mode:Lwt_io.input fname (fun _ -> conflict ())
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
  | Some el -> conflict ()
  | None ->
    forward_to_others ips (`Other "LOCK") (Request.make ~meth:(`Other "LOCK") (Request.uri req)) body
    >>= only_one_response
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
      (* Not_found is returned by only_one_response when no hosts said OK *)
      | `Conflict | `Not_found -> conflict ()
      | _ -> critical_error (Failure (Response.sexp_of_t response |> Sexp.to_string))

let put req body =
  let filename = get_filename req in
  let flags = [Unix.O_WRONLY; Unix.O_TRUNC] in
  let mode = Lwt_io.output in
  try_lwt (
    Lwt_io.with_file ~flags ~mode filename (Fn.flip Cohttp_lwt_body.write_body body <*> Lwt_io.write)
    >>= Server.respond_string ~status:`OK ~body:""
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

let format_ips raw =
  List.map ~f:(fun str ->
    String.split ~on:':' str
    |> function
    | host :: port :: [] -> Uri.make ~scheme:"http" ~host ~port:(Int.of_string port) ()
    | host :: [] -> Uri.make ~scheme:"http" ~host ~port:default_port ()
    | _ as arg -> failwith ("The command-line argument is not a valid IP: " ^ (String.concat ~sep:" " arg))
  ) raw

let make_server port ips () =
  let ctx = Cohttp_lwt_unix_net.init () in
  let mode = `TCP (`Port port) in
  let config_tcp = Server.make ~callback:(callback (format_ips ips)) () in
  Server.create ~ctx ~mode config_tcp
