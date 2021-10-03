function save_results_DA_no_reserve(m, net, load)
    G = net.generators
    n_generators = net.n_generators
    n_buses = net.n_buses
    S_base = 100

    Pg_value = value.(m[:Pg])*S_base
    CSV.write("output/test/DA_no_reserve/Pg.csv", Tables.table(Pg_value), header=false)

    rg_max_value = value.(m[:rg_max])*S_base
    CSV.write("output/test/DA_no_reserve/rg_max.csv", Tables.table(rg_max_value), header=false)

    rg_min_value = value.(m[:rg_min])*S_base
    CSV.write("output/test/DA_no_reserve/rg_min.csv", Tables.table(rg_min_value), header=false)

    #bus_out_value = value.(m[:bus_out_power])*S_base
    #CSV.write("output/test/DA_no_reserve/bus_out_power.csv", Tables.table(bus_out_value), header=false)

    #DC_flow_value = value.(m[:DC_flow])*S_base
    #CSV.write("output/test/DA_no_reserve/power_flow.csv", Tables.table(DC_flow_value), header=false)

    #θ_value = value.(m[:θ])
    #CSV.write("output/test/DA_no_reserve/theta_power.csv", Tables.table(θ_value), header=false)

    #slack_value = value.(m[:load_slack])*S_base
    #CSV.write("output/test/DA_no_reserve/slack_power.csv", Tables.table(slack_value), header=false)

    cost_t = zeros(Float64, t_num, 1)
    for t in 1:t_num
        for i in 1:n_generators
            cost_t[t]=cost_t[t]+(Pg_value[i,t]<=0.0001 ? 0 : G[i].c0) + G[i].c1*Pg_value[i,t] + G[i].c2 *Pg_value[i,t]^2
        end
    end
    CSV.write("output/test/DA_no_reserve/cost.csv", Tables.table(cost_t), header=false)

    Energy_price = []
    for t in 1:t_num
        for b in 1:n_buses
            push!(Energy_price, dual(m[:λ][b,t])/S_base)
        end
    end
    energy_prices = reshape(Energy_price,(n_buses,t_num))
    CSV.write("output/test/DA_no_reserve/energy_prices.csv", Tables.table(energy_prices), header=false)

    pay_t = sum(energy_prices.*load[1:11,:])

    return cost_t, pay_t
end

function save_results_DA_with_reserve(m, net, load, datadir)
    G = net.generators
    buses = net.buses
    n_generators = net.n_generators
    n_buses = net.n_buses
    S_base = 100

    Pg_value = value.(m[:Pg])*S_base
    CSV.write("output/test/DA_with_reserve/$datadir/Pg.csv", Tables.table(Pg_value), header=false)

    rg_plus_value = value.(m[:rg_plus])*S_base
    CSV.write("output/test/DA_with_reserve/$datadir/rg_plus.csv", Tables.table(rg_plus_value), header=false)

    rg_minus_value = value.(m[:rg_minus])*S_base
    CSV.write("output/test/DA_with_reserve/$datadir/rg_minus.csv", Tables.table(rg_minus_value), header=false)

    rg_max_value = value.(m[:rg_max])*S_base
    CSV.write("output/test/DA_with_reserve/$datadir/rg_max.csv", Tables.table(rg_max_value), header=false)

    rg_min_value = value.(m[:rg_min])*S_base
    CSV.write("output/test/DA_with_reserve/$datadir/rg_min.csv", Tables.table(rg_min_value), header=false)

    #θ_power_value = value.(m[:θ_power])
    #CSV.write("output/test/DA_with_reserve/$datadir/theta_power.csv", Tables.table(θ_power_value), header=false)

    #θ_reserve_value = value.(m[:θ_reserve])
    #CSV.write("output/test/DA_with_reserve/$datadir/theta_reserve.csv", Tables.table(θ_reserve_value), header=false)

    #bus_out_power_value = value.(m[:bus_out_power])*S_base
    #CSV.write("output/test/DA_with_reserve/$datadir/bus_out_power.csv", Tables.table(bus_out_power_value), header=false)

    #bus_out_reserve_value = value.(m[:bus_out_reserve])*S_base
    #CSV.write("output/test/DA_with_reserve/$datadir/bus_out_reserve.csv", Tables.table(bus_out_reserve_value), header=false)

    #power_flow_value = value.(m[:power_flow])*S_base
    #CSV.write("output/test/DA_with_reserve/$datadir/power_flow.csv", Tables.table(power_flow_value), header=false)

    #reserve_flow_value = value.(m[:reserve_flow])*S_base
    #CSV.write("output/test/DA_with_reserve/$datadir/reserve_flow.csv", Tables.table(reserve_flow_value), header=false)

    #slack_power_value = value.(m[:slack_power])*S_base
    #CSV.write("output/test/DA_with_reserve/$datadir/slack_power.csv", Tables.table(slack_power_value), header=false)

    #slack_reserve_value = value.(m[:slack_reserve])*S_base
    #CSV.write("output/test/DA_with_reserve/$datadir/slack_reserve.csv", Tables.table(slack_reserve_value), header=false)

    cost_t = zeros(Float64, t_num, 1)
    for t in 1:t_num
        for i in 1:n_generators
            cost_t[t]=cost_t[t]+(Pg_value[i,t]<=0.0001 ? 0 : G[i].c0) + G[i].c1*Pg_value[i,t] + G[i].c2 *Pg_value[i,t]^2
        end
    end
    CSV.write("output/test/DA_with_reserve/$datadir/cost.csv", Tables.table(cost_t), header=false)

    Energy_price = []
    for t in 1:t_num
        for b in 1:n_buses
            push!(Energy_price, dual(m[:λ][b,t])/S_base)
        end
    end
    energy_prices = reshape(Energy_price,(n_buses,t_num))
    CSV.write("output/test/DA_with_reserve/$datadir/energy_prices.csv", Tables.table(energy_prices), header=false)

    Reserve_price = []
    for t in 1:t_num
        for b in 1:n_buses
            push!(Reserve_price, dual(m[:γ][b,t])/S_base)
        end
    end
    reserve_prices = reshape(Reserve_price,(n_buses,t_num))
    CSV.write("output/test/DA_with_reserve/$datadir/reserve_prices.csv", Tables.table(reserve_prices), header=false)

    rg_plus = Matrix(CSV.read("output/test/DA_with_reserve/$datadir/rg_plus.csv", DataFrame, header=false))
    rg_minus = Matrix(CSV.read("output/test/DA_with_reserve/$datadir/rg_minus.csv", DataFrame, header=false))

    #pay_t = sum(energy_prices.*load[1:11,:], dims=1) + sum(reserve_prices, dims=1).*(sum(rg_plus - rg_minus, dims=1))/11
    pay_energy = sum(energy_prices.*load[1:11,:])
    pay_reserve = 0
    for i in 1:n_buses
        pay_reserve = pay_reserve + sum(reserve_prices[i,:].*sum(rg_plus[g,:]-rg_minus[g,:] for g in buses[i].generator))
    end
    pay_t = pay_energy + pay_reserve

    return cost_t, pay_t
end

function save_results_RT(m, load, net)
    G = net.generators
    n_generators = net.n_generators
    n_buses = net.n_buses
    S_base = 100

    Pg_value = value.(m[:Pg])*S_base
    CSV.write("output/test/RT/Pg.csv", Tables.table(Pg_value), header=false)

    #bus_out_value = value.(m[:bus_out_power])*S_base
    #CSV.write("output/test/RT/bus_out_power.csv", Tables.table(bus_out_value), header=false)

    #DC_flow_value = value.(m[:DC_flow])*S_base
    #CSV.write("output/test/RT/power_flow.csv", Tables.table(DC_flow_value), header=false)

    #θ_value = value.(m[:θ])
    #CSV.write("output/test/RT/theta_power.csv", Tables.table(θ_value), header=false)

    #slack_value = value.(m[:load_slack])*S_base
    #CSV.write("output/test/RT/slack_power.csv", Tables.table(slack_value), header=false)

    cost_t = zeros(Float64, t_num, 1)
    for t in 1:t_num
        for i in 1:n_generators
            cost_t[t]=cost_t[t]+(Pg_value[i,t]<=0.0001 ? 0 : G[i].c0) + G[i].c1*Pg_value[i,t] + G[i].c2 *Pg_value[i,t]^2
        end
    end
    CSV.write("output/test/RT/cost.csv", Tables.table(cost_t), header=false)

    Energy_price = []
    for t in 1:t_num
        for b in 1:n_buses
            push!(Energy_price, dual(m[:λ][b,t])/S_base)
        end
    end
    energy_prices = reshape(Energy_price,(n_buses,t_num))
    CSV.write("output/test/RT/energy_prices.csv", Tables.table(energy_prices), header=false)

    pay_t = sum(energy_prices.*load[1:11,:])

    return cost_t, pay_t
end
