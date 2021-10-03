# Build, run and process a single model run
function run_case_study(net, wind_power, load, wind_num, t_num)
#    println(">>>> Building Model")
    m = build_model(net, wind_power, load, wind_num, t_num)
#    println(">>>> Running Model")
    solvetime = @elapsed optimize!(m)
#    status = termination_status(m)
#    println(">>>> Model finished with status $status in $solvetime seconds")

#    println(">>>> Post-Processing")
    cost_t, Energy_price = save_results(m, net, t_num)
    return cost_t, Energy_price
end
