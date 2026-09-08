include ../tasks/shared/code/shell_functions.make

all: paper.pdf

paper.pdf: paper.tex ../lit_review/references.bib Makefile ../tasks/shared/code/shell_functions.make
	$(LATEX) -interaction=nonstopmode -halt-on-error paper.tex
	$(BIBTEX) paper
	$(LATEX) -interaction=nonstopmode -halt-on-error paper.tex
	$(LATEX) -interaction=nonstopmode -halt-on-error paper.tex