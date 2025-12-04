# Atomic Design Planning References

## Foundational Reading

- **Atomic Design** by Brad Frost (https://atomicdesign.bradfrost.com/) - The definitive guide
- **Design Systems** by Alla Kholmatova - Building component libraries
- **Refactoring UI** by Adam Wathan & Steve Schoger - Practical patterns

## Brad Frost's Chemistry Metaphor

```
Atoms     → Hydrogen, Oxygen        → Basic UI elements (Button, Input)
Molecules → H₂O                     → Simple compounds (FormField)
Organisms → Cells                   → Complex structures (LoginForm)
Templates → Organ systems           → Page layouts
Pages     → Complete organisms      → Templates with data
```

## Related Plugin Commands

| Command/Agent | Purpose |
|---------------|---------|
| `jira-mvp-story-creator` | Identifies existing components during investigation |
| `execute-issue-jira` | Implements components following atomic patterns |

## Component Checklist

Before creating any new component:

```
□ Searched atoms/ directory for similar component
□ Searched molecules/ directory for similar component
□ Searched organisms/ directory for similar component
□ Confirmed no existing component can be extended
□ Determined correct level (atom/molecule/organism)
□ Will be reused in 2+ places
□ Named following project conventions
```

## Directory Structure Convention

```
src/
├── components/
│   ├── atoms/
│   │   └── Button/, Input/, Icon/
│   ├── molecules/
│   │   └── SearchInput/, FormField/
│   ├── organisms/
│   │   └── Header/, LoginForm/
│   └── templates/
│       └── DashboardLayout/
└── pages/
```
