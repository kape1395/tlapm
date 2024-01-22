open Tlapm_lsp_prover

type t = Proved | Failed | Omitted | Missing | Pending | Progress

let of_tlapm_obl_state = function
  | ToolboxProtocol.ToBeProved -> Progress
  | ToolboxProtocol.BeingProved -> Pending
  | ToolboxProtocol.Normalized -> Progress
  | ToolboxProtocol.Proved -> Proved
  | ToolboxProtocol.Failed -> Failed
  | ToolboxProtocol.Interrupted -> Failed
  | ToolboxProtocol.Trivial -> Proved
  | ToolboxProtocol.Unknown _ -> Failed

let to_string = function
  | Proved -> "proved"
  | Failed -> "failed"
  | Omitted -> "omitted"
  | Missing -> "missing"
  | Pending -> "pending"
  | Progress -> "progress"

let to_message = function
  | Failed -> "Proof failed."
  | Missing -> "Proof missing."
  | Omitted -> "Proof omitted."
  | Progress -> "Proving in progress."
  | Pending -> "Proof pending."
  | Proved -> "Proof checked successfully."

let to_order = function
  | Failed -> 0
  | Missing -> 1
  | Omitted -> 2
  | Progress -> 3
  | Pending -> 4
  | Proved -> 5

let of_order = function
  | 0 -> Failed
  | 1 -> Missing
  | 2 -> Omitted
  | 3 -> Progress
  | 4 -> Pending
  | 5 -> Proved
  | _ -> failwith "Impossible order"

let top = Proved
let min a b = of_order (min (to_order a) (to_order b))
let yojson_of_t t = `String (to_string t)

let is_diagnostic = function
  | Failed -> true
  | Missing -> false
  | Omitted -> false
  | Progress -> false
  | Pending -> false
  | Proved -> false