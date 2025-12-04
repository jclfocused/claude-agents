---
name: vertical-slice-planning
description: Use this skill when discussing feature breakdown, PR structure, implementation ordering, or how to decompose work. Guides thinking about vertical slices (end-to-end functionality) rather than horizontal layers (all of one layer first). Triggers on "how should we break this down?", "what order should we implement?", "how many PRs?", or decomposition discussions.
---

# Vertical Slice Planning Skill

This skill guides the decomposition of features into vertical slices - thin, end-to-end pieces of functionality that can be shipped independently.

## When to Use

Apply this skill when:
- Breaking down a feature into Subtasks
- Deciding implementation order for a feature
- Planning PR structure for a feature
- Users ask "how should we break this down?"
- Discussing what to build first
- Reviewing feature decomposition plans

## What is a Vertical Slice?

A vertical slice cuts through ALL layers of the application to deliver a thin piece of complete functionality.

```
┌─────────────────────────────────────────┐
│              HORIZONTAL LAYERS           │
├─────────────────────────────────────────┤
│  UI Layer      │ █ │     │     │        │
├────────────────┼───┼─────┼─────┼────────┤
│  API Layer     │ █ │     │     │        │
├────────────────┼───┼─────┼─────┼────────┤
│  Service Layer │ █ │     │     │        │
├────────────────┼───┼─────┼─────┼────────┤
│  Data Layer    │ █ │     │     │        │
└────────────────┴───┴─────┴─────┴────────┘
                  ↑
            Vertical Slice
         (Complete feature)
```

## Vertical vs Horizontal

### Horizontal Approach (Avoid)
Building all of one layer before moving to the next:
1. Build all database models
2. Build all API endpoints
3. Build all UI components
4. Wire everything together

**Problems:**
- Nothing works until everything is done
- Late integration issues
- Hard to show progress
- Can't ship incrementally

### Vertical Approach (Prefer)
Building thin, complete features:
1. User can view empty product list (UI → API → DB)
2. User can add a product (UI → API → DB)
3. User can edit a product (UI → API → DB)
4. User can delete a product (UI → API → DB)

**Benefits:**
- Each slice is shippable
- Continuous integration
- Visible progress
- Early feedback possible

## How to Identify Vertical Slices

### 1. Start with User Actions
What can the user DO? Each action is often a slice:
- "User can log in"
- "User can create a post"
- "User can search products"

### 2. Find the Thinnest Version
For each action, what's the minimal implementation?
- Skip validation (add later)
- Skip edge cases (add later)
- Skip optimization (add later)
- Skip beautification (add later)

### 3. Order by Dependency
Which slices enable other slices?
- "View list" before "Filter list"
- "Create item" before "Edit item"
- "Basic auth" before "OAuth"

## Slice Sizing Guidelines

### Too Big (Split It)
- Multiple user actions combined
- Takes more than 1-2 days to implement
- Requires multiple PRs to review safely
- Has many acceptance criteria

### Too Small (Combine It)
- Just infrastructure with no user value
- Just types/interfaces with no implementation
- Just tests with no production code
- Takes less than an hour

### Just Right
- One user-facing capability
- Completable in 1-2 days
- Reviewable in one PR
- 3-5 acceptance criteria

## Example Decomposition

### Feature: "Product Catalog with Search"

**Horizontal (Bad):**
1. Create Product model and migrations
2. Create ProductService with all methods
3. Create all API endpoints
4. Create ProductList, ProductCard, SearchBar components
5. Wire everything together

**Vertical (Good):**
1. **SLICE 1**: Display hardcoded product list
   - ProductList component with mock data
   - Proves UI structure works

2. **SLICE 2**: Display products from API
   - GET /products endpoint
   - Product model (minimal fields)
   - Connect UI to real data

3. **SLICE 3**: Basic text search
   - Search input in UI
   - Query param on API
   - Filter in service layer

4. **SLICE 4**: Category filter
   - Category dropdown
   - Category field on Product
   - Filter logic

5. **SLICE 5**: Pagination
   - Page controls in UI
   - Limit/offset on API
   - Efficient DB query

## Naming Convention for Jira Subtasks

Since Jira Subtasks are flat (no nesting), use prefixes:
```
SLICE 1: Basic product list display
SLICE 1.1: Add product image support
SLICE 1.2: Add product pricing display
SLICE 2: Product search functionality
SLICE 2.1: Search result highlighting
SLICE 3: Category filtering
REFACTOR: Extract shared product utils
TEST: Integration tests for product API
```

## Questions to Guide Slicing

1. **What's the first thing a user should be able to do?**
   → That's your first slice

2. **What's the simplest version of this action?**
   → Strip away nice-to-haves

3. **What do we need to learn before building more?**
   → Build that learning into early slices

4. **What would we demo to stakeholders first?**
   → That shapes early slices

5. **If we had to ship tomorrow, what would we cut?**
   → Cut features become later slices

## Integration with Jira Workflow

When creating Jira Stories:
- Parent Story = Full feature context
- Subtasks = Vertical slices (potential PRs)

Each slice should be:
- Independently deployable
- Independently testable
- Adds user value (even if small)

Remember: **Ship working software frequently. Slices make this possible.**
