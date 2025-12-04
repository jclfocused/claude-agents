---
name: vertical-slice-planning
description: Use this skill when discussing feature breakdown, PR structure, implementation ordering, or how to decompose work. Guides thinking about vertical slices (end-to-end functionality) rather than horizontal layers (all of one layer first). Triggers on "how should we break this down?", "what order should we implement?", "how many PRs?", or decomposition discussions.
---

# Vertical Slice Planning Skill

This skill guides the decomposition of features into vertical slices - thin, end-to-end pieces of functionality that can be shipped independently.

## When to Use

Apply this skill when:
- Breaking down a feature into sub-issues
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

**Problems:** Nothing works until everything is done, late integration issues, hard to show progress.

### Vertical Approach (Prefer)
Building thin, complete features:
1. User can view empty product list (UI → API → DB)
2. User can add a product (UI → API → DB)
3. User can edit a product (UI → API → DB)

**Benefits:** Each slice is shippable, continuous integration, visible progress.

## How to Identify Vertical Slices

### 1. Start with User Actions
What can the user DO? Each action is often a slice.

### 2. Find the Thinnest Version
For each action, what's the minimal implementation?
- Skip validation (add later)
- Skip edge cases (add later)
- Skip optimization (add later)

### 3. Order by Dependency
Which slices enable other slices?
- "View list" before "Filter list"
- "Create item" before "Edit item"

## Slice Sizing Guidelines

| Size | Indicators |
|------|------------|
| **Too Big** | Multiple user actions, >2 days work, many acceptance criteria |
| **Too Small** | Just infrastructure, just types, <1 hour work |
| **Just Right** | One capability, 1-2 days, 3-5 acceptance criteria |

## Naming Convention for Issues

Use prefixes to show slice relationships:
```
SLICE 1: Basic product list display
SLICE 1.1: Add product image support
SLICE 2: Product search functionality
```

## Questions to Guide Slicing

1. What's the first thing a user should be able to do? → First slice
2. What's the simplest version of this action? → Strip nice-to-haves
3. What do we need to learn before building more? → Early slices
4. If we had to ship tomorrow, what would we cut? → Later slices

## Integration with Linear Workflow

When creating Linear issues:
- Parent issue = Full feature context
- Direct sub-issues = Vertical slices (potential PRs)

Each slice should be independently deployable, testable, and valuable.

Remember: **Ship working software frequently. Slices make this possible.**
