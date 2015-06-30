open Core.Std
open Lwt
open Lwt_unix
open Unix

let exec cmd =
  let parsed = String.split ~on:' ' cmd
  |> function
  | [] -> failwith "Command can't be empty"
  | hd::_ as ll -> (hd, (List.to_array ll))
  in
  Lwt_process.with_process_full parsed (fun proc ->
  proc#status >>= function
  | WEXITED s | WSIGNALED s | WSTOPPED s ->
    Lwt_io.read_lines proc#stdout
    |> Lwt_stream.to_list
    >|= fun lines ->
      let output = String.concat ~sep:"\n" lines in
      (Int.to_int s, output)
  )
