import gleam/otp/actor
import gleam/erlang/process as process
import gleam/option
import gleam/float
import gleam/int
import gleam/list

import coordinator

pub type Msg {
  SetNeighbors(List(process.Subject(Msg)))
  SetCoordinator(process.Subject(coordinator.Message))
  Start
  Pair(Float, Float)
}

type State {
  State(
    id: Int,
    s: Float,
    w: Float,
    prev_ratio: Float,
    stable_count: Int,
    neighbors: List(process.Subject(Msg)),
    coord: option.Option(process.Subject(coordinator.Message)),
    converged: Bool,
    notified: Bool, // notify the coordinator once
    next_idx: Int,  // round-robin pointer into neighbors
  )
}

// Slightly looser for tiny graphs
const epsilon = 1.0e-8

pub fn start_node(id: Int) -> process.Subject(Msg) {
  let s0 = int.to_float(id + 1)
  let assert Ok(started) =
    actor
      .new(State(id, s0, 1.0, s0, 0, [], option.None, False, False, 0))
      |> actor.on_message(handle)
      |> actor.start

  started.data
}

fn handle(s: State, msg: Msg) -> actor.Next(State, Msg) {
  case msg {
    SetNeighbors(ns) ->
      actor.continue(State(..s, neighbors: ns))

    SetCoordinator(c) ->
      actor.continue(State(..s, coord: option.Some(c)))

    Start ->
      // Kick off: send once even without incoming mass
      actor.continue(send_half_rr(s))

    Pair(rs, rw) -> {
      // absorb incoming
      let s1 = State(..s, s: s.s +. rs, w: s.w +. rw)
      let ratio = s1.s /. s1.w
      let diff = float.absolute_value(ratio -. s1.prev_ratio)
      let new_count =
        case diff <. epsilon {
          True -> s1.stable_count + 1
          False -> 1
        }
      let s2 = State(..s1, prev_ratio: ratio, stable_count: new_count)

      // If stable, notify once but KEEP RELAYING so others can converge
      let s3 =
        case new_count >= 3 {
          True ->
            case s2.notified {
              True -> s2
              False -> {
                case s2.coord {
                  option.Some(c) -> process.send(c, coordinator.NodeDone(s2.id))
                  option.None -> Nil
                }
                State(..s2, converged: True, notified: True)
              }
            }
          False -> s2
        }

      actor.continue(send_half_rr(s3))
    }
  }
}

// Round-robin: send half to neighbors[next_idx % len], then advance pointer
fn send_half_rr(s: State) -> State {
  let n = list.length(s.neighbors)
  case n {
    0 -> s
    _ -> {
      let idx = s.next_idx % n
      let next_ptr = s.next_idx + 1

      let target =
        case nth(s.neighbors, idx) {
          option.Some(p) -> p
          option.None -> // fallback to first if out-of-bounds somehow
            case nth(s.neighbors, 0) {
              option.Some(p0) -> p0
              option.None -> process.new_subject() // unreachable if n>0
            }
        }

      let half_s = s.s /. 2.0
      let half_w = s.w /. 2.0
      let s2 = State(..s, s: half_s, w: half_w, next_idx: next_ptr)
      process.send(target, Pair(half_s, half_w))
      s2
    }
  }
}

fn nth(a: List(a), i: Int) -> option.Option(a) {
  case a {
    [] -> option.None
    [h, ..t] ->
      case i {
        0 -> option.Some(h)
        _ -> nth(t, i - 1)
      }
  }
}
