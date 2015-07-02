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
    ) (fun () ->
      Lwt_unix.run (
          
      )
    )

let () = Command.run ~version:"0.0.1" ~build_info:"github.com/SGrondin/git-fs" command
