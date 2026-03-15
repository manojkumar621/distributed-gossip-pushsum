import gleam/list
import gleam/string

pub type Topology {
  Full
  Line
  Grid3D
  ImperfectGrid3D
}

pub fn parse_topology(s: String) -> Result(Topology, String) {
  case string.lowercase(s) {
    "full" -> Ok(Full)
    "line" -> Ok(Line)
    "3d" -> Ok(Grid3D)
    "imp3d" -> Ok(ImperfectGrid3D)
    other -> Error("unknown topology: " <> other)
  }
}

/// Build neighbors for node ids 0..n-1
pub fn build_neighbors(n: Int, topo: Topology) -> List(List(Int)) {
  case topo {
    Full -> full_neighbors(n)
    Line -> line_neighbors(n)
    Grid3D -> grid3d_neighbors(n, False)
    ImperfectGrid3D -> grid3d_neighbors(n, True)
  }
}

fn full_neighbors(n: Int) -> List(List(Int)) {
  let ids = list.range(0, n - 1)
  list.map(ids, fn(i) {
    list.filter(ids, fn(j) { j != i })
  })
}

fn line_neighbors(n: Int) -> List(List(Int)) {
  list.range(0, n - 1)
  |> list.map(fn(i) {
    let left =
      case i > 0 {
        True -> [i - 1]
        False -> []
      }

    let right =
      case i < n - 1 {
        True -> [i + 1]
        False -> []
      }

    // concatenate: left ++ right  ->  list.append(left, right)
    list.append(left, right)
  })
}

/// Find smallest l such that l^3 >= n
fn cube_side_for(n: Int) -> Int {
  cube_side_for_go(n, 1)
}

fn cube_side_for_go(n: Int, l: Int) -> Int {
  case l * l * l >= n {
    True -> l
    False -> cube_side_for_go(n, l + 1)
  }
}

fn idx(x: Int, y: Int, z: Int, l: Int) -> Int {
  x * l * l + y * l + z
}

fn in_bounds(x: Int, y: Int, z: Int, l: Int) -> Bool {
  x >= 0 && x < l && y >= 0 && y < l && z >= 0 && z < l
}

fn grid3d_neighbors(n: Int, imperfect: Bool) -> List(List(Int)) {
  let l = cube_side_for(n)

  list.range(0, n - 1)
  |> list.map(fn(i) {
    let x = i / { l * l }
    let y = { i / l } % l
    let z = i % l

    let base =
      [
        #(x - 1, y, z), #(x + 1, y, z),
        #(x, y - 1, z), #(x, y + 1, z),
        #(x, y, z - 1), #(x, y, z + 1),
      ]
      |> list.filter(fn(p) {
        let #(a, b, c) = p
        in_bounds(a, b, c, l)
      })
      |> list.map(fn(p) {
        let #(a, b, c) = p
        idx(a, b, c, l)
      })
      |> list.filter(fn(j) { j < n })

    case imperfect {
      False -> base
      True -> add_extra_neighbor(i, n, base)
    }
  })
}

fn add_extra_neighbor(i: Int, n: Int, neigh: List(Int)) -> List(Int) {
  case n <= 1 {
    True -> neigh
    False -> {
      let cand1 = {i + 7} % n
      case cand1 != i {
        True -> {
          case list.contains(neigh, cand1) {
            True -> {
              let cand2 = {i + 13} % n
              case cand2 != i {
                True -> {
                  case list.contains(neigh, cand2) {
                    True -> neigh
                    False -> list.append(neigh, [cand2])
                  }
                }
                False -> neigh
              }
            }
            False -> list.append(neigh, [cand1])
          }
        }
        False -> {
          let cand2 = {i + 13} % n
          case cand2 != i {
            True -> {
              case list.contains(neigh, cand2) {
                True -> neigh
                False -> list.append(neigh, [cand2])
              }
            }
            False -> neigh
          }
        }
      }
    }
  }
}
