function save_results(m, net, t_num)
    G = net.generators
    n_generators = net.n_generators
    n_buses = net.n_buses

    t_list = collect(1:t_num)
    bus_list = collect(1:n_buses)

    Pg_value = value.(m[:Pg])
    #CSV.write("output/OPF_results/Pg_value.csv", Tables.table(Pg_value), header=false)

    #slack_value = value.(m[:load_slack])
    #CSV.write("output/OPF_results/slack_value.csv", Tables.table(slack_value), header=false)

    #bus_out_value = value.(m[:bus_out_power])*100
    #CSV.write("output/OPF_results/bus_out_value.csv", Tables.table(bus_out_value), header=false)

    #DC_flow_value = value.(m[:DC_flow])*100
    #CSV.write("output/OPF_results/DC_flow_value.csv", Tables.table(DC_flow_value), header=false)

    #θ_value = value.(m[:θ])
    #CSV.write("output/OPF_results/theta.csv", Tables.table(θ_value), header=false)

    cost_t = zeros(Float64, t_num, 1)
    for t = 1:t_num
        for i = 1:n_generators
            cost_t[t]=cost_t[t]+(Pg_value[i,t]<=0.0001 ? 0 : G[i].c0) + G[i].c1*Pg_value[i,t] + G[i].c2 *Pg_value[i,t]^2
        end
    end
#=
    f = open("output/OPF_results/Cost.txt", "w")
    for t in t_list
        println(f, cost_t[t])
    end
    close(f)
=#
    Energy_price = []
    for t in t_list
        for b in bus_list
            push!(Energy_price, dual(m[:λ][b,t])/100)
        end
    end

    prices = reshape(Energy_price,(n_buses,t_num))
#=
    f = open("output/OPF_results/Energy_price.txt", "w")
    for t in t_list
        for b in bus_list
            println(f, prices[b,t])
        end
        print(f, "\n")
    end
    close(f)
==#
    return cost_t, prices
end
