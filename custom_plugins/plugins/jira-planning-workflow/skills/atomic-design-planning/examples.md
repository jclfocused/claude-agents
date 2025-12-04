# Atomic Design Planning Examples

## Example: Building a Comment Feature

### Analysis
```
Existing atoms to REUSE (don't recreate!):
├── Avatar        → Use with size="sm" prop
├── Button        → Use with variant="primary" prop
├── TextArea      → Use with placeholder prop
└── Timestamp     → Use with relative={true} prop

New molecule to CREATE:
└── CommentInput
    ├── Uses: Avatar + TextArea + Button
    └── Props: onSubmit, placeholder, user

New organism to CREATE:
└── CommentThread
    ├── Uses: CommentInput + list of Comment molecules
    └── Props: comments[], onAddComment, currentUser

DO NOT CREATE (anti-patterns):
├── CommentAvatar     → Just use Avatar with props!
├── CommentButton     → Just use Button with props!
└── CommentTimestamp  → Just use Timestamp with props!
```

---

## Anti-Pattern Examples

### Anti-Pattern 1: Feature-Specific Atoms
```
❌ WRONG:
atoms/
├── UserProfileButton.tsx    → This is an organism!
├── ShoppingCartIcon.tsx     → Just use Icon with name prop

✓ CORRECT:
atoms/
├── Button.tsx               → Generic, with variants
├── Icon.tsx                 → Generic, with name prop
```

### Anti-Pattern 2: Skipping Molecule Level
```
❌ WRONG:
organisms/LoginForm.tsx
└── Directly uses: Label, Input, Button atoms

✓ CORRECT:
molecules/FormField.tsx
└── Uses: Label + Input + ErrorMessage atoms

organisms/LoginForm.tsx
└── Uses: FormField molecules + Button atom
```

---

## Decision Flowchart

```
Does this component exist already?
├── YES → Use it with props
└── NO ↓

Is it a basic HTML wrapper with styling?
├── YES → It's an ATOM
└── NO ↓

Does it combine 2-4 atoms with simple logic?
├── YES → It's a MOLECULE
└── NO ↓

Is it a complete, distinct UI section?
├── YES → It's an ORGANISM
└── NO → Probably a PAGE or TEMPLATE
```
