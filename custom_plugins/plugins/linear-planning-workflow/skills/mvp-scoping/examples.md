# MVP Scoping Examples

## Conversation Examples

### Example 1: User Authentication

**User**: "We need user authentication"

**MVP Response**: "For MVP, let's focus on email/password login with basic JWT tokens. We can defer OAuth providers, password reset, and 2FA to future iterations once we validate the core auth flow works."

**Deferred**:
- OAuth providers (Google, GitHub)
- Password reset flow
- Two-factor authentication
- Session management UI
- Login history

---

### Example 2: Dashboard Metrics

**User**: "Build a dashboard showing user metrics"

**MVP Response**: "What's the single most important metric users need to see? Let's ship a dashboard with just that metric first, then add others based on what users actually request."

**Deferred**:
- Multiple chart types
- Date range filters
- Export functionality
- Customizable layouts
- Real-time updates

---

### Example 3: Notification System

**User**: "We need a notification system"

**MVP Response**: "What's the one notification users absolutely can't miss? Let's start with just that trigger and email delivery. We can add in-app notifications, preferences, and additional triggers after validating the core flow."

**Deferred**:
- In-app notifications
- Notification preferences
- Multiple channels (SMS, push)
- Notification history
- Batching/digests

---

## Visual: MVP vs Full Scope

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

---

## Scoping Decision Tree

```
Is this feature essential for the core use case to work?
├── YES → Include in MVP
└── NO → Is it a "nice to have"?
    ├── YES → Defer to future iteration
    └── NO (it's polish) → Defer until core is proven

Would users be blocked without this?
├── YES → Include in MVP
└── NO → Can we ship without it and learn?
    ├── YES → Defer and measure demand
    └── NO → Include minimal version only
```

---

## Deferral Documentation Template

When deferring features, document them clearly:

```markdown
## Deferred for Future Iterations

### Phase 2 (After MVP validation)
- [ ] Password reset flow
- [ ] OAuth integration (Google)
- [ ] Remember me functionality

### Phase 3 (Based on user feedback)
- [ ] Two-factor authentication
- [ ] Session management UI
- [ ] Login analytics

### Maybe Later (Low priority)
- [ ] Biometric authentication
- [ ] SSO integration
- [ ] Custom session timeouts
```
