# Local public-name dictionaries

The original dictionary files in this directory are from Shutterstock, Inc.'s
[List of Dirty, Naughty, Obscene, and Otherwise Bad Words](https://github.com/LDNOOBW/List-of-Dirty-Naughty-Obscene-and-Otherwise-Bad-Words),
commit `5faf2ba42d7b1c0977169ec3611df25a3c08eb13`. Copyright 2012–2020
Shutterstock, Inc. They are distributed under **Creative Commons Attribution 4.0
International**; the full license is in [LICENSE.txt](LICENSE.txt).

`sources.json` records each original file's SHA-256, size and line count. These
upstream files are unmodified. No download happens when the backend runs.

The 26 included lists cover Arabic, Czech, Danish, German, English, Esperanto,
Spanish, Persian, Finnish, Filipino, French, Hindi, Hungarian, Italian, Japanese,
Kabyle, Korean, Dutch, Norwegian, Polish, Portuguese, Russian, Swedish, Thai,
Turkish and Chinese. List quality, vocabulary and script coverage vary; notably,
the upstream Russian list primarily uses transliteration. They are a starting
point for moderation, not a claim of complete language coverage.

`policy.json` is Beat my track's separately maintained policy:

- `excluded_terms` removes ambiguous ordinary words, personal names and neutral
  identity terms from dictionary matching. Examples include Dick, Fanny, Concha,
  Finnish Pipari and the English word fan. These exceptions apply to dictionary
  entries, never to an entire input; adding a prohibited word to an otherwise
  allowed name still rejects it.
- `additional_terms` supplements omissions, common disguised spellings and
  native Russian/Japanese terms.
- `embedded_roots` is a smaller reviewed set of unambiguous terms checked inside
  compound names. Other dictionary entries use word/phrase boundaries, so
  Scunthorpe, Dickinson, Cockpit and Middlesex remain valid.

`name_moderation.py` adds bounded normalization for compatibility characters,
combining/format marks, selected visual confusables, common leet substitutions,
repeated letters and split-letter spellings. Japanese/Chinese/Thai substring
matching applies only to terms containing those scripts, avoiding short Latin
abbreviations accidentally matching ordinary names.

To adjust policy, edit the JSON, increment its version, extend the offensive and
harmless name fixtures in `tests/test_name_moderation.py`, run the focused and
related backend suites, and deliver a matching backend build. Dictionary updates
must retain attribution and update source fingerprints. Policy is loaded once
at process startup. Reports and operator review remain necessary for missed abuse
and mistaken matches.
