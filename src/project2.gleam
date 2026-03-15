import gleam/int
import gleam/string
import gleam/list
import gleam/result
import gleam/option
import gleam/io
import gleam/erlang/process as process

import topology
import coordinator
import gossip
import push_sum
import time
import argv

pub fn main() {
  case argv.load().arguments {
    [num_nodes_s, topo_s, algo_s] -> {
      let n = result.unwrap(int.parse(num_nodes_s), 0)
      case n > 0 {
        True -> run(n, topo_s, algo_s)
        False -> io.println("numNodes must be > 0")
      }
    }
    _ ->
      io.println("Usage: gleam run -- <numNodes> <topology> <algorithm>")
  }
}


fn run(n: Int, topo_s: String, algo_s: String) {
  let topo =
    case topology.parse_topology(topo_s) {
      Ok(t) -> t
      Error(e) -> {
        io.println(e)
        topology.Full
      }
    }

  let neighbors = topology.build_neighbors(n, topo)

  let start_ticks = time.system_time_native()
  let done_notify: process.Subject(Int) = process.new_subject()
  let coord = coordinator.start(n, start_ticks, done_notify)

  case string.lowercase(algo_s) {
    "gossip" -> start_gossip(n, neighbors, coord)
    "push-sum" -> start_push_sum(n, neighbors, coord)
    other -> io.println("Unknown algorithm: " <> other)
  }

  // Block until coordinator notifies completion (with elapsed ticks)
  let _ = process.receive(done_notify, within: 600_000)
  Nil
}

fn start_gossip(n: Int, neighbors: List(List(Int)), coord: process.Subject(coordinator.Message)) {
  let threshold = 10

  // Spawn nodes
  let nodes: List(process.Subject(gossip.Msg)) =
    list.range(0, n - 1)
    |> list.map(fn(i) { gossip.start_node(i, threshold) })

  // Wire neighbors + coordinator
  list.range(0, n - 1)
  |> list.each(fn(i) {
    let ids = option.unwrap(nth(neighbors, i), [])
    let neigh_subjects =
      list.map(ids, fn(j) {
        option.unwrap(nth(nodes, j), process.new_subject())
      })

    let me = option.unwrap(nth(nodes, i), process.new_subject())
    process.send(me, gossip.SetNeighbors(neigh_subjects))
    process.send(me, gossip.SetCoordinator(coord))
  })

  // Seed rumor at node 0
  case nth(nodes, 0) {
    option.Some(s0) -> process.send(s0, gossip.Rumor)
    option.None -> Nil
  }
}

fn start_push_sum(n: Int, neighbors: List(List(Int)), coord: process.Subject(coordinator.Message)) {
  // Spawn nodes
  let nodes: List(process.Subject(push_sum.Msg)) =
    list.range(0, n - 1)
    |> list.map(fn(i) { push_sum.start_node(i) })

  // Wire neighbors + coordinator
  list.range(0, n - 1)
  |> list.each(fn(i) {
    let ids = option.unwrap(nth(neighbors, i), [])
    let neigh_subjects =
      list.map(ids, fn(j) {
        option.unwrap(nth(nodes, j), process.new_subject())
      })

    let me = option.unwrap(nth(nodes, i), process.new_subject())
    process.send(me, push_sum.SetNeighbors(neigh_subjects))
    process.send(me, push_sum.SetCoordinator(coord))
  })

  // Kick off at node 0
  case nth(nodes, 0) {
    option.Some(s0) -> process.send(s0, push_sum.Start)
    option.None -> Nil
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
