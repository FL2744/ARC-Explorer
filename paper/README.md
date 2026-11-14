# ARC Explorer technical report

**Technical paper:** [PDF](ARC-Explorer.pdf) · [LaTeX](ARC-Explorer.tex) · [Markdown](TECHNICAL_PAPER.md) · [BibTeX references](references.bib) · [Screenshot illustrations](figures/)

William Taggart, Modern and Classical Languages and Literatures, Virginia Tech. Email: wtaggart@vt.edu.

Build from the repository root:

```sh
python3 scripts/render_paper.py
tectonic paper/ARC-Explorer.tex
```

Alternatively, use a current TeX installation with `acmart`, `graphicx`, `xurl`, `placeins`, and BibTeX; run LaTeX, BibTeX, then LaTeX twice from this directory. The Markdown file is the prose source. The generator preserves its sections, citations, and figures in the LaTeX version.
