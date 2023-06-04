let main fs =
  Tlapm_lib.main fs

let () = (* TODO: Handle it properly. *)
    let x = Setup_paths.Sites.backends in
    let _ = List.map (fun u -> (Printf.printf "TODO: path=%s\n" u)) x in
        Printf.printf("TODO: paths printed.\n")

exception Stacktrace;;

Sys.set_signal
    Sys.sigusr1
    (Sys.Signal_handle (fun _ -> raise Stacktrace));
Tlapm_lib.init ()
