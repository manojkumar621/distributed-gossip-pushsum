import gleam/otp/actor
import gleam/erlang/process as process
import gleam/option
import gleam/list
import coordinator

pub type Msg {
  SetNeighbors(List(process.Subject(Msg)))
  SetCoordinator(process.Subject(coordinator.Message))
  Rumor
}

type State {
  State(
    id: Int,
    heard: Int,
    threshold: Int,
    neighbors: List(process.Subject(Msg)),
    coord: option.Option(process.Subject(coordinator.Message)),
    next_idx: Int,
  )
}

const fanout = 5 // send to up to 5 neighbors per receive

pub fn start_node(id: Int, threshold: Int) -> process.Subject(Msg) {
  let assert Ok(started) =
    actor
      .new(State(id, 0, threshold, [], option.None, 0))
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

    Rumor -> {
      let new_heard = s.heard + 1

      case new_heard >= s.threshold {
        True -> {
          // Notify convergence once
          case s.coord {
            option.Some(c) -> process.send(c, coordinator.NodeDone(s.id))
            option.None -> Nil
          }
          actor.continue(State(..s, heard: new_heard))
        }

        False -> {
          let n = list.length(s.neighbors)
          case n == 0 {
            True -> actor.continue(State(..s, heard: new_heard))
            False -> {
              // pick how many neighbors to send to
              let to_send =
                case fanout < n {
                  True -> fanout
                  False -> n
                }

              send_round_robin(s.neighbors, s.next_idx, to_send)
              actor.continue(
                State(..s, heard: new_heard, next_idx: s.next_idx + to_send),
              )
            }
          }
        }
      }
    }
  }
}

fn send_round_robin(
  neighs: List(process.Subject(Msg)),
  start_idx: Int,
  count: Int,
) -> Nil {
  send_rr_go(neighs, start_idx, count, count)
}

fn send_rr_go(
  neighs: List(process.Subject(Msg)),
  start_idx: Int,
  count: Int,
  k: Int,
) -> Nil {
  case k {
    0 -> Nil
    _ -> {
      let n = list.length(neighs)
      let idx = { start_idx + { count - k } } % n
      case nth(neighs, idx) {
        option.Some(p) -> process.send(p, Rumor)
        option.None -> Nil
      }
      send_rr_go(neighs, start_idx, count, k - 1)
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
