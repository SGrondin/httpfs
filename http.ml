open Core.Std
open Lwt
open Cohttp_lwt_unix

type http_response = Response.t * Cohttp_lwt_body.t
type http_request = Request.t * Cohttp_lwt_body.t
type request_handler = Uri.t list -> http_request -> http_response Lwt.t
type servers = Uri.t list

let (<*>) f g x = f (g x)
let locked = Hashtbl.create ~hashable:String.hashable ()
let lock_timeout = 1.5

let get_filename req =
  let path = Uri.path (Request.uri req) in
  Sys.getcwd () ^ path

let critical_error e =
  let body = Exn.to_string_mach e in
  print_endline body;
  Server.respond_string ~status:`Internal_server_error ~body ()

let conflict = Server.respond_string ~status:`Conflict ~body:""
let not_found = Server.respond_string ~status:`Not_found ~body:""
let ok = Server.respond_string ~status:`OK ~body:""

let forward_to_others ips meth (req, body) =
  match Cohttp.Header.get (Request.headers req) "forwarded" with
  | Some _ -> None
  | None -> Some (
    Lwt_list.map_p (fun remote ->
      let uri = Request.uri req
      |> Fn.flip Uri.with_scheme (Uri.scheme remote)
      |> Fn.flip Uri.with_host (Uri.host remote)
      |> Fn.flip Uri.with_port (Uri.port remote)
      in
      let original_headers = Request.headers req in
      let headers = Cohttp.Header.init ()
      |> fun h -> Option.value_map ~default:h ~f:(fun _ -> Cohttp.Header.add h "is-directory" "true") (Cohttp.Header.get original_headers "is-directory")
      |> fun h -> Cohttp.Header.add h "forwarded" "true"
      in
      Client.call ~headers ~body ~chunked:false meth uri
    ) ips)

let only_one_response ls =
  List.filter ~f:(function (resp, _) -> Response.status resp = `OK) ls
  |> function
  | [] -> not_found ()
  | x :: [] -> return x
  | xs ->
    let xs' = List.map ~f:(Sexp.to_string <*> Response.sexp_of_t <*> fst) xs in
    critical_error (Failure (List.to_string ~f:Fn.id xs'))

let get ips (req, body) =
  let add_trailing_slash_if_directory root filename =
    Lwt_unix.stat (root ^ "/" ^ filename)
    >|= (fun stats ->
      match stats.Lwt_unix.st_kind with
      | Unix.S_DIR -> filename ^ "/"
      | _ -> filename)
  in
  let get_directory_content path =
    Lwt_unix.files_of_directory path
    |> Lwt_stream.map_s (add_trailing_slash_if_directory path)
    |> Lwt_stream.to_list
  in
  let fname = get_filename req in
  try_lwt (
    Lwt_unix.stat fname
    >>= fun stats ->
      match Lwt_unix.(stats.st_kind) with
      | Unix.S_DIR ->
        Option.value ~default:(return []) (forward_to_others ips `GET (req, body))
        >>= fun contents ->
          if List.for_all ~f:((List.mem [`OK; `Not_found]) <*> Response.status <*> fst) contents then
            (get_directory_content fname
            >>= (fun local_content ->
                Lwt_list.map_p (Cohttp_lwt_body.to_string <*> snd) contents
                >|= (List.join <*> List.map ~f:String.split_lines)
                >|= List.append local_content
                >|= List.dedup ~compare:String.compare
                >|= List.fold ~init:"" ~f:(fun acc -> fun file -> file ^ "\n" ^ acc))
            >>= fun body -> Server.respond_string
              ~headers:(Cohttp.Header.init_with "is-directory" "true")
              ~status:`OK
              ~body
              ())
          else
            let contents' =
              List.map ~f:(Sexp.to_string <*> Response.sexp_of_t <*> fst) contents
            in
            critical_error (Failure (List.to_string ~f:Fn.id contents'))
      | Unix.S_REG | Unix.S_LNK -> Server.respond_file ~fname ()
      | _ -> critical_error (Failure "Unsupported file kind")
  ) with
  | Unix.Unix_error (Unix.ENOENT, _, _) ->
      Option.value_map
        ~default:(not_found ())
        ~f:(Fn.flip Lwt.bind only_one_response)
        (forward_to_others ips `GET (req, body))
  | e -> critical_error e

let path_exists fname =
  try_lwt (
    Lwt_unix.stat fname >|= fun _ -> Ok false
  ) with
  | Unix.Unix_error (Unix.ENOENT, _, _) -> return (Ok true)
  | e -> return (Error e)

let lock ips (req, body) =
  let fname = get_filename req in
  path_exists fname >>= function
  | Ok true -> conflict ()
  | Ok false ->
    Hashtbl.set locked fname true;
    ignore (Lwt_unix.timeout lock_timeout >|= fun () -> Hashtbl.remove locked fname);
    ok ()
  | Error e -> critical_error e

let post ips (req, body) =
  let fname = get_filename req in
  match Hashtbl.find locked fname with
  | Some el -> conflict ()
  | None ->
    path_exists fname >>= function
    | Ok true -> conflict ()
    | Error e -> critical_error e
    | Ok false ->
      let headers = Option.value_map ~default:(Cohttp.Header.init ())
        ~f:(fun _ -> Cohttp.Header.init_with "is-directory" "true") (Cohttp.Header.get (Request.headers req) "is-directory") in
      let lock_request = ((Request.make ~meth:(`Other "LOCK") ~headers (Request.uri req)), body) in
      match forward_to_others ips (`Other "LOCK") lock_request with
      | None -> critical_error (Failure "Impossible case, LOCK cannot be forwarded")
      | Some x ->
        x >>= fun responses ->
          if List.for_all ~f:((=) `OK <*> Response.status <*> fst) responses then
            (try_lwt (
              Lwt_io.with_file ~flags:[Unix.O_WRONLY; Unix.O_CREAT] ~mode:Lwt_io.output fname (fun ch ->
                Lwt_io.write ch "" >>= ok
              )
            ) with e -> critical_error e)
          else conflict ()

let put ips (req, body) =
  let filename = get_filename req in
  let flags = [Unix.O_WRONLY; Unix.O_TRUNC] in
  let mode = Lwt_io.output in
  try_lwt (
    Lwt_io.with_file ~flags ~mode filename (Fn.flip Cohttp_lwt_body.write_body body <*> Lwt_io.write)
    >>= ok
  ) with
  | Unix.Unix_error (Unix.ENOENT, _, _) ->
    Option.value_map
      ~default:(not_found ())
      ~f:(Fn.flip Lwt.bind only_one_response)
      (forward_to_others ips `PUT (req, body))
  | e -> critical_error e

let delete ips (req, body) =
  let filename = get_filename req in
  try_lwt (
    (Option.value_map (Cohttp.Header.get (Request.headers req) "is-directory")
      ~default:Lwt_unix.unlink ~f:(fun _ -> Lwt_unix.rmdir)) filename >>= ok
  ) with
  | Unix.Unix_error (Unix.ENOENT, _, _) ->
    Option.value_map
      ~default:(not_found ())
      ~f:(Fn.flip Lwt.bind only_one_response)
      (forward_to_others ips `DELETE (req, body))
  | e -> critical_error e

let callback _ ips ((req, _) as http_request) =
  try_lwt (
    ignore (Lwt_io.printf "%s %s\n%s"
      (Cohttp.Code.string_of_method (Request.meth req))
      (Uri.to_string (Request.uri req))
      (String.concat ~sep:"\n" (Cohttp.Header.to_lines (Request.headers req))));
    match Request.meth (fst http_request) with
    | `GET -> get ips http_request
    | `Other "LOCK" -> lock ips http_request
    | `POST -> Lwt.pick [post ips http_request; Lwt_unix.timeout lock_timeout >>= fun () -> critical_error (Failure "Timeout while acquiring lock")]
    | `PUT -> put ips http_request
    | `DELETE -> delete ips http_request
    | meth -> Server.respond_string ~status:`Method_not_allowed ~body:("Method unimplemented: " ^ Cohttp.Code.string_of_method meth) ()
  ) with e -> critical_error e

let make_server ~port ips () =
  let ctx = Cohttp_lwt_unix_net.init () in
  let mode = `TCP (`Port port) in
  let config_tcp =
    Server.make ~callback:(fun conn -> Tuple2.curry (callback conn ips)) ()
  in
  Server.create ~ctx ~mode config_tcp
