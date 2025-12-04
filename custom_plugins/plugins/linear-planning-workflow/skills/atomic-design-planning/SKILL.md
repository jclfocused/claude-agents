---
name: atomic-design-planning
description: Use this skill when discussing UI components, design systems, frontend implementation, or component architecture. Guides thinking about Atomic Design methodology - atoms, molecules, organisms - and promotes component reuse over creation. Triggers on UI/frontend discussions, "what components do we need?", "should I create a new component?", or design system questions.
---

# Atomic Design Planning Skill

This skill guides UI component architecture using Atomic Design methodology, emphasizing reuse of existing components and proper categorization of new ones.

## When to Use

Apply this skill when:
- Planning UI features or components
- Deciding whether to create new components
- Discussing frontend architecture
- Users ask "what components do we need?"
- Reviewing UI implementation plans
- Discussing design system structure

## Atomic Design Hierarchy

```
┌─────────────────────────────────────────────────────────┐
│  PAGES                                                   │
│  Complete screens composed of templates + content        │
├─────────────────────────────────────────────────────────┤
│  TEMPLATES                                               │
│  Page-level layout structures                            │
├─────────────────────────────────────────────────────────┤
│  ORGANISMS                                               │
│  Complex UI sections (Header, ProductCard, LoginForm)    │
├─────────────────────────────────────────────────────────┤
│  MOLECULES                                               │
│  Simple component groups (SearchInput, NavItem)          │
├─────────────────────────────────────────────────────────┤
│  ATOMS                                                   │
│  Basic building blocks (Button, Input, Label, Icon)      │
└─────────────────────────────────────────────────────────┘
```

## Component Categories

### Atoms
The smallest, indivisible UI elements:
- Buttons
- Input fields
- Labels
- Icons
- Typography elements
- Colors/Tokens

**Characteristics:**
- No dependencies on other components
- Highly reusable across the app
- Controlled by props only
- Often wrap native HTML elements

### Molecules
Simple combinations of atoms:
- Search input (input + button + icon)
- Form field (label + input + error message)
- Navigation item (icon + text + badge)
- Card header (avatar + title + timestamp)

**Characteristics:**
- Combine 2-4 atoms
- Single responsibility
- Reusable in multiple organisms
- May have simple internal state

### Organisms
Complex, distinct UI sections:
- Navigation header
- Product card
- Login form
- Comment thread
- Data table
- Modal dialogs

**Characteristics:**
- Combine molecules and/or atoms
- Represent a complete UI section
- May connect to data/state
- Often feature-specific

### Templates
Page-level structural layouts:
- Dashboard layout
- Auth page layout
- List/detail layout
- Admin layout

**Characteristics:**
- Define content placement
- Contain slots for organisms
- Handle responsive behavior
- Feature-agnostic

### Pages
Specific instances with real content:
- Home page
- Product detail page
- User settings page

**Characteristics:**
- Templates filled with data
- Route-specific
- May manage page-level state

## The Reuse-First Principle

### Before Creating ANY Component:

1. **Search existing atoms**
   - Is there a Button that works?
   - Can an Input be configured for this?
   - Does a similar atom exist?

2. **Search existing molecules**
   - Is there a FormField variant?
   - Can a SearchInput be adapted?
   - Does a similar molecule exist?

3. **Search existing organisms**
   - Is there a similar Card component?
   - Can an existing Form be extended?
   - Does a similar organism exist?

4. **Only then consider creating new**
   - Is this truly unique?
   - Will it be reused elsewhere?
   - Should this be an atom, molecule, or organism?

### Questions Before Creating

| Question | If Yes | If No |
|----------|--------|-------|
| Does something similar exist? | Reuse/extend it | Continue evaluation |
| Will this be used in 2+ places? | Consider making it | Inline it instead |
| Is it truly indivisible? | Make it an atom | Make it a molecule+ |
| Does it combine 2-4 atoms? | Make it a molecule | Make it an organism |
| Is it a complete UI section? | Make it an organism | Reconsider structure |

## Component Creation Guidelines

### When Creating Atoms
```typescript
// atoms/Button.tsx
- Accept standard HTML attributes
- Use design tokens for styling
- Support variants (primary, secondary, etc.)
- Support sizes (sm, md, lg)
- Be fully controlled via props
```

### When Creating Molecules
```typescript
// molecules/SearchInput.tsx
- Compose from existing atoms
- Minimal internal state
- Clear single purpose
- Props control behavior
```

### When Creating Organisms
```typescript
// organisms/ProductCard.tsx
- Compose from atoms and molecules
- May connect to application state
- Represent complete UI sections
- May have significant internal logic
```

## Directory Structure

```
src/
├── components/
│   ├── atoms/
│   │   ├── Button/
│   │   ├── Input/
│   │   └── Icon/
│   ├── molecules/
│   │   ├── SearchInput/
│   │   ├── FormField/
│   │   └── NavItem/
│   ├── organisms/
│   │   ├── Header/
│   │   ├── ProductCard/
│   │   └── LoginForm/
│   └── templates/
│       ├── DashboardLayout/
│       └── AuthLayout/
└── pages/
    ├── Home/
    └── Products/
```

## Anti-Patterns to Avoid

### Creating When Reusing Works
"I need a slightly different button" → Configure existing Button with props

### Wrong Level of Abstraction
Organism doing atom's job → Split it up
Atom that's actually a molecule → Recognize the composition

### Skipping Levels
Page directly using atoms → Add organisms for maintainability
Organism duplicating molecule → Extract the molecule

### Feature-Specific Atoms
"UserProfileButton" as an atom → This is an organism
Atoms should be feature-agnostic

## Integration with Linear Workflow

When planning UI features, create issues for:
1. **Atom issues** - New basic components needed
2. **Molecule issues** - New component combinations
3. **Organism issues** - New feature-level components
4. **Integration issues** - Connecting organisms to pages

Investigation phase should identify:
- Existing components to reuse
- Missing components to create
- Components needing extension

Remember: **Reuse existing components. Only create what's truly missing.**
