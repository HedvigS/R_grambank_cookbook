#This script contains the code from the package geoR for the particular funciton varcov.spatial. It was not possible to load the package itself due to problems with XQuartz from xquartz.macosforge.org no longer part of  OS X, making it cumbersome for many mac-users to run the code. We are grateful to the creators of the package (Paulo J. Ribeiro Jr, Peter J. Diggle, Ole Christensen, Martin Schlather, Roger Bivand and Brian Ripley) for their labour acknowledge that this is their funciton.
# ' Computes Covariance Matrix and Related Results. Adjusted function from geoR which computes earth distances better. The functions in the package files for geoR are in the script named "geoR/R/corcov.R".

#' @description
#' This function builds the covariance matrix for a set of spatial locations, given the covariance parameters. According to the input options other results related to the covariance matrix (such as decompositions, determinants, inverse. etc) can also be returned.
#' This function is an updated version of geoR::varcov.spatial. The adjustment concerns when the function is given coordinates. The old function used 2D euclidean distances (stats::dist()), which is not appropriate for earth. The updated function uses fields::rdst.earth() instead.
#' @param coords an n x 2 matrix with the coordinates of the data locations. First column should be longitudes and second  latitudes. The coords are passed to fields::rdist.earth() which compute greater-circle distances. If not provided the argument dists.lowertri should be provided instead.
#' @param dists.lowertri a vector with the lower triangle of the matrix of distances between pairs of data points. If not provided the argument coords should be provided instead.
#' @param cov.model a string indicating the type of the correlation function. More details in the documentation for cov.spatial. Defaults are equivalent to the exponential model.
#' @param kappa values of the additional smoothness parameter, only required by the following correlation functions: "matern", "powered.exponential", "cauchy" and "gneiting.matern".
#' @param nugget the value of the nugget parameter τ^2.
#' @param cov.pars a vector with 2 elements or an ns * 2 matrix with the covariance parameters. The first element (if a vector) or first column (if a matrix) corresponds to the variance parameter σ^2. The second element or column corresponds to the correlation function parameter φ. If a matrix is provided each row corresponds to the parameters of one spatial structure. Models with several structures are also called nested models in the geostatistical literature.
#' @param inv if TRUE the inverse of covariance matrix is returned. Defaults to FALSE.
#' @param det if TRUE the  logarithmic of the square root of the determinant of the covariance matrix is returned. Defaults to FALSE.
#' @param func.inv algorithm used for the decomposition and inversion of the covariance matrix. Options are "chol" for Cholesky decomposition, "svd" for singular value decomposition and "eigen" for eigenvalues/eigenvectors decomposition. Defaults to "chol".
#' @param scaledlogical indicating whether the covariance matrix should be scaled. If TRUE the partial sill parameter σ^2 is set to 1. Defaults to FALSE.
#' @param only.decomposition logical. If TRUE only the square root of the covariance matrix is returned. Defaults to FALSE.
#' @param sqrt.inv if TRUE the square root of the inverse of  covariance matrix is returned. Defaults to FALSE.
#' @param try.another.decomposition logical. If TRUE and the argument func.inv is one of "cholesky", "svd" or "solve", the matrix decomposition or inversion is tested and, if it fails, the argument func.inv is re-set to "eigen".
#' @param only.inv.lower.diaglogical. If TRUE only the lower triangle and the diagonal of the inverse of the covariance matrix are returned. Defaults to FALSE.
#' @param \dots Only for internal usage.
#' @details
#' The elements of the covariance matrix are computed by the function cov.spatial. Typically this is an auxiliary function called by other functions in the geoR package.
#'
#' @author Original function: Paulo J. Ribeiro Jr. and Peter J. Diggle. Updated function in this script (correcting stat:dist() -> fields::rdist.earth()): Hedvig Skirgård and Sam Passmore.
#' @note The differences between this function and the function in geoR (version 1.9-4) are as follows: when the user has not supplied the dists.lowertri-argument but has supplied coords, distances are calculated between the longitude latitude points using fields::rdist.earth instead of stats::dist. To make the scale more comparable to that of stats::dist, the distances are all divded by 100. Minor changes: the functions varcov.spatial and matern are now preceeded by a ".", making them hidden (as they are not to be used directly by the user of varcov.spatial.3D).
#' 

#' @returns The result is always list of the same kind as geoR::varcov.spatial. The components will vary according to the input options. The possible components are:
#' varcov the covariance matrix.
#'  sqrt.varcov a square root of the covariance matrix.
#' lower.inverse the lower triangle of the inverse of covariance matrix.
#' diag.inverse the diagonal of the inverse of covariance matrix.
#'  inverse the inverse of covariance matrix.
#'  sqrt.inverse a square root of the inverse of covariance matrix.
#' log.det.to.half the logarithmic of the square root of the determinant of the covariance matrix.
#' @export

varcov.spatial.3D <-
    function(coords = NULL, dists.lowertri = NULL, cov.model = "matern",
             kappa = 0.5, nugget = 0, cov.pars = stop("no cov.pars argument"),
             inv = FALSE, det = FALSE,
             func.inv = c("cholesky", "eigen", "svd", "solve"),
             scaled = FALSE, only.decomposition = FALSE,
             sqrt.inv = FALSE, try.another.decomposition = TRUE,
             only.inv.lower.diag = FALSE, ...)
    {
        func.inv <- match.arg(func.inv)
        cov.model <- sapply(cov.model, match.arg, choices = .geoR.cov.models)
        if(only.inv.lower.diag)  inv <- TRUE
        if(is.null(coords) & is.null(dists.lowertri))
            stop("one of the arguments, coords or dists.lowertri must be provided")
        if (!is.null(coords) & !is.null(dists.lowertri))
            stop("only ONE argument, either coords or dists.lowertri must be provided")
        if (!is.null(coords))  n <- nrow(coords)
        if (!is.null(dists.lowertri))
            n <- as.integer(round(0.5 * (1 + sqrt(1 + 8 * length(dists.lowertri)))))
        tausq <- nugget
        if (is.vector(cov.pars)) {
            sigmasq <- cov.pars[1]
            phi <- cov.pars[2]
        }
        else {
            sigmasq <- cov.pars[, 1]
            phi <- cov.pars[, 2]
        }
        ##  print(c(tausq=tausq, sigmasq=sigmasq, phi=phi, kappa=kappa))

        if (!is.null(coords)) {
            rdist.earth_dists <- fields::rdist.earth(x1 = coords, x2 = coords, miles = FALSE)

            #to make the dists more similar to what stats::dist would produce, and therefore easier to apply the same kappa and sigma values, we divide the distances by 100. This means that the distances are measured in 100’s of km rather than km’s.

            rdist.earth_dists <-  rdist.earth_dists / 100 #divide by 100 to make the scale similar to stat::dist

            rdist.earth_dists[upper.tri(rdist.earth_dists, diag = TRUE)] <- NA

            dists.lowertri <- as.vector(rdist.earth_dists) %>% na.omit()}

        if (round(1e+12 * min(dists.lowertri)) == 0)
            warning("Two or more pairs of data at coincident (or very close) locations. \nThis may cause crashes in some matrices operations.\n")
        varcov <- matrix(0, n, n)
        if (scaled) {
            if (all(phi < 1e-12))
                varcov <- diag(x = (1 + (tausq/sum(sigmasq))), n)
            else {
                if (is.vector(cov.pars)) cov.pars.sc <- c(1, phi)
                else cov.pars.sc <- cbind(1, phi)
                covvec <- .cov.spatial(obj = dists.lowertri, cov.model = cov.model,
                                      kappa = kappa, cov.pars = cov.pars.sc)
                varcov[lower.tri(varcov)] <- covvec
                varcov <- t(varcov)
                varcov[lower.tri(varcov)] <- covvec
                remove("covvec")
                if(sum(sigmasq) < 1e-16) diag(varcov) <- 1
                else diag(varcov) <- 1 + (tausq/sum(sigmasq))
            }
        }
        else {
            if (all(sigmasq < 1e-10) | all(phi < 1e-10)) {
                varcov <- diag(x = (tausq + sum(sigmasq)), n)
            }
            else {
                covvec <- .cov.spatial(obj = dists.lowertri, cov.model = cov.model,
                                      kappa = kappa, cov.pars = cov.pars)
                varcov[lower.tri(varcov)] <- covvec
                varcov <- t(varcov)
                varcov[lower.tri(varcov)] <- covvec
                remove("covvec")
                diag(varcov) <- tausq + sum(sigmasq)
            }
        }
        if (inv | det | only.decomposition | sqrt.inv | only.inv.lower.diag) {
            if (func.inv == "cholesky") {
                varcov.sqrt <- try(chol(varcov), silent=TRUE)
                if (inherits(varcov.sqrt, "try-error")) {
                    if (try.another.decomposition){
                        cat("trying another decomposition (svd)\n")
                        func.inv <- "svd"
                    }
                    else {
                        print(varcov.sqrt[1])
                        stop()
                    }
                }
                else {
                    if (only.decomposition | inv) remove("varcov")
                    if (!only.decomposition) {
                        if (det) cov.logdeth <- sum(log(diag(varcov.sqrt)))
                        if (sqrt.inv) inverse.sqrt <- solve(varcov.sqrt)
                        if (inv) {
                            invcov <- chol2inv(varcov.sqrt)
                            if (!sqrt.inv) remove("varcov.sqrt")
                        }
                    }
                }
            }
            if (func.inv == "svd") {
                varcov.svd <- svd(varcov, nv = 0)
                cov.logdeth <- try(sum(log(sqrt(varcov.svd$d))), silent=TRUE)
                if (inherits(cov.logdeth, "try-error")) {
                    if (try.another.decomposition){
                        cat("trying another decomposition (eigen)\n")
                        func.inv <- "eigen"
                    }
                    else {
                        print(cov.logdeth[1])
                        stop()
                    }
                }
                else {
                    if (only.decomposition | inv) remove("varcov")
                    if (only.decomposition)
                        varcov.sqrt <- crossprod(t(varcov.svd$u) * sqrt(sqrt(varcov.svd$d)))
                    if (inv) {
                        invcov <- crossprod(t(varcov.svd$u)/sqrt(varcov.svd$d))
                    }
                    if (sqrt.inv)
                        inverse.sqrt <- crossprod(t(varcov.svd$u)/sqrt(sqrt(varcov.svd$d)))
                }
            }
            if (func.inv == "solve") {
                if (det)
                    stop("the option func.inv == \"solve\" does not allow computation of determinants. \nUse func.inv = \"chol\",\"svd\" or \"eigen\"\n")
                invcov <- try(solve(varcov), silent=TRUE)
                if (inherits(cov.logdeth, "try-error")) {
                    if (try.another.decomposition)
                        func.inv <- "eigen"
                    else {
                        print(invcov[1])
                        stop()
                    }
                }
                remove("varcov")
            }
            if (func.inv == "eigen") {
                varcov.eig <- try(eigen(varcov, symmetric = TRUE), silent=TRUE)
                cov.logdeth <- try(sum(log(sqrt(varcov.eig$val))), silent=TRUE)
                if (inherits(cov.logdeth, "try.error") | inherits(varcov.eig, "try-error")) {
                    diag(varcov) <- 1.0001 * diag(varcov)
                    varcov.eig <- try(eigen(varcov, symmetric = TRUE), silent=TRUE)
                    cov.logdeth <- try(sum(log(sqrt(varcov.eig$val))), silent=TRUE)
                    if (inherits(cov.logdeth, "try.error") | inherits(varcov.eig, "try-error")) {
                        return(list(crash.parms = c(tausq=tausq, sigmasq=sigmasq, phi=phi, kappa=kappa)))
                    }
                }
                else {
                    if (only.decomposition | inv) remove("varcov")
                    if (only.decomposition)
                        varcov.sqrt <- crossprod(t(varcov.eig$vec)* sqrt(sqrt(varcov.eig$val)))
                    if (inv) invcov <- crossprod(t(varcov.eig$vec)/sqrt(varcov.eig$val))
                    if (sqrt.inv)
                        inverse.sqrt <- crossprod(t(varcov.eig$vec)/sqrt(sqrt(varcov.eig$val)))
                }
            }
        }
        if (!only.decomposition) {
            if (det) {
                if (inv) {
                    if (only.inv.lower.diag)
                        result <- list(lower.inverse = invcov[lower.tri(invcov)],
                                       diag.inverse = diag(invcov), log.det.to.half = cov.logdeth)
                    else result <- list(inverse = invcov, log.det.to.half = cov.logdeth)
                }
                else {
                    result <- list(varcov = varcov, log.det.to.half = cov.logdeth)
                }
                if (sqrt.inv)
                    result$sqrt.inverse <- inverse.sqrt
            }
            else {
                if (inv) {
                    if (only.inv.lower.diag)
                        result <- list(lower.inverse = invcov[lower.tri(invcov)],
                                       diag.inverse = diag(invcov))
                    else {
                        if (sqrt.inv)
                            result <- list(inverse = invcov, sqrt.inverse = inverse.sqrt)
                        else result <- list(inverse = invcov)
                    }
                }
                else result <- list(varcov = varcov)
            }
        }
        else result <- list(sqrt.varcov = varcov.sqrt)
        result$crash.parms <- NULL
        return(result)
    }







########################

".geoR.cov.models" <-
  c("matern", "exponential", "gaussian", "spherical",
    "circular", "cubic", "wave", "linear", "power",
    "powered.exponential", "stable", "cauchy", "gencauchy",
    "gneiting", "gneiting.matern", "pure.nugget")

########################
".check.cov.model" <-
  function(cov.model, cov.pars, kappa, env=NULL, output=TRUE)
    return(list(cov.model=cov.model, sigmasq=sigmasq, phi=phi, kappa=kappa, ns=ns))

########################

".matern" <-
  function (u, phi, kappa) 
  {
    if(is.vector(u)) names(u) <- NULL
    if(is.matrix(u)) dimnames(u) <- list(NULL, NULL)
    uphi <- u/phi
    uphi <- ifelse(u > 0,
                   (((2^(-(kappa-1)))/ifelse(0, Inf,gamma(kappa))) *
                      (uphi^kappa) *
                      besselK(x=uphi, nu=kappa)), 1)    
    uphi[u > 600*phi] <- 0 
    return(uphi)
  }

########################

".check.cov.model" <-
  function(cov.model, cov.pars, kappa, env=NULL, output=TRUE)
  {
    ## extracting covariance parameters
    if(is.vector(cov.pars)) sigmasq <- cov.pars[1]
    else sigmasq <- cov.pars[, 1]
    if(is.vector(cov.pars)) phi <-  cov.pars[2]
    else phi <- cov.pars[, 2]
    if(missing(kappa) || is.null(kappa)) kappa <- NA
    ## checking for nested models
    cov.pars <- drop(cov.pars)
    if(is.vector(cov.pars)) ns <- 1
    else{
      ns <- nrow(cov.pars)
      if(length(cov.model) == 1) cov.model <- rep(cov.model, ns)
      if(length(kappa) == 1) kappa <- rep(kappa, ns)
    }
    if(length(cov.model) != ns) stop("wrong length for cov.model")
    ##
    cov.model <- sapply(cov.model, match.arg, .geoR.cov.models)
    cov.model[cov.model == "stable"] <- "powered.exponential"
    if(any(cov.model == c("gneiting.matern", "gencauchy"))){
      if(length(kappa) != 2*ns)
        stop(paste("wrong length for kappa, ", cov.model, "model requires two values for the argument kappa")) 
    }
    else{
      if(length(kappa) != ns) stop('wrong length for kappa')
    }
    ## settings for power model (do not reverse order of the next two lines!)
    phi[cov.model == "linear"] <- 1
    cov.model[cov.model == "linear"] <- "power"
    ## checking input for cov. models with extra parameter(s)
    if(any(cov.model == 'gneiting.matern') && ns > 1)
      stop('nested models including the gneiting.matern are not implemented') 
    for(i in 1:ns){
      if(any(cov.model[i] == c("matern","powered.exponential", "cauchy",
                               "gneiting.matern", "gencauchy"))){
        if(any(cov.model[i] == c("gneiting.matern", "gencauchy"))){
          if(any(is.na(kappa)) || length(kappa) != 2*ns)
            stop(paste(cov.model[i],"correlation function model requires a vector with 2 parameters in the argument kappa"))
        }
        else{
          if(is.na(kappa[i]) | is.null(kappa[i]))
            stop("for matern, powered.exponential and cauchy covariance functions the parameter kappa must be provided")
        }
        if((cov.model[i] == "matern" | cov.model[i] == "powered.exponential" | 
            cov.model[i] == "cauchy") & length(kappa) != 1*ns)
          stop("kappa must have 1 parameter for this correlation function")
        if(cov.model[i] == "matern" & kappa[i] == 0.5) cov.model[i] == "exponential"
      }      
      if(cov.model[i] == "power")
        if(any(phi[i] >= 2) | any(phi[i] <= 0))
          stop("for power model the phi parameters must be in the interval ]0,2[")
    }
    if(!is.null(env)){
      assign("sigmasq", sigmasq, envir=env)
      assign("phi", phi, envir=env)
      assign("kappa", kappa, envir=env)
      assign("ns", ns, envir=env)
      assign("cov.model", cov.model, envir=env)
    }
    if(output)
      return(list(cov.model=cov.model, sigmasq=sigmasq, phi=phi, kappa=kappa, ns=ns))
    else return(invisible())
  }

######################

".cov.spatial" <-
  function(obj, cov.model = "matern",
           cov.pars = stop("no cov.pars argument provided"),
           kappa = 0.5)
  {
    fn.env <- sys.frame(sys.nframe())
    .check.cov.model(cov.model=cov.model, cov.pars=cov.pars, kappa=kappa,
                     env=fn.env, output=FALSE)
    phi <- get("phi", envir=fn.env)
    sigmasq <- get("sigmasq", envir=fn.env)
    ##
    ## computing correlations/covariances
    ##
    #  covs <- array(0, dim = dim(obj))
    covs <- obj; covs[] <- 0 
    for(i in 1:get("ns", envir=fn.env)) {
      if(phi[i] < 1e-16)
        cov.model[i] <- "pure.nugget"
      obj.sc <- obj/phi[i]
      cov.values <- switch(cov.model[i],
                           pure.nugget = rep(0, length(obj)),
                           wave = (1/obj) * (phi[i] * sin(obj.sc)),
                           exponential = exp( - (obj.sc)),
                           matern = {
                             if(kappa[i] == 0.5) exp( - (obj.sc))
                             else .matern(u = obj, phi = phi[i], kappa = kappa[i])},
                           gaussian = exp( - ((obj.sc)^2)),
                           spherical = ifelse(obj < phi[i], (1 - 1.5 * (obj.sc) +
                                                               0.5 * (obj.sc)^3), 0),
                           circular = {
                             obj.sc[obj.sc > 1] <- 1;
                             ifelse(obj < phi[i], (1 - (2 * ((obj.sc) *
                                                               sqrt(1 - ((obj.sc)^2)) +
                                                               asin(obj.sc)))/pi), 0)
                           },
                           cubic = {
                             ifelse(obj < phi[i], (1 - (7 * (obj.sc^2) -
                                                          8.75 * (obj.sc^3) +
                                                          3.5 * (obj.sc^5) -
                                                          0.75 * (obj.sc^7))), 0)
                           },
                           power = (obj)^phi,
                           powered.exponential = exp( - ((obj.sc)^kappa[i])),
                           cauchy = (1 + (obj.sc)^2)^(-kappa[i]),
                           gneiting = {
                             obj.sc <- 0.301187465825 * obj.sc;   
                             t2 <- (1 - obj.sc);
                             t2 <- ifelse(t2 > 0, (t2^8), 0);
                             (1 + 8 * obj.sc + 25 * (obj.sc^2) + 32 * (obj.sc^3)) * t2
                           },
                           gencauchy = (1 + (obj.sc)^kappa[2])^(-kappa[1]/kappa[2]),
                           gneiting.matern = {
                             obj.sc <- 0.301187465825 * obj.sc/kappa[2] ;
                             t2 <- (1 - obj.sc);
                             t2 <- ifelse(t2 > 0, (t2^8), 0);
                             cov.values <- (1 + 8 * obj.sc + 25 * (obj.sc^2) + 32 * (obj.sc^3)) * t2;
                             cov.values * .matern(u = obj, phi = phi[i], kappa = kappa[1])
                             
                           },
                           stop("wrong or no specification of cov.model")
      )
      if(cov.model[i] == "power"){
        A <- (max(cov.values)/sqrt(pi))*gamma((1+phi[i])/2)*gamma(1-(phi[i]/2))
        ## 1:2 below ensures valid results for 1 and 2D
        A <- A * max(gamma(phi[i]+(1+(1:2))/2)/(gamma(1+phi[i])*gamma((1+(1:2))/2)))
        cov.values <- A - cov.values
        cov.values <- cov.values/max(cov.values)
      }
      cov.values <- ifelse(obj < 1e-16, sigmasq[i], sigmasq[i] * cov.values)
      covs <- covs + cov.values
    }
    #  if(all(cov.model == "power"))
    #    covs <- max(covs) - covs
    #  else covs[obj < 1e-16] <- sum(sigmasq)
    if(sum(sigmasq) < 1e-16) covs[obj < 1e-16] <- 1
    if(any(!is.finite(covs))) warning("Infinity value in .cov.spatial")
    if(any(is.na(covs))) warning("NA value in .cov.spatial")
    if(any(is.nan(covs))) warning("NaN value in .cov.spatial")
    return(covs)
  }