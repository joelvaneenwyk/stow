# Documentation

## "I can't find file `texinfo.tex'"

This means that one of the `TeX` tools is unable to find `texinfo.tex` so it fails. There is not one answer for this issue as it depends on the tools being used. Most tools read `TEXINPUTS` environment variable and try to find it there. Some tools, however, like pdf2tex do not use that environment variable on Windows so that solution does not work. In those cases, you can specify a local path using dot-slash `./` in the `\input` references to fix them.

Useful resources:

* [Preparing for TeX (GNU Texinfo 6.8)](https://www.gnu.org/software/texinfo/manual/texinfo/html_node/Preparing-for-TeX.html)
* [texlive - Definition of the TEXINPUTS variable - TeX - LaTeX Stack Exchange](https://tex.stackexchange.com/questions/93712/definition-of-the-texinputs-variable)
* [environmental.pdf](https://www2.ph.ed.ac.uk/~wjh/tex/documents/environmental.pdf).

## "texinfo.tex appears to be broken"

This one can happen when running `texi2dvi` when not using the `--expand` option. It generates a simple texi file and attempt to generate a document from it. However, if dot `.` is not in your `PATH` then this will fail.

It seems overall this is more complicated than it appears. Few potential complications:

1. If you try to use a Windows install of TeX Live from MSYS2, there will potentially be a mix of path separators either ';' or ':' depending on existence of COMSPEC. This means mixing installations is a **really bad idea**.
2. TEXINPUTS needs to have `.` (dot) in the list to search local paths, but `texi2dvi` converts all paths to absolute paths on start. This makes it problematic and you need to store the dot in a variable to prevent it from getting expanded before hand.

## Resources

* [Texinfo (automake)](https://www.gnu.org/software/automake/manual/html_node/Texinfo.html)
* [texlive - Definition of the TEXINPUTS variable - TeX - LaTeX Stack Exchange](https://tex.stackexchange.com/questions/93712/definition-of-the-texinputs-variable)
* [automake - Building documentation](https://gnu.huihoo.org/automake-1.5/html_chapter/automake_12.html)
* [File: Makefile.am | Debian Sources](https://sources.debian.org/src/texinfo/6.5.0.dfsg.1-4/Makefile.am/)
* [Texinfo (automake)](https://www.gnu.org/software/automake/manual/html_node/Texinfo.html)
* [VPATH Builds (automake)](https://www.gnu.org/software/automake/manual/html_node/VPATH-Builds.html)
* [Checking the Distribution (automake)](https://www.gnu.org/software/automake/manual/html_node/Checking-the-Distribution.html)
* [DESTDIR (GNU Coding Standards)](https://www.gnu.org/prep/standards/html_node/DESTDIR.html)
* [installing - Font installation - mktexmf cannot find newtxbttsla.mf file - TeX - LaTeX Stack Exchange](https://tex.stackexchange.com/questions/213960/font-installation-mktexmf-cannot-find-newtxbttsla-mf-file)
* [Kpathsea: A library for path searching](https://www.tug.org/texinfohtml/kpathsea.html#Introduction)
* [texi2dvi - Creating PDF documents from .texi files - TeX - LaTeX Stack Exchange](https://tex.stackexchange.com/questions/71604/creating-pdf-documents-from-texi-files)
* [Preparing for TeX (GNU Texinfo 6.8)](https://www.gnu.org/software/texinfo/manual/texinfo/html_node/Preparing-for-TeX.html)
* [Search · TEXI2PDF extension:am language:Makefile language:Makefile](https://github.com/search?l=Makefile&p=2&q=TEXI2PDF+extension%3Aam+language%3AMakefile+language%3AMakefile&ref=advsearch&type=Code)

## Experiments

```log
COMSPEC="" /c/Users/{username}/Projects/stow/.tmp/perl/perl/bin/perl.exe

COMSPEC="" /c/Users/{username}/Projects/stow/.tmp/perl/perl/bin/perl.exe /c/Users/{username}/Projects/stow/.tmp/perl/perl/bin/cpanm --local-lib /c/Users/{username}/Projects/stow/.tmp/perllib/msys_mingw64_nt_10_0_19043/5.14.4.763351b4 --notest local::lib App::cpanminus YAML Carp Scalar::Util IO::Scalar Module::Build IO::Socket::SSL Net::SSLeay Moose TAP::Harness TAP::Harness::Env Test::Harness Test::More Test::Exception Test::Output Devel::Cover Devel::Cover::Report::Coveralls TAP::Formatter::JUnit ExtUtils::PL2Bat Inline::C Win32::Mutex

COMSPEC="" /c/Users/{username}/Projects/stow/.tmp/perl/perl/bin/perl.exe /c/Users/{username}/Projects/stow/.tmp/perl/perl/bin/cpanm --local-lib /c/Users/{username}/Projects/stow/.tmp/perllib/msys_mingw64_nt_10_0_19043/5.14.4.763351b4 --notest local::lib App::cpanminus YAML Carp Scalar::Util IO::Scalar Module::Build IO::Socket::SSL Net::SSLeay Moose TAP::Harness TAP::Harness::Env Test::Harness Test::More Test::Exception Test::Output Devel::Cover Devel::Cover::Report::Coveralls TAP::Formatter::JUnit ExtUtils::PL2Bat Inline::C Win32::Mutex

/c/Users/{username}/Projects/stow/.tmp/perl/perl/bin/perl.exe /c/Users/{username}/Projects/stow/.tmp/perllib/msys_mingw64_nt_10_0_19043/5.14.4.763351b4/bin/cpanm_install --self-upgrade

/c/Users/{username}/Projects/stow/.tmp/perl/perl/bin/perl.exe /c/Users/{username}/Projects/stow/.tmp/perl/perl/bin/cpanm Inline::C

/c/Windows/System32/cmd.exe //D //C $(cygpath --windows /c/Users/{username}/Projects/stow/.tmp/perl/perl/bin/perl.exe) $(cygpath --windows /c/Users/{username}/Projects/stow/.tmp/perllib/msys_mingw64_nt_10_0_19043/5.14.4.763351b4/bin/cpanm_install) Inline::C

/c/Windows/System32/cmd.exe //D //C  "/c/Users/{username}/Projects/stow/.tmp/perl/perl/bin/cpanm.bat" Inline::C

/c/Windows/System32/cmd.exe //D //C "cmd.exe /c C:\Users\{username}\Projects\stow\.tmp\perl\perl\bin\perl.exe C:\Users\{username}\Projects\stow\.tmp\perl\perl\bin\cpanm Inline::C"

/c/Windows/System32/cmd.exe //D //C $(cygpath --windows /c/Users/{username}/Projects/stow/.tmp/perl/perl/bin/perl.exe) $(cygpath --windows /c/Users/{username}/Projects/stow/.tmp/perllib/msys_mingw64_nt_10_0_19043/5.14.4.763351b4/bin/cpanm_install) Inline::C

"C:\Users\{username}\Projects\stow\.tmp\perl\perl\bin\perl.exe" "C:\Users\{username}\Projects\stow\.tmp\perl\perl\bin\cpanm" App::cpanminus

"C:\Users\{username}\Projects\stow\.tmp\perl\perl\bin\cpanm.bat" Inline::C
COMSPEC="" /c/Users/{username}/Projects/stow/.tmp/perl/perl/bin/perl.exe /c/Users/{username}/Projects/stow/.tmp/perl/perl/bin/cpanm --local-lib /c/Users/{username}/Projects/stow/.tmp/perllib/msys_mingw64_nt_10_0_19043/5.14.4.763351b4 --notest local::lib App::cpanminus YAML Carp Scalar::Util IO::Scalar Module::Build IO::Socket::SSL Net::SSLeay Moose TAP::Harness TAP::Harness::Env Test::Harness Test::More Test::Exception Test::Output Devel::Cover Devel::Cover::Report::Coveralls TAP::Formatter::JUnit ExtUtils::PL2Bat Inline::C Win32::Mutex

/c/Users/{username}/Projects/stow/.tmp/perl/perl/bin/perl.exe -I /c/Users/{username}/Projects/stow/.tmp/perllib/msys_mingw64_nt_10_0_19043/5.14.4.763351b4 -Mlocal::lib=/c/Users/{username}/Projects/stow/.tmp/perllib/msys_mingw64_nt_10_0_19043/5.14.4.763351b4

 /c/Users/{username}/Projects/stow/.tmp/perl/perl/bin/perl.exe -I /c/Users/{username}/Projects/stow/.tmp/perllib/msys_mingw64_nt_10_0_19043/5.14.4.763351b4 -Mlocal::lib=/c/Users/{username}/Projects/stow/.tmp/perllib/msys_mingw64_nt_10_0_19043/5.14.4.763351b4 -MCPAN -e "CPAN::Shell->notest('install', 'local::lib')"
```
