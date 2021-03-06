# ===============================================================================
#
# PROGRAMMERS:
#
# jean-romain.roussel.1@ulaval.ca  -  https://github.com/Jean-Romain/lidR
#
# COPYRIGHT:
#
# Copyright 2016-2018 Jean-Romain Roussel
#
# This file is part of lidR R package.
#
# lidR is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>
#
# ===============================================================================

#' Spatial Interpolation Algorithm
#'
#' This function is made to be used in \link{grid_terrain} or \link{lasnormalize}. It implements an algorithm
#' for spatial interpolation. Spatial interpolation is based on a Delaunay triangulation, which performs
#' a linear interpolation within each triangle. There are usually a few points outside the convex hull,
#' determined by the ground points at the very edge of the dataset, that cannot be interpolated with
#' a triangulation. Extrapolation is done using the nearest neighbour approach.
#'
#' @export
#'
#' @family spatial interpolation algorithms
#'
#' @examples
#' LASfile <- system.file("extdata", "Topography.laz", package="lidR")
#' las = readLAS(LASfile)
#'
#' # plot(las)
#'
#' dtm = grid_terrain(las, algorithm = tin())
#'
#' plot(dtm, col = terrain.colors(50))
#' plot_dtm3d(dtm)
tin = function()
{
  f = function(what, where)
  {
    assert_is_valid_context(LIDRCONTEXTSPI, "tin")
    z    <- interpolate_delaunay(what, where)
    isna <- is.na(z)
    nnas <- sum(isna)
    if (nnas > 0) z[isna] <- C_knnidw(where$X[!isna], where$Y[!isna], z[!isna], where$X[isna], where$Y[isna], 1, 1, getThread())
    return(z)
  }

  class(f) <- c("function", "SpatialInterpolation", "OpenMP",  "Algorithm", "lidR")
  return(f)
}

#' Spatial Interpolation Algorithm
#'
#' This function is made to be used in \link{grid_terrain} or \link{lasnormalize}. It implements an algorithm
#' for spatial interpolation. Interpolation is done using a k-nearest neighbour (KNN) approach with
#' an inverse-distance weighting (IDW).
#'
#' @param k numeric. Number of k-nearest neighbours. Default 10.
#'
#' @param p numeric. Power for inverse-distance weighting. Default 2.
#'
#' @export
#'
#' @family spatial interpolation algorithms
#'
#' @examples
#' LASfile <- system.file("extdata", "Topography.laz", package="lidR")
#' las = readLAS(LASfile)
#'
#' # plot(las)
#'
#' dtm = grid_terrain(las, algorithm = knnidw(k = 6L, p = 2))
#'
#' plot(dtm, col = terrain.colors(50))
#' plot_dtm3d(dtm)
knnidw = function(k = 10, p = 2)
{
  f = function(what, where)
  {
    assert_is_valid_context(LIDRCONTEXTSPI, "knnidw")
    return(interpolate_knnidw(what, where, k, p))
  }

  class(f) <- c("SpatialInterpolation", "Algorithm", "OpenMP", "lidR", "function")
  return(f)
}

#' Spatial Interpolation Algorithm
#'
#' This function is made to be used in \link{grid_terrain} or \link{lasground}. It implements an algorithm
#' for spatial interpolation. Spatial interpolation is based on universal kriging using the \link[gstat:krige]{krige}
#' function from \code{gstat}. This method combines the KNN approach with the kriging approach. For each
#' point of interest it kriges the terrain using the k-nearest neighbour ground points. This method
#' is more difficult to manipulate but it is also the most advanced method for interpolating spatial data.
#'
#' @param k numeric. Number of k-nearest neighbours. Default 10.
#'
#' @param model A variogram model computed with \link[gstat:vgm]{vgm}. If NULL it performs an ordinary
#' or weighted least squares prediction.
#'
#' @export
#'
#' @family spatial interpolation algorithms
#'
#' @examples
#' LASfile <- system.file("extdata", "Topography.laz", package="lidR")
#' las = readLAS(LASfile)
#'
#' # plot(las)
#'
#' dtm = grid_terrain(las, algorithm = kriging())
#'
#' plot(dtm, col = terrain.colors(50))
#' plot_dtm3d(dtm)
kriging = function(model = gstat::vgm(.59, "Sph", 874), k = 10L)
{
  f = function(what, where)
  {
    assert_is_valid_context(LIDRCONTEXTSPI, "kriging")
    return(interpolate_kriging(what, where, model, k))
  }

  class(f) <- c( "function", "SpatialInterpolation", "Algorithm", "lidR")
  return(f)
}

interpolate_knnidw = function(points, coord, k, p)
{
  z <- C_knnidw(points$X, points$Y, points$Z, coord$X, coord$Y, k, p, getThread())
  return(z)
}

interpolate_kriging = function(points, coord, model, k)
{
  requireNamespace("gstat")
  X <- Y <- Z <- NULL

  if (!getOption("lidR.verbose"))
    sink(tempfile())

  x  <- gstat::krige(Z~X+Y, location = ~X+Y, data = points, newdata = coord, model, nmax = k)

  sink()

  return(x$var1.pred)
}

interpolate_delaunay <- function(points, coord, trim = 0)
{
  P <- as.matrix(points)
  X <- as.matrix(coord)
  D <- tDelaunay(P, trim = trim)
  Z <- tInterpolate(D, P, X, getThreads())
  return(Z)
}
