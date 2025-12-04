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
| `/planFeature` | Creates issues organized as vertical slices |
| `linear-mvp-project-creator` | Structures sub-issues as potential PRs |
| `execute-issue` | Implements slices one at a time |

## External Resources

- [Vertical Slices - Agile Alliance](https://www.agilealliance.org/glossary/vertical-slice/)
- [Elephant Carpaccio Exercise](https://alistair.cockburn.us/elephant-carpaccio-exercise/)
- [Walking Skeleton Pattern](https://wiki.c2.com/?WalkingSkeleton)

## The Walking Skeleton

A walking skeleton is the thinnest possible vertical slice that:
- Touches all architectural layers
- Proves the system works end-to-end
- Can be deployed to production
- Forms the foundation for incremental growth

Build your first slice as a walking skeleton, then flesh it out.
