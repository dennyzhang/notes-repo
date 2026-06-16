# human-input/feedback — the human correction stream

The ongoing human steering signal: operator corrections (from 1:1 co-debug), resolved
doc-comments, and incident-owner RCAs. This is the ground-truth the eval validates the
agent against (the online signal + Ceiling-1 owner input).

Today this signal is scattered (gchat threads, Phabricator/collab-file comments,
postmortems). The evolve loop should harvest it here as structured entries so corrections
compound instead of evaporating. (Capture mechanism = TODO; see eval/README.md "Known limitations".)
