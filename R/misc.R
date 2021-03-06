p <- function(x, i = NULL, row = TRUE) {
  # flexible indexing of vector and matrix type objects
  # Args:
  #   x: an R object typically a vector or matrix
  #   i: optional index; if NULL, x is returned unchanged
  #   row: indicating if rows or cols should be indexed
  #        only relevant if x has two or three dimensions
  if (isTRUE(length(dim(x)) > 3L)) {
    stop2("'p' can only handle objects up to 3 dimensions.")
  }
  if (!length(i)) {
    out <- x
  } else if (length(dim(x)) == 2L) {
    if (row) {
      out <- x[i, , drop = FALSE]
    } else {
      out <- x[, i, drop = FALSE]
    }
  } else if (length(dim(x)) == 3L) {
    if (row) {
      out <- x[i, , , drop = FALSE]
    } else {
      out <- x[, i, , drop = FALSE]
    }
  } else {
    out <- x[i]
  }
  out
}

extract <- function(x, ..., drop = FALSE, drop_dim = NULL) {
  # extract parts of an object with selective dropping of dimensions
  # Args:
  #   x, ..., drop: same as in x[..., drop]
  #   drop_dim: Optional numeric or logical vector controlling 
  #     which dimensions to drop. Will overwrite argument 'drop'.
  if (!length(dim(x))) {
    return(x[...])
  }
  if (length(drop_dim)) {
    drop <- FALSE
  } else {
    drop <- as_one_logical(drop)
  }
  out <- x[..., drop = drop]
  if (drop || !length(drop_dim) || any(dim(out) == 0L)) {
    return(out)
  }
  if (is.numeric(drop_dim)) {
    drop_dim <- seq_along(dim(x)) %in% drop_dim
  }
  if (!is.logical(drop_dim)) {
    stop2("'drop_dim' needs to be logical or numeric.")
  }
  keep <- dim(out) > 1L | !drop_dim
  new_dim <- dim(out)[keep]
  if (length(new_dim) == 1L) {
    # use vectors instead of 1D arrays
    new_dim <- NULL  
  }
  dim(out) <- new_dim
  out
}

extract_col <- function(x, i) {
  # savely extract columns without dropping other dimensions
  # Args:
  #   x: an array
  #   i: colum index
  ldim <- length(dim(x))
  if (ldim < 2L) {
    return(x)
  }
  commas <- collapse(rep(", ", ldim - 2))
  expr <- paste0("extract(x, , i", commas, ", drop_dim = 2)")
  eval2(expr)
}

seq_rows <- function(x) {
  seq_len(NROW(x))
}

seq_cols <- function(x) {
  seq_len(NCOL(x))
}

seq_dim <- function(x, dim) {
  dim <- as_one_numeric(dim)
  if (dim == 1) {
    len <- NROW(x)
  } else if (dim == 2) {
    len <- NCOL(x)
  } else {
    len <- dim(x)[dim]
  }
  if (length(len) == 1L && !isNA(len)) {
    out <- seq_len(len) 
  } else {
    out <- integer(0)
  }
  out
}

match_rows <- function(x, y, ...) {
  # match rows in x with rows in y
  x <- as.data.frame(x)
  y <- as.data.frame(y)
  x <- do_call("paste", c(x, sep = "\r"))
  y <- do_call("paste", c(y, sep = "\r"))
  match(x, y, ...)
}

find_elements <- function(x, ..., ls = list(), fun = '%in%') {
  # find elements of x matching subelements passed via ls and ...
  x <- as.list(x)
  if (!length(x)) {
    return(logical(0))
  }
  out <- rep(TRUE, length(x))
  ls <- c(ls, list(...))
  if (!length(ls)) {
    return(out)
  }
  if (is.null(names(ls))) {
    stop("Argument 'ls' must be named.")
  }
  for (name in names(ls)) {
    tmp <- lapply(x, "[[", name)
    out <- out & do_call(fun, list(tmp, ls[[name]]))
  }
  out
}

find_rows <- function(x, ..., ls = list(), fun = '%in%') {
  # find rows of x matching columns passed via ls and ...
  # similar to 'find_elements' but for matrix like objects
  x <- as.data.frame(x)
  if (!nrow(x)) {
    return(logical(0))
  }
  out <- rep(TRUE, nrow(x))
  ls <- c(ls, list(...))
  if (!length(ls)) {
    return(out)
  }
  if (is.null(names(ls))) {
    stop("Argument 'ls' must be named.")
  }
  for (name in names(ls)) {
    out <- out & do_call(fun, list(x[[name]], ls[[name]]))
  }
  out
}

subset2 <- function(x, ..., ls = list(), fun = '%in%') {
  # subset x using arguments passed via ls and ...
  x[find_rows(x, ..., ls = ls, fun = fun), , drop = FALSE]
}

array2list <- function(x) {
  # convert array to list of elements with reduced dimension
  # Args: 
  #   x: an arrary of dimension d
  # Returns: 
  #   A list of arrays of dimension d-1
  if (is.null(dim(x))) {
    stop("Argument 'x' has no dimension.")
  }
  ndim <- length(dim(x))
  out <- list(length = dim(x)[ndim])
  ind <- collapse(rep(",", ndim - 1))
  for (i in seq_len(dim(x)[ndim])) {
    out[[i]] <- eval(parse(text = paste0("x[", ind, i, "]")))
    if (length(dim(x)) > 2) {
      # avoid accidental dropping of other dimensions
      dim(out[[i]]) <- dim(x)[-ndim] 
    }
  }
  names(out) <- dimnames(x)[[ndim]]
  out
}

move2start <- function(x, first) {
  # move elements to the start of a named object
  x[c(first, setdiff(names(x), first))]
}

repl <- function(expr, n) {
  # wrapper around replicate but without simplifying
  replicate(n, expr, simplify = FALSE)
}

first_greater <- function(A, target, i = 1) {
  # find the first element in A that is greater than target
  # Args: 
  #   A: a matrix
  #   target: a vector of length nrow(A)
  #   i: column of A being checked first
  # Returns: 
  #   A vector of the same length as target containing the column ids 
  #   where A[,i] was first greater than target
  ifelse(target <= A[, i] | ncol(A) == i, i, first_greater(A, target, i + 1))
}

isNULL <- function(x) {
  # check if an object is NULL
  is.null(x) || ifelse(is.vector(x), all(sapply(x, is.null)), FALSE)
}

rmNULL <- function(x, recursive = TRUE) {
  # recursively removes NULL entries from an object
  x <- Filter(Negate(isNULL), x)
  if (recursive) {
    x <- lapply(x, function(x) if (is.list(x)) rmNULL(x) else x)
  }
  x
}

first_not_null <- function(...) {
  # find the first argument that is not NULL
  dots <- list(...)
  out <- NULL
  i <- 1L
  while (isNULL(out) && i <= length(dots)) {
    if (!isNULL(dots[[i]])) {
      out <- dots[[i]]
    }
    i <- i + 1L
  }
  out
}

isNA <- function(x) {
  length(x) == 1L && is.na(x)
}

is_equal <- function(x, y, ...) {
  isTRUE(all.equal(x, y, ...))
}

is_like_factor <- function(x) {
  # check if x behaves like a factor in design matrices
  is.factor(x) || is.character(x) || is.logical(x)
}

as_factor <- function(x, levels = NULL) {
  # similar to as.factor but allows to pass levels
  if (is.null(levels)) {
    out <- as.factor(x)
  } else {
    out <- factor(x, levels = levels)
  }
  out
}

as_one_logical <- function(x, allow_na = FALSE) {
  # coerce 'x' to TRUE or FALSE if possible
  s <- substitute(x)
  x <- as.logical(x)
  if (length(x) != 1L || anyNA(x) && !allow_na) {
    s <- deparse_combine(s, max_char = 100L)
    stop2("Cannot coerce ", s, " to a single logical value.")
  }
  x
}

as_one_numeric <- function(x, allow_na = FALSE) {
  # coerce 'x' to a signle number value
  s <- substitute(x)
  x <- SW(as.numeric(x))
  if (length(x) != 1L || anyNA(x) && !allow_na) {
    s <- deparse_combine(s, max_char = 100L)
    stop2("Cannot coerce ", s, " to a single numeric value.")
  }
  x
}

as_one_character <- function(x, allow_na = FALSE) {
  # coerce 'x' to a single character string
  s <- substitute(x)
  x <- as.character(x)
  if (length(x) != 1L || anyNA(x) && !allow_na) {
    s <- deparse_combine(s, max_char = 100L)
    stop2("Cannot coerce ", s, " to a single character value.")
  }
  x
}

has_rows <- function(x) {
  isTRUE(nrow(x) > 0L)
}

has_cols <- function(x) {
  isTRUE(ncol(x) > 0L)
}

expand <- function(..., dots = list(), length = NULL) {
  # expand arguments of be of the same length
  # Args:
  #   ...: arguments to expand
  #   length: optional expansion length
  dots <- c(dots, list(...))
  if (is.null(length)) {
    length <- max(sapply(dots, length))
  }
  as.data.frame(lapply(dots, rep, length.out = length))
}

structure_not_null <- function(.Data, ...) {
  # structure but ignore NULL
  if (!is.null(.Data)) {
    .Data <- structure(.Data, ...)
  }
  .Data
}

rm_attr <- function(x, attr) {
  # remove certain attributes
  attributes(x)[attr] <- NULL
  x
}

subset_keep_attr <- function(x, y) {
  # take a subset of vector, list, etc.
  # while keeping all attributes except for names
  att <- attributes(x)
  x <- x[y]
  att$names <- names(x)
  attributes(x) <- att
  x
}

is_wholenumber <- function(x, tol = .Machine$double.eps) {  
  # check if x is a whole number (integer)
  if (!is.numeric(x)) {
    out <- FALSE
  } else {
    out <- abs(x - round(x)) < tol
  }
  out
}

is_symmetric <- function(x, tol = sqrt(.Machine$double.eps)) {
  # helper function to check symmetry of a matrix
  isSymmetric(x, tol = tol, check.attributes = FALSE)
}

ulapply <- function(X, FUN, ..., recursive = TRUE, use.names = TRUE) {
  # short for unlist(lapply())
  unlist(lapply(X, FUN, ...), recursive, use.names)
}

all_vars <- function(expr, ...) {
  # like all.vars but can handle characters
  if (is.character(expr)) {
    expr <- parse(text = expr)
  }
  all.vars(expr, ...)
}

lc <- function(x, ...) {
  # append list(...) to x
  dots <- rmNULL(list(...), recursive = FALSE)
  c(x, dots)
}

'c<-' <- function(x, value) {
  c(x, value)
}

'lc<-' <- function(x, value) {
  lc(x, value)
}

collapse <- function(..., sep = "") {
  # wrapper for paste with collapse = ""
  paste(..., sep = sep, collapse = "")
}

collapse_comma <- function(...) {
  paste0("'", ..., "'", collapse = ", ")
}

'str_add<-' <- function(x, start = FALSE, value) {
  # add characters to an existing string
  if (start) paste0(value, x) else paste0(x, value)
}

str_if <- function(cond, yes, no = "") {
  # type-stable if clause for strings with default else output
  cond <- as_one_logical(cond)
  if (cond) as.character(yes) else as.character(no)
}

str_subset <- function(x, pattern, ...) {
  # select elements which match a regex pattern
  x[grepl(pattern, x, ...)]
}

glue <- function(..., sep = "", collapse = NULL, envir = parent.frame(), 
                 open = "{", close = "}", na = "NA") {
  # similar to glue::glue but specialized for generating Stan code
  dots <- list(...)
  dots <- dots[lengths(dots) > 0L]
  args <- list(
    .x = NULL, .sep = sep, .envir = envir, .open = open, 
    .close = close, .na = na, .transformer = zero_length_transformer,
    .trim = FALSE
  )
  out <- do_call(glue::glue_data, c(dots, args))
  if (!is.null(collapse)) {
    collapse <- as_one_character(collapse)
    out <- paste0(out, collapse = collapse)
  }
  out
}

zero_length_transformer <- function(text, envir) {
  out <- glue::identity_transformer(text, envir)
  if (!length(out)) {
    out <- ""
  }
  out
}

cglue <- function(..., envir = parent.frame()) {
  # collapse strings evaluated with glue
  glue(..., envir = envir, collapse = "")
}

na.omit2 <- function(object, ...) {
  # like stats:::na.omit.data.frame but allows to ignore variables
  # keeps NAs in variables with attribute keep_na = TRUE
  stopifnot(is.data.frame(object))
  omit <- logical(nrow(object))
  for (j in seq_along(object)) {
    x <- object[[j]]
    keep_na <- isTRUE(attr(x, "keep_na", TRUE))
    if (!is.atomic(x) || keep_na) {
      next
    } 
    x <- is.na(x)
    d <- dim(x)
    if (is.null(d) || length(d) != 2L) {
      omit <- omit | x
    } else {
      for (ii in seq_len(d[2L])) {
        omit <- omit | x[, ii]
      } 
    } 
  }
  if (any(omit > 0L)) {
    out <- object[!omit, , drop = FALSE]
    temp <- setNames(seq(omit)[omit], attr(object, "row.names")[omit])
    attr(temp, "class") <- "omit"
    attr(out, "na.action") <- temp
    warning2("Rows containing NAs were excluded from the model.")
  } else {
    out <- object
  }
  out
}

require_package <- function(package, version = NULL) {
  if (!requireNamespace(package, quietly = TRUE)) {
    stop2("Please install the '", package, "' package.")
  }
  if (!is.null(version)) {
    version <- as.package_version(version)
    if (utils::packageVersion(package) < version) {
      stop2("Please install package '", package, 
            "' version ", version, " or higher.")
    }
  }
  invisible(TRUE)
}

rename <- function(x, pattern = NULL, replacement = NULL, 
                   fixed = TRUE, check_dup = FALSE, ...) {
  # rename certain patterns in a character vector
  # Args:
  #   x: a character vector to be renamed
  #   pattern: the regular expressions in x to be replaced
  #   replacement: the replacements
  #   fixed: same as for sub, grepl etc
  #   check_dup: logical; check for duplications in x after renaming
  #   ...: passed to gsub
  # Returns: 
  #   renamed character vector of the same length as x
  pattern <- as.character(pattern)
  replacement <- as.character(replacement)
  if (!length(pattern) && !length(replacement)) {
    # default renaming to avoid special characters in coeffcient names 
    pattern <- c(
      " ", "(", ")", "[", "]", ",", "\"", "'", 
      "?", "+", "-", "*", "/", "^", "="
    )
    replacement <- c(rep("", 9), "P", "M", "MU", "D", "E", "EQ")
  }
  if (length(replacement) == 1L) {
    replacement <- rep(replacement, length(pattern))
  }
  stopifnot(length(pattern) == length(replacement))
  # avoid zero-length pattern error
  has_chars <- nzchar(pattern)
  pattern <- pattern[has_chars]
  replacement <- replacement[has_chars]
  out <- x
  for (i in seq_along(pattern)) {
    out <- gsub(pattern[i], replacement[i], out, fixed = fixed, ...)
  }
  dup <- duplicated(out)
  if (check_dup && any(dup)) {
    dup <- x[out %in% out[dup]]
    stop2("Internal renaming led to duplicated names. \n",
          "Occured for: ", collapse_comma(dup))
  }
  out
}

collapse_lists <- function(..., ls = list()) {
  # collapse strings having the same name in different lists
  # Args:
  #  ls: a list of named lists
  # Returns:
  #  a named list containg the collapsed strings
  ls <- c(list(...), ls)
  elements <- unique(unlist(lapply(ls, names)))
  out <- do_call(mapply, 
    c(FUN = collapse, lapply(ls, "[", elements), SIMPLIFY = FALSE)
  )
  names(out) <- elements
  out
}

nlist <- function(...) {
  # create a named list using object names
  m <- match.call()
  dots <- list(...)
  no_names <- is.null(names(dots))
  has_name <- if (no_names) FALSE else nzchar(names(dots))
  if (all(has_name)) return(dots)
  nms <- as.character(m)[-1]
  if (no_names) {
    names(dots) <- nms
  } else {
    names(dots)[!has_name] <- nms[!has_name]
  }
  dots
}

named_list <- function(names, values = NULL) {
  # initialize a named list
  # Args:
  #   names: names of the elements
  #   values: values of the elements
  if (!is.null(values)) {
    if (length(values) <= 1L) {
      values <- replicate(length(names), values)
    }
    values <- as.list(values)
    stopifnot(length(values) == length(names))
  } else {
    values <- vector("list", length(names))
  }
  setNames(values, names)
}

#' Execute a Function Call
#'
#' Execute a function call similar to \code{\link{do.call}}, but without
#' deparsing function arguments.
#' 
#' @param what Either a function or a non-empty character string naming the
#'   function to be called.
#' @param args A list of arguments to the function call. The names attribute of
#'   \code{args} gives the argument names.
#' @param pkg Optional name of the package in which to search for the
#'   function if \code{what} is a character string.
#'
#' @return The result of the (evaluated) function call.
#' 
#' @keywords internal
#' @export
do_call <- function(what, args, pkg = NULL) {
  call <- ""
  if (length(args)) {
    if (!is.list(args)) {
      stop2("'args' must be a list.")
    }
    fun_args <- names(args)
    if (is.null(fun_args)) {
      fun_args <- rep("", length(args))
    } else {
      nzc <- nzchar(fun_args)
      fun_args[nzc] <- paste0("`", fun_args[nzc], "` = ")
    }
    names(args) <- paste0(".x", seq_along(args))
    call <- paste0(fun_args, names(args), collapse = ",")
  } else {
    args <- list()
  }
  if (is.function(what)) {
    args$.fun <- what
    what <- ".fun" 
  } else {
    what <- paste0("`", as_one_character(what), "`")
    if (!is.null(pkg)) {
      what <- paste0(as_one_character(pkg), "::", what)
    }
  }
  call <- paste0(what, "(", call, ")")
  eval2(call, envir = args, enclos = parent.frame())
}

empty_data_frame <- function() {
  as.data.frame(matrix(nrow = 0, ncol = 0))
}

'replace_args<-' <- function(x, dont_replace = NULL, value) {
  # replace elements in x with elements in value
  # Args:
  #   x: named list like object
  #   value: another named list like object
  #   dont_replace names of elements that cannot be replaced
  value_name <- deparse_combine(substitute(value), max_char = 100L)
  value <- as.list(value)
  if (length(value) && is.null(names(value))) {
    stop2("Argument '", value_name, "' must be named.")
  }
  invalid <- names(value)[names(value) %in% dont_replace]
  if (length(invalid)) {
    invalid <- collapse_comma(invalid)
    stop2("Argument(s) ", invalid, " cannot be replaced.")
  }
  x[names(value)] <- value
  x
}

deparse_no_string <- function(x) {
  # deparse x if it is no string
  if (!is.character(x)) {
    x <- deparse(x)
  }
  x
}

deparse_combine <- function(x, max_char = NULL) {
  # combine deparse lines into one string
  out <- collapse(deparse(x))
  if (isTRUE(max_char > 0)) {
    out <- substr(out, 1L, max_char)
  }
  out
}

eval2 <- function(expr, envir = parent.frame(), ...) {
  # like eval() but parses characters before evaluation
  if (is.character(expr)) {
    expr <- parse(text = expr)
  }
  eval(expr, envir, ...)
}

eval_silent <- function(expr, type = "output", try = FALSE, 
                        silent = TRUE, ...) {
  # evaluate an expression without printing output or messages
  # Args:
  #   expr: expression to be evaluated
  #   type: type of output to be suppressed (see ?sink)
  #   try: wrap evaluation of expr in 'try' and 
  #     not suppress outputs if evaluation fails?
  #   silent: actually evaluate silently?
  try <- as_one_logical(try)
  silent <- as_one_logical(silent)
  type <- match.arg(type, c("output", "message"))
  expr <- substitute(expr)
  envir <- parent.frame()
  if (silent) {
    if (try && type == "message") {
      try_out <- try(utils::capture.output(
        out <- eval(expr, envir), type = type, ...
      ))
      if (is(try_out, "try-error")) {
        # try again without suppressing error messages
        out <- eval(expr, envir)
      }
    } else {
      utils::capture.output(out <- eval(expr, envir), type = type, ...)
    }
  } else {
    out <- eval(expr, envir)
  }
  out
}

eval_NA <- function(expr, ...) {
  # evaluate an expression for all variables set to NA
  if (is.character(expr)) {
    expr <- parse(text = expr)
  }
  data <- named_list(all.vars(expr), NA_real_)
  eval(expr, envir = data, ...)
}

sort_dependencies <- function(x, sorted = NULL) {
  # recursive sorting of dependencies
  # Args:
  #   x: named list of dependencies per element
  #   sorted: already sorted element names
  # Returns:
  #   a vector of sorted element names
  if (!length(x)) {
    return(NULL)
  }
  if (length(names(x)) != length(x)) {
    stop2("Argument 'x' must be named.")
  }
  take <- !ulapply(x, function(dep) any(!dep %in% sorted))
  new <- setdiff(names(x)[take], sorted)
  out <- union(sorted, new)
  if (length(new)) {
    out <- union(out, sort_dependencies(x, sorted = out))
  } else if (!all(names(x) %in% out)) {
    stop2("Cannot handle circular dependency structures.")
  }
  out
}

stop2 <- function(...) {
  stop(..., call. = FALSE)
}

warning2 <- function(...) {
  warning(..., call. = FALSE)
}

get_arg <- function(x, ...) {
  # find first occurrence of x in ... objects
  # Args:
  #  x: The name of the required element
  #  ...: R objects that may contain x
  dots <- list(...)
  i <- 1
  out <- NULL
  while (i <= length(dots) && is.null(out)) {
    if (!is.null(dots[[i]][[x]])) {
      out <- dots[[i]][[x]]
    } else {
      i <- i + 1
    }
  }
  out
}

SW <- function(expr) {
  # just a short form for suppressWarnings
  base::suppressWarnings(expr)
}

get_matches <- function(pattern, text, simplify = TRUE, 
                        first = FALSE, ...) {
  # get pattern matches in text as vector
  # Args:
  #   simplify: return an atomic vector of matches?
  #   first: only return the first match in each string?
  x <- regmatches(text, gregexpr(pattern, text, ...))
  if (first) {
    x <- lapply(x, function(t) if (length(t)) t[1] else t)
  }
  if (simplify) {
    if (first) {
      x <- lapply(x, function(t) if (length(t)) t else "")
    }
    x <- unlist(x)
  }
  x
}

get_matches_expr <- function(pattern, expr, ...) {
  # loop over the parse tree of 'expr '
  # and find matches of 'pattern'
  if (is.character(expr)) {
    expr <- parse(text = expr)
  }
  out <- NULL
  for (i in seq_along(expr)) {
    sexpr <- try(expr[[i]], silent = TRUE)
    if (!is(sexpr, "try-error")) {
      sexpr_char <- deparse_combine(sexpr)
      out <- c(out, get_matches(pattern, sexpr_char, ...))
    }
    if (is.call(sexpr) || is.expression(sexpr)) {
      out <- c(out, get_matches_expr(pattern, sexpr, ...))
    }
  }
  unique(out)
}

grepl_expr <- function(pattern, expr, ...) {
  # like base::grepl but handles (parse trees of) expressions 
  as.logical(ulapply(expr, function(e) 
    length(get_matches_expr(pattern, e, ...)) > 0L))
}

escape_dot <- function(x) {
  gsub(".", "\\.", x, fixed = TRUE)
}

escape_all <- function(x) {
  special <- c(".", "*", "+", "?", "^", "$", "(", ")", "[", "]", "|")
  for (s in special) {
    x <- gsub(s, paste0("\\", s), x, fixed = TRUE)
  }
  x
}

usc <- function(x, pos = c("prefix", "suffix")) {
  # add an underscore to non-empty character strings
  # Args:
  #   x: a character vector
  #   pos: position of the underscore
  pos <- match.arg(pos)
  x <- as.character(x)
  if (!length(x)) x <- ""
  if (pos == "prefix") {
    x <- ifelse(nzchar(x), paste0("_", x), "")
  } else {
    x <- ifelse(nzchar(x), paste0(x, "_"), "")
  }
  x
}

round_largest_remainder <- function(x) {
  # round using the largest remainder method
  x <- as.numeric(x)
  total <- round(sum(x))
  out <- floor(x)
  diff <- x - out
  J <- order(diff, decreasing = TRUE)
  I <- seq_len(total - floor(sum(out)))
  out[J[I]] <- out[J[I]] + 1
  out
}

wsp <- function(x = "", nsp = 1) {
  # add leading and trailing whitespaces
  # Args:
  #   x: object accepted by paste
  #   nsp: number of whitespaces to add
  sp <- collapse(rep(" ", nsp))
  if (length(x)) {
    out <- ifelse(nzchar(x), paste0(sp, x, sp), sp)
  } else {
    out <- NULL
  } 
  out
}

rm_wsp <- function(x) {
  # remove whitespaces from strings
  gsub("[ \t\r\n]+", "", x, perl = TRUE)
}

limit_chars <- function(x, chars = NULL, lsuffix = 4) {
  # limit the number of characters of a vector
  # Args:
  #   x: a character vector
  #   chars: maximum number of characters to show
  #   lsuffix: number of characters to keep 
  #            at the end of the strings
  stopifnot(is.character(x))
  if (!is.null(chars)) {
    chars_x <- nchar(x) - lsuffix
    suffix <- substr(x, chars_x + 1, chars_x + lsuffix)
    x <- substr(x, 1, chars_x)
    x <- ifelse(chars_x <= chars, x, paste0(substr(x, 1, chars - 3), "..."))
    x <- paste0(x, suffix)
  }
  x
}

use_alias <- function(arg, alias = NULL, default = NULL,
                      warn = TRUE) {
  # ensure that deprecated arguments still work
  # Args:
  #   arg: input to the new argument
  #   alias: input to the deprecated argument
  #   default: the default value of alias
  #   warn: should a warning be printed if alias is specified?
  arg_name <- Reduce(paste, deparse(substitute(arg)))
  alias_name <- Reduce(paste, deparse(substitute(alias)))
  if (!is_equal(alias, default)) {
    arg <- alias
    if (grepl("^dots\\$", alias_name)) {
      alias_name <- gsub("^dots\\$", "", alias_name)
    } else if (grepl("^dots\\[\\[", alias_name)) {
      alias_name <- gsub("^dots\\[\\[\"|\"\\]\\]$", "", alias_name)
    }
    if (warn) {
      warning2("Argument '", alias_name, "' is deprecated. ", 
               "Please use argument '", arg_name, "' instead.")
    }
  }
  arg
}

warn_deprecated <- function(new, old = as.character(sys.call(sys.parent()))[1]) {
  msg <- paste0("Function '", old, "' is deprecated.")
  if (!missing(new)) {
    msg <- paste0(msg, " Please use '", new, "' instead.")
  }
  warning2(msg)
  invisible(NULL)
}

viridis6 <- function() {
  # colours taken from the viridis package
  c("#440154", "#414487", "#2A788E", "#22A884", "#7AD151", "#FDE725")
}

expect_match2 <- function(object, regexp, ..., all = TRUE) {
  # just testthat::expect_match with fixed = TRUE
  testthat::expect_match(object, regexp, fixed = TRUE, ..., all = all)
}

.onAttach <- function(libname, pkgname) {
  # startup messages for brms
  version <- utils::packageVersion("brms")
  packageStartupMessage(
    "Loading 'brms' package (version ", version, "). Useful instructions\n", 
    "can be found by typing help('brms'). A more detailed introduction\n", 
    "to the package is available through vignette('brms_overview')."
  )
  invisible(NULL)
}

.onLoad <- function(libname, pkgname) {
  backports::import(pkgname)
}
