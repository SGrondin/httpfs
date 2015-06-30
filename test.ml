open Core.Std
open Lwt
open Unix

let main () =
  Lwt_process.with_process_full ("cat", [|"cat"; "test.ml"|]) (fun proc ->
    ignore (proc#status >|= function
    | WEXITED s | WSIGNALED s | WSTOPPED s -> print_endline @@ Int.to_string s);

    Lwt_io.read_lines proc#stdout
    |> Lwt_stream.to_list
    >|= fun x ->
      String.concat ~sep:"\n" x
      |> print_endline;
      x
  ) >|= fun x ->
    print_endline "Done"


let () = Lwt_unix.run @@ main ()
