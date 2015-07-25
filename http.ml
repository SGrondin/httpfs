open Core.Std
open Lwt
open Cohttp_lwt_unix

module Body = Cohttp_lwt_body
type http_response = Response.t * Body.t
type http_request = Request.t * Body.t
type request_handler = Uri.t list -> http_request -> http_response Lwt.t
type servers = Uri.t list

let (<*>) f g x = f (g x)
let default_port = 2020
let locked = Hashtbl.create ~hashable:String.hashable ()
let lock_timeout = 1.5
let known_servers = ref []

let get_filename req =
  let path = Uri.path (Request.uri req) in
  Sys.getcwd () ^ path

let critical_error e =
  let body = Exn.to_string_mach e in
  ignore (Lwt_io.printl body);
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
                Lwt_list.map_p (Body.to_string <*> snd) contents
                >|= (List.fold ~init:"" ~f:(fun acc -> fun file -> file ^ "\n" ^ acc)
                  <*> List.dedup ~compare:String.compare
                  <*> List.append local_content
                  <*> List.join
                  <*> List.map ~f:String.split_lines))
            >>= fun body -> Server.respond_string
              ~headers:(Cohttp.Header.init_with "is-directory" "true")
              ~status:`OK ~body ())
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
    Lwt_unix.stat fname >|= fun _ -> Ok true
  ) with
  | Unix.Unix_error (Unix.ENOENT, _, _) -> return (Ok false)
  | e -> return (Error e)

let lock ips (req, body) =
  let fname = get_filename req in
  path_exists fname >>= function
  | Ok true -> conflict ()
  | Ok false ->
    Hashtbl.set locked fname true;
    ignore (Lwt_preemptive.detach (fun () -> Unix.sleep 1; Hashtbl.remove locked fname) ());
    ok ()
  | Error e -> critical_error e

let post ips (req, body) =
  let fname = get_filename req in
  let is_dir = Option.is_some (Cohttp.Header.get (Request.headers req) "is-directory") in
  let create_exn chunks =
    Lwt_list.fold_left_s (fun (acc, i) chunk ->
      if chunk = "" then return (acc, (i+1)) else (* Ignore consecutive slashes *)
      let added = chunk :: acc in
      let partial_name = String.concat ~sep:"/" (List.rev added) in
      try_lwt (
        if (is_dir || (List.length chunks) <> i) then (* Create a directory *)
          Lwt_unix.mkdir partial_name 493 >|= fun () -> (added, (i+1)) (* octal 755 = decimal 493 *)
        else (* Create a file *)
          Lwt_io.with_file ~flags:[Unix.O_WRONLY; Unix.O_CREAT] ~mode:Lwt_io.output partial_name (fun ch ->
            Lwt_io.write ch "" >|= fun () -> (added, (i+1))
          )
      ) with
      | Unix.Unix_error (Unix.EEXIST, _, _) -> return (added, (i+1))
      | e -> raise e
    ) ([], 1) chunks
  in
  match Hashtbl.find locked fname with
  | Some el -> conflict ()
  | None ->
    path_exists fname >>= function
    | Ok true -> conflict ()
    | Error e -> critical_error e
    | Ok false ->
      let headers = if is_dir then Cohttp.Header.init_with "is-directory" "true"
        else Cohttp.Header.init () in
      let lock_request = ((Request.make ~headers (Request.uri req)), body) in
      match forward_to_others ips (`Other "LOCK") lock_request with
      | None -> critical_error (Failure "Impossible case, LOCK cannot be forwarded")
      | Some x ->
        x >>= fun responses ->
          if List.for_all ~f:((=) `OK <*> Response.status <*> fst) responses then
            match Result.try_with (fun () -> create_exn (String.split ~on:'/' (Uri.path (Request.uri req)))) with
            | Ok _ -> ok ()
            | Error e -> critical_error e
          else conflict ()

let put ips (req, body) =
  let filename = get_filename req in
  let flags = [Unix.O_WRONLY; Unix.O_TRUNC] in
  let mode = Lwt_io.output in
  try_lwt (
    Lwt_io.with_file ~flags ~mode filename (Fn.flip Body.write_body body <*> Lwt_io.write)
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

let format_ips =
  List.map ~f:(fun str ->
    String.split ~on:':' str
    |> function
    | "http" :: host :: port :: [] -> Uri.make ~scheme:"http" ~host:(String.strip ~drop:((=) '/') host) ~port:(Int.of_string port) ()
    | host :: port :: [] -> Uri.make ~scheme:"http" ~host ~port:(Int.of_string port) ()
    | host :: [] -> Uri.make ~scheme:"http" ~host ~port:default_port ()
    | _ -> failwith ("The command-line argument is not a valid IP: " ^ str)
  )

let discover ips (req, body) =
  let body = String.concat ~sep:"\n" (List.map ~f:Uri.to_string ips) in
  Server.respond_string ~status:`OK ~body ()

let get_remote_uri ch body =
  let get_addr_from_ch = function
  | Conduit_lwt_unix.TCP {Conduit_lwt_unix.fd; _} -> begin (* Also contains ip and port *)
    match Lwt_unix.getpeername fd with
    | Lwt_unix.ADDR_INET (ia, _port) -> Ipaddr.to_string (Ipaddr_unix.of_inet_addr ia)
    | _ -> failwith "Not an IP socket" end
  | _ -> failwith "Not a TCP socket"
  in
  [get_addr_from_ch ch] |> format_ips |> List.hd |> function
  | None -> failwith "Could not extract raw IP from the socket"
  | Some remote_ip ->
    Body.to_string body >|= fun port ->
      Uri.with_port remote_ip (Some (Int.of_string port))

let hello ch ips (req, body) : http_response t =
  get_remote_uri ch body
  >>= fun remote_uri ->
    known_servers := List.append (!known_servers) [remote_uri];
    ok ()

let bye ch ips (req, body) =
  get_remote_uri ch body >>= fun remote_uri ->
    let string_remote = Uri.to_string remote_uri in
    known_servers := (List.filter_map
      ~f:(fun uri -> if (Uri.to_string uri) <> string_remote then (Some uri) else None)
      (!known_servers));
    ok ()

let disconnect port ips (req, body) =
  match forward_to_others ips (`Other "BYE") ((Request.make (Uri.make ())), (Body.of_string (Int.to_string port))) with
  | None -> failwith "Impossible case, BYE cannot be forwarded"
  | Some ls -> ls >>= fun responses ->
    let pair = if List.for_all ~f:((=) `OK <*> Response.status <*> fst) responses then ok ()
    else critical_error (Failure "Not all servers responded OK to the disconnect request. Cluster inconsistent.")
    in
    ignore (Lwt_preemptive.detach (fun () -> Unix.sleep 1; exit 0) ());
    pair

let callback ~port (ch, _) (_:servers) ((req, _) as http_request) =
  let ips = !known_servers in
  try_lwt (
    ignore (Lwt_io.printlf "%s %s\n%s\n-----------------"
      (Cohttp.Code.string_of_method (Request.meth req))
      (Uri.to_string (Request.uri req))
      (String.concat ~sep:"" (Cohttp.Header.to_lines (Request.headers req))));
    match Request.meth (fst http_request) with
    | `GET -> get ips http_request
    | `Other "LOCK" -> lock ips http_request
    | `POST -> Lwt.pick [post ips http_request; Lwt_unix.timeout lock_timeout >>= fun () -> critical_error (Failure "Timeout while acquiring lock")]
    | `PUT -> put ips http_request
    | `DELETE -> delete ips http_request
    | `Other "DISCOVER" -> discover ips http_request
    | `Other "HELLO" -> hello ch ips http_request
    | `Other "BYE" -> bye ch ips http_request
    | `Other "DISCONNECT" -> disconnect port ips http_request
    | meth -> Server.respond_string ~status:`Method_not_allowed ~body:("Method unimplemented: " ^ Cohttp.Code.string_of_method meth) ()
  ) with e -> critical_error e

let discovery_startup port ip_str =
  let uri = List.hd_exn (format_ips [ip_str]) in
  Client.call (`Other "DISCOVER") uri
  >>= (Body.to_string <*> snd)
  >|= (List.dedup <*> List.append [uri] <*> format_ips <*> String.split_lines)
  >>= fun ips ->
    ignore (Lwt_io.printlf "Joined %s" (List.map ~f:Uri.to_string ips |> String.concat ~sep:", "));
    match forward_to_others ips (`Other "HELLO") ((Request.make uri), (Body.of_string (Int.to_string port))) with
    | None -> failwith "Impossible case, HELLO cannot be forwarded"
    | Some ls -> ls >>= fun responses ->
      if List.for_all ~f:((=) `OK <*> Response.status <*> fst) responses then return ips
      else (
        ignore (Lwt_io.printl "Failed to join the cluster, attempting to disconnect cleanly...");
        disconnect port ips ((Request.make (Uri.make ())), (Body.of_string ""))
        >|= (Response.status <*> fst) >|= function
        | `OK -> []
        | _ -> failwith "Failed to disconnect cleanly. The cluster is inconsistent.")

let make_server ~port ips () =
  known_servers := ips;
  let ctx = Cohttp_lwt_unix_net.init () in
  let mode = `TCP (`Port port) in
  let config_tcp =
    Server.make ~callback:(fun conn -> Tuple2.curry (callback ~port conn ips)) ()
  in
  Server.create ~ctx ~mode config_tcp
