# Vertical Slice Planning Examples

## Example 1: User Profile Feature

### Horizontal (Anti-Pattern)
```
1. Create User model with all fields
2. Create UserService with all methods
3. Create all API endpoints (GET, PUT, POST, DELETE)
4. Create ProfilePage, ProfileForm, AvatarUpload components
5. Wire everything together
   → Nothing works until step 5 is complete!
```

### Vertical (Correct) - As Jira Subtasks
```
SLICE 1: View basic profile
├── GET /profile → ProfilePage (name, email display only)
└── Can ship and get feedback immediately

SLICE 2: Edit profile name
├── PUT /profile → ProfileForm (just name field)
└── Save button works, users can update names

SLICE 3: Upload avatar
├── POST /profile/avatar → AvatarUpload component
└── Users can personalize their profile

SLICE 4: Change email with verification
├── Complex flow, deferred until basic profile proven
└── Build this after validating simpler flows work
```

---

## Example 2: Product Catalog with Search

### As Jira Subtasks
```
SLICE 1: Display hardcoded product list
├── ProductList component with mock data
└── Proves UI structure works

SLICE 2: Display products from API
├── GET /products endpoint
├── Product model (minimal fields)
└── Connect UI to real data

SLICE 3: Basic text search
├── Search input in UI
├── Query param on API
└── Filter in service layer

SLICE 4: Category filter
├── Category dropdown
├── Category field on Product
└── Filter logic

SLICE 5: Pagination
├── Page controls in UI
├── Limit/offset on API
└── Efficient DB query
```

---

## Common Slicing Mistakes

### Mistake 1: Database First
```
❌ SLICE 1: Create all database tables
❌ SLICE 2: Create all API endpoints
❌ SLICE 3: Create all UI
```

**Fix:** Each Subtask includes DB + API + UI for one feature.

### Mistake 2: Infrastructure Subtasks
```
❌ SLICE 1: Set up authentication middleware
❌ SLICE 2: Set up database connection
❌ SLICE 3: Set up API framework
```

**Fix:** Infrastructure should be part of first feature Subtask.

---

## Slicing Decision Flowchart

```
START: Feature Request
│
├── Can the user DO something with this?
│   ├── YES → Good Subtask candidate
│   └── NO → Combine with a user-facing Subtask
│
├── Does it touch multiple layers?
│   ├── YES → Good vertical slice
│   └── NO → Consider if it's complete
│
└── Does it deliver user value?
    ├── YES → Create the Subtask
    └── NO → Combine with something valuable
```
