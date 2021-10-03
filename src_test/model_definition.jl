function build_model_DA_no_reserve(net, load)
    buses = net.buses
    lines = net.lines
    G = net.generators
    n_buses = net.n_buses
    n_lines = net.n_lines
    n_generators = net.n_generators
    root_bus = net.root_bus
    S_base = 100
    Z_base = 100

    t_list = collect(1:t_num)
    bus_list = collect(1:n_buses)
    line_list = collect(1:n_lines)
    G_list = collect(1:n_generators)

    wind_node = zeros(n_buses,t_num)
    for i in 1:wind_num-1
        wind_node[wind_bus[i],:] = wind_node[wind_bus[i],:] + wind_power[i,:]
    end

    m = Model(Gurobi.Optimizer)
    set_optimizer_attribute(m, "OutputFlag", 0)

    # Define Variables
    @variable(m, Pg[G_list,t_list]>=0)
    @variable(m, rg_max[G_list,t_list])
    @variable(m, rg_min[G_list,t_list])
    @variable(m, θ[bus_list,t_list])
    @variable(m, bus_out_power[bus_list,t_list])
    @variable(m, DC_flow[line_list,t_list])
    @variable(m, load_slack[bus_list,t_list]>=0)

    # Add constraints
    @constraint(m, [i=line_list, t=t_list], DC_flow[i,t] == (θ[lines[i].from_node,t]- θ[lines[i].to_node,t])*lines[i].b)

    for i in bus_list
        if buses[i].inlist ==[] && buses[i].outlist ==[]
            @constraint(m, [i,t=t_list], bus_out_power[i,t] == 0)
        elseif buses[i].inlist !=[] && buses[i].outlist ==[]
            @constraint(m, [i,t=t_list], bus_out_power[i,t] == sum(-DC_flow[k,t] for k in buses[i].inlist))
        elseif buses[i].inlist ==[] && buses[i].outlist !=[]
            @constraint(m, [i,t=t_list], bus_out_power[i,t] == sum(DC_flow[k,t] for k in buses[i].outlist))
        elseif buses[i].inlist !=[] && buses[i].outlist !=[]
            @constraint(m, [i,t=t_list], bus_out_power[i,t] == sum(-DC_flow[k,t] for k in buses[i].inlist) + sum(DC_flow[k,t] for k in buses[i].outlist))
        end
    end
    @constraint(m, [i=G_list,t=t_list], rg_max[i,t] == G[i].Pgmax/S_base - Pg[i,t])
    #@constraint(m, [i=G_list,t=t_list], rg_min[i,t] == Pg[i,t] - G[i].Pgmin/S_base)
    @constraint(m, [i=G_list,t=t_list], rg_min[i,t] == Pg[i,t])
    @constraint(m, η[i=G_list,t=t_list], Pg[i,t] <= G[i].Pgmax/S_base)
    @constraint(m, [i=line_list,t=t_list], -lines[i].s_max/S_base*1<= DC_flow[i,t] <=lines[i].s_max/S_base*1)
    @constraint(m, [t=t_list], θ[root_bus,t] == 0)
    @constraint(m, λ[i=bus_list,t=t_list], sum(Pg[g,t] for g in buses[i].generator) + wind_node[i,t]/S_base == load[i,t]/S_base-load_slack[i,t] + bus_out_power[i,t])

    @objective(m, Min,sum(sum(G[i].c0 + G[i].c1*Pg[i,t]*S_base + G[i].c2 *(Pg[i,t]*S_base)^2 for i in G_list) for t in t_list)+sum(sum(10000*load_slack[i,t] for i in bus_list) for t in t_list))

    return m
end

function build_model_DA_with_reserve(net, load, error)
    buses = net.buses
    lines = net.lines
    G = net.generators
    n_buses = net.n_buses
    n_lines = net.n_lines
    n_generators = net.n_generators
    root_bus = net.root_bus
    S_base = 100
    Z_base = 100

    t_list = collect(1:t_num)
    bus_list = collect(1:n_buses)
    line_list = collect(1:n_lines)
    G_list = collect(1:n_generators)

    wind_node = zeros(n_buses,t_num)
    for i in 1:wind_num-1
        wind_node[wind_bus[i],:] = wind_node[wind_bus[i],:] + wind_power[i,:]
    end

    m = Model(Gurobi.Optimizer)
    set_optimizer_attribute(m, "OutputFlag", 0)

    # Define Variables
    @variable(m, Pg[G_list,t_list]>=0)
    @variable(m, rg_plus[G_list,t_list]>=0)
    @variable(m, rg_minus[G_list,t_list]>=0)
    @variable(m, rg_max[G_list,t_list])
    @variable(m, rg_min[G_list,t_list])
    @variable(m, θ_power[bus_list,t_list])
    @variable(m, θ_reserve[bus_list,t_list])
    @variable(m, bus_out_power[bus_list,t_list])
    @variable(m, bus_out_reserve[bus_list,t_list])
    @variable(m, power_flow[line_list,t_list])
    @variable(m, reserve_flow[line_list,t_list])
    @variable(m, slack_power[bus_list,t_list]>=0)
    @variable(m, slack_reserve[bus_list,t_list]>=0)

    # Add constraints
    @constraint(m, [i=line_list, t=t_list], power_flow[i,t] == (θ_power[lines[i].from_node,t]- θ_power[lines[i].to_node,t])*lines[i].b)
    @constraint(m, [i=line_list, t=t_list], reserve_flow[i,t] == (θ_reserve[lines[i].from_node,t]- θ_reserve[lines[i].to_node,t])*lines[i].b)

    for i in bus_list
        if buses[i].inlist ==[] && buses[i].outlist ==[]
            @constraint(m, [i,t=t_list], bus_out_power[i,t] == 0)
            @constraint(m, [i,t=t_list], bus_out_reserve[i,t] == 0)
        elseif buses[i].inlist !=[] && buses[i].outlist ==[]
            @constraint(m, [i,t=t_list], bus_out_power[i,t] == sum(-power_flow[k,t] for k in buses[i].inlist))
            @constraint(m, [i,t=t_list], bus_out_reserve[i,t] == sum(-reserve_flow[k,t] for k in buses[i].inlist))
        elseif buses[i].inlist ==[] && buses[i].outlist !=[]
            @constraint(m, [i,t=t_list], bus_out_power[i,t] == sum(power_flow[k,t] for k in buses[i].inlist))
            @constraint(m, [i,t=t_list], bus_out_reserve[i,t] == sum(reserve_flow[k,t] for k in buses[i].inlist))
        elseif buses[i].inlist !=[] && buses[i].outlist !=[]
            @constraint(m, [i,t=t_list], bus_out_power[i,t] == sum(-power_flow[k,t] for k in buses[i].inlist) + sum(power_flow[k,t] for k in buses[i].outlist))
            @constraint(m, [i,t=t_list], bus_out_reserve[i,t] == sum(-reserve_flow[k,t] for k in buses[i].inlist) + sum(reserve_flow[k,t] for k in buses[i].outlist))
        end
    end

    @constraint(m, η[i=G_list,t=t_list], Pg[i,t] + rg_plus[i,t] - rg_minus[i,t] <= G[i].Pgmax/S_base)
    @constraint(m, [i=G_list,t=t_list], rg_max[i,t] == G[i].Pgmax/S_base -Pg[i,t])
    #@constraint(m, [i=G_list,t=t_list], rg_min[i,t] == Pg[i,t] - G[i].Pgmin/S_base)
    @constraint(m, [i=G_list,t=t_list], rg_min[i,t] == Pg[i,t])
    @constraint(m, [i=line_list,t=t_list], -lines[i].s_max/S_base*1<= power_flow[i,t] <=lines[i].s_max/S_base*1)
    @constraint(m, [i=line_list,t=t_list], -lines[i].s_max/S_base*1<= power_flow[i,t] + reserve_flow[i,t] <=lines[i].s_max/S_base*1)
    @constraint(m, [t=t_list], θ_power[root_bus,t] == 0)
    @constraint(m, [t=t_list], θ_reserve[root_bus,t] == 0)
    @constraint(m, λ[i=bus_list,t=t_list], sum(Pg[g,t] for g in buses[i].generator) + wind_node[i,t]/S_base == load[i,t]/S_base-slack_power[i,t] + bus_out_power[i,t])
    @constraint(m, γ[i=bus_list,t=t_list], sum(rg_plus[g,t] for g in buses[i].generator) - sum(rg_minus[g,t] for g in buses[i].generator) == error[i,t]/S_base-slack_reserve[i,t] + bus_out_reserve[i,t])
    @objective(m, Min,sum(sum(G[i].c0+G[i].c1*Pg[i,t]*S_base+G[i].c2*(Pg[i,t]*S_base)^2 +(rg_plus[i,t]+rg_minus[i,t])*S_base*100 for i in G_list) for t in t_list)+sum(sum(10000*(slack_power[i,t]+slack_reserve[i,t]) for i in bus_list) for t in t_list))

    return m
end

function build_model_RT(net, load)
    buses = net.buses
    lines = net.lines
    G = net.generators
    n_buses = net.n_buses
    n_lines = net.n_lines
    n_generators = net.n_generators
    root_bus = net.root_bus
    S_base = 100
    Z_base = 100

    t_list = collect(1:t_num)
    bus_list = collect(1:n_buses)
    line_list = collect(1:n_lines)
    G_list = collect(1:n_generators)

    wind_node = zeros(n_buses,t_num)
    for i in 1:wind_num-1
        wind_node[wind_bus[i],:] = wind_node[wind_bus[i],:] + wind_power[i,:]
    end

    m = Model(Gurobi.Optimizer)
    set_optimizer_attribute(m, "OutputFlag", 0)

    # Define Variables
    @variable(m, Pg[G_list,t_list]>=0)
    @variable(m, θ[bus_list,t_list])
    @variable(m, bus_out_power[bus_list,t_list])
    @variable(m, DC_flow[line_list,t_list])
    @variable(m, load_slack[bus_list,t_list]>=0)

    # Add constraints
    @constraint(m, [i=line_list, t=t_list], DC_flow[i,t] == (θ[lines[i].from_node,t]- θ[lines[i].to_node,t])*lines[i].b)

    for i in bus_list
        if buses[i].inlist ==[] && buses[i].outlist ==[]
            @constraint(m, [i,t=t_list], bus_out_power[i,t] == 0)
        elseif buses[i].inlist !=[] && buses[i].outlist ==[]
            @constraint(m, [i,t=t_list], bus_out_power[i,t] == sum(-DC_flow[k,t] for k in buses[i].inlist))
        elseif buses[i].inlist ==[] && buses[i].outlist !=[]
            @constraint(m, [i,t=t_list], bus_out_power[i,t] == sum(DC_flow[k,t] for k in buses[i].outlist))
        elseif buses[i].inlist !=[] && buses[i].outlist !=[]
            @constraint(m, [i,t=t_list], bus_out_power[i,t] == sum(-DC_flow[k,t] for k in buses[i].inlist) + sum(DC_flow[k,t] for k in buses[i].outlist))
        end
    end

    @constraint(m, η[i=G_list,t=t_list], Pg[i,t] <= G[i].Pgmax/S_base)
    @constraint(m, [i=line_list,t=t_list], -lines[i].s_max/S_base*1<= DC_flow[i,t] <=lines[i].s_max/S_base*1)
    @constraint(m, [t=t_list], θ[root_bus,t] == 0)
    @constraint(m, λ[i=bus_list,t=t_list], sum(Pg[g,t] for g in buses[i].generator) + wind_node[i,t]/S_base == load[i,t]/S_base-load_slack[i,t] + bus_out_power[i,t])

    @objective(m, Min,sum(sum(G[i].c0 + G[i].c1*Pg[i,t]*S_base + G[i].c2 *(Pg[i,t]*S_base)^2 for i in G_list) for t in t_list)+sum(sum(10000*load_slack[i,t] for i in bus_list) for t in t_list))

    return m
end
