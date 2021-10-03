using Base.Iterators: partition
using Flux
using Flux.Optimise: update!
using Flux.Losses: logitbinarycrossentropy
using Flux.Data: DataLoader
using DataFrames, CSV
using Plots, StatsPlots
using Statistics, Random
using Parameters: @with_kw
using Gurobi
using JuMP
using MAT
using StatsBase

# Load functions and model
include("src_OPF/tools.jl") # Some additional functions
include("src_OPF/input.jl") # Type definitions and read-in functions
include("src_OPF/model_definition.jl") # Model definiton
include("src_OPF/output.jl") # Postprocessing of solved model

net = load_net("data/data_OPF")
wind_power = load_timeseries("data/data_OPF")
wind_num, t_num  = size(wind_power)

k = 0.8

@with_kw struct HyperParams
    full_size::Int = 1100
    training_size::Int = 1000
    testing_size::Int = 100
    nclasses::Int = 4
    batch_size::Int = 100
    latent_dim::Int = 100
    epochs::Int = 30
    verbose_freq::Int = training_size/batch_size
    output_x::Int = 4
    output_y::Int = 3
    lr_dscr::Float64 = 0.02
    lr_gen::Float64 = 0.02
    data_rows::Int = 12
    data_cols::Int = 24
    data_size::Int = data_rows*data_cols
end

struct Discriminator
    d_labels
    d_common
end

function discriminator(hparams)
    d_labels = Chain(Dense(hparams.nclasses, hparams.data_size),
                  x-> reshape(x, hparams.data_rows, hparams.data_cols, 1, size(x, 2)))
    d_common = Chain(Conv((3,3), 2=>12, stride = (2,2), pad = SamePad()),
                  x-> leakyrelu.(x, 0.2),
                  Dropout(0.25),
                  Conv((3,3), 12=>12, stride = (2,2), pad = SamePad(), leakyrelu),
                  x-> leakyrelu.(x, 0.2),
                  x-> reshape(x, :, size(x, 4)),
                  Dropout(0.25),
                  Dense(216, 1))
    Discriminator(d_labels, d_common)
end

function (m::Discriminator)(x, y)
    t = cat(m.d_labels(x), y, dims=3)
    return m.d_common(t)
end

struct Generator
    g_labels
    g_latent
    g_common
end

function generator(hparams)
    g_labels = Chain(Dense(hparams.nclasses, 4608),
           x-> reshape(x, (48, 96, 1, size(x, 2))))
    g_latent = Chain(Dense(hparams.latent_dim, 4608),
           x-> leakyrelu.(x, 0.2),
           x-> reshape(x, (48, 96, 1, size(x, 2))))
    g_common = Chain(Conv((3, 3), 2=>12; stride=2, pad=SamePad()),
            BatchNorm(12, leakyrelu),
            Dropout(0.25),
            Conv((3, 3), 12=>12; stride=2, pad=SamePad()),
            BatchNorm(12, leakyrelu),
            Conv((3, 3), 12=>1, tanh; stride=1, pad=SamePad()))
    Generator(g_labels, g_latent, g_common)
end

function (m::Generator)(x, y)
    t = cat(m.g_labels(x), m.g_latent(y), dims=3)
    return m.g_common(t)
end

function load_data(hparams)
    fileIn = matopen("data/data_load/RT_load.mat")
    RT_training_load = read(fileIn)
    close(fileIn)
    fileIn = matopen("data/data_load/DA_load.mat")
    DA_training_load = read(fileIn)
    close(fileIn)
    RT_load = get(RT_training_load, "RT_load",1)
    DA_load = get(DA_training_load, "DA_load",1)

    # Normalization
    max_load = []
    min_load = []
    mean_load = []
    for i in 1:hparams.full_size
        maxs,  = findmax(DA_load[:,:,i], dims=2)
        mins,  = findmin(DA_load[:,:,i], dims=2)
        means = mean(DA_load[:,:,i], dims=2)
        push!(max_load, maxs)
        push!(min_load, mins)
        push!(mean_load, means)
    end
    DA_load_norm = zeros(hparams.data_rows, hparams.data_cols, hparams.full_size)
    RT_load_norm = zeros(hparams.data_rows, hparams.data_cols, hparams.full_size)
    for i in 1:hparams.full_size
        DA_load_norm[:,:,i] = (DA_load[:,:,i].-mean_load[i])./(max_load[i]-min_load[i])
        RT_load_norm[:,:,i] = (RT_load[:,:,i].-mean_load[i])./(max_load[i]-min_load[i])
    end
    Error_norm = RT_load_norm - DA_load_norm
    Error_norm_piled = reshape(Error_norm, (hparams.data_rows, hparams.data_cols*hparams.full_size))

    # Standardization
    dt = fit(ZScoreTransform, Error_norm_piled, dims=2)
    Error_norm0 = StatsBase.transform(dt, Error_norm_piled)
    data_tensor = reshape(Error_norm0, (hparams.data_rows, hparams.data_cols, 1, :))

    labels = zeros(hparams.full_size,1)
    for i in 1:hparams.full_size
        if i % 365 <= 90
            labels[i] = 0
        elseif i % 365 <= 181
            labels[i] = 1
        elseif i % 365 <= 273
            labels[i] = 2
        else
            labels[i] = 3
        end
    end

    #sample(1:1100, 100, replace=false)

    y = reshape(float.(Flux.onehotbatch(labels, 0:hparams.nclasses-1)), (hparams.nclasses, hparams.full_size))
    data_train = DataLoader((data_tensor[:,:,:,1:1000], y[:,1:1000], DA_load[:,:,1:1000]), batchsize=hparams.batch_size, shuffle=true)
    data_test = DataLoader((data_tensor[:,:,:,1001:1100], y[:,1001:1100], DA_load[:,:,1001:1100]), batchsize=hparams.batch_size, shuffle=true)
    return data_train, data_test, dt
end

# Loss functions
function discr_loss(real_output, fake_output)
    real_loss = logitbinarycrossentropy(real_output, 0f0)
    fake_loss = logitbinarycrossentropy(fake_output, 1f0)
    return (real_loss + fake_loss)
end

function generator_loss1(fake_output)
    gen_loss1 = logitbinarycrossentropy(fake_output, 0f0)*k
    return gen_loss1
end

function generator_loss2(fake_output, λ, hparams)
    fake_data = reshape(fake_output, (hparams.data_rows, hparams.data_cols))
    gen_loss2 = -sum(fake_data.*λ)/200/hparams.batch_size*(1-k)
    return gen_loss2
end

function train_discr(discr, fake_data, fake_labels, original_data, original_label, opt_discr)
    ps_discr = params(discr.d_labels, discr.d_common)
    loss = discr_loss(discr(original_label, original_data), discr(fake_labels, fake_data))
    gs_discr = gradient(() -> discr_loss(discr(original_label, original_data), discr(fake_labels, fake_data)), ps_discr)
    update!(opt_discr, ps_discr, gs_discr)
    return loss
end

function train_gen(gen, discr, original_data, original_label, original_load, opt_gen, opt_discr, hparams, dt)
    # Random Gaussian Noise and Labels as input for the generator
    noise = randn!(similar(original_data, (hparams.latent_dim, hparams.batch_size)))
    fake_labels = rand(0:hparams.nclasses-1, hparams.batch_size)
    fake_y = Flux.onehotbatch(fake_labels, 0:hparams.nclasses-1)
    noise, fake_y  = noise, float.(fake_y)
    fake_data = gen(fake_y, noise)

    ps_gen = params(gen.g_labels, gen.g_latent, gen.g_common)
    gs_gen1 = gradient(() -> generator_loss1(discr(fake_y, gen(fake_y, noise))), ps_gen)
    update!(opt_gen, ps_gen, gs_gen1)

    cost = []
    a = zeros(hparams.data_rows, hparams.data_cols*hparams.full_size, hparams.batch_size)
    a[:,1:hparams.data_cols,:] = reshape(fake_data, (hparams.data_rows, hparams.data_cols, :))

    for i in 1:hparams.batch_size
        final_results0 = StatsBase.reconstruct(dt::ZScoreTransform, a[:,1:hparams.data_cols,i])
        maxs,  = findmax(original_load[:,:,i], dims=2)
        mins,  = findmin(original_load[:,:,i], dims=2)
        gen_load = final_results0 .*(maxs - mins) + original_load[:,:,i]

        C, λ = run_case_study(net, wind_power, gen_load[1:hparams.data_rows-1,1:hparams.data_cols], wind_num, t_num)
        λλ = zeros(hparams.data_rows, hparams.data_cols)
        λλ[1:hparams.data_rows-1, 1:hparams.data_cols] = λ
        λλ[hparams.data_rows,:] = λλ[6,:]
        push!(cost, sum(C)/hparams.batch_size/7e6)
        gs_gen2 = gradient(() -> generator_loss2(gen(fake_y, noise)[:,:,:,i], λλ, hparams), ps_gen)
        update!(opt_gen, ps_gen, gs_gen2)
    end

    loss = Dict()
    loss["discr"] = train_discr(discr, fake_data, fake_y, original_data, original_label, opt_discr)
    loss["gen1"] = generator_loss1(discr(fake_y, fake_data))*k
    loss["gen2"] = sum(cost)*(1-k)
    return loss
end

function train_cGAN()
    hparams = HyperParams()
    data_train, data_test, dt = load_data(hparams)
    # Discriminator
    discr = discriminator(hparams)
    # Generator
    gen =  generator(hparams)
    # Optimizers
    opt_discr = Descent(hparams.lr_dscr)
    opt_gen = Descent(hparams.lr_gen)

    # Check if the `output` directory exists or needed to be created
    isdir("output")||mkdir("output")
    loss_discr = []
    loss_gen1 = []
    loss_gen2 = []

    # Training
    train_steps = 0
    total_cost = []
    for ep in 1:hparams.epochs
        @info "Epoch $ep"
        for (x, y, z) in data_train
            # Update discriminator and generator
            loss = train_gen(gen, discr, x, y, z, opt_gen, opt_discr, hparams, dt)

            if train_steps % hparams.verbose_freq == 0
                @info("Train step $(train_steps), Discriminator loss = $(loss["discr"]),
                Generator loss 1= $(loss["gen1"]), Generator loss 2= $(loss["gen2"])")
                push!(loss_gen1, loss["gen1"])
                push!(loss_gen2, loss["gen2"])
                push!(loss_discr, loss["discr"])
                # Save generated fake data
                for i in 0:hparams.nclasses-1
                    test_output = create_test_output(gen, hparams, i)
                    a = zeros(hparams.data_rows,hparams.data_cols*hparams.full_size)
                    a[:,1:hparams.data_cols] = test_output
                    final_results0 = StatsBase.reconstruct(dt::ZScoreTransform, a)
                    draw_pictures(ep, final_results0[:,1:hparams.data_cols], hparams, i)
                end
            end
            train_steps += 1
        end        
        for (x, y, z) in data_test
            OPF_cost = test_G(ep, gen, hparams, x, y, z, dt)
            push!(total_cost, sum(OPF_cost))
        end
    end
    save_loss(loss_gen1, loss_gen2, loss_discr, total_cost, hparams)
end

function create_test_output(gen, hparams, i)
    test_noise = randn(hparams.latent_dim, 1)
    test_labels = float.(Flux.onehotbatch(i, 0:hparams.nclasses-1))
    test_output = gen(test_labels, test_noise)
    return test_output
end

function test_G(ep, gen, hparams, test_error, test_labels, original_load, dt)
    test_noise = randn(hparams.latent_dim, hparams.batch_size)
    test_data = gen(test_labels, test_noise)

    OPF_cost = []
    a = zeros(hparams.data_rows, hparams.data_cols*hparams.full_size, hparams.batch_size)
    a[:,1:hparams.data_cols,:] = reshape(test_data, (hparams.data_rows, hparams.data_cols, :))

    final_results0 = StatsBase.reconstruct(dt::ZScoreTransform, a[:,1:hparams.data_cols,1])
    maxs,  = findmax(original_load[:,:,1], dims=2)
    mins,  = findmin(original_load[:,:,1], dims=2)
    gen_error_piled = final_results0 .*(maxs - mins)
    gen_load = gen_error_piled + original_load[:,:,1]

    C, λ = run_case_study(net, wind_power, gen_load[1:hparams.data_rows-1,1:hparams.data_cols], wind_num, t_num)
    push!(OPF_cost, sum(C))

    for i in 2:hparams.testing_size
        final_results0 = StatsBase.reconstruct(dt::ZScoreTransform, a[:,1:hparams.data_cols,i])
        maxs,  = findmax(original_load[:,:,i], dims=2)
        mins,  = findmin(original_load[:,:,i], dims=2)
        gen_error = final_results0 .*(maxs - mins)
        gen_error_piled = vcat(gen_error_piled, gen_error)
        gen_load = gen_error + original_load[:,:,i]

        C, λ = run_case_study(net, wind_power, gen_load[1:hparams.data_rows-1,1:hparams.data_cols], wind_num, t_num)
        push!(OPF_cost, sum(C))
    end
    CSV.write("output/output_OPF/test/Error_$ep.csv", Tables.table(gen_error_piled), header=false)
    return OPF_cost
end

function draw_pictures(datadir, test_output, hparams, i)
    df = DataFrame(A = 1:24, B =rand(24))
    plotd1 = @df df plot(test_output[1,:])
    plotd2 = @df df plot(test_output[2,:])
    plotd3 = @df df plot(test_output[3,:])
    plotd4 = @df df plot(test_output[4,:])
    plotd5 = @df df plot(test_output[5,:])
    plotd6 = @df df plot(test_output[6,:])
    plotd7 = @df df plot(test_output[7,:])
    plotd8 = @df df plot(test_output[8,:])
    plotd9 = @df df plot(test_output[9,:])
    plotd10 = @df df plot(test_output[10,:])
    plotd11 = @df df plot(test_output[11,:])
    plotd12 = @df df plot(test_output[12,:])
    plotd = plot(plotd1,plotd2,plotd3,plotd4,plotd5,plotd6,plotd7,plotd8,plotd9,plotd10,plotd11,plotd12,
                 layout = (4, 3), legend = false, fmt = :png)
    savefig(plotd,"output/output_OPF/label_$i/$datadir.png")
    CSV.write("output/output_OPF/label_$i/Power_$datadir.csv", Tables.table(test_output), header=false)
end

function save_loss(loss_gen1, loss_gen2, loss_discr, total_cost, hparams)
    e_list = collect(1:hparams.epochs)
    f = open("output/output_OPF/loss_gen1.txt", "w")
    for e in e_list
        println(f, loss_gen1[e])
    end
    close(f)
    f = open("output/output_OPF/loss_gen2.txt", "w")
    for e in e_list
        println(f, loss_gen2[e])
    end
    close(f)
    f = open("output/output_OPF/loss_gen_sum.txt", "w")
    for e in e_list
        println(f, loss_gen1[e]+loss_gen2[e])
    end
    close(f)
    f = open("output/output_OPF/loss_discr.txt", "w")
    for e in e_list
        println(f, loss_discr[e])
    end
    close(f)
    f = open("output/output_OPF/total_cost.txt", "w")
    for e in e_list
        println(f, total_cost[e])
    end
    close(f)
end
train_cGAN()
