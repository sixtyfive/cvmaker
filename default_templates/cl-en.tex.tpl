%----------------------------------------------------------------------------------------
%	COVER LETTER
%----------------------------------------------------------------------------------------
\recipient{VAR_ADDRESSEE_FULLNAME}
          {VAR_ADDRESSEE_INSTITUTION\\VAR_ADDRESSEE_STREET\\VAR_ADDRESSEE_CITY\\VAR_ADDRESSEE_COUNTRY}
\date{\today}
\opening{Dear VAR_ADDRESSEE_TITLEANDLASTNAME,}
\closing{With kind regards,}
\enclosure[Attached]{VAR_CL_ATTACHMENTS}
\subject{VAR_CL_SUBJECT}
\makelettertitle % print letter title

\justifying % force hyphenation
VAR_CL_PARAGRAPHS

\par
\makeletterclosing
