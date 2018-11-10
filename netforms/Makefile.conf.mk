NUMJOBS = $(shell getconf _NPROCESSORS_ONLN)
# uncomment to parallel builds by default
# or set MAKEFLAGS="-j$(getconf _NPROCESSORS_ONLN)" in your shell rc
#MAKEFLAGS += --jobs=$(NUMJOBS)

# define SKIP if certain *.tex or *.tikz files are not to be build directly
# but reside in the root or a figures dir
# e.g. if they are only to be included in other documents or
# are utterly broken and should not be build
SKIP := studentdefs.tex

PDFLATEX_FLAGS := -shell-escape
BIBTEX_FLAGS :=
TEXINPUTS := $(CURDIR)/tumcommon:

## Example for jobname targets
#TEXSLIDESRC := $(filter-out $(SKIP),$(wildcard slides*.tex))
#TEXSLIDEPDF := $(TEXSLIDESRC:.tex=.pdf)
#TEXSLIDENOTEPDF := $(TEXSLIDESRC:.tex=-notes.pdf)
#
#SPECIALTEXPDF := $(TEXSLIDENOTEPDF)
#
#$(TEXSLIDENOTEPDF): %-notes.pdf: %.tex $$(DEPS_$$*) $$(FIGURESPDF_$$*) $(DEPS) $(BUILDDIR)/$$@.d
#	$(call pdfbuilder,$<,$@,notes)

## additional figure dependencies
#$(TEXSLIDEPDF): slides_%.pdf: $$(FIGURESPDF_$$*)
#$(TEXSLIDENOTEPDF): slides_%-notes.pdf: $$(FIGURESPDF_$$*)
