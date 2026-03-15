# Project 2 — Gossip Protocol & Push-Sum Algorithms on Different Topologies (Gleam Actors)

## Team Members
- Manoj Kumar Galla (UFID: 81687436)  
- Vandana Cendrollu Nagesh (UFID: 46498764) 

## Abstract
Implements **Asynchronous Gossip** (info propagation) and **Push–Sum** (aggregate sum) using the actor model in Gleam/Erlang. Includes four topologies (full, line, 3D grid, imperfect 3D grid), CLI per the spec, and prints **convergence time** in milliseconds.


## What is Working
- Implemented **actor-based simulation** of both **Gossip** and **Push-Sum** algorithms.  
- Supported **topologies**:
  - Full Network
  - Line
  - 2D Grid
  - Imperfect 2D Grid
- Gossip converges successfully up to **~500–1500 nodes** depending on topology.  
- Push-Sum converges for smaller networks (≤100 nodes depending on topology), but scaling remains challenging due to floating-point precision and message propagation delays.  

---

## Largest Network Sizes Managed

| Algorithm  | Topology     | Max Nodes Tested (Converged) | Approx. Convergence Time  |
|------------|--------------|------------------------------|---------------------------|
| Gossip     | Full         | 1500                         | ~40–45 ms                 |
| Gossip     | Line         | 100000                       | ~770 ms                   |
| Gossip     | 3d           | 50000                        | ~330 ms                   |
| Gossip     | Imp 3d       | 50000                        | ~400 ms                   |
| Push-Sum   | Full         | 500                          | ~200-300 ms (unstable)    |
| Push-Sum   | Line         | 300                          | >700 ms (often diverges)  |
| Push-Sum   | 3d           | 3000                         | ~300-350 ms               |
| Push-Sum   | Imp 3d       | 5000                         | ~600 ms                   |

## How to Run
gleam build
gleam deps download
```bash
gleam run -- <numNodes> <topology> <algorithm>
```

## Build & Run Examples
```bash
gleam run 1000 full gossip
```
```bash
gleam run 2000 imp3D push-sum
```
