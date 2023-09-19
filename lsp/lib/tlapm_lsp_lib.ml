(** Here we construct a decoder/encoder for the LSP protocol on top of Eio flows. *)
module EioLspCodec : sig
  type 'a io_res = IoOk of 'a | IoErr of exn

  val read : Eio.Buf_read.t -> Jsonrpc.Packet.t option io_res
  val write : Eio.Buf_write.t -> Jsonrpc.Packet.t -> unit io_res
end = struct
  type 'a io_res = IoOk of 'a | IoErr of exn

  module IoState = struct
    type 'a t = 'a io_res

    let return x = IoOk x
    let raise exn = IoErr exn

    module O = struct
      let ( let+ ) st f =
        match st with IoOk a -> IoOk (f a) | IoErr exn -> IoErr exn

      let ( let* ) st f = match st with IoOk a -> f a | IoErr exn -> IoErr exn
    end
  end

  module IoChan = struct
    type output = Eio.Buf_write.t
    type input = Eio.Buf_read.t

    let read_line (buf : input) : string option IoState.t =
      let line = Eio.Buf_read.line buf in
      IoOk (Some line)

    let read_exactly (buf : input) (n : int) : string option IoState.t =
      let data = Eio.Buf_read.take n buf in
      IoOk (Some data)

    let rec write (buf : output) (lines : string list) : unit IoState.t =
      match lines with
      | [] -> IoOk ()
      | line :: tail ->
          let () = Eio.Buf_write.string buf line in
          write buf tail
  end

  module LspIo = Lsp.Io.Make (IoState) (IoChan)

  let read = LspIo.read
  let write = LspIo.write
end

(** Here we serve the LSP RPC over TCP. *)
module EioLspServer : sig
  val run : Eio_unix.Stdenv.base -> string Eio.Std.Promise.t -> unit
end = struct
  (* // TODO: curl -vvv -X POST -H 'Content-Type: application/vscode-jsonrpc; charset=utf-8' -d '{"jsonrpc": "2.0", "id": 1, "method": "textDocument/completion", "params": { }}' http://localhost:8080/ *)
  let lsp_packet_handler (packet : Jsonrpc.Packet.t) write_fun =
    Eio.traceln "Got LSP Packet";
    write_fun packet (* // TODO: That's just echo. *)

  let rec lsp_stream_handler buf_r buf_w =
    let open EioLspCodec in
    let write_fun out_packet =
      match write buf_w out_packet with
      | IoOk () -> Eio.Buf_write.flush buf_w
      | IoErr exn ->
          Eio.traceln "IO Error reading packet: %s" (Printexc.to_string exn)
    in
    match read buf_r with
    | IoOk (Some packet) ->
        lsp_packet_handler packet write_fun;
        lsp_stream_handler buf_r buf_w
    | IoOk None -> Eio.traceln "No packet was read."
    | IoErr exn ->
        Eio.traceln "IO Error reading packet: %s" (Printexc.to_string exn)

  let err_handler = Eio.traceln "Error handling connection: %a" Fmt.exn

  let req_handler flow _addr =
    Eio.traceln "Server: got connection from client";
    let buf_r = Eio.Buf_read.of_flow flow ~max_size:1024 in
    Eio.Buf_write.with_flow flow @@ fun buf_w -> lsp_stream_handler buf_r buf_w

  let switch (net : 'a Eio.Net.ty Eio.Std.r) port stop_promise sw =
    Eio.traceln "Switch started";
    let addr = `Tcp (Eio.Net.Ipaddr.V4.loopback, port) in
    let sock = Eio.Net.listen net ~sw ~reuse_addr:true ~backlog:5 addr in
    let stopResult =
      Eio.Net.run_server sock req_handler ~on_error:err_handler
        ?stop:(Some stop_promise)
    in
    Eio.traceln "StopResult=%s" stopResult

  let run env stop_promise =
    let net = Eio.Stdenv.net env in
    let port = 8080 in
    Eio.Switch.run @@ switch net port stop_promise
end
