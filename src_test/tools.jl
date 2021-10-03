# Build, run and process a single model run
function run_DA_no_reserve(net, load)
    #println(">>>> Building DA No Reserve Model")
    m = build_model_DA_no_reserve(net, load)
    #println(">>>> Running DA No Reserve Model")
    solvetime = @elapsed optimize!(m)
    status = termination_status(m)
    #println(">>>> Model finished with status $status in $solvetime seconds")

    #println(">>>> Post-Processing of DA No Reserve Model")
    cost, pay = save_results_DA_no_reserve(m, net, load)
    return m, cost, pay
end

function run_DA_with_reserve(net, load, error, datadir)
    #println(">>>> Building DA With Reserve Model")
    m = build_model_DA_with_reserve(net, load, error)
    #println(">>>> Running DA With Reserve Model")
    solvetime = @elapsed optimize!(m)
    status = termination_status(m)
    #println(">>>> Model finished with status $status in $solvetime seconds")

    #println(">>>> Post-Processing of DA With Reserve Model")
    cost, pay = save_results_DA_with_reserve(m, net, load, datadir)
    return m, cost, pay
end

function run_RT(net, load)
    #println(">>>> Building RT Model")
    m = build_model_RT(net, load)
    #println(">>>> Running RT Model")
    solvetime = @elapsed optimize!(m)
    status = termination_status(m)
    #println(">>>> Model finished with status $status in $solvetime seconds")

    #println(">>>> Post-Processing of RT Model")
    cost, pay = save_results_RT(m, load, net)
    return m, cost, pay
end
