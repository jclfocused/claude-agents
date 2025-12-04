# Vertical Slice Planning References

## Foundational Reading

- **Agile Software Development** by Alistair Cockburn - Original source for vertical slice concept
- **User Stories Applied** by Mike Cohn - INVEST criteria for story sizing
- **Continuous Delivery** by Jez Humble & David Farley - Why vertical slices enable continuous deployment

## INVEST Criteria for Good Slices

Each vertical slice should be:

| Criterion | Meaning |
|-----------|---------|
| **I**ndependent | Can be developed without other slices |
| **N**egotiable | Details can be discussed, not a contract |
| **V**aluable | Delivers value to end user |
| **E**stimable | Can reasonably estimate effort |
| **S**mall | Fits in a single sprint/iteration |
| **T**estable | Clear criteria for "done" |

## Related Plugin Commands

| Command/Agent | Purpose |
|---------------|---------|
| `/planFeature` | Creates Subtasks organized as vertical slices |
| `jira-mvp-story-creator` | Structures Subtasks with SLICE prefixes |
| `execute-issue-jira` | Implements slices one at a time |

## External Resources

- [Vertical Slices - Agile Alliance](https://www.agilealliance.org/glossary/vertical-slice/)
- [Elephant Carpaccio Exercise](https://alistair.cockburn.us/elephant-carpaccio-exercise/)
- [Walking Skeleton Pattern](https://wiki.c2.com/?WalkingSkeleton)
