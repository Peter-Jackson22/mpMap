#' Fit a full model including all QTL and effects from base model
#' 
#' Given the output from a scan of chromosomes with significant genetic
#' variation, fits a full mixed model containing all effects in base model and
#' all QTL effects. 
#' @aliases fit fit.mpqtl
#' @importFrom stats cor
#' @importFrom stats update
#' @importFrom stats as.formula
#' @importFrom stats coef
#' @importFrom stats vcov
#' @param object Object of class \code{mpqtl}
# @param baseModel asreml output from fit of base model
# @param pheno data frame containing phenotypes required to fit base model
# @param qindex Optional indices for which QTL to include
#' @param \dots Additional arguments to be used in \code{asreml}
#' @return An asreml model and summary table of QTL effects, p-values and Wald statistics from fitting the full model; also, percent phenotypic variance explained by full model and by each QTL individually.
#' @seealso \code{\link[mpMap]{mpIM}}, \code{\link[mpMap]{summary.mpqtl}}
#' @examples
#' sim.map <- qtl::sim.map(len=rep(100, 2), n.mar=11, include.x=FALSE, eq.spacing=TRUE)
#' sim.ped <- sim.mpped(4, 1, 500, 6, 1)
#' sim.dat <- sim.mpcross(map=sim.map, pedigree=sim.ped, 
#'		qtl=matrix(data=c(1, 10, .4, 0, 0, 0, 1, 70, 0, .35, 0, 0), 
#'		nrow=2, ncol=6, byrow=TRUE), seed=1)
#' mpp.dat <- mpprob(sim.dat, program="qtl", step=2)
#' mpq.dat <- mpIM(object=mpp.dat, ncov=0, responsename="pheno")
#' fit(mpq.dat)

#' @export
fit <- function(object, ...)
{
	UseMethod("fit")
}

# note: random effects fitting will eventually be added. Not currently an option
#' @export
#' @method fit mpqtl
fit.mpqtl <- function(object, baseModel, pheno, qindex,  ...)
{

  if (!inherits(object, "mpqtl")) stop("Must have object of type mpqtl to
	  fit full model\n")

  output <- list()

  ## given a QTL object want to fit a full model 
  ## containing all the terms in the base model, etc. 
  lines <- rownames(object$finals)
  qtlres <- object$QTLresults$qtl
  nqtl <- attr(qtlres, "nqtl")
  n.founders <- nrow(object$founders)
  map <- object$map
  f3 <- substr(rownames(object$founders), 1, 3)
  fmap <- attr(object$prob, "map")
  baseModel <- object$QTLresults$baseModel
  pheno <- object$QTLresults$pheno
  method <- attr(object$QTLresults, "method")

  if (missing(qindex)) qindex <- 1:nqtl
  nqtl <- length(qindex)

  ## need to figure out what position they're at
  ## attr(, "index") may be useful for this
  ## is this something updated with findqtl2?

  ## so we need to a) set up a df to include the genetic terms for 
  ## each QTL
  ## b) replace the third term in the fixed model statement
  ## c) extract all the estimates etc. and store them
#  index <- unlist(lapply(qtlres, function(x) attr(x, "index")))
  index <- unlist(attr(qtlres, "index"))
  chr <- rep(names(qtlres), unlist(lapply(qtlres, function(x) return(nrow(x)))))
  chr <- chr[qindex]
  gen <- list()
  ## check this is extracting the right columns
  pr <- do.call("cbind", object$prob)
  for (i in 1:length(qindex)) {
	gen[[i]] <- pr[, (index[qindex[i]]-1)*n.founders+1:n.founders]
#object$prob[[chr[i]]][,(index[i]-1)*n.founders+1:n.founders]
  
	qq <- which(cor(gen[[i]][, 1:n.founders])>.95, arr.ind=T)
	qq <- qq[qq[,1]<qq[,2],, drop=F]
	  if (nrow(qq)>0) {
	    for (pp in 1:nrow(qq))
	      gen[[i]][,qq[pp,1]] <- gen[[i]][,qq[pp,2]] <- (gen[[i]][,qq[pp,1]]+gen[[i]][,qq[pp,2]])/2
	  }
	}
  
  gen <- do.call("cbind", gen)
  colnames(gen) <- paste("P", rep(1:(ncol(gen)/n.founders), each=n.founders), "F", LETTERS[1:n.founders], sep="")

  df <- matrix(nrow=nrow(pheno), ncol=ncol(gen))

  genid <- vector()
  pheid <- vector()
  for (k in 1:length(lines)) {
   	  matchid <- which(as.character(pheno$id)==as.character(lines[k]))
     	  genid <- c(genid, rep(k, length(matchid)))
     	  pheid <- c(pheid, matchid) 
  	}
  df <- as.matrix(gen[genid,])
  df <- cbind(pheno[pheid,], df)
  df <- as.data.frame(df)

  for (k in 1:ncol(pheno))
  {
    	fx <- paste("as.", class(pheno[,k]), sep="")
     	df[, k] <- do.call(fx, list(df[,k]))
  }
  names(df) <- c(names(pheno), colnames(gen))

  # recenter probabilities to 0
  df[, (ncol(pheno)+1):ncol(df)] <- scale(df[, (ncol(pheno)+1):ncol(df)], scale=FALSE)
  

  wald <- vector(length=nqtl)
  pval <- vector(length=nqtl)
  pvar <- vector(length=nqtl)
  degf <- vector(length=nqtl)
  fmrkl <- vector(length=nqtl)
  fmrkr <- vector(length=nqtl)

  if (method=="lm") {
    mod <- update(baseModel, 
	formula=eval(as.formula(paste(baseModel$call$formula[2], 
	baseModel$call$formula[1], 
	paste(c(as.character(baseModel$call$formula[3]), 
	names(df)[ncol(pheno)+1:ncol(gen)]), collapse="+"), sep=""))), 
	data=df)

    cat("Percent Phenotypic Variance explained by full model: ", round(100*summary(mod)$adj.r.squared, 2), "\n")

 if (!requireNamespace("aods3", quietly = TRUE)) {
    stop("aods3 needed for fit to work. Please install it.\n",
      call. = FALSE)
  }

    summ <- summary(mod)$coefficients
    effect <- se <- rep(NA, length(grep("P", names(coef(mod)))))
    names(effect) <- names(se) <- names(coef(mod))[grep("P", names(coef(mod)))]
    ind <- match(rownames(summ)[grep("P", rownames(summ))], names(effect))
    effect[ind] <- summ[grep("P", rownames(summ)), 1]
    se[ind] <- summ[grep("P", rownames(summ)),2]

    cm <- round(unlist(lapply(qtlres, function(x) return(x[,1]))),2)[qindex]
    ## these should be done individually for each QTL to test for significance
    for (j in 1:nqtl) {	
	subind <- grep(paste("P", j, "F", sep=""), rownames(summ))
# Change BEH 9/11/12
#  	man <- subind[which(!is.na(coef(mod)[subind]))]
	man <- match(rownames(summ)[subind], colnames(vcov(mod)))
  	wt <- aods3::wald.test(varb=vcov(mod), b=coef(mod)[!is.na(coef(mod))], Terms=man)
	wald[j] <- wt$result$chi2[1]
	degf[j] <- wt$result$chi2[2]
	pval[j] <- wt$result$chi2[3]
	mrkli <- max(which(map[[chr[j]]]==max(map[[chr[j]]]*(map[[chr[j]]]<=cm[j]))))
	if (length(map[[chr[j]]])>1) {
	if (mrkli==length(map[[chr[j]]])) mrkli <- mrkli-1
	fmrkl[j] <- names(map[[chr[j]]])[mrkli]
	fmrkr[j] <- names(map[[chr[j]]])[mrkli+1]
	
	### Fit individual models containing each QTL
	mod1 <- update(baseModel, 
		formula=eval(as.formula(paste(baseModel$call$formula[2], 
		baseModel$call$formula[1], paste(c(as.character(baseModel$call$formula[3]), grep(paste("P", j, "F", sep=""), names(df), value=T)), collapse="+"), sep=""))), data=df)	 
	pvar[j] <- summary(mod1)$adj.r.squared*100

	}
  else fmrkl[j] <- fmrkr[j] <- names(map[[chr[j]]])[mrkli]
    }
  } ## end of method=="lm"

  if (method=="mm") {
    if (!requireNamespace("asreml", quietly = TRUE)) 
      stop("asreml needed for mixed model fit to work. Please install it.\n",
      call. = FALSE)
    mod <- update(baseModel, 
	fixed=eval(as.formula(paste(baseModel$call$fixed[2], 
	baseModel$call$fixed[1], 
	paste(c(as.character(baseModel$call$fixed[3]), 
	names(df)[ncol(pheno)+1:ncol(gen)]), collapse="+"), sep=""))), 
	data="df", Cfixed=TRUE, na.method.X="include")

    effect <- summary(mod, all=T)$coef.fixed[ncol(gen):1,1]
    se <- summary(mod, all=T)$coef.fixed[ncol(gen):1, 2]

    cm <- round(unlist(lapply(qtlres, function(x) return(x[,1]))),2)[qindex]
    ## these should be done individually for each QTL to test for significance
    for (j in 1:nqtl) {	
	subind <- grep(paste("P", j, "F", sep=""), names(mod$coefficients$fixed))
  	man <- subind[which(mod$coefficients$fixed[subind]!=0)]
  	wald[j] <- wald.test.asreml(mod, list(list(man, "zero")))$zres$zwald
    	degf[j] <- nrow(wald.test.asreml(mod, list(list(man, "zero")))$zres$ZRows[[1]])
    	pval[j] <- wald.test.asreml(mod, list(list(man, "zero")))$zres$zpval
	mrkli <- which.max(map[[chr[j]]]*(map[[chr[j]]]<=cm[j]))
	if (length(map[[chr[j]]])>1) {
	if (mrkli==length(map[[chr[j]]])) mrkli <- mrkli-1
	fmrkl[j] <- names(map[[chr[j]]])[mrkli]
	fmrkr[j] <- names(map[[chr[j]]])[mrkli+1]
	} else fmrkl[j] <- fmrkr[j] <- names(map[[chr[j]]])[mrkli]
    }
  } ## end of method=="mm"


   ## these will stay the same - just get the values out separately 
   effect <- t(matrix(round(effect,2), nrow=nqtl, ncol=n.founders, byrow=T))
   se <- t(matrix(round(se,3), nrow=nqtl, ncol=n.founders, byrow=T))
   eff3 <- paste("Effect_",f3,sep="")
   se3 <- paste("SE_",f3,sep="")
   if (n.founders==4)
	table <- data.frame("Chr"=chr, "Pos"=cm, "LeftMrk"=fmrkl, "RightMrk"=fmrkr, effect[1,], se[1,], effect[2,], se[2,], effect[3,], se[3,], effect[4,], se[4,], "Wald"=round(wald,2), "df"=degf, "pvalue"=signif(pval,3), "PctVar"=round(pvar, 2))
   else if (n.founders==8)
	table <- data.frame("Chr"=chr, "Pos"=cm, "LeftMrk"=fmrkl, "RightMrk"=fmrkr, effect[1,], se[1,], effect[2,], se[2,], effect[3,], se[3,], effect[4,], se[4,], effect[5,], se[5,], effect[6,], se[6,], effect[7,], se[7,], effect[8,], se[8,], "Wald"=round(wald,2), "df"=degf, "pvalue"=signif(pval,3), "PctVar"=round(pvar, 2))
  else 
    table <- data.frame("Chr"=chr, "Pos"=cm, "LeftMrk"=fmrkl, "RightMrk"=fmrkr, "Wald"=round(wald,2), "df"=degf, "pvalue"=signif(pval,3), "PctVar"=round(pvar, 2))
  if (n.founders %in% c(4, 8)) {
    names(table)[seq(5, 4+(2*n.founders), 2)] <- eff3
    names(table)[seq(6, 4+(2*n.founders), 2)] <- se3
    }
   
  output$df <- df
  output$table <- table
  output$call <- match.call()
  output$FullModel <- mod
  output
}

