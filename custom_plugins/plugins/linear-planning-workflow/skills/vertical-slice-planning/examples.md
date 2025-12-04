# Vertical Slice Planning Examples

## Example 1: Product Catalog with Search

### Horizontal (Bad)
```
1. Create Product model and migrations
2. Create ProductService with all methods
3. Create all API endpoints
4. Create ProductList, ProductCard, SearchBar components
5. Wire everything together
   → Nothing works until step 5!
```

### Vertical (Good)
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

## Example 2: User Profile Feature

### Horizontal (Anti-Pattern)
```
1. Create User model with all fields
2. Create UserService with all methods
3. Create all API endpoints (GET, PUT, POST, DELETE)
4. Create ProfilePage, ProfileForm, AvatarUpload components
5. Wire everything together
   → Nothing works until step 5 is complete!
```

### Vertical (Correct)
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

## Example 3: E-commerce Checkout

### Decomposition
```
SLICE 1: View cart contents
├── Display items in cart
├── Show quantities and prices
└── Calculate total

SLICE 2: Update quantities
├── +/- buttons on each item
├── API to update cart
└── Recalculate total

SLICE 3: Remove items
├── Remove button on each item
├── API to remove from cart
└── Handle empty cart state

SLICE 4: Basic checkout (hardcoded shipping)
├── Collect shipping address
├── Hardcoded shipping cost
└── Create order in database

SLICE 5: Calculate real shipping
├── Integrate shipping provider API
├── Show shipping options
└── User selects shipping method

SLICE 6: Payment integration
├── Integrate Stripe
├── Handle payment success/failure
└── Order confirmation
```

---

## Slicing Decision Flowchart

```
START: Feature Request
│
├── Can the user DO something with this?
│   ├── YES → Good slice candidate
│   └── NO → Probably infrastructure, combine with a user-facing slice
│
├── Does it touch multiple layers?
│   ├── YES → Good vertical slice
│   └── NO → Consider if it's complete
│
├── Can it be deployed independently?
│   ├── YES → Good slice
│   └── NO → Too coupled, needs splitting differently
│
└── Does it deliver user value?
    ├── YES → Ship it!
    └── NO → Combine with something valuable
```

---

## Common Slicing Mistakes

### Mistake 1: Database First
```
❌ SLICE 1: Create all database tables
❌ SLICE 2: Create all API endpoints
❌ SLICE 3: Create all UI
```

**Fix:** Make each slice include DB + API + UI for one feature.

### Mistake 2: UI First
```
❌ SLICE 1: Build complete UI with mock data
❌ SLICE 2: Build all APIs
❌ SLICE 3: Wire them together
```

**Fix:** Each slice should have real data flowing through.

### Mistake 3: Infrastructure Slices
```
❌ SLICE 1: Set up authentication middleware
❌ SLICE 2: Set up database connection
❌ SLICE 3: Set up API framework
```

**Fix:** Infrastructure should be part of first feature slice (walking skeleton).
