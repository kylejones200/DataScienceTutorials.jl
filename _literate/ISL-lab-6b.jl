# ## Getting started

using MLJ
import RDatasets: dataset
using PrettyPrinting
MLJ.color_off() # hide
import Distributions
const D = Distributions

@load LinearRegressor pkg=MLJLinearModels
@load RidgeRegressor pkg=MLJLinearModels
@load LassoRegressor pkg=MLJLinearModels

hitters = dataset("ISLR", "Hitters")
@show size(hitters)
names(hitters) |> pprint

# The target is `Salary`

y, X = unpack(hitters, ==(:Salary), col->true);

# It has missing values which we will just ignore:

no_miss = .!ismissing.(y)
y = collect(skipmissing(y))
X = X[no_miss, :]
train, test = partition(eachindex(y), 0.5, shuffle=true, rng=424);

#

using PyPlot

figure(figsize=(8,6))
plot(y, ls="none", marker="o")

xticks(fontsize=12); yticks(fontsize=12)
xlabel("Index", fontsize=14), ylabel("Salary", fontsize=14)

savefig(joinpath(@OUTPUT, "ISL-lab-6-g1.svg")) # hide

# \figalt{Salary}{ISL-lab-6-g1.svg}

# That looks quite skewed, let's have a look at a histogram:

figure(figsize=(8,6))
hist(y, bins=50, density=true)

xticks(fontsize=12); yticks(fontsize=12)
xlabel("Salary", fontsize=14); ylabel("Density", fontsize=14)

edfit = D.fit_mle(D.Exponential, y)
xx = range(minimum(y), 2500, length=100)
yy = pdf.(edfit, xx)
plot(xx, yy, lw=3, label="Exponential distribution fit")

legend(fontsize=12)

savefig(joinpath(@OUTPUT, "ISL-lab-6-g2.svg")) # hide

# \figalt{Distribution of salary}{ISL-lab-6-g2.svg}
#
# ### Data preparation
#
# Most features are currently encoded as integers but we will consider them as continuous

Xc = coerce(X, autotype(X, rules=(:discrete_to_continuous,)))
scitype(Xc)

# There're a few features that are categorical which we'll one-hot-encode.

# ## Ridge pipeline
# ### Baseline
#
# Let's first fit a simple pipeline with a standardizer, a one-hot-encoder and a basic linear regression:

@pipeline RegPipe(std = Standardizer(),
                  hot = OneHotEncoder(),
                  reg = LinearRegressor())

model = RegPipe()
pipe  = machine(model, Xc, y)
fit!(pipe, rows=train)
ŷ = predict(pipe, rows=test)
round(rms(ŷ, y[test])^2, sigdigits=4)

# Let's get a feel for how we're doing

figure(figsize=(8,6))

res = ŷ .- y[test]
stem(res)

xticks(fontsize=12); yticks(fontsize=12)
xlabel("Index", fontsize=14); ylabel("Residual (ŷ - y)", fontsize=14)

ylim([-1300, 1000])

savefig(joinpath(@OUTPUT, "ISL-lab-6-g3.svg")) # hide

# \figalt{Residuals}{ISL-lab-6-g3.svg}

figure(figsize=(8,6))
hist(res, bins=30, density=true, color="green")

xx = range(-1100, 1100, length=100)
ndfit = D.fit_mle(D.Normal, res)
lfit  = D.fit_mle(D.Laplace, res)

plot(xx, pdf.(ndfit, xx), lw=3, color="orange", label="Normal fit")
plot(xx, pdf.(lfit, xx), lw=3, color="magenta", label="Laplace fit")

legend(fontsize=12)

xticks(fontsize=12); yticks(fontsize=12)
xlabel("Residual (ŷ - y)", fontsize=14); ylabel("Density", fontsize=14)
xlim([-1100, 1100])

savefig(joinpath(@OUTPUT, "ISL-lab-6-g4.svg")) # hide

# \figalt{Distribution of residuals}{ISL-lab-6-g4.svg}

# ### Basic Ridge
#
# Let's now swap the linear regressor for a Ridge one without specifying the penalty (`1` by default):

pipe.model.reg = RidgeRegressor()
fit!(pipe, rows=train)
ŷ = predict(pipe, rows=test)
round(rms(ŷ, y[test])^2, sigdigits=4)

# Ok that's a bit better but surely we can do better with an appropriate selection of the hyperparameter.

# ### Cross validating

# What penalty should you use? Let's do a simple CV to try  to find out:

r  = range(model, :(reg.lambda), lower=1e-2, upper=100_000, scale=:log10)
tm = TunedModel(model=model, ranges=r, tuning=Grid(resolution=50),
                resampling=CV(nfolds=3, rng=4141), measure=rms)
mtm = machine(tm, Xc, y)
fit!(mtm, rows=train)

best_mdl = fitted_params(mtm).best_model
round(best_mdl.reg.lambda, sigdigits=4)

# right, and  with that we get:

ŷ = predict(mtm, rows=test)
round(rms(ŷ, y[test])^2, sigdigits=4)

# Let's see:

figure(figsize=(8,6))

res = ŷ .- y[test]
stem(res)

xticks(fontsize=12); yticks(fontsize=12)
xlabel("Index", fontsize=14); ylabel("Residual (ŷ - y)", fontsize=14)

ylim([-1300, 1000])

savefig(joinpath(@OUTPUT, "ISL-lab-6-g5.svg")) # hide

# \figalt{Ridge residuals}{ISL-lab-6-g5.svg}
#
# You can compare that with the residuals obtained earlier.

# ## Lasso pipeline
#
# Let's do the same as above but using a Lasso model and adjusting the range a bit:

mtm.model.model.reg = LassoRegressor()
mtm.model.range = range(model, :(reg.lambda), lower=500, upper=100_000, scale=:log10)
fit!(mtm, rows=train)

best_mdl = fitted_params(mtm).best_model
round(best_mdl.reg.lambda, sigdigits=4)

# Ok and let's see how that does:

ŷ = predict(mtm, rows=test)
round(rms(ŷ, y[test])^2, sigdigits=4)

# Pretty good! and the parameters are reasonably sparse as expected:

coefs, intercept = fitted_params(mtm.fitresult.fitresult.machine)
@show coefs
@show intercept

# with around 50% sparsity:

coef_vals = [c[2] for c in coefs]
sum(coef_vals .≈ 0) / length(coefs)

# Let's visualise this:

figure(figsize=(8,6))
stem(coefs)

## name of the features including one-hot-encoded ones
all_names = [:AtBat, :Hits, :HmRun, :Runs, :RBI, :Walks, :Years,
             :CAtBat, :CHits, :CHmRun, :CRuns, :CRBI, :CWalks,
             :League__A, :League__N, :Div_E, :Div_W,
             :PutOuts, :Assists, :Errors, :NewLeague_A, :NewLeague_N]

idxshow = collect(1:length(coefs))[abs.(coefs) .> 10]
xticks(idxshow .- 1, all_names[idxshow], rotation=45, fontsize=12)
yticks(fontsize=12)
ylabel("Amplitude", fontsize=14)

savefig(joinpath(@OUTPUT, "ISL-lab-6-g6.svg")) # hide

# \figalt{Lasso coefficients}{ISL-lab-6-g6.svg}

# ## Elastic net pipeline

@load ElasticNetRegressor pkg=MLJLinearModels

mtm.model.model.reg = ElasticNetRegressor()
mtm.model.range = [range(model, :(reg.lambda), lower=0.1, upper=100, scale=:log10),
                    range(model, :(reg.gamma),  lower=500, upper=10_000, scale=:log10)]
mtm.model.tuning = Grid(resolution=10)
fit!(mtm, rows=train)

best_mdl = fitted_params(mtm).best_model
@show round(best_mdl.reg.lambda, sigdigits=4)
@show round(best_mdl.reg.gamma, sigdigits=4)

# And it's not too bad in terms of accuracy either

ŷ = predict(mtm, rows=test)
round(rms(ŷ, y[test])^2, sigdigits=4)

# But the simple ridge regression seems to work best here.
PyPlot.close_figs() # hide
