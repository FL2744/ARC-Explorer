"""Generate ACM LaTeX from this project's deliberately simple Markdown paper."""
from pathlib import Path
import re
root=Path(__file__).resolve().parent.parent
src=(root/'paper/TECHNICAL_PAPER.md').read_text()
def tex(s):
    mapping={'\\':r'\textbackslash{}','&':r'\&','%':r'\%','$':r'\$','#':r'\#','_':r'\_','{':r'\{','}':r'\}','~':r'\textasciitilde{}','^':r'\textasciicircum{}'}
    s=''.join(mapping.get(c,c) for c in s)
    return re.sub(r'\[@([A-Za-z0-9]+)\]',lambda m:r'\cite{'+m[1]+'}',s)
abstract=src.split('## Abstract\n\n',1)[1].split('\n\n## 1.',1)[0]
body=src.split('## 1.',1)[1].split('\n## References',1)[0]
body='## 1.'+body
out=[r'''\documentclass[manuscript,screen,nonacm]{acmart}
\setcopyright{none}
\settopmatter{printacmref=false,printccs=false}
\acmDOI{}
\acmISBN{}
\usepackage{graphicx,xurl,placeins}
\setcitestyle{numbers}
\raggedbottom
\title{ARC Explorer: A Native macOS Workspace for Remote High-Performance Computing}
\subtitle{Technical report; ARC Explorer v0.1; November 13, 2026. Not an ACM publication.}
\author{William Taggart}
\affiliation{\department{Modern and Classical Languages and Literatures}\institution{Virginia Tech}\city{Blacksburg}\state{Virginia}\country{USA}}
\email{wtaggart@vt.edu}
\begin{document}
\begin{abstract}
'''+tex(abstract)+r'''
\end{abstract}
\keywords{high-performance computing, Slurm, SSH, macOS, scientific gateways, remote development}
\maketitle
''']
for block in body.strip().split('\n\n'):
    if block.startswith('## '):
        title=re.sub(r'^\d+\.\s*','',block[3:])
        out.append(r'\section{'+tex(title)+'}')
    elif block.startswith('!['):
        m=re.fullmatch(r'!\[(.*?)\]\((.*?)\)',block,re.S)
        out.append(r'\begin{figure}[htbp]'+'\n'+r'\centering'+'\n'+r'\includegraphics[width=\textwidth,height=0.62\textheight,keepaspectratio]{'+m[2]+'}\n'+r'\caption{'+tex(m[1])+'}\n'+r'\Description{'+tex(m[1])+'}\n'+r'\end{figure}')
    else: out.append(tex(block))
out.append(r'\bibliographystyle{ACM-Reference-Format}'+'\n'+r'\bibliography{references}'+'\n'+r'\end{document}')
(root/'paper/ARC-Explorer.tex').write_text('\n\n'.join(out)+'\n')
