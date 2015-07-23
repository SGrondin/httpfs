open Core.Std
open Lwt

(* Force usage of libev *)
(* let () = Lwt_engine.set ~transfer:true ~destroy:true (new Lwt_engine.libev) *)

(* Replace the default uncaught exception hook with one that doesn't quit *)
let () = Lwt.async_exception_hook := fun ex -> print_endline (Exn.to_string ex)

let default_port = 2020

let format_ips =
  List.map ~f:(fun str ->
    String.split ~on:':' str
    |> function
    | host :: port :: [] -> Uri.make ~scheme:"http" ~host ~port:(Int.of_string port) ()
    | host :: [] -> Uri.make ~scheme:"http" ~host ~port:default_port ()
    | _ -> failwith ("The command-line argument is not a valid IP: " ^ str)
  )

let command =
  Command.basic
    ~summary:"Synchronized distributed Git filesystem"
    Command.Spec.(
      empty
      +> anon (sequence ("cluster IPs" %: string))
      +> flag "-p" (optional int) ~doc:"port number"
    ) (fun ips port () ->
      Lwt_unix.run (
          Http.make_server ~port:(Option.value ~default:default_port port)
          (format_ips ips) ()
      )
    )

let () = Command.run ~version:"0.0.1" ~build_info:"github.com/SGrondin/git-fs" command
