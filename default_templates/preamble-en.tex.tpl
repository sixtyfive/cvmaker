\documentclass[11pt,a4paper,sans]{moderncv}
\moderncvstyle{classic} % 'casual' (default), 'classic', 'oldstyle' and 'banking'
\moderncvcolor{orange} % 'blue' (default), 'orange', 'green', 'red', 'purple', 'grey' and 'black'
\usepackage[scale=0.85]{geometry} % Reduce document margins
%\setlength{\hintscolumnwidth}{3cm} % Uncomment to change the width of the dates column
%\setlength{\makecvtitlenamewidth}{10cm} % For the 'classic' style, uncomment to adjust the width of the space allocated to your name
\newcommand\colorhref[3][orange]{\href{#2}{\color{#1}\underline{#3}}}
\usepackage[super]{nth}
\usepackage{ragged2e}
\usepackage{pdfpages}

\newcommand{\cvplace}{VAR_OWN_CITY}
\newcommand{\cvdate}{\today}
\makeatletter
\newcommand{\signature}{\@firstname ~\@familyname}

\makeatletter
\renewcommand*{\makeletterclosing}{
  \bigskip%
  \@closing\\[0.5em]%
  \includegraphics[scale=0.1]{VAR_OWN_SIGNATURE}\\
  {\@firstname~\@familyname}%
  \ifthenelse{\isundefined{\@enclosure}}{}{%
    \\%
    \vfill%
    {\color{color2}\itshape\enclname: \@enclosure}}}
\makeatother

\firstname{VAR_OWN_FIRSTNAME}
\familyname{VAR_OWN_LASTNAME}
\title{Curriculum Vitae}
\address{VAR_OWN_STREET}{VAR_OWN_CITY, VAR_OWN_COUNTRY}
\mobile{VAR_OWN_MOBILE}
\email{VAR_OWN_EMAIL}
\photo[70pt][0.4pt]{VAR_OWN_PICTURE} % The first bracket is the picture height, the second is the thickness of the frame around the picture (0pt for no frame)
% \extrainfo{}
% \quote{}
