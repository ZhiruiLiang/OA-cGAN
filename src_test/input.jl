# TYPE DEFINITIONS
mutable struct Traditional_Generator
   index::Any
   bus_idx::Int
   Pgmax::Float64
   Pgmin::Float64
   c0::Float64
   c1::Float64
   c2::Float64
   function Traditional_Generator(index, bus_idx, Pgmax, Pgmin, c0, c1, c2)
      g = new()
      g.index  = index
      g.bus_idx = bus_idx
      g.Pgmax = Pgmax
      g.Pgmin = Pgmin
      g.c0 = c0
      g.c1 = c1
      g.c2 = c2
      return g
   end
end

mutable struct Bus
   index::Any
   bus_idx::Int
   is_root::Bool
   inlist::Vector{Int}
   outlist::Vector{Int}
   generator::Vector{Int}
   function Bus(index, bus_idx, is_root)
      b = new()
      b.index = index
      b.bus_idx = bus_idx
      b.is_root = is_root
      b.inlist = Int[]
      b.outlist = Int[]
      b.generator = Int[]
      return b
   end
end

mutable struct Line
   index::Any
   from_node::Int
   to_node::Int
   b::Float64 # the susceptance value
   s_max::Float64 # the capacity of the line
   function Line(index, from_node, to_node, b, s_max)
      l = new()
      l.index = index
      l.from_node = from_node
      l.to_node = to_node
      l.b = b
      l.s_max = s_max
      return l
   end
end

mutable struct Topo
  buses::Array{Bus}
  lines::Array{Line}
  generators::Array{Traditional_Generator}
  n_buses::Int
  n_lines::Int
  n_generators::Int
  root_bus::Int
  function Topo(buses, lines, generators)
    f  = new()
    f.buses = buses
    f.lines = lines
    f.generators = generators
    f.n_buses = length(buses)
    f.n_lines = length(lines)
    f.n_generators = length(generators)
    for (i,b) in enumerate(buses)
      if b.is_root
        f.root_bus = i
        break
      end
    end
    return f
  end
end

function load_net(datadir)
  # READ RAW DATA
  #println(">>>>> Reading feeder data from $(datadir)")

  nodes_raw = CSV.read("$datadir/nodes.csv", DataFrame)
  sum(nonunique(nodes_raw, :index)) != 0 ? @warn("Ambiguous Node Indices") : nothing

  buses = []
  for n in 1:nrow(nodes_raw)
      index = nodes_raw[n, :index]
      bus_idx = nodes_raw[n, :bus_idx]
      is_root = nodes_raw[n, :is_root]
      newb = Bus(index, bus_idx, is_root)
      push!(buses, newb)
  end

  generators_raw = CSV.read("$datadir/generators.csv", DataFrame)
  sum(nonunique(generators_raw, :index)) != 0 ? @warn("Ambiguous Generator Indices") : nothing

  generators = []
  for g in 1:nrow(generators_raw)
      index = generators_raw[g, :index]
      bus_idx = generators_raw[g, :bus_idx]
      Pgmax = generators_raw[g, :pgmax]
      Pgmin = generators_raw[g, :pgmin]
      c0 = generators_raw[g, :c0]
      c1 = generators_raw[g, :c1]
      c2 = generators_raw[g, :c2]
      newg = Traditional_Generator(index, bus_idx, Pgmax, Pgmin, c0, c1, c2)
      for n in 1:nrow(nodes_raw)
          if buses[n].bus_idx==newg.bus_idx
              push!(buses[n].generator, newg.index)
          end
      end
      push!(generators, newg)
  end

  lines_raw = CSV.read("$datadir/lines.csv", DataFrame)
  sum(nonunique(lines_raw, :index)) != 0  ? @warn("Ambiguous Line Indices") : nothing

  lines = []
  for l in 1:nrow(lines_raw)
      index = lines_raw[l, :index]
      from_node = lines_raw[l, :from_node]
      to_node = lines_raw[l, :to_node]
      b = lines_raw[l, :b]
      s_max = lines_raw[l, :s_max]
      newl = Line(index, from_node, to_node, b, s_max)
      for n in 1:nrow(nodes_raw)
          if buses[n].bus_idx == newl.from_node
              push!(buses[n].outlist, newl.index)
          elseif buses[n].bus_idx == newl.to_node
              push!(buses[n].inlist, newl.index)
          end
      end
      push!(lines, newl)
  end

  net = Topo(buses, lines, generators)

  return net
end

function load_timeseries(datadir)
  #println(">>>>> Reading Timeseries data from $(datadir)")
  wind_power = Matrix(CSV.read("$datadir/wind_power.csv", DataFrame, header=false))
  wind_power= wind_power'
  return wind_power
end
