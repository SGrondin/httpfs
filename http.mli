open Cohttp
open Cohttp_lwt_unix
open Core.Std

type http_response = Response.t * Cohttp_lwt_body.t
type http_request = Request.t * Cohttp_lwt_body.t
type request_handler = Uri.t list -> http_request -> http_response Lwt.t

val forward_to_others' :
  Uri.t list ->
  Code.meth ->
  http_request ->
  http_response list Lwt.t option

val only_one_response : http_response list -> http_response Lwt.t

val delete : request_handler
val get : request_handler
val lock : request_handler
val post : request_handler
val put : request_handler

val callback : 'a -> request_handler

val make_server : int -> Uri.t list -> unit -> unit Lwt.t
