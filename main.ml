open Core.Std
open Lwt

(* Force usage of libev *)
(* let () = Lwt_engine.set ~transfer:true ~destroy:true (new Lwt_engine.libev) *)

(* Replace the default uncaught exception hook with one that doesn't quit *)
let () = Lwt.async_exception_hook := fun ex -> print_endline (Exn.to_string ex)

let command =
  Command.basic
    ~summary:"Synchronized distributed Git filesystem"
    Command.Spec.(
      empty
      +> anon (sequence ("cluster IPs" %: string))
      +> flag "-p" (optional int) ~doc:"port number"
      +> flag "-d" (optional string) ~doc:" join an existing cluster"
    ) (fun ips_str port_opt discover () ->
      Lwt_unix.run (
        let port = Option.value ~default:Http.default_port port_opt in
        Option.value_map
          ~default:(return (Http.format_ips ips_str))
          ~f:Http.discovery_startup
          discover
        >>= fun ips ->
          Http.make_server ~port ips ()
      )
    )

let () = Command.run ~version:"0.0.1" ~build_info:"github.com/SGrondin/git-fs" command
