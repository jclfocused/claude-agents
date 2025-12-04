---
name: mvp-scoping
description: Use this skill when discussing features, planning work, or when users describe what they want to build. Guides MVP thinking - focusing on "what's the minimum to make this work?" rather than comprehensive solutions. Triggers on phrases like "help me think through this feature", "what should we build first?", "how should we scope this?", or any feature planning discussion.
---

# MVP Scoping Skill

This skill guides Claude to apply MVP (Minimum Viable Product) thinking during feature discussions and planning conversations.

## When to Use

Apply this skill when:
- Users describe a new feature they want to build
- Discussing scope or requirements for upcoming work
- Users ask "what should we build first?" or similar
- Planning conversations before formal issue creation
- Users seem to be over-engineering or gold-plating solutions
- Reviewing feature proposals or specifications

## Core Principles

### 1. Ruthless Prioritization
Ask: "What is the absolute minimum needed for this feature to be functional?"

- Focus on core functionality only
- Defer edge cases to future iterations
- Ship something that works, iterate later
- If in doubt, cut it out

### 2. Vertical Slices Over Horizontal Layers
Build end-to-end functionality, not isolated layers:

- **Good MVP**: "Users can create and save a basic profile"
- **Bad MVP**: "Complete user model with all fields" (no UI, no save)

### 3. The "Ship Tomorrow" Test
For each requirement, ask: "If we had to ship tomorrow, would this be essential?"

- Essential = Must have for feature to work at all
- Nice-to-have = Can be added in a follow-up
- Polish = Defer until core is proven

### 4. Explicit Deferrals
Always document what you're NOT doing:

```
## Deferred for Future Iterations
- Advanced filtering options
- Bulk operations
- Export functionality
- Admin configuration UI
```

## Guiding Questions

When scoping features, ask:
1. What's the single most important user outcome?
2. What's the simplest way to achieve that outcome?
3. What can we remove and still have something useful?
4. What assumptions can we validate with this MVP?
5. What would embarrass us if we shipped without it? (Only those are essential)

## Anti-Patterns to Avoid

### Over-Engineering
- Adding configuration for things that could be hardcoded
- Building abstraction layers "for future flexibility"
- Implementing features "while we're in there"

### Premature Optimization
- Performance tuning before measuring
- Caching before proving it's needed
- Scaling considerations for v1

### Gold-Plating
- Perfect error messages for unlikely scenarios
- Comprehensive validation for internal tools
- Beautiful UI for admin-only features

## Example Conversations

### User: "We need user authentication"
**MVP Response**: "For MVP, let's focus on email/password login with basic JWT tokens. We can defer OAuth providers, password reset, and 2FA to future iterations once we validate the core auth flow works."

### User: "Build a dashboard showing user metrics"
**MVP Response**: "What's the single most important metric users need to see? Let's ship a dashboard with just that metric first, then add others based on what users actually request."

### User: "We need a notification system"
**MVP Response**: "What's the one notification users absolutely can't miss? Let's start with just that trigger and email delivery. We can add in-app notifications, preferences, and additional triggers after validating the core flow."

## Integration with Jira Workflow

When this skill influences planning, the resulting Jira Stories should:
- Have clear, minimal acceptance criteria
- Include a "Deferred" section documenting what's out of scope
- Focus on vertical slices that could ship independently
- Subtasks should not include "nice to have" features

## References

### Foundational Reading
- **The Lean Startup** by Eric Ries - The seminal work on MVP methodology and validated learning
- **Getting Real** by 37signals (Basecamp) - Practical guide to building less and shipping faster

### Key Concepts
- **Build-Measure-Learn**: Ship something small, measure real usage, learn, iterate
- **Validated Learning**: Use MVPs to test assumptions before investing heavily
- **Pivot or Persevere**: MVP results inform whether to change direction or double down

### Related Plugin Commands
- `/planFeature` - Creates MVP-scoped Jira Stories automatically
- `jira-mvp-story-creator` agent - Enforces MVP thinking during Story creation

### The MVP Mindset in Practice

```
Feature Request: "Build a complete e-commerce platform"

Full Scope (Don't do this):
├── Product catalog with advanced filtering
├── Shopping cart with saved items
├── Multiple payment providers
├── Order management dashboard
├── Inventory management
├── Reviews and ratings
├── Wishlists
└── Recommendation engine

MVP Scope (Do this):
├── SLICE 1: Display product list from API
├── SLICE 2: Add to cart and checkout with Stripe
└── SLICE 3: Order confirmation email

Deferred: Everything else until core purchase flow is proven
```

Remember: **"Ship the minimum that works."**
