NUMJOBS = $(shell getconf _NPROCESSORS_ONLN)
# uncomment to parallel builds by default
# or set MAKEFLAGS="-j$(getconf _NPROCESSORS_ONLN)" in your shell rc
MAKEFLAGS += --jobs=$(NUMJOBS)

# define SKIP if certain *.tex or *.tikz files are not to be build directly
# but reside in the root or a figures dir
# e.g. if they are only to be included in other documents or
# are utterly broken and should not be build
#SKIP := $(wildcard bibliography.tex)

PDFLATEX_FLAGS := -shell-escape
BIBTEX_FLAGS :=
TEXINPUTS := $(CURDIR)/packages:$(CURDIR)/tumcommon:

TARGETEXTRASRC := $(wildcard $(FIGUREDIR)/*/*.tikz)
TARGETEXTRAPDF := $(TARGETEXTRASRC:.tikz=.pdf)

BIBTEXSRC := $(wildcard ./bib/*.bib)

TARGETSRC := thesis.tex
TARGETPDF := $(TARGETSRC:.tex=.pdf)

$(TARGETPDF): $(TARGETEXTRAPDF) $(DEPS) $(BUILDDIR)/$$@.d $$(DEPS_$$*) $(BIBTEXSRC)

