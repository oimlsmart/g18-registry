# TODO.user — Decision Flow Redesign

## The user's mental model

G 18 is NOT a vocabulary — it's a REGISTRY of how terms are used across OIML publications. Each term comes FROM specific OIML Recommendations/Documents. The VIM/VIML are the AUTHORITATIVE vocabularies. The decision flow is: "Given this term as used in these publications, what should we do about its alignment with VIM/VIML?"

## Decision flow (user's 3 steps)

```
                    [Term used in OIML publications]
                              |
                    Does it cite VIM/VIML?
                     /                    \
                   YES (defined_in_vim/viml)    NO (oiml_original)
                    |                            |
              Is citation                 Resembles VIM/VIML?
              up to date?                 /              \
              /         \               YES               NO
            YES          NO              |                 |
             |            |        [Adopt similar       [Propose
        [Nothing      [Update       term from VIM/VIML   for V 3]
         to do]       citation      OR propose for V 3
                      to latest     OR update to use
                      VIM/VIML]     another term]
                    |
              Still in VIM/VIML?
              /              \
            YES               NO
             |                 |
        [Update will      [Propose for
         fix it]           V 1/V 2/V 3]
```

## Step 3: Divergent definitions

When multiple publications use different definitions for the same term, these serve as REFERENCE material to help the user make the Step 1/2 decisions. They are NOT the primary action target.

## Work items

- [ ] 01-decision-flow-svg.md — SVG decision tree component for the term action box
- [ ] 02-term-header-sourcing.md — prominently display originating documents in the page header
- [ ] 03-action-box-restructure.md — restructure the action box to follow the decision flow
- [ ] 04-concept-diff-comparison.md — use concept diff to compare G 18 def with VIM/VIML def
- [ ] 05-publication-instances-as-reference.md — reframe publication instances section as reference material
