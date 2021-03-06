% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/mpcross.R
\name{mpcross}
\alias{mpcross}
\alias{mpcross.object}
\alias{print.mpcross}
\title{Multi-parent cross object}
\usage{
mpcross(founders, finals, pedigree, id, fid)
}
\arguments{
\item{founders}{Matrix of founder genotypes}

\item{finals}{Matrix of final genotypes}

\item{pedigree}{Cross pedigree}

\item{id}{Vector of numeric IDs for lines (which rows in pedigree are observed)}

\item{fid}{Vector of founder IDs}
}
\value{
Let n.founders be the number of founders (either 4 or 8); n.finals be the number of final RILs genotyped; and n.mrk be the number of markers genotyped. Then
\item{founders}{ Founder genotypes - a matrix with dimensions n.founders x n.mrk. Row names of the matrix should be lines names; Column names should be marker names}
\item{finals}{ Final genotypes - a matrix with dimensions n.finals x n.mrk. Row names of the matrix should be line name; column names should be marker names.}
\item{id}{ Vector of final IDs with length n.finals}
\item{fid}{ Vector of founder IDs with length n.founders}
\item{pedigree}{ Numeric pedigree with 3 columns - mother, father, ID}
\item{pheno}{ Phenotypic data}
Optional components:
\item{map}{ Linkage map - either from which data was generated in \code{sim.mpcross} or estimated at some point}
\item{ibd}{ IBD genotypes from founders if data has been generated from \code{sim.mpcross}}
\item{qtlgeno}{ Genotypes at QTL if data has been generated from \code{sim.mpcross}}
\item{rf}{ Recombination fractions if data has been analyzed with \code{mpestrf}}
\item{lg}{ Linkage groups if data has been analyzed with \code{mpgroup}}
}
\description{
The class of object generated from \code{sim.mpcross} and the format input to functions to construct linkage maps for multi-parent crosses. Basic constructor - takes required R objects and formats as an mpcross object.
}
\examples{
map <- qtl::sim.map(len=rep(100,2), n.mar=11, eq.spacing=TRUE, include.x=FALSE)
sim.ped <- sim.mpped(4, 1, 500, 6, 1)
sim.dat <- sim.mpcross(map=map, pedigree=sim.ped, 
	qtl=matrix(data=c(1, 10, .4, 0, 0, 0, 1, 70, 0, .35, 0, 0), 
	nrow=2, ncol=6, byrow=TRUE), seed=1)
}
\seealso{
\code{\link[mpMap]{sim.mpcross}}, \code{\link[mpMap]{mpestrf}}, \code{\link[mpMap]{mpgroup}}
}

