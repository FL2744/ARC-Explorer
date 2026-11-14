# ARC Explorer technical report

**Technical paper:** [PDF](ARC-Explorer.pdf) · [LaTeX](ARC-Explorer.tex) · [Markdown](TECHNICAL_PAPER.md) · [BibTeX references](references.bib) · [Screenshot illustrations](figures/)

William Taggart, Modern and Classical Languages and Literatures, Virginia Tech. Email: wtaggart@vt.edu.

This is an independent technical report in ACM manuscript style, not an ACM publication. The AI disclosure appears immediately before the references. Figures show cropped actual offline application views without pointer or hover overlays; they do not depict invented job results.

Build from the repository root:

```sh
python3 scripts/render_paper.py
tectonic paper/ARC-Explorer.tex
```

Alternatively, use a current TeX installation with `acmart`, `graphicx`, `xurl`, `placeins`, and BibTeX; run LaTeX, BibTeX, then LaTeX twice from this directory. The Markdown file is the prose source. The generator preserves its sections, citations, and figures in the LaTeX version.
