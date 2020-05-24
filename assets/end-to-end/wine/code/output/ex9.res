MnPipe(
    std = Standardizer(
            features = Symbol[],
            ignore = false,
            ordered_factor = false,
            count = false),
    clf = MultinomialClassifier(
            lambda = 1.0,
            gamma = 0.0,
            penalty = :l2,
            fit_intercept = true,
            penalize_intercept = false,
            solver = nothing,
            nclasses = 2)) @ 1…64