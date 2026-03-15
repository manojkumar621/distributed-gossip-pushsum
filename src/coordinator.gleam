import gleam/io
import gleam/erlang/process as process
import gleam/otp/actor
import time
import gleam/int

pub type Message {
  NodeDone(Int)
}

type State {
  State(
    total: Int,
    done_count: Int,
    start_ticks: Int,               // native unit ticks
    notify: process.Subject(Int),   // we’ll send the elapsed ticks to main
  )
}

/// Start coordinator; returns its Subject<Message>.
pub fn start(total_nodes: Int, start_ticks: Int, notify: process.Subject(Int)) ->
  process.Subject(Message)
{
  let assert Ok(started) =
    actor
      .new(State(total_nodes, 0, start_ticks, notify))
      |> actor.on_message(handle)
      |> actor.start

  started.data
}

fn handle(s: State, msg: Message) -> actor.Next(State, Message) {
  case msg {
    NodeDone(_) -> {
      let new_done = s.done_count + 1

      case new_done == s.total {
        True -> {
          let elapsed = time.system_time_native() - s.start_ticks
          // Print elapsed ticks (native Erlang unit). If you later wire up
          // convert_time_unit to ms, print that instead to match your spec.
          io.println(int.to_string(elapsed))
          process.send(s.notify, elapsed)
          actor.stop()
        }
        False ->
          actor.continue(State(..s, done_count: new_done))
      }
    }
  }
}
