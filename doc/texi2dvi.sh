#! /bin/sh
# texi2dvi --- produce DVI (or PDF) files from Texinfo (or (La)TeX) sources.
#
# Copyright 1992-2021 Free Software Foundation, Inc.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License,
# or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# Originally written by Noah Friedman.
#
# Please send bug reports, etc. to bug-texinfo@gnu.org.
# If possible, please send a copy of the output of the script called with
# the `--debug' option when making a bug report.

test -f /bin/ksh && test -z "$RUNNING_KSH" &&
    {
        UNAMES=$(uname -s)
        test "x$UNAMES" = xULTRIX
    } 2>/dev/null &&
    {
        RUNNING_KSH=true
        export RUNNING_KSH
        exec /bin/ksh $0 ${1+"$@"}
    }
unset RUNNING_KSH

# No failure shall remain unpunished.
set -e

# In case the default sed doesn't suffice.
: ${SED=sed}

program=$(echo $0 | $SED -e 's!.*/!!')

build_mode=${TEXI2DVI_BUILD_MODE:-local}
build_dir=${TEXI2DVI_BUILD_DIRECTORY:-.}

orig_pwd=$(pwd)

# Initialize variables for option overriding and otherwise.
# Don't use `unset' since old bourne shells don't have this command.
# Instead, assign them an empty value.
action=compile
debug=false
escape="\\"
expand=false # true for expansion via makeinfo
includes=
line_error=true # pass --file-line-error to TeX
max_iters=7     # when to quit
oname=          # --output
out_lang=dvi
quiet=false # let the tools' message be displayed
set_language=
src_specials=
shell_escape=
latex2html=hevea   # or set to tex4ht
textra=            # Extra TeX commands to insert in the input file.
txiprereq=19990129 # minimum texinfo.tex version with macro expansion
verb=false         # true for verbose mode
translate_file=    # name of charset translation file

# We have to initialize IFS to space tab newline since we save and
# restore IFS and apparently POSIX allows stupid/broken behavior with
# empty-but-set IFS.
# http://lists.gnu.org/archive/html/automake-patches/2006-05/msg00008.html
# We need space, tab and newline, in precisely that order.  And don't leave
# trailing blanks.
space=' '
tab='	'
newline='
'
IFS="$space$tab$newline"

: ${EGREP=egrep}

# Systems which define $COMSPEC or $ComSpec use semicolons to separate
# directories in TEXINPUTS -- except for Cygwin and Msys, where COMSPEC
# might be inherited, but : is used.

# In the case of Msys, uname returns a value derived from MSYSTEM, as
# MSYSTEM is user configurable, it is not so safe to use it to detect
# Msys. It is safer to use OSTYPE, this is why we set MSYSTEM to
# $OSTYPE before calling uname
if test -n "$COMSPEC$ComSpec" &&
    MSYSTEM=$OSTYPE uname | $EGREP -iv 'cygwin|msys' >/dev/null; then
    path_sep=";"
else
    path_sep=":"
fi

# Pacify verbose cds.
CDPATH=${ZSH_VERSION+.}$path_sep

# Now we define numerous functions, with no other executable code.
# The main program is at the end of the file.

#
# Standard help and version functions.
#
# usage - display usage and exit successfully.
usage() {
    cat <<EOF
Usage: $program [OPTION]... FILE...
  or:  texi2pdf [OPTION]... FILE...
  or:  pdftexi2dvi [OPTION]... FILE...

Run each Texinfo or (La)TeX FILE through TeX in turn until all
cross-references are resolved, building all indices.  The directory
containing each FILE is searched for included files.  The suffix of FILE
is used to determine its language ((La)TeX or Texinfo).  To process
(e)plain TeX files, set the environment variable LATEX=tex.

When invoked as \`texi2pdf' or given the option --pdf generate PDF output.
Otherwise, generate DVI.

General options:
  -D, --debug         turn on shell debugging (set -x)
  -h, --help          display this help and exit successfully
  -o, --output=OFILE  leave output in OFILE; only one input FILE is allowed
  -q, --quiet         no output unless errors
  -v, --version       display version information and exit successfully
  -V, --verbose       report on what is done
  --max-iterations=N  don't process files more than N times [$max_iters]
  --mostly-clean      remove auxiliary files or directories from
                          previous runs (but not the output)

Output format:
      --dvi     output a DVI file [default]
      --dvipdf  output a PDF file via DVI (using a dvi-to-pdf program)
      --html    output an HTML file from LaTeX, using HeVeA
      --info    output an Info file from LaTeX, using HeVeA
  -p, --pdf     use pdftex or pdflatex for processing
      --ps      output a PostScript file via DVI (using dvips)
      --text    output a plain text file from LaTeX, using HeVeA

TeX tuning:
  -E, --expand               macro expansion using makeinfo
  -I DIR                     search DIR for Texinfo files
  -l, --language=LANG        specify LANG for FILE, either latex or texinfo
      --no-line-error        do not pass --file-line-error to TeX
      --shell-escape         pass --shell-escape to TeX
      --src-specials         pass --src-specials to TeX
      --translate-file=FILE  use given charset translation file for TeX
  -t, --command=CMD          insert CMD in copy of input file

Build modes:
  --build=MODE         specify the treatment of auxiliary files [$build_mode]
      --tidy           same as --build=tidy
  -c, --clean          same as --build=clean
      --build-dir=DIR  specify where the tidy compilation is performed;
                         implies --tidy;
                         defaults to TEXI2DVI_BUILD_DIRECTORY [$build_dir]

The MODE specifies where the TeX compilation takes place, and, as a
consequence, how auxiliary files are treated.  The build mode can also
be set using the environment variable TEXI2DVI_BUILD_MODE.

Valid values of MODE are:
  \`local'      compile in the current directory, leaving all the auxiliary
               files around.  This is the traditional TeX use.
  \`tidy'       compile in a local *.t2d directory, where the auxiliary files
               are left.  Output files are copied back to the original file.
  \`clean'      same as \`tidy', but remove the auxiliary directory afterwards.
               Every compilation therefore requires the full cycle.

The values of these environment variables are used to run the
corresponding commands, if they are set:

  BIBER BIBTEX DVIPDF DVIPS EGREP HEVEA LATEX MAKEINDEX MAKEINFO
  PDFLATEX PDFTEX SED T4HT TEX TEX4HT TEXINDEX TEXINDY THUMBPDF_CMD

Regarding --dvipdf, if DVIPDF is not set in the environment, the
following programs are looked for (in this order): dvipdfmx dvipdfm
dvipdf dvi2pdf dvitopdf.

If Texinfo is installed on your site, then the command

  info texi2dvi

should give you access to more documentation.

Report bugs to bug-texinfo@gnu.org,
general questions and discussion to help-texinfo@gnu.org.
GNU Texinfo home page: <http://www.gnu.org/software/texinfo/>
General help using GNU software: <http://www.gnu.org/gethelp/>
EOF
    exit 0
}

# version - Display version info and exit successfully.
version() {
    cat <<EOF
texi2dvi (GNU Texinfo 6.8)

Copyright (C) 2021 Free Software Foundation, Inc.
License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.
EOF
    exit 0
}

#
# Generic auxiliary functions.

# Used to access files and directories after we have changed directory
# (for --tidy).
rel=

# Change directory, updating some relative paths.
cd_dir() {
    cd "$1"

    # Check if argument or input file is absolute, and if so, make all the path
    # variables absolute.
    use_absolute=false
    case $1 in
    [\\/]* | ?:[\\/]*) # absolute path
        use_absolute=true ;;
    esac
    case $in_input in
    [\\/]* | ?:[\\/]*)
        use_absolute=true
        ;;
    esac

    if $use_absolute; then
        for cdd_dir in work_build workdir t2ddir work_bak in_input in_dir; do
            eval "$cdd_dir=\`absolute \$$cdd_dir\`"
        done
        return
    fi

    # Replace each path component with ".." and add a single trailing slash.
    rel=$(echo "$1" | $SED -e 's/[^/\\][^/\\]*/../g' -e 's/[/\\]*$/\//')
}

# cd_orig - Return to the original directory.
cd_orig() {
    # In case $orig_pwd is on a different drive (for DOS).
    cd /

    # Return to the original directory so that
    # - the next file is processed in correct conditions
    # - the temporary file can be removed
    cd "$orig_pwd" || exit 1

    rel=
}

# func_dirname FILE - Return the directory part of FILE.
func_dirname() {
    dirname "$1" 2>/dev/null ||
        { echo "$1" | $SED 's!/[^/]*$!!;s!^$!.!'; }
}

# noext FILE - Return FILE with one extension removed:
#   foo.bar.baz -> foo.bar
noext() {
    echo "$1" | $SED -e 's/\.[^/.][^/.]*$//'
}

# absolute NAME - Return an absolute path to NAME.
absolute() {
    case $1 in
    [\\/]* | ?:[\\/]*)
        # Absolute paths don't need to be expanded.
        echo "$1"
        ;;
    *)
        absolute_slashes=$(echo "$1" | $SED -n 's,.*[^/]\(/*\)$,\1,p')
        absolute_rel=$orig_pwd/$(func_dirname "$1")
        if test -d "$absolute_rel"; then
            (
                cd "$absolute_rel" 2>/dev/null &&
                    absolute_name=$(pwd)/$(basename "$1")"$absolute_slashes"
                echo "$absolute_name"
            )
        else
            error 1 "not a directory: $absolute_rel"
        fi
        ;;
    esac
}

# ensure_dir DIR1 DIR2... - Make sure given directories exist.
ensure_dir() {
    for dir; do
        # Beware that in parallel builds we may have several concurrent
        # attempts to create the directory.  So fail only if "mkdir"
        # failed *and* the directory still does not exist.
        test -d "$dir" ||
            mkdir -p "$dir" ||
            test -d "$dir" ||
            error 1 "cannot create directory: $dir"
    done
}

# error EXIT_STATUS LINE1 LINE2... - Report an error and exit with
#   failure if EXIT_STATUS is non-null.
error() {
    error_status="$1"
    shift
    report "$@"
    if test "$error_status" != 0; then
        exit $error_status
    fi
}

# findprog PROG - Return true if PROG is somewhere in PATH, else false.
findprog() {
    saveIFS="$IFS"
    IFS=$path_sep # break path components at the path separator
    for dir in $PATH; do
        IFS=$saveIFS
        # The basic test for an executable is `test -f $f && test -x $f'.
        # (`test -x' is not enough, because it can also be true for directories.)
        # We have to try this both for $1 and $1.exe.
        #
        # Note: On Cygwin and DJGPP, `test -x' also looks for .exe.  On Cygwin,
        # also `test -f' has this enhancement, but not on DJGPP.  (Both are
        # design decisions, so there is little chance to make them consistent.)
        # Thusly, it seems to be difficult to make use of these enhancements.
        #
        if { test -f "$dir/$1" && test -x "$dir/$1"; } ||
            { test -f "$dir/$1.exe" && test -x "$dir/$1.exe"; }; then
            return 0
        fi
    done
    return 1
}

# report LINE1 LINE2... - Echo each argument to stderr.
report() {
    for i in "$@"; do
        echo >&2 "$0: $i"
    done
}

# run COMMAND-LINE - Run COMMAND-LINE verbosely, catching errors as failures.
run() {
    verbose "Running $@"
    "$@" 2>&5 1>&2 ||
        error 1 "$1 failed"
}

# verbose WORD1 WORD2... - Echo concatenated WORDs to stderr, if $verb.
verbose() {
    if $verb; then
        echo >&2 "$0: $@"
    fi
}

#
# Handling lists.
#
# list_append LIST-NAME ELEM - Append ELEM to (the contents of) LIST-NAME.
list_append() {
    list_name="$1"
    shift
    eval set X \$$list_name "$@"
    shift
    eval $list_name=\""$@"\"
}

# list_concat_dirs LIST-NAME DIR-LIST - Append to LIST-NAME all the
# components (including empty ones) from the $path_sep-separated list
# DIR-LIST.  Make the paths absolute.
list_concat_dirs() {
    lcd_list="$1"
    # Empty path components are meaningful to tex.  We rewrite them as
    # `EMPTY' so they don't get lost when we split on $path_sep.
    # Hopefully no one will have an actual directory named EMPTY.
    lcd_replace_EMPTY="-e 's/^$path_sep/EMPTY$path_sep/g' \
                     -e 's/$path_sep\$/${path_sep}EMPTY/g' \
                     -e 's/$path_sep$path_sep/${path_sep}EMPTY${path_sep}/g'"
    save_IFS=$IFS
    IFS=$path_sep
    set x $(echo "$2" | eval $SED $lcd_replace_EMPTY)
    shift
    IFS=$save_IFS
    for lcd_dir; do
        case $lcd_dir in
        EMPTY)
            list_append $lcd_list ""
            ;;
        *)
            if test -d $lcd_dir; then
                dir=$(absolute "$lcd_dir")
                list_append $lcd_list "$lcd_dir"
            fi
            ;;
        esac
    done
}

# list_prefix LIST-NAME SEP -> STRING - Return string with each element
# of LIST-NAME preceded by SEP.
list_prefix() {
    lp_separator="$2"
    eval set X \$$1
    shift
    lp_result=''
    for i; do
        lp_result="$lp_result \"$lp_separator\" \"$i\""
    done
    echo "$lp_result"
}

# list_infix LIST-NAME SEP -> STRING - Same as list_prefix, but a separator.
list_infix() {
    eval set X \$$1
    shift
    save_IFS="$IFS"
    IFS=$path_sep
    echo "$*"
    IFS=$save_IFS
}

# list_dir_to_abs LIST-NAME - Convert list to using only absolute dir names.
# Currently unused, but should replace absolute_filenames some day.
list_dir_to_abs() {
    ldta_list="$1"
    eval set X \$$ldta_list
    shift
    ldta_result=''
    for dir; do
        dir=$(absolute "$dir")
        test -d "$dir" || continue
        ldta_result="$ldata_result \"$dir\""
    done
    set X $ldta_result
    shift
    eval $ldta_list=\"$@\"
}

#
# Language auxiliary functions.
#
# out_lang_set LANG - set $out_lang to LANG (dvi, pdf, etc.), or error.
out_lang_set() {
    case $1 in
    dvi | dvipdf | html | info | pdf | ps | text) out_lang=$1 ;;
    *) error 1 "invalid output format: $1" ;;
    esac
}

# out_lang_tex - Return the tex output language (DVI or PDF) for $out_lang.
out_lang_tex() {
    case $out_lang in
    dvi | ps | dvipdf) echo dvi ;;
    pdf) echo $out_lang ;;
    html | info | text) echo $out_lang ;;
    *) error 1 "invalid out_lang: $1" ;;
    esac
}

# out_lang_ext - Return the extension for $out_lang (pdf, dvi, etc.).
out_lang_ext() {
    case $out_lang in
    dvipdf) echo pdf ;;
    dvi | html | info | pdf | ps | text) echo $out_lang ;;
    *) error 1 "invalid out_lang: $1" ;;
    esac
}

#
# TeX file auxiliary functions.
#
# absolute_filenames TEX-PATH -> TEX-PATH - Convert relative paths to
# absolute, so we can run in another directory (e.g., in tidy build
# mode, or during the macro-support detection).
absolute_filenames() {
    # Empty path components are meaningful to tex.  We rewrite them as
    # `EMPTY' so they don't get lost when we split on $path_sep.
    # Hopefully no one will have an actual directory named EMPTY.
    af_replace_empty="-e 's/^$path_sep/EMPTY$path_sep/g' \
                    -e 's/$path_sep\$/${path_sep}EMPTY/g' \
                    -e 's/$path_sep$path_sep/${path_sep}EMPTY${path_sep}/g'"
    af_result=$(echo "$1" | eval $SED $af_replace_empty)
    save_IFS=$IFS
    IFS=$path_sep
    set x $af_result
    shift
    af_result=
    af_path_sep=
    for dir; do
        case $dir in
        EMPTY)
            af_result=$af_result$af_path_sep
            ;;
        *)
            if test -d "$dir"; then
                af_result=$af_result$af_path_sep$(absolute "$dir")
            else
                # Even if $dir is not a directory, preserve it in the path.
                # It might contain metacharacters that TeX will expand in
                # turn, e.g., /some/path/{a,b,c}.  This will not get the
                # implicit absolutification of the path, but we can't help that.
                af_result=$af_result$af_path_sep$dir
            fi
            ;;
        esac
        af_path_sep=$path_sep
    done
    echo "$af_result"
}

# output_base_name FILE - Return the name of FILE, possibly renamed to
# satisfy --output.  FILE is local, i.e., without any directory part.
output_base_name() {
    case $oname in
    '') echo "$1" ;;
    *)
        obn_out_noext=$(noext "$oname")
        obn_file_ext=$(echo "$1" | $SED 's/^.*\.//')
        echo "$obn_out_noext.$obn_file_ext"
        ;;
    esac
}

# destdir - Return the directory where the output is expected.
destdir() {
    case $oname in
    '') echo "$orig_pwd" ;;
    *) dirname "$oname" ;;
    esac
}

# move_to_dest FILE... - Move FILE(s) to the place where the user expects.
# Truly move it, that is, it must not remain in its build location
# unless that is also the output location.  (Otherwise it might appear
# as an extra file in make distcheck.)
#
# FILE can be the principal output (in which case -o directly applies),
# or an auxiliary file with the same base name.
move_to_dest() {
    #  echo "move_to_dest $*, tidy=$tidy, oname=$oname"

    # If we built in place and have no output name, there is nothing to
    # do, so just return.
    case $tidy:$oname in
    false:) return ;;
    esac

    for file; do
        test -f "$file" ||
            error 1 "no such file or directory: $file"
        case $tidy:$oname in
        true:)
            mtd_destdir=$orig_pwd
            mtd_destfile=$mtd_destdir/$file
            ;;
        true:*)
            mtd_destfile=$(output_base_name "$file")
            mtd_destdir=$(dirname "$mtd_destfile")
            ;;
        false:*)
            mtd_destfile=$oname
            mtd_destdir=$(dirname "$mtd_destfile")
            ;;
        esac

        # We want to compare the source location and the output location,
        # and if they are different, do the move.  But if they are the
        # same, we must preserve the source.  Since we can't assume
        # stat(1) or test -ef is available, resort to comparing the
        # directory names, canonicalized with pwd.  We can't use cmp -s
        # since the output file might not actually change from run to run;
        # e.g., TeX DVI output is timestamped to only the nearest minute.
        mtd_destdir=$(cd "$mtd_destdir" && pwd)
        mtd_destbase=$(basename "$mtd_destfile")

        mtd_sourcedir=$(dirname "$file")
        mtd_sourcedir=$(cd "$mtd_sourcedir" && pwd)
        mtd_sourcebase=$(basename "$file")

        if test "$mtd_sourcedir/$mtd_sourcebase" != "$mtd_destdir/$mtd_destbase"; then
            verbose "Moving $file to $mtd_destfile"
            rm -f "$mtd_destfile"
            mv "$file" "$mtd_destfile"
        fi
    done
}

#
# Managing xref files.
#
# aux_file_p FILE - Echo FILE if FILE is an aux file.
aux_file_p() {
    test -f "$1" || return 0
    case $1 in
    *.aux) echo "$1" ;;
    *) return 0 ;;
    esac
}

# bibaux_file_p FILE - Echo FILE if FILE contains citation requests.
bibaux_file_p() {
    test -s "$1" || return 0
    if (
        grep '^\\bibstyle[{]' "$1" &&
            grep '^\\bibdata[{]' "$1"
        ## The following line is suspicious: fails when there
        ## are citations in sub aux files.  We need to be
        ## smarter in this case.
        ## && grep '^\\citation[{]' "$f"
    ) >&6 2>&1; then
        echo "$1"
    fi
    return 0
}

# index_file_p FILE - Echo FILE if FILE is an index file.
index_file_p() {
    test -f "$1" || return 0
    case $in_lang:$latex2html:$(out_lang_tex):$($SED '1q' "$1") in
    # When working with TeX4HT, *.idx are created by LaTeX.  They must
    # be processed to produce *.4ix, *.4dx files.  The *.4dx file is
    # passed to makeindex to produce the *.ind file.  This sequence is
    # handled by run_index, so we are only interested in the *.idx
    # files, which have each "\indexentry" preceded by a
    # "\beforeentry".
    latex:tex4ht:html:"\\beforeentry {"*) echo $1 ;;

        # When index.sty is used, there is a space before the brace.
    latex:*:*:"\\indexentry{"* | latex:*:*:"\\indexentry {"*) echo $1 ;;

    texinfo:*:*:"\\entry{"*) echo $1 ;;
    texinfo:*:*:"@entry{"*) echo $1 ;;
        # @entry is output from newer versions of texinfo.tex
    esac
    return 0
}

########### not used currently
# xref_file_p FILE - Return success if FILE is an xref file (indexes,
# tables and lists).
xref_file_p() {
    test -f "$1" || return 1
    # If the file is not suitable to be an index or xref file, don't
    # process it.  It's suitable if the first character is a
    # backslash or right quote or at, as long as the first line isn't
    # \input texinfo.
    case $($SED '1q' "$1") in
    "\\input texinfo"*) return 1 ;;
    [\\''@]*) return 0 ;;
    *) return 1 ;;
    esac
}

# Used in generated_files_get
generated_files_get_from_log() {
    if test -f "$1.log"; then
        # Usually the output is like: \openout1 = `foobar.tex'.
        # (including the final period)
        # but luatex outputs: \openout1 = foobar.tex
        # (no quotes, no period).
        # So we have to make the punctuation optional.
        grep '^\\openout[0-9]' "$1.log" |
            $SED -e "s/\\\\openout[^=]*= *[\`']*//" \
                -e "s/'\.$//"
    fi
}

# Used in generated_files_get
generated_files_get_from_fls() {
    if test -f "$1.fls"; then
        grep '^OUTPUT ' "$1.fls" | cut -b 8- |
            grep -v '\.dvi$' | grep -v '\.log$' | grep -v '\.pdf$' || true
    fi
}

# generated_files_get - Output the list of files generated by the TeX
#                       compilation.
generated_files_get() {
    $generated_files_get_method "$in_noext"
    if test $generated_files_get_method = generated_files_get_from_fls; then
        if test -r "$in_noext.fl"; then
            report 'WARNING!!  The fl index may typeset as garbage!' # goes to stderr
            report 'Try upgrading your version of texinfo.tex, or else try setting'
            report 'the environment variable TEXI2DVI_USE_RECORDER to '\''no'\''.'
            report 'Once you'\''ve done that, delete the file with an '\''fl'\'' extension.'
        fi
    fi
}

# xref_files_save - set xref_files_orig from xref_files_new, and save xref
#                   files in $work_bak.
xref_files_save() {
    # Save copies of auxiliary files for later comparison.
    xref_files_orig=$xref_files_new
    if test -n "$xref_files_orig"; then
        verbose "Backing up xref files: $xref_files_orig"
        # The following line improves `cp $xref_files_orig "$work_bak"'
        # by preserving the directory parts.  Think of
        # cp chap1/main.aux chap2/main.aux $work_bak.
        #
        # Users may have, e.g., --keep-old-files.  Don't let this interfere.
        # (Don't use unset for the sake of ancient shells.)
        TAR_OPTIONS=
        export TAR_OPTIONS
        tar cf - $xref_files_orig | (cd "$rel$work_bak" && tar xf -)
    fi

    # Remove auxiliary files in same directory as main input file.  Otherwise,
    # these will likely be read instead of those in the build dir.
    if $tidy; then
        secondary_xref_files=$(sorted_index_files)
        for f in $xref_files_new $secondary_xref_files; do
            if test -f "$rel$in_dir/$f"; then
                remove $rel$in_dir/$f
            fi
        done
    fi
}

# xref_files_changed - Return success if the xref files have changed
# since the previous run.
xref_files_changed() {
    xref_files_new=$(generated_files_get)

    # LaTeX (and the package changebar) report in the LOG file if it
    # should be rerun.  This is needed for files included from
    # subdirs, since texi2dvi does not try to compare xref files in
    # subdirs.  Performing xref files test is still good since LaTeX
    # does not report changes in xref files.
    if grep "Rerun to get" "$in_noext.log" >&6 2>&1; then
        return 0
    fi
    # Similarly, check for biblatex report of whether rerunning is needed.
    if grep "biblatex.*(re)run" "$in_noext.log" >&6 2>&1; then
        return 0
    fi

    # If old and new lists don't have the same file list,
    # then something has definitely changed.
    verbose "Original xref files = $xref_files_orig"
    verbose "New xref files      = $xref_files_new"
    if test "x$xref_files_orig" != "x$xref_files_new"; then
        return 0
    fi

    # Compare each file until we find a difference.
    for this_file in $xref_files_new; do
        verbose "Comparing xref file $(echo $this_file | $SED 's|\./||g') ..."
        # cmp -s returns nonzero exit status if files differ.
        if cmp -s "$this_file" "$rel$work_bak/$this_file"; then :; else
            verbose "xref file $(echo $this_file | $SED 's|\./||g') differed ..."
            if $debug; then
                diff -u "$rel$work_bak/$this_file" "$this_file"
            fi
            return 0
        fi
    done

    secondary_xref_files=$(sorted_index_files)
    verbose "Secondary xref files = $secondary_xref_files"
    for this_file in $secondary_xref_files; do
        if test -f $this_file; then :; else
            verbose "$this_file missing ..."
            return 0
        fi
    done

    # No change.
    return 1
}

#
# Running the TeX suite.
#
# Set tex_cmd variable, for running TeX.
make_tex_cmd() {
    case $in_lang:$latex2html:$(out_lang_tex) in
    latex:*:dvi | latex:tex4ht:html)
        tex=${LATEX:-latex}
        ;;
    latex:*:pdf)
        tex=${PDFLATEX:-pdflatex}
        ;;
    texinfo:*:dvi)
        # MetaPost also uses the TEX environment variable.  If the user
        # has set TEX=latex for that reason, don't bomb out.
        case $TEX in
        *latex) tex=tex ;; # don't bother trying to find etex
        *) tex=$TEX ;;
        esac
        ;;
    texinfo:*:pdf) tex=$PDFTEX ;;
    *) error 1 "$out_lang not supported for $in_lang" ;;
    esac

    # Beware of aux files in subdirectories that require the
    # subdirectory to exist.
    case $in_lang:$tidy in
    latex:true)
        $SED -n 's|^[ ]*\\include{\(.*\)/.*}.*|\1|p' "$in_input" |
            sort -u |
            while read d; do
                ensure_dir "$work_build/$d"
            done
        ;;
    esac

    # Note that this will be used via an eval: quote properly.
    tex_cmd="$tex"

    # If possible, make TeX report error locations in GNU format.
    if $line_error; then
        if test "${tex_help:+set}" != set; then
            # Go to a temporary directory to try --help, since old versions that
            # don't accept --help will generate a texput.log.
            tex_help_dir=$t2ddir/tex_help
            ensure_dir "$tex_help_dir"
            tex_help=$(cd "$tex_help_dir" >&6 && $tex --help </dev/null 2>&1 || true)
        fi
        # The mk program and perhaps others want to parse TeX's
        # original error messages.
        case $tex_help in
        *file-line-error*) tex_cmd="$tex_cmd --file-line-error" ;;
        esac
    fi

    # Tell TeX about -recorder option, if specified
    # recorder_option_maybe is in { " -recorder", "" }
    tex_cmd="$tex_cmd$recorder_option_maybe"

    # Tell TeX about TCX file, if specified.
    test -n "$translate_file" &&
        tex_cmd="$tex_cmd --translate-file=$translate_file"

    # Tell TeX to make source specials (for backtracking from output to
    # source, given a sufficiently smart editor), if specified.
    test -n "$src_specials" && tex_cmd="$tex_cmd $src_specials"

    # Tell TeX to allow running external executables
    test -n "$shell_escape" && tex_cmd="$tex_cmd $shell_escape"

    # Run without interaction, stopping at the first error.
    tex_cmd="$tex_cmd </dev/null"
}

# run_tex - Run TeX, taking care of errors and logs.
run_tex() {
    # Check for any unusual characters in the filename.
    # However, >, \ and any whitespace characters are not supported
    # filenames.
    in_input_funnies=$(echo "$in_input" |
        $SED -e 's![^}#$%&^_{~]!!g' -e 's!\(.\)!\1\''
!g' | uniq)

    if test -n "$in_input_funnies"; then
        # Make > an end group character, as it's unlikely to appear in
        # a filename.
        tex_cmd="$tex_cmd '${escape}bgroup${escape}catcode62=2${escape}relax'"

        # If the filename has funny characters, change the TeX category codes of
        # some characters within a group, and use \expandafter to input the file
        # outside of the group.
        for w in $in_input_funnies; do
            tex_cmd="$tex_cmd '${escape}catcode\`${escape}$w=12${escape}relax'"
        done

        # Set \toks0 to "\input FILENAME\relax"
        tex_cmd="$tex_cmd '${escape}toks0${escape}bgroup${escape}input' '$rel$in_input' '${escape}relax>"

        # Expand \toks0 after the end of the group
        tex_cmd="$tex_cmd${escape}expandafter${escape}egroup"
        tex_cmd="$tex_cmd${escape}the${escape}toks0${escape}relax'"
    else
        # In the case of a simple filename, just pass the filename
        # with no funny tricks.
        tex_cmd="$tex_cmd '${escape}input' '$rel$in_input'"
    fi

    verbose "$0: Running $tex_cmd ..."
    if (eval "$tex_cmd" >&5); then
        case $out_lang in
        dvi | pdf) move_to_dest "$in_noext.$out_lang" ;;
        esac
    else
        tex_failed=true
    fi
}

# run_bibtex - Run bibtex (or biber) on current file
# - if its input (AUX) exists,
# - or if some citations are missing (LOG contains `Citation'),
# - or if the LOG complains of a missing .bbl.
#
# Don't try to be too smart:
# 1. Running bibtex only if the bbl file exists and is older than
# the LaTeX file is wrong, since the document might include files
# that have changed.
#
# 2. Because there can be several AUX (if there are \include's),
# but a single LOG, looking for missing citations in LOG is
# easier, though we take the risk of matching false messages.
run_bibtex() {
    case $in_lang in
    latex) bibtex=${BIBTEX:-bibtex} ;;
    texinfo) return ;;
    esac

    # "Citation undefined" is for LaTeX, "Undefined citation" for btxmac.tex.
    # The no .aux && \bibdata test is also for btxmac, in case it was the
    # first run of a bibtex-using document.  Otherwise, it's possible that
    # bibtex would never be run.
    if test -r "$in_noext.aux" &&
        test -r "$in_noext.log" &&
        ( (grep 'Warning:.*Citation.*undefined' "$in_noext.log" ||
            grep '.*Undefined citation' "$in_noext.log" ||
            grep 'No file .*\.bbl\.' "$in_noext.log") ||
            (grep 'No \.aux file' "$in_noext.log" &&
                grep '^\\bibdata' "$in_noext.aux")) \
            >&6 2>&1; then
        bibtex_aux=$(filter_files bibaux_file_p)
        for f in $bibtex_aux; do
            run $bibtex "$f"
        done
    fi

    # biber(+biblatex) check.
    if test -r "$in_noext.bcf" &&
        grep '</bcf:controlfile>' "$in_noext.bcf" >/dev/null; then
        run ${BIBER:-biber} "$in_noext"
    fi
}

# filter_file PREDICATE - Go through the list of files in xref_files_new
# and use PREDICATE on each one to optionally print it or print other files
# based on the filename.
filter_files() {
    test -n "$xref_files_new" || return 0
    echo "$xref_files_new" |
        # Filter existing files matching the criterion.
        #
        while read file; do
            $1 "$file"
        done |
        sort |
        # Some files are opened several times, e.g., listings.sty's *.vrb.
        uniq
}

# run_index - Run texindex (or makeindex or texindy) on current index
# files.  If they already exist, and after running TeX a first time the
# index files don't change, then there's no reason to run TeX again.
# But we won't know that if the index files are out of date or nonexistent.
run_index() {
    index_files=$(filter_files index_file_p)
    test -n "$index_files" ||
        return 0

    : ${MAKEINDEX:=makeindex}
    : ${TEXINDEX:=texindex}
    : ${TEXINDY:=texindy}

    case $in_lang:$latex2html:$(out_lang_tex) in
    latex:tex4ht:html)
        for index_file in $index_files; do
            index_noext=$(noext "$index_file")
            run tex \
                '\def\filename{{'"$index_noext"'}{idx}{4dx}{ind}}
             \input idxmake.4ht'
            run $MAKEINDEX -o $index_noext.ind $index_noext.4dx
        done
        ;;

    latex:*)
        if $TEXINDY --version >&6 2>&1; then
            run $TEXINDY $index_files
        else
            run $MAKEINDEX $index_files
        fi
        ;;

    texinfo:*)
        run $TEXINDEX $index_files
        ;;
    esac
}

# run_tex4ht - Run the last two phases of TeX4HT: tex4ht extracts the
# HTML from the instrumented DVI file, and t4ht converts the figures and
# installs the files when given -d.
#
# Because knowing exactly which files are created is complex (in
# addition the names are not simple to compute), which makes it
# difficult to install the output files in a second step, we
# tell t4ht to install the output files.
run_tex4ht() {
    case $in_lang:$latex2html:$(out_lang_tex) in
    latex:tex4ht:html)
        : ${TEX4HT:=tex4ht} ${T4HT:=t4ht}
        run "$TEX4HT" "-f/$in_noext"
        # Do not remove the / after the destdir.
        run "$T4HT" "-d$(destdir)/" "-f/$in_noext"
        ;;
    esac
}

# run_thumbpdf - Run thumbpdf.
run_thumbpdf() {
    if test $(out_lang_tex) = pdf &&
        test -r "$in_noext.log" &&
        grep 'thumbpdf\.sty' "$in_noext.log" >&6 2>&1; then
        thumbpdf=${THUMBPDF_CMD:-thumbpdf}
        thumbcmd="$thumbpdf $in_dir/$in_noext"
        verbose "Running $thumbcmd ..."
        if $thumbcmd >&5; then
            run_tex
        else
            report "$thumbpdf exited with bad status." \
                "Ignoring its output."
        fi
    fi
}

# run_dvipdf FILE.dvi - Convert FILE.dvi to FILE.pdf.
run_dvipdf() {
    # Find which dvi->pdf program is available.
    if test -n "$DVIPDF"; then
        dvipdf=$DVIPDF # user envvar, use it without checking

    elif test -z "$dvipdf"; then
        for i in dvipdfmx dvipdfm dvipdf dvi2pdf dvitopdf; do
            if findprog $i; then
                dvipdf=$i
            fi
        done
    fi
    # These tools have varying interfaces, some 'input output', others
    # 'input -o output'.  They all seem to accept 'input' only,
    # outputting using the expected file name.
    run $dvipdf "$1"
    if test ! -f $(echo "$1" | $SED -e 's/\.dvi$/.pdf/'); then
        error 1 "cannot find output file"
    fi
}

# run_tex_suite - Run the TeX tools until a stable point is reached.
run_tex_suite() {
    make_tex_cmd

    # Move to the working directory.
    if $tidy; then
        verbose "cd $work_build"
        cd_dir "$work_build" || exit 1
    fi

    # Count the number of cycles.
    suite_cycle=0

    # Start by checking the log files for what files were created last
    # time.  This will mean that if they don't change, we finish in 1 cycle.
    xref_files_new=$(generated_files_get)
    xref_files_save

    while :; do
        # check for (probably) LaTeX loop (e.g. varioref)
        if test $suite_cycle -eq "$max_iters"; then
            error 0 "Maximum of $max_iters cycles exceeded"
            break
        fi

        # report progress
        suite_cycle=$(expr $suite_cycle + 1)
        verbose "Cycle $suite_cycle for $command_line_filename"

        tex_failed=false
        run_core_conversion
        xref_files_changed || break
        xref_files_save

        # We run bibtex first, because it's more likely for the indexes
        # to change after bibtex is run than the reverse, though either
        # would be rare.
        run_bibtex
        run_index
    done

    if $tex_failed; then
        # TeX failed, and the xref files did not change.
        error 1 "$tex exited with bad status, quitting."
    fi

    # If we were using thumbpdf and producing PDF, then run thumbpdf
    # and TeX one last time.
    run_thumbpdf

    # If we are using tex4ht, call it.
    run_tex4ht

    # Install the result if we didn't already (i.e., if the output is
    # dvipdf or ps).
    case $latex2html:$out_lang in
    *:dvipdf)
        run_dvipdf "$in_noext.$(out_lang_tex)"
        move_to_dest "$in_noext.$(out_lang_ext)"
        ;;
    *:ps)
        : ${DVIPS:=dvips}
        run $DVIPS -o "$in_noext.$(out_lang_ext)" "$in_noext.$(out_lang_tex)"
        move_to_dest "$in_noext.$(out_lang_ext)"
        ;;
    esac

    cd_orig
}

#
# TeX processing auxiliary tools.
#
# run_makeinfo - Expand macro commands in the original source file using
# Makeinfo.  Always use `end' footnote style, since the `separate' style
# generates different output (arguably this is a bug in -E).  Discard
# main info output, the user asked to run TeX, not makeinfo.
run_makeinfo() {
    test $in_lang = texinfo ||
        return 0

    # Unless required by the user, makeinfo expansion is wanted only
    # if texinfo.tex is too old.
    if $expand; then
        makeinfo=${MAKEINFO:-makeinfo}
    else
        # Check if texinfo.tex performs macro expansion by looking for
        # its version.  The version is a date of the form YEAR-MO-DA.
        # We don't need to use [0-9] to match the digits since anyway
        # the comparison with $txiprereq, a number, will fail with non-digits.
        # Run in a temporary directory to avoid leaving files.
        version_test_dir=$t2ddir/version_test
        ensure_dir "$version_test_dir"
        if (
            cd "$version_test_dir"
            report "PWD: $(pwd)"
            echo '\input texinfo.tex @bye' >txiversion.tex
            # Be sure that if tex wants to fail, it is not interactive:
            # close stdin.
            #TEXINPUTS=".;../;doc/;;"
            unset BIBINPUTS BSTINPUTS DVIPSHEADERS INDEXSTYLE MFINPUTS MPINPUTS TEXINPUTS TFMFONTS
            unset COMSPEC ComSpec
            TEXINPUTS=".;../;doc/;;" TFMFONTS="" \
                $TEX txiversion.tex </dev/null >txiversion.out 2>txiversion.err
        ); then :; else
            report "texinfo.tex appears to be broken.
This may be due to the environment variable TEX set to something
other than (plain) tex, a corrupt texinfo.tex file, or
to tex itself simply not working."
            report "TEXINPUTS = $TEXINPUTS"
            cat "$version_test_dir/txiversion.out"
            cat "$version_test_dir/txiversion.err" >&2
            error 1 "quitting."
        fi
        eval $($SED -n 's/^.*\[\(.*\)version \(....\)-\(..\)-\(..\).*$/txiformat=\1 txiversion="\2\3\4"/p' "$version_test_dir/txiversion.out")
        verbose "texinfo.tex preloaded as \`$txiformat', version is \`$txiversion' ..."
        if test "$txiprereq" -le "$txiversion" >&6 2>&1; then
            makeinfo=
        else
            makeinfo=${MAKEINFO:-makeinfo}
        fi
        # If TeX is preloaded, offer the user this convenience:
        if test "$txiformat" = Texinfo; then
            escape=@
        fi
    fi

    if test -n "$makeinfo"; then
        # in_src: the file with macros expanded.
        # Use the same basename to generate the same aux file names.
        work_src=$workdir/src
        ensure_dir "$work_src"
        in_src=$work_src/$in_base
        run_mi_includes=$(list_prefix includes -I)
        verbose "Macro-expanding $command_line_filename to $in_src ..."
        # eval $makeinfo because it might be defined as something complex
        # (running missing) and then we end up with things like '"-I"',
        # and "-I" (including the quotes) is not an option name.  This
        # happens with gettext 0.14.5, at least.
        $SED "$comment_iftex" "$command_line_filename" |
            eval $makeinfo --footnote-style=end -I "$in_dir" $run_mi_includes \
                -o /dev/null --macro-expand=- |
            $SED "$uncomment_iftex" >"$in_src"
        # Continue only if everything succeeded.
        if test $? -ne 0 ||
            test ! -r "$in_src"; then
            verbose "Expansion failed, ignored..."
        else
            in_input=$in_src
        fi
    fi
}

# Unfortunately, makeinfo --iftex --no-ifinfo doesn't work well enough
# in versions before 5.0, as makeinfo can't parse the TeX commands
# inside @tex blocks, so work around with sed.
#
# This sed script preprocesses Texinfo sources in order to keep the
# iftex sections only.  We want to remove non-TeX sections, and comment
# (with `@c _texi2dvi') TeX sections so that makeinfo does not try to
# parse them.  Nevertheless, while commenting TeX sections, don't
# comment @macro/@end macro so that makeinfo does propagate them.
# Similarly, preserve the @top node to avoid makeinfo complaining about
# it being missed.  Comment it out after preprocessing, so that it does
# not appear in the generated document.
#
# We assume that `@c _texi2dvi' or `@c (_texi2dvi)' starting a line is
# not present in the document.  Additionally, conditionally defined
# macros inside the @top node may end up with the wrong value, although
# this is unlikely in practice.
#
comment_iftex='/^@tex/,/^@end tex/{
  s/^/@c _texi2dvi/
}
/^@iftex/,/^@end iftex/{
  s/^/@c _texi2dvi/
  /^@c _texi2dvi@macro/,/^@c _texi2dvi@end macro/{
    s/^@c _texi2dvi//
  }
}
/^@ifnottex/,/^@end ifnottex/{
  s/^/@c (_texi2dvi)/
  /^@c (_texi2dvi)@node Top/,/^@c (_texi2dvi)@end ifnottex/ {
    /^@c (_texi2dvi)@end ifnottex/b
    s/^@c (_texi2dvi)//
  }
}
/^@ifinfo/,/^@end ifinfo/{
  /^@node/p
  /^@menu/,/^@end menu/p
  t
  s/^/@c (_texi2dvi)/
}
s/^@ifnotinfo/@c _texi2dvi@ifnotinfo/
s/^@end ifnotinfo/@c _texi2dvi@end ifnotinfo/'

# Uncomment @iftex blocks by removing any leading `@c texi2dvi' (repeated
# copies can sneak in via macro invocations).  Likewise, comment out
# the @top node inside a @ifnottex block.
uncomment_iftex='s/^@c _texi2dvi\(@c _texi2dvi\)*//
/^@c (_texi2dvi)@ifnottex/,/^@c (_texi2dvi)@end ifnottex/{
  s/^/@c (_texi2dvi)/
}'

# insert_commands - Insert $textra commands at the beginning of the file.
# Recommended to be used for @finalout, @smallbook, etc.
insert_commands() {
    if test -n "$textra"; then
        # _xtr.  The file with the user's extra commands.
        work_xtr=$workdir/xtr
        in_xtr=$work_xtr/$in_base
        ensure_dir "$work_xtr"
        verbose "Inserting extra commands: $textra"
        case $in_lang in
        latex) textra_cmd=1i ;;
        texinfo)
            textra_cmd='/^\\input texinfo/a'
            # insert after @setfilename line if present
            if head -n 10 $in_input | grep '^@setfilename'; then
                textra_cmd='/^@setfilename/a'
            fi
            ;;
        *) error 1 "internal error, unknown language: $in_lang" ;;
        esac
        $SED "$textra_cmd\\
$textra" "$in_input" >"$in_xtr"
        in_input=$in_xtr
    fi

    case $in_lang:$latex2html:$(out_lang_tex) in
    latex:tex4ht:html)
        # _tex4ht.  The file with the added \usepackage{tex4ht}.
        work_tex4ht=$workdir/tex4ht
        in_tex4ht=$work_tex4ht/$in_base
        ensure_dir "$work_tex4ht"
        verbose "Inserting \\usepackage{tex4ht}"
        perl -pe 's<\\documentclass(?:\[.*\])?{.*}>
                 <$&\\usepackage[xhtml]{tex4ht}>' \
            "$in_input" >"$in_tex4ht"
        in_input=$in_tex4ht
        ;;
    esac
}

# compute_language FILENAME - Return the short string for the language
# in which FILENAME is written: `texinfo' or `latex'.
compute_language() {
    # If the user explicitly specified the language, use that.
    # Otherwise, if the first line is \input texinfo, assume it's texinfo.
    # Otherwise, guess from the file extension.
    if test -n "$set_language"; then
        echo $set_language
    elif $SED 1q "$1" | grep 'input texinfo' >&6; then
        echo texinfo
    else
        # Get the type of the file (latex or texinfo) from the given language
        # we just guessed, or from the file extension if not set yet.
        case $1 in
        *.ltx | *.tex | *.drv | *.dtx) echo latex ;;
        *) echo texinfo ;;
        esac
    fi
}

# run_hevea (MODE) - Convert to HTML/INFO/TEXT.
#
# Don't pass `-noiso' to hevea: it's useless in HTML since anyway the
# charset is set to latin1, and troublesome in other modes since
# accented characters loose their accents.
#
# Don't pass `-o DEST' to hevea because in that case it leaves all its
# auxiliary files there too...  Too bad, because it means we will need
# to handle images some day.
run_hevea() {
    run_hevea_name="${HEVEA:-hevea}"
    run_hevea_cmd="$run_hevea_name"

    case $1 in
    html) ;;
    text | info) run_hevea_cmd="$run_hevea_cmd -$1" ;;
    *) error 1 "run_hevea_cmd: invalid argument: $1" ;;
    esac

    # Compiling to the tmp directory enables to preserve a previous
    # successful compilation.
    run_hevea_cmd="$run_hevea_cmd -fix -O -o '$out_base'"
    run_hevea_cmd="$run_hevea_cmd $(list_prefix includes -I) -I '$orig_pwd' "
    run_hevea_cmd="$run_hevea_cmd '$rel$in_input'"

    if $debug; then
        run_hevea_cmd="$run_hevea_cmd -v -v"
    fi

    verbose "running $run_hevea_cmd"
    if eval "$run_hevea_cmd" >&5; then
        # hevea leaves trailing white spaces, this is annoying.
        case $1 in text | info)
            perl -pi -e 's/[ \t]+$//g' "$out_base"*
            ;;
        esac
        case $1 in
        html | text) move_to_dest "$out_base" ;;
        info) # There can be foo.info-1, foo.info-2 etc.
            move_to_dest "$out_base"* ;;
        esac
    else
        error 1 "$run_hevea_name exited with bad status, quitting."
    fi
}

# run_core_conversion - Run TeX (or HeVeA).
run_core_conversion() {
    case $in_lang:$latex2html:$(out_lang_tex) in
    *:dvi | *:pdf | latex:tex4ht:html)
        run_tex
        ;;
    latex:*:html | latex:*:text | latex:*:info)
        run_hevea $out_lang
        ;;
    *)
        error 1 "invalid input/output combination: $in_lang/$out_lang"
        ;;
    esac
}

# compile - Run the full compilation chain, from pre-processing to
# installation of the output at its expected location.
compile() {
    # Set include path for tools:
    #   .  Include current directory in case there are files there already, so
    #     we don't have more TeX runs than necessary.  orig_pwd is used in case
    #     we are in clean build mode, where we have cd'd to a temp directory.
    #   .  Include directory containing file, in case there are other
    #     files @include'd.
    #   .  Keep a final path_sep to get the default (system) TeX
    #     directories included.
    #   .  If we have any includes, put those at the end.

    common="$orig_pwd$path_sep$in_dir$path_sep"
    #
    txincludes=$(list_infix includes $path_sep)
    test -n "$txincludes" && common="$common$txincludes$path_sep"
    #
    for var in $tex_envvars; do
        eval val="\$common\$${var}_orig"
        # Convert relative paths to absolute paths, so we can run in another
        # directory (e.g., in clean build mode, or during the macro-support
        # detection).
        val=$(absolute_filenames "$val")
        eval $var="\"$val\""
        export $var
        eval verbose \"$var=\'\$${var}\'\"
    done

    # --expand
    run_makeinfo

    # --command, --texinfo
    insert_commands

    # Run until a fixed point is reached.
    run_tex_suite
}

# make_openout_test FLAGS EXTENSION
# - Run TeX with an input file that performs an \openout.  Pass FLAGS to TeX.
#
make_openout_test() {
    recorder_option_maybe="$1"
    make_tex_cmd

    ensure_dir "$workdir"/check_recorder
    cd_dir "$workdir"/check_recorder

    cat >openout.tex <<EOF
\newwrite\ourwrite
\immediate\openout\ourwrite dum.dum
\bye
EOF
    # \bye doesn't work for LaTeX, but it will cause latex
    # to exit with an input error.
    tex_cmd="$tex_cmd '${escape}input' ./openout.tex"
    # ./ in case . isn't in path
    verbose "$0: running $tex_cmd ..."
    rm -fr "openout.$2"
    (eval "$tex_cmd" >/dev/null 2>&1)
}

# Check tex supports -recorder option
check_recorder_support() {
    verbose "Checking TeX recorder support..."
    make_openout_test " -recorder" fls
    if test -f openout.fls && grep '^OUTPUT dum.dum$' openout.fls >/dev/null; then
        cd_orig
        verbose "Checking TeX recorder support... yes"
        return 0
    else
        cd_orig
        verbose "Checking TeX recorder support... no"
        return 1
    fi
}

# Check tex supports \openout traces in log
check_openout_in_log_support() {
    verbose "Checking TeX \openout in log support..."
    make_openout_test "" log
    if test -f openout.log &&
        grep '^\\openout..\? *= *`\?dum\.dum'\''\?' openout.log >/dev/null; then
        cd_orig
        verbose "Checking TeX \openout in log support... yes"
        return 0
    else
        cd_orig
        verbose "Checking TeX \openout in log support... no"
        return 1
    fi
}

# Set that output auxiliary files are detected with the -recorder option,
# which creates a file JOBNAME.fls which is a machine-readable listing of
# files read and written during the job.
set_aux_files_from_fls() {
    recorder_option_maybe=" -recorder"
    generated_files_get_method=generated_files_get_from_fls
}

# Set that output auxiliary files are detected with searching for \openout
# in the log file.
set_aux_files_from_log() {
    recorder_option_maybe=''
    generated_files_get_method=generated_files_get_from_log
}

# Decide whether output auxiliary files are detected with the -recorder
# option, or by searching for \openout in the log file.
decide_aux_files_method() {
    # Select output file detection method
    # Valid values of TEXI2DVI_USE_RECORDER are:
    #   yes           use the -recorder option, no checks.
    #   no            scan for \openout in the log file, no checks.
    #   yesmaybe      check whether -recorder option is supported, and if yes
    #                use it, otherwise check for tracing \openout in the
    #                log file is supported, and if yes use it, else it is an
    #                error.
    #   nomaybe      same as `yesmaybe', except that the \openout trace in
    #                log file is checked first.
    #
    #  The default behaviour is `nomaybe'.

    test -n "$TEXI2DVI_USE_RECORDER" || TEXI2DVI_USE_RECORDER=nomaybe

    case $TEXI2DVI_USE_RECORDER in
    yes) set_aux_files_from_fls ;;

    no) set_aux_files_from_log ;;

    yesmaybe)
        if check_recorder_support; then
            set_aux_files_from_fls
        elif check_openout_in_log_support; then
            set_aux_files_from_log
        else
            error 1 "TeX neither supports -recorder nor outputs \\openout lines in its log file"
        fi
        ;;

    nomaybe)
        if check_openout_in_log_support; then
            set_aux_files_from_log
        elif check_recorder_support; then
            set_aux_files_from_fls
        else
            error 1 "TeX neither supports -recorder nor outputs \\openout lines in its log file"
        fi
        ;;

    *) error 1 "Invalid value of TEXI2DVI_USE_RECORDER environment variable : $TEXI2DVI_USE_RECORDER." ;;

    esac
}

# remove FILE...
remove() {
    verbose "Removing" "$@"
    rm -rf "$@"
}

# all_files - Echo the names of all files generated, including those by
#             auxiliary tools like texindex.
all_files() {
    echo $in_noext.log
    echo $in_noext.fls
    echo $xref_files_new
    echo $(sorted_index_files)
}

sorted_index_files() {
    filter_files sorted_index_filter
}

# Print the name of a generated file based on FILE if there is one.
sorted_index_filter() {
    case $in_lang in
    texinfo)
        # texindex: texinfo.cp -> texinfo.cps
        if test -n "$(index_file_p $1)"; then
            echo $1s
        fi
        ;;
    esac
}

# Not currently used - use with filter_files to add secondary files created by
# bibtex
bibtex_secondary_files() {
    case $in_lang in
    latex)
        if test -n "$(aux_file_p $1)"; then
            # bibtex: *.aux -> *.bbl and *.blg.
            echo $1 | $SED 's/^\(.*\)\.aux$/\1.bbl/'
            echo $1 | $SED 's/^\(.*\)\.aux$/\1.blg/'
        fi
        ;;
    esac
}

# mostly_clean - Remove auxiliary files and directories.  Changes back to
# the original directory.
mostly_clean() {
    cd_orig
    set X "$t2ddir"
    shift
    $tidy || {
        set X ${1+"$@"} $(all_files)
        shift
    }
    remove ${1+"$@"}
}

# cleanup - Remove what should be removed according to options.
# Called at the end of each compilation cycle, and at the end of
# the script.  Changes the current directory.
cleanup() {
    case $clean:$tidy in
    true:true) mostly_clean ;; # build mode is "clean"
    false:false)
        cd_orig
        #remove "$t2ddir"
        ;; # build mode is "local"
    esac
}

#
# input_file_name_decode - Decode COMMAND_LINE_FILENAME, and set the
# following shell variables:
#
# - COMMAND_LINE_FILENAME
#   The filename given on the commmand line, but cleaned of TeX commands.
# - IN_DIR
#   The directory containing the input file.
# - IN_BASE
#   The input file base name (no directory part).
# - IN_NOEXT
#   The input file name with neither file extensions nor directory part.
# - IN_INPUT
#   The path to the input file for passing as a command-line argument
#   to TeX.  Defaults to COMMAND_LINE_FILENAME, but might change if the
#   input is preprocessed.
input_file_name_decode() {
    case $command_line_filename in
    *\\input\{*\}*)
        # Let AUC-TeX error parser deal with line numbers.
        line_error=false
        command_line_filename=$(
            expr X"$command_line_filename" : X'.*input{\([^}]*\)}'
        )
        ;;
    esac

    # If the COMMAND_LINE_FILENAME is not absolute (e.g., --debug.tex),
    # prepend `./' in order to avoid that the tools take it as an option.
    echo "$command_line_filename" | LC_ALL=C $EGREP '^(/|[A-Za-z]:/)' >&6 ||
        command_line_filename="./$command_line_filename"

    # See if the file exists.  If it doesn't we're in trouble since, even
    # though the user may be able to reenter a valid filename at the tex
    # prompt (assuming they're attending the terminal), this script won't
    # be able to find the right xref files and so forth.
    test -r "$command_line_filename" ||
        error 1 "cannot read $command_line_filename, skipping."

    # Get the name of the current directory.
    in_dir=$(func_dirname "$command_line_filename")

    # Strip directory part but leave extension.
    in_base=$(basename "$command_line_filename")
    # Strip extension.
    in_noext=$(noext "$in_base")

    # The normalized file name to compile.  Must always point to the
    # file to actually compile (in case of recoding, macro-expansion etc.).
    in_input=$in_dir/$in_base

    # Compute the output file name.
    if test x"$oname" != x; then
        out_name=$oname
    else
        out_name=$in_noext.$(out_lang_ext)
    fi
    out_dir=$(func_dirname "$out_name")
    out_dir_abs=$(absolute "$out_dir")
    out_base=$(basename "$out_name")
    out_noext=$(noext "$out_base")
}

#
#################### Main program starts ##########################

# Initialize more variables.
#
# Save TEXINPUTS so we can construct a new TEXINPUTS path for each file.
# Likewise for bibtex and makeindex.
tex_envvars="BIBINPUTS BSTINPUTS DVIPSHEADERS INDEXSTYLE MFINPUTS MPINPUTS \
TEXINPUTS TFMFONTS"
for var in $tex_envvars; do
    eval ${var}_orig=\$$var
    export $var
done

# Push a token among the arguments that will be used to notice when we
# ended options/arguments parsing.
# Use "set dummy ...; shift" rather than 'set - ..." because on
# Solaris set - turns off set -x (but keeps set -e).
# Use ${1+"$@"} rather than "$@" because Digital Unix and Ultrix 4.3
# still expand "$@" to a single argument (the empty string) rather
# than nothing at all.
arg_sep="$$--$$"
set dummy ${1+"$@"} "$arg_sep"
shift

while test x"$1" != x"$arg_sep"; do
    # Handle --option=value by splitting apart and putting back on argv.
    case "$1" in
    --*=*)
        opt=$(echo "$1" | $SED -e 's/=.*//')
        val=$(echo "$1" | $SED -e 's/[^=]*=//')
        shift
        set dummy "$opt" "$val" ${1+"$@"}
        shift
        ;;
    esac

    case "$1" in
    -@) escape=@ ;;
    -~) verbose "Option -~ is obsolete: texi2dvi ignores it." ;;
    -b | --batch) ;; # Obsolete
    --build)
        shift
        build_mode=$1
        ;;
    --build-dir)
        shift
        build_dir=$1
        build_mode=tidy
        ;;
    -c | --clean) build_mode=clean ;;
    -D | --debug) debug=true ;;
    -e | -E | --expand) expand=true ;;
    -h | --help) usage ;;
    -I)
        shift
        list_concat_dirs includes "$1"
        ;;
    -l | --lang | --language)
        shift
        set_language=$1
        ;;
    --mostly-clean) action=mostly-clean ;;
    --no-line-error) line_error=false ;;
    --max-iterations)
        shift
        max_iters=$1
        ;;
    -o | --out | --output)
        shift
        # Make it absolute, just in case we also have --clean, or whatever.
        oname=$(absolute "$1")
        ;;

    # Output formats.
    -O | --output-format)
        shift
        out_lang_set "$1"
        ;;
    --dvi | --dvipdf | --html | --info | --pdf | --ps | --text)
        out_lang_set $(echo "x$1" | $SED 's/^x--//')
        ;;

    -p) out_lang_set pdf ;;
    -q | -s | --quiet | --silent) quiet=true ;;
    --src-specials) src_specials=--src-specials ;;
    --shell-escape) shell_escape=--shell-escape ;;
    --tex4ht) latex2html=tex4ht ;;
    -t | --texinfo | --command)
        shift
        textra="$textra\\
"$(echo "$1" | $SED 's/\\\\/\\\\\\\\/g')
        ;;
    --translate-file)
        shift
        translate_file="$1"
        ;;
    --tidy) build_mode=tidy ;;
    -v | --vers*) version ;;
    -V | --verb*) verb=true ;;
    --) # What remains are not options.
        shift
        while test x"$1" != x"$arg_sep"; do
            set dummy ${1+"$@"} "$1"
            shift
            shift
        done
        break
        ;;
    -*)
        error 1 "Unknown or ambiguous option \`$1'." \
            "Try \`--help' for more information."
        ;;
    *)
        set dummy ${1+"$@"} "$1"
        shift
        ;;
    esac
    shift
done
# Pop the token
shift

# $tidy:  compile in a t2d directory.
# $clean: remove all the aux files.
case $build_mode in
local)
    clean=false
    tidy=false
    ;;
tidy)
    clean=false
    tidy=true
    ;;
clean)
    clean=true
    tidy=true
    ;;
*) error 1 "invalid build mode: $build_mode" ;;
esac

# Interpret remaining command line args as filenames.
case $# in
0)
    error 2 "Missing file arguments." "Try \`--help' for more information."
    ;;
1) ;;
*)
    if test -n "$oname"; then
        error 2 "Can't use option \`--output' with more than one argument."
    fi
    ;;
esac

# We can't do much without tex.
# End up with the TEX and PDFTEX variables set to what we are going to use.
#
# If $TEX is set to a directory, don't use it.
test -n "$TEX" && test -d "$TEX" && unset TEX

# But otherwise, use $TEX if it is set.
if test -z "$TEX"; then
    if findprog tex; then :; else
        cat <<EOM >&2
You don't have a working TeX binary (tex) installed anywhere in
your PATH, and texi2dvi cannot proceed without one.  If you want to use
this script, you'll need to install TeX (if you don't have it) or change
your PATH or TEX environment variable (if you do).  See the --help
output for more details.

For information about obtaining TeX, please see http://tug.org/texlive,
or do a web search for TeX and your operating system or distro.
EOM
        exit 1
    fi

    # We want to use etex (or pdftex) if they are available, and the user
    # didn't explicitly specify.  We don't check for elatex and pdfelatex
    # because (as of 2003), the LaTeX team has asked that new distributions
    # use etex by default anyway.
    #
    if findprog etex; then TEX=etex; else TEX=tex; fi
fi

# For many years, the pdftex binary has included the e-tex extensions,
# but for those people with ancient TeX distributions ...
if test -z "$PDFTEX"; then
    if findprog pdfetex; then PDFTEX=pdfetex; else PDFTEX=pdftex; fi
fi

# File descriptor usage:
# 0 standard input
# 1 standard output (--verbose messages)
# 2 standard error
# 5 tools output (turned off by --quiet)
# 6 tracing/debugging (set -x output, etc.)

# Main tools' output (TeX, etc.) that TeX users are used to seeing.
#
# If quiet, discard, else redirect to the message flow.
if $quiet; then
    exec 5>/dev/null
else
    exec 5>&1
fi

# Enable tracing, and auxiliary tools output.
#
# This fd should be used where you'd typically use /dev/null to throw
# output away.  But sometimes it is convenient to see that output (e.g.,
# from a grep) to aid debugging.  Especially debugging at distance, via
# the user.
#
if $debug; then
    exec 6>&1
    set -vx
else
    exec 6>/dev/null
fi

#
# Main program main loop - TeXify each file in turn.
for command_line_filename; do
    verbose "Processing $command_line_filename ..."

    input_file_name_decode

    # `texinfo' or `latex'?
    in_lang=$(compute_language "$command_line_filename")

    # An auxiliary directory used for all the auxiliary tasks involved
    # in compiling this document.
    case $build_dir in
    '' | .) t2ddir=$out_noext.t2d ;;
    *) # Avoid collisions between multiple occurrences of the same
        # file, so depend on the output path.  Remove leading `./',
        # at least to avoid creating a file starting with `.!', i.e.,
        # an invisible file. The sed expression is fragile if the cwd
        # has active characters.  Transform / into ! so that we don't
        # need `mkdir -p'.  It might be something to reconsider.
        t2ddir=$build_dir/$(echo "$out_dir_abs/$out_noext.t2d" |
            $SED "s,^$orig_pwd/,,;s,^\./,,;s,/,!,g") ;;
    esac
    # Remove it at exit if clean mode.
    trap "cleanup" 0 1 2 15

    ensure_dir "$build_dir" "$t2ddir"

    # Sometimes there are incompatibilities between auxiliary files for
    # DVI and PDF.  The contents can also change whether we work on PDF
    # and/or DVI.  So keep separate spaces for each.
    workdir=$t2ddir/$(out_lang_tex)
    ensure_dir "$workdir"

    # _build.  In a tidy build, where the auxiliary files are output.
    if $tidy; then
        work_build=$workdir/build
    else
        work_build=.
    fi

    # _bak.  Copies of the previous auxiliary files (another round is
    # run if they differ from the new ones).
    work_bak=$workdir/bak

    # Make those directories.
    ensure_dir "$work_build" "$work_bak"

    # Decide how to find auxiliary files created by TeX.
    decide_aux_files_method

    case $action in
    compile)
        # Compile the document.
        compile
        cleanup
        ;;

    mostly-clean)
        xref_files_new=$(generated_files_get)
        mostly_clean
        ;;
    esac
done

verbose "done."
exit 0 # exit successfully, not however we ended the loop.
# Local Variables:
# sh-basic-offset: 2
# sh-indentation: 2
# End: