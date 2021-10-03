using DataFrames, CSV
using JuMP
using Gurobi
using LinearAlgebra
using MAT

# Load functions and model
include("src_test/tools.jl") # Some additional functions
include("src_test/input.jl") # Type definitions and read-in functions
include("src_test/model_definition.jl") # Model definiton
include("src_test/output.jl") # Postprocessing of solved model

# Load data
net = load_net("data/data_OPF")
wind_power = load_timeseries("data/data_OPF")
wind_num, t_num  = size(wind_power)
wind_bus = Matrix(CSV.read("data/data_OPF/wind_bus.csv", DataFrame, header=false))

fileIn = matopen("data/data_load/RT_load.mat")
RT_training_load = read(fileIn)
close(fileIn)
fileIn = matopen("data/data_load/DA_load.mat")
DA_training_load = read(fileIn)
close(fileIn)
RT_load = get(RT_training_load, "RT_load",1)
DA_load = get(DA_training_load, "DA_load",1)

RT_load_test = RT_load[:,:,1001:1100]
DA_load_test = DA_load[:,:,1001:1100]

error_generated0_10 = Matrix(CSV.read("output/output_OPF_1_1000_new/test/Error_30.csv", DataFrame, header=false))
error_generated_10 = reshape(error_generated0_10, (12,24,100))

error_generated0_9 = Matrix(CSV.read("output/output_OPF_0.9_1000_new/test/Error_30.csv", DataFrame, header=false))
error_generated_9 = reshape(error_generated0_9, (12,24,100))

error_generated0_8 = Matrix(CSV.read("output/output_OPF_0.8_1000_new/test/Error_30.csv", DataFrame, header=false))
error_generated_8 = reshape(error_generated0_8, (12,24,100))

error_robust_5 = 0.9 * DA_load_test
error_robust_4 = 0.7 * DA_load_test
error_robust_3 = 0.5 * DA_load_test
error_robust_2 = 0.3 * DA_load_test
error_robust_1 = 0.1 * DA_load_test

S_base = 100

enough_min_no_reserve = []
enough_max_no_reserve = []
cost_no_reserve = []
pay_no_reserve = []

enough_min_generated_error_10 = []
enough_min_generated_error_9 = []
enough_min_generated_error_8 = []

enough_max_generated_error_10 = []
enough_max_generated_error_9 = []
enough_max_generated_error_8 = []

enough_minus_generated_error_10 = []
enough_minus_generated_error_9 = []
enough_minus_generated_error_8 = []

enough_plus_generated_error_10 = []
enough_plus_generated_error_9 = []
enough_plus_generated_error_8 = []

cost_generated_error_10 = []
cost_generated_error_9 = []
cost_generated_error_8 = []

pay_generated_error_10 = []
pay_generated_error_9 = []
pay_generated_error_8 = []

enough_min_robust_error_5 = []
enough_min_robust_error_4 = []
enough_min_robust_error_3 = []
enough_min_robust_error_2 = []
enough_min_robust_error_1 = []

enough_max_robust_error_5 = []
enough_max_robust_error_4 = []
enough_max_robust_error_3 = []
enough_max_robust_error_2 = []
enough_max_robust_error_1 = []

enough_minus_robust_error_5 = []
enough_minus_robust_error_4 = []
enough_minus_robust_error_3 = []
enough_minus_robust_error_2 = []
enough_minus_robust_error_1 = []

enough_plus_robust_error_5 = []
enough_plus_robust_error_4 = []
enough_plus_robust_error_3 = []
enough_plus_robust_error_2 = []
enough_plus_robust_error_1 = []

cost_robust_error_5 = []
cost_robust_error_4 = []
cost_robust_error_3 = []
cost_robust_error_2 = []
cost_robust_error_1 = []

pay_robust_error_5 = []
pay_robust_error_4 = []
pay_robust_error_3 = []
pay_robust_error_2 = []
pay_robust_error_1 = []

cost_RT_sum = []
pay_RT_sum = []

error_none = zeros(11,24)
for i in 1:100
    #m_DA_no_reserve, cost_DA_no_reserve, pay_DA_no_reserve = run_DA_no_reserve(net, DA_load_test[:,:,i])
    m_DA_no_reserve, cost_DA_no_reserve, pay_DA_no_reserve= run_DA_with_reserve(net, DA_load_test[:,:,i], error_none,"no_reserve")

    m_DA_generated_error_10, cost_DA_generated_error_10, pay_DA_generated_error_10= run_DA_with_reserve(net, DA_load_test[:,:,i], error_generated_10[:,:,i],"generated_1")
    m_DA_generated_error_9, cost_DA_generated_error_9, pay_DA_generated_error_9 = run_DA_with_reserve(net, DA_load_test[:,:,i], error_generated_9[:,:,i],"generated_0.9")
    m_DA_generated_error_8, cost_DA_generated_error_8, pay_DA_generated_error_8 = run_DA_with_reserve(net, DA_load_test[:,:,i], error_generated_8[:,:,i],"generated_0.8")

    m_DA_robust_error_5, cost_DA_robust_error_5, pay_DA_robust_error_5 = run_DA_with_reserve(net, DA_load_test[:,:,i], error_robust_5[:,:,i],"robust_0.5")
    m_DA_robust_error_4, cost_DA_robust_error_4, pay_DA_robust_error_4  = run_DA_with_reserve(net, DA_load_test[:,:,i], error_robust_4[:,:,i],"robust_0.4")
    m_DA_robust_error_3, cost_DA_robust_error_3, pay_DA_robust_error_3  = run_DA_with_reserve(net, DA_load_test[:,:,i], error_robust_3[:,:,i],"robust_0.3")
    m_DA_robust_error_2, cost_DA_robust_error_2, pay_DA_robust_error_2  = run_DA_with_reserve(net, DA_load_test[:,:,i], error_robust_2[:,:,i],"robust_0.2")
    m_DA_robust_error_1, cost_DA_robust_error_1, pay_DA_robust_error_1  = run_DA_with_reserve(net, DA_load_test[:,:,i], error_robust_1[:,:,i],"robust_0.1")

    m_RT, cost_RT, pay_RT  = run_RT(net, RT_load_test[:,:,i])

    push!(cost_no_reserve, sum(cost_DA_no_reserve))

    push!(cost_generated_error_10, sum(cost_DA_generated_error_10))
    push!(cost_generated_error_9, sum(cost_DA_generated_error_9))
    push!(cost_generated_error_8, sum(cost_DA_generated_error_8))

    push!(cost_robust_error_5, sum(cost_DA_robust_error_5))
    push!(cost_robust_error_4, sum(cost_DA_robust_error_4))
    push!(cost_robust_error_3, sum(cost_DA_robust_error_3))
    push!(cost_robust_error_2, sum(cost_DA_robust_error_2))
    push!(cost_robust_error_1, sum(cost_DA_robust_error_1))

    push!(cost_RT_sum, sum(cost_RT))

    push!(pay_no_reserve, pay_DA_no_reserve)

    push!(pay_generated_error_10, pay_DA_generated_error_10)
    push!(pay_generated_error_9, pay_DA_generated_error_9)
    push!(pay_generated_error_8, pay_DA_generated_error_8)

    push!(pay_robust_error_5, pay_DA_robust_error_5)
    push!(pay_robust_error_4, pay_DA_robust_error_4)
    push!(pay_robust_error_3, pay_DA_robust_error_3)
    push!(pay_robust_error_2, pay_DA_robust_error_2)
    push!(pay_robust_error_1, pay_DA_robust_error_1)

    push!(pay_RT_sum, sum(pay_RT))

    #Pg_DA_no_reserve = Matrix(CSV.read("output/test/DA_no_reserve/Pg.csv", DataFrame, header=false))
    #rg_max_no_reserve = Matrix(CSV.read("output/test/DA_no_reserve/rg_max.csv", DataFrame, header=false))
    #rg_min_no_reserve = Matrix(CSV.read("output/test/DA_no_reserve/rg_min.csv", DataFrame, header=false))

    Pg_DA_no_reserve = Matrix(CSV.read("output/test/DA_with_reserve/no_reserve/Pg.csv", DataFrame, header=false))
    rg_max_no_reserve = Matrix(CSV.read("output/test/DA_with_reserve/no_reserve/rg_max.csv", DataFrame, header=false))
    rg_min_no_reserve = Matrix(CSV.read("output/test/DA_with_reserve/no_reserve/rg_min.csv", DataFrame, header=false))

    Pg_DA_generated_10 = Matrix(CSV.read("output/test/DA_with_reserve/generated_1/Pg.csv", DataFrame, header=false))
    rg_max_generated_10 = Matrix(CSV.read("output/test/DA_with_reserve/generated_1/rg_max.csv", DataFrame, header=false))
    rg_min_generated_10 = Matrix(CSV.read("output/test/DA_with_reserve/generated_1/rg_min.csv", DataFrame, header=false))
    rg_plus_generated_10 = Matrix(CSV.read("output/test/DA_with_reserve/generated_1/rg_plus.csv", DataFrame, header=false))
    rg_minus_generated_10 = Matrix(CSV.read("output/test/DA_with_reserve/generated_1/rg_minus.csv", DataFrame, header=false))

    Pg_DA_generated_9 = Matrix(CSV.read("output/test/DA_with_reserve/generated_0.9/Pg.csv", DataFrame, header=false))
    rg_max_generated_9 = Matrix(CSV.read("output/test/DA_with_reserve/generated_0.9/rg_max.csv", DataFrame, header=false))
    rg_min_generated_9 = Matrix(CSV.read("output/test/DA_with_reserve/generated_0.9/rg_min.csv", DataFrame, header=false))
    rg_plus_generated_9 = Matrix(CSV.read("output/test/DA_with_reserve/generated_0.9/rg_plus.csv", DataFrame, header=false))
    rg_minus_generated_9 = Matrix(CSV.read("output/test/DA_with_reserve/generated_0.9/rg_minus.csv", DataFrame, header=false))

    Pg_DA_generated_8 = Matrix(CSV.read("output/test/DA_with_reserve/generated_0.8/Pg.csv", DataFrame, header=false))
    rg_max_generated_8 = Matrix(CSV.read("output/test/DA_with_reserve/generated_0.8/rg_max.csv", DataFrame, header=false))
    rg_min_generated_8 = Matrix(CSV.read("output/test/DA_with_reserve/generated_0.8/rg_min.csv", DataFrame, header=false))
    rg_plus_generated_8 = Matrix(CSV.read("output/test/DA_with_reserve/generated_0.8/rg_plus.csv", DataFrame, header=false))
    rg_minus_generated_8 = Matrix(CSV.read("output/test/DA_with_reserve/generated_0.8/rg_minus.csv", DataFrame, header=false))

    Pg_DA_robust_5 = Matrix(CSV.read("output/test/DA_with_reserve/robust_0.5/Pg.csv", DataFrame, header=false))
    rg_max_robust_5 = Matrix(CSV.read("output/test/DA_with_reserve/robust_0.5/rg_max.csv", DataFrame, header=false))
    rg_min_robust_5 = Matrix(CSV.read("output/test/DA_with_reserve/robust_0.5/rg_min.csv", DataFrame, header=false))
    rg_plus_robust_5 = Matrix(CSV.read("output/test/DA_with_reserve/robust_0.5/rg_plus.csv", DataFrame, header=false))
    rg_minus_robust_5 = Matrix(CSV.read("output/test/DA_with_reserve/robust_0.5/rg_minus.csv", DataFrame, header=false))

    Pg_DA_robust_4 = Matrix(CSV.read("output/test/DA_with_reserve/robust_0.4/Pg.csv", DataFrame, header=false))
    rg_max_robust_4 = Matrix(CSV.read("output/test/DA_with_reserve/robust_0.4/rg_max.csv", DataFrame, header=false))
    rg_min_robust_4 = Matrix(CSV.read("output/test/DA_with_reserve/robust_0.4/rg_min.csv", DataFrame, header=false))
    rg_plus_robust_4 = Matrix(CSV.read("output/test/DA_with_reserve/robust_0.4/rg_plus.csv", DataFrame, header=false))
    rg_minus_robust_4 = Matrix(CSV.read("output/test/DA_with_reserve/robust_0.4/rg_minus.csv", DataFrame, header=false))

    Pg_DA_robust_3 = Matrix(CSV.read("output/test/DA_with_reserve/robust_0.3/Pg.csv", DataFrame, header=false))
    rg_max_robust_3 = Matrix(CSV.read("output/test/DA_with_reserve/robust_0.3/rg_max.csv", DataFrame, header=false))
    rg_min_robust_3 = Matrix(CSV.read("output/test/DA_with_reserve/robust_0.3/rg_min.csv", DataFrame, header=false))
    rg_plus_robust_3 = Matrix(CSV.read("output/test/DA_with_reserve/robust_0.3/rg_plus.csv", DataFrame, header=false))
    rg_minus_robust_3 = Matrix(CSV.read("output/test/DA_with_reserve/robust_0.3/rg_minus.csv", DataFrame, header=false))

    Pg_DA_robust_2 = Matrix(CSV.read("output/test/DA_with_reserve/robust_0.2/Pg.csv", DataFrame, header=false))
    rg_max_robust_2 = Matrix(CSV.read("output/test/DA_with_reserve/robust_0.2/rg_max.csv", DataFrame, header=false))
    rg_min_robust_2 = Matrix(CSV.read("output/test/DA_with_reserve/robust_0.2/rg_min.csv", DataFrame, header=false))
    rg_plus_robust_2 = Matrix(CSV.read("output/test/DA_with_reserve/robust_0.2/rg_plus.csv", DataFrame, header=false))
    rg_minus_robust_2 = Matrix(CSV.read("output/test/DA_with_reserve/robust_0.2/rg_minus.csv", DataFrame, header=false))

    Pg_DA_robust_1 = Matrix(CSV.read("output/test/DA_with_reserve/robust_0.1/Pg.csv", DataFrame, header=false))
    rg_max_robust_1 = Matrix(CSV.read("output/test/DA_with_reserve/robust_0.1/rg_max.csv", DataFrame, header=false))
    rg_min_robust_1 = Matrix(CSV.read("output/test/DA_with_reserve/robust_0.1/rg_min.csv", DataFrame, header=false))
    rg_plus_robust_1 = Matrix(CSV.read("output/test/DA_with_reserve/robust_0.1/rg_plus.csv", DataFrame, header=false))
    rg_minus_robust_1 = Matrix(CSV.read("output/test/DA_with_reserve/robust_0.1/rg_minus.csv", DataFrame, header=false))

    Pg_RT = Matrix(CSV.read("output/test/RT/Pg.csv", DataFrame, header=false))

    push!(enough_min_no_reserve, sum(-rg_min_no_reserve .< Pg_RT-Pg_DA_no_reserve))
    push!(enough_max_no_reserve, sum(Pg_RT-Pg_DA_no_reserve.<= rg_max_no_reserve))

    push!(enough_min_generated_error_10, sum(-rg_min_generated_10 .< Pg_RT-Pg_DA_generated_10))
    push!(enough_max_generated_error_10, sum(Pg_RT-Pg_DA_generated_10 .<= rg_max_generated_10))
    push!(enough_minus_generated_error_10, sum(-rg_minus_generated_10 .<= Pg_RT-Pg_DA_generated_10))
    push!(enough_plus_generated_error_10, sum(Pg_RT-Pg_DA_generated_10 .<= rg_plus_generated_10))

    push!(enough_min_generated_error_9, sum(-rg_min_generated_9 .< Pg_RT-Pg_DA_generated_9))
    push!(enough_max_generated_error_9, sum(Pg_RT-Pg_DA_generated_9 .<= rg_max_generated_9))
    push!(enough_minus_generated_error_9, sum(-rg_minus_generated_9 .<= Pg_RT-Pg_DA_generated_9))
    push!(enough_plus_generated_error_9, sum(Pg_RT-Pg_DA_generated_9 .<= rg_plus_generated_9))

    push!(enough_min_generated_error_8, sum(-rg_min_generated_8 .< Pg_RT-Pg_DA_generated_8))
    push!(enough_max_generated_error_8, sum(Pg_RT-Pg_DA_generated_8 .<= rg_max_generated_8))
    push!(enough_minus_generated_error_8, sum(-rg_minus_generated_8 .<= Pg_RT-Pg_DA_generated_8))
    push!(enough_plus_generated_error_8, sum(Pg_RT-Pg_DA_generated_8 .<= rg_plus_generated_8))

    push!(enough_min_robust_error_5, sum(-rg_min_robust_5 .< Pg_RT-Pg_DA_robust_5))
    push!(enough_max_robust_error_5, sum(Pg_RT-Pg_DA_robust_5 .<= rg_max_robust_5))
    push!(enough_minus_robust_error_5, sum(-rg_minus_robust_5 .<= Pg_RT-Pg_DA_robust_5))
    push!(enough_plus_robust_error_5, sum(Pg_RT-Pg_DA_robust_5 .<= rg_plus_robust_5))

    push!(enough_min_robust_error_4, sum(-rg_min_robust_4 .< Pg_RT-Pg_DA_robust_4))
    push!(enough_max_robust_error_4, sum(Pg_RT-Pg_DA_robust_4 .<= rg_max_robust_4))
    push!(enough_minus_robust_error_4, sum(-rg_minus_robust_4 .<= Pg_RT-Pg_DA_robust_4))
    push!(enough_plus_robust_error_4, sum(Pg_RT-Pg_DA_robust_4 .<= rg_plus_robust_4))

    push!(enough_min_robust_error_3, sum(-rg_min_robust_3 .< Pg_RT-Pg_DA_robust_3))
    push!(enough_max_robust_error_3, sum(Pg_RT-Pg_DA_robust_3 .<= rg_max_robust_3))
    push!(enough_minus_robust_error_3, sum(-rg_minus_robust_3 .<= Pg_RT-Pg_DA_robust_3))
    push!(enough_plus_robust_error_3, sum(Pg_RT-Pg_DA_robust_3 .<= rg_plus_robust_3))

    push!(enough_min_robust_error_2, sum(-rg_min_robust_2 .< Pg_RT-Pg_DA_robust_2))
    push!(enough_max_robust_error_2, sum(Pg_RT-Pg_DA_robust_2 .<= rg_max_robust_2))
    push!(enough_minus_robust_error_2, sum(-rg_minus_robust_2 .<= Pg_RT-Pg_DA_robust_2))
    push!(enough_plus_robust_error_2, sum(Pg_RT-Pg_DA_robust_2 .<= rg_plus_robust_2))

    push!(enough_min_robust_error_1, sum(-rg_min_robust_1 .< Pg_RT-Pg_DA_robust_1))
    push!(enough_max_robust_error_1, sum(Pg_RT-Pg_DA_robust_1 .<= rg_max_robust_1))
    push!(enough_minus_robust_error_1, sum(-rg_minus_robust_1 .<= Pg_RT-Pg_DA_robust_1))
    push!(enough_plus_robust_error_1, sum(Pg_RT-Pg_DA_robust_1 .<= rg_plus_robust_1))
end
CSV.write("output/test/enough/enough_min_no_reserve.csv", Tables.table(enough_min_no_reserve), header=false)
CSV.write("output/test/enough/enough_max_no_reserve.csv", Tables.table(enough_max_no_reserve), header=false)
CSV.write("output/test/enough/cost_no_reserve.csv", Tables.table(cost_no_reserve), header=false)
CSV.write("output/test/enough/pay_no_reserve.csv", Tables.table(pay_no_reserve), header=false)

CSV.write("output/test/enough/enough_min_generated_error_10.csv", Tables.table(enough_min_generated_error_10), header=false)
CSV.write("output/test/enough/enough_min_generated_error_9.csv", Tables.table(enough_min_generated_error_9), header=false)
CSV.write("output/test/enough/enough_min_generated_error_8.csv", Tables.table(enough_min_generated_error_8), header=false)

CSV.write("output/test/enough/enough_max_generated_error_10.csv", Tables.table(enough_max_generated_error_10), header=false)
CSV.write("output/test/enough/enough_max_generated_error_9.csv", Tables.table(enough_max_generated_error_9), header=false)
CSV.write("output/test/enough/enough_max_generated_error_8.csv", Tables.table(enough_max_generated_error_8), header=false)

CSV.write("output/test/enough/enough_minus_generated_error_10.csv", Tables.table(enough_minus_generated_error_10), header=false)
CSV.write("output/test/enough/enough_minus_generated_error_9.csv", Tables.table(enough_minus_generated_error_9), header=false)
CSV.write("output/test/enough/enough_minus_generated_error_8.csv", Tables.table(enough_minus_generated_error_8), header=false)

CSV.write("output/test/enough/enough_plus_generated_error_10.csv", Tables.table(enough_plus_generated_error_10), header=false)
CSV.write("output/test/enough/enough_plus_generated_error_9.csv", Tables.table(enough_plus_generated_error_9), header=false)
CSV.write("output/test/enough/enough_plus_generated_error_8.csv", Tables.table(enough_plus_generated_error_8), header=false)

CSV.write("output/test/enough/cost_generated_error_10.csv", Tables.table(cost_generated_error_10), header=false)
CSV.write("output/test/enough/cost_generated_error_9.csv", Tables.table(cost_generated_error_9), header=false)
CSV.write("output/test/enough/cost_generated_error_8.csv", Tables.table(cost_generated_error_8), header=false)

CSV.write("output/test/enough/pay_generated_error_10.csv", Tables.table(pay_generated_error_10), header=false)
CSV.write("output/test/enough/pay_generated_error_9.csv", Tables.table(pay_generated_error_9), header=false)
CSV.write("output/test/enough/pay_generated_error_8.csv", Tables.table(pay_generated_error_8), header=false)

CSV.write("output/test/enough/enough_min_robust_error_5.csv", Tables.table(enough_min_robust_error_5), header=false)
CSV.write("output/test/enough/enough_min_robust_error_4.csv", Tables.table(enough_min_robust_error_4), header=false)
CSV.write("output/test/enough/enough_min_robust_error_3.csv", Tables.table(enough_min_robust_error_3), header=false)
CSV.write("output/test/enough/enough_min_robust_error_2.csv", Tables.table(enough_min_robust_error_2), header=false)
CSV.write("output/test/enough/enough_min_robust_error_1.csv", Tables.table(enough_min_robust_error_1), header=false)

CSV.write("output/test/enough/enough_max_robust_error_5.csv", Tables.table(enough_max_robust_error_5), header=false)
CSV.write("output/test/enough/enough_max_robust_error_4.csv", Tables.table(enough_max_robust_error_4), header=false)
CSV.write("output/test/enough/enough_max_robust_error_3.csv", Tables.table(enough_max_robust_error_3), header=false)
CSV.write("output/test/enough/enough_max_robust_error_2.csv", Tables.table(enough_max_robust_error_2), header=false)
CSV.write("output/test/enough/enough_max_robust_error_1.csv", Tables.table(enough_max_robust_error_1), header=false)

CSV.write("output/test/enough/enough_minus_robust_error_5.csv", Tables.table(enough_minus_robust_error_5), header=false)
CSV.write("output/test/enough/enough_minus_robust_error_4.csv", Tables.table(enough_minus_robust_error_4), header=false)
CSV.write("output/test/enough/enough_minus_robust_error_3.csv", Tables.table(enough_minus_robust_error_3), header=false)
CSV.write("output/test/enough/enough_minus_robust_error_2.csv", Tables.table(enough_minus_robust_error_2), header=false)
CSV.write("output/test/enough/enough_minus_robust_error_1.csv", Tables.table(enough_minus_robust_error_1), header=false)

CSV.write("output/test/enough/enough_plus_robust_error_5.csv", Tables.table(enough_plus_robust_error_5), header=false)
CSV.write("output/test/enough/enough_plus_robust_error_4.csv", Tables.table(enough_plus_robust_error_4), header=false)
CSV.write("output/test/enough/enough_plus_robust_error_3.csv", Tables.table(enough_plus_robust_error_3), header=false)
CSV.write("output/test/enough/enough_plus_robust_error_2.csv", Tables.table(enough_plus_robust_error_2), header=false)
CSV.write("output/test/enough/enough_plus_robust_error_1.csv", Tables.table(enough_plus_robust_error_1), header=false)

CSV.write("output/test/enough/cost_robust_error_5.csv", Tables.table(cost_robust_error_5), header=false)
CSV.write("output/test/enough/cost_robust_error_4.csv", Tables.table(cost_robust_error_4), header=false)
CSV.write("output/test/enough/cost_robust_error_3.csv", Tables.table(cost_robust_error_3), header=false)
CSV.write("output/test/enough/cost_robust_error_2.csv", Tables.table(cost_robust_error_2), header=false)
CSV.write("output/test/enough/cost_robust_error_1.csv", Tables.table(cost_robust_error_1), header=false)

CSV.write("output/test/enough/pay_robust_error_5.csv", Tables.table(pay_robust_error_5), header=false)
CSV.write("output/test/enough/pay_robust_error_4.csv", Tables.table(pay_robust_error_4), header=false)
CSV.write("output/test/enough/pay_robust_error_3.csv", Tables.table(pay_robust_error_3), header=false)
CSV.write("output/test/enough/pay_robust_error_2.csv", Tables.table(pay_robust_error_2), header=false)
CSV.write("output/test/enough/pay_robust_error_1.csv", Tables.table(pay_robust_error_1), header=false)

CSV.write("output/test/enough/cost_RT.csv", Tables.table(cost_RT_sum), header=false)
CSV.write("output/test/enough/pay_RT.csv", Tables.table(pay_RT_sum), header=false)

enough_min_total = []
enough_max_total = []
enough_minus_total = []
enough_plus_total = []
cost_total = []
revenue_total = []

push!(enough_min_total, sum(enough_min_no_reserve))
push!(enough_min_total, sum(enough_min_generated_error_10))
push!(enough_min_total, sum(enough_min_generated_error_9))
push!(enough_min_total, sum(enough_min_generated_error_8))
push!(enough_min_total, sum(enough_min_robust_error_5))
push!(enough_min_total, sum(enough_min_robust_error_4))
push!(enough_min_total, sum(enough_min_robust_error_3))
push!(enough_min_total, sum(enough_min_robust_error_2))
push!(enough_min_total, sum(enough_min_robust_error_1))

push!(enough_max_total, sum(enough_max_no_reserve))
push!(enough_max_total, sum(enough_max_generated_error_10))
push!(enough_max_total, sum(enough_max_generated_error_9))
push!(enough_max_total, sum(enough_max_generated_error_8))
push!(enough_max_total, sum(enough_max_robust_error_5))
push!(enough_max_total, sum(enough_max_robust_error_4))
push!(enough_max_total, sum(enough_max_robust_error_3))
push!(enough_max_total, sum(enough_max_robust_error_2))
push!(enough_max_total, sum(enough_max_robust_error_1))

push!(enough_minus_total, 0)
push!(enough_minus_total, sum(enough_minus_generated_error_10))
push!(enough_minus_total, sum(enough_minus_generated_error_9))
push!(enough_minus_total, sum(enough_minus_generated_error_8))
push!(enough_minus_total, sum(enough_minus_robust_error_5))
push!(enough_minus_total, sum(enough_minus_robust_error_4))
push!(enough_minus_total, sum(enough_minus_robust_error_3))
push!(enough_minus_total, sum(enough_minus_robust_error_2))
push!(enough_minus_total, sum(enough_minus_robust_error_1))

push!(enough_plus_total, 0)
push!(enough_plus_total, sum(enough_plus_generated_error_10))
push!(enough_plus_total, sum(enough_plus_generated_error_9))
push!(enough_plus_total, sum(enough_plus_generated_error_8))
push!(enough_plus_total, sum(enough_plus_robust_error_5))
push!(enough_plus_total, sum(enough_plus_robust_error_4))
push!(enough_plus_total, sum(enough_plus_robust_error_3))
push!(enough_plus_total, sum(enough_plus_robust_error_2))
push!(enough_plus_total, sum(enough_plus_robust_error_1))

push!(cost_total, sum(cost_no_reserve))
push!(cost_total, sum(cost_generated_error_10))
push!(cost_total, sum(cost_generated_error_9))
push!(cost_total, sum(cost_generated_error_8))
push!(cost_total, sum(cost_robust_error_5))
push!(cost_total, sum(cost_robust_error_4))
push!(cost_total, sum(cost_robust_error_3))
push!(cost_total, sum(cost_robust_error_2))
push!(cost_total, sum(cost_robust_error_1))

push!(revenue_total, sum(pay_no_reserve))
push!(revenue_total, sum(pay_generated_error_10))
push!(revenue_total, sum(pay_generated_error_9))
push!(revenue_total, sum(pay_generated_error_8))
push!(revenue_total, sum(pay_robust_error_5))
push!(revenue_total, sum(pay_robust_error_4))
push!(revenue_total, sum(pay_robust_error_3))
push!(revenue_total, sum(pay_robust_error_2))
push!(revenue_total, sum(pay_robust_error_1))

CSV.write("output/test/final_results/enough_min_total.csv", Tables.table(enough_min_total/(362*24*100)), header=false)
CSV.write("output/test/final_results/enough_max_total.csv", Tables.table(enough_max_total/(362*24*100)), header=false)
CSV.write("output/test/final_results/enough_minus_total.csv", Tables.table(enough_minus_total/(362*24*100)), header=false)
CSV.write("output/test/final_results/enough_plus_total.csv", Tables.table(enough_plus_total/(362*24*100)), header=false)
CSV.write("output/test/final_results/cost_total.csv", Tables.table(cost_total), header=false)
CSV.write("output/test/final_results/revenue_total.csv", Tables.table(revenue_total), header=false)
