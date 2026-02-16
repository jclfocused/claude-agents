# Mermaid Diagram Templates

Templates for common diagram types used in Linear issues.

## Parent Issue: High-Level Flow (REQUIRED)

Every parent issue MUST include a high-level flow diagram.

### User Journey Flow

```mermaid
flowchart TD
    A[User Action] --> B{Decision Point}
    B -->|Option 1| C[Outcome 1]
    B -->|Option 2| D[Outcome 2]
    C --> E[End State]
    D --> E
```

### Feature Flow Example

```mermaid
flowchart TD
    Start[User Opens App] --> Auth{Authenticated?}
    Auth -->|No| Login[Show Login]
    Auth -->|Yes| Dashboard[Show Dashboard]
    Login --> Validate{Valid Credentials?}
    Validate -->|Yes| Dashboard
    Validate -->|No| Error[Show Error]
    Error --> Login
    Dashboard --> End[User Interacts]
```

### Data Flow Example

```mermaid
flowchart TD
    Input[User Input] --> Validate[Validation Layer]
    Validate --> API[API Endpoint]
    API --> Service[Business Logic]
    Service --> DB[(Database)]
    DB --> Service
    Service --> API
    API --> Response[Response to User]
```

## Sub-Issue: API Interactions

For sub-issues involving API calls or service interactions.

### Sequence Diagram

```mermaid
sequenceDiagram
    participant U as User
    participant F as Frontend
    participant A as API
    participant D as Database

    U->>F: Click Submit
    F->>A: POST /api/resource
    A->>D: INSERT query
    D-->>A: Success
    A-->>F: 201 Created
    F-->>U: Show Success
```

### With Error Handling

```mermaid
sequenceDiagram
    participant U as User
    participant F as Frontend
    participant A as API
    participant D as Database

    U->>F: Submit Form
    F->>A: POST /api/resource
    A->>D: INSERT query
    alt Success
        D-->>A: OK
        A-->>F: 201 Created
        F-->>U: Success Message
    else Validation Error
        A-->>F: 400 Bad Request
        F-->>U: Show Errors
    else Server Error
        D-->>A: Error
        A-->>F: 500 Error
        F-->>U: Try Again Message
    end
```

## Sub-Issue: State Workflows

For issues involving status or state changes.

### State Diagram

```mermaid
stateDiagram-v2
    [*] --> Draft
    Draft --> Pending: Submit
    Pending --> Approved: Approve
    Pending --> Rejected: Reject
    Rejected --> Draft: Revise
    Approved --> Published: Publish
    Published --> Archived: Archive
    Archived --> [*]
```

### Issue Status Flow

```mermaid
stateDiagram-v2
    [*] --> Todo
    Todo --> InProgress: Start Work
    InProgress --> InReview: Create PR
    InReview --> Done: Merge PR
    InReview --> InProgress: Request Changes
    InProgress --> Todo: Pause Work
    Todo --> Canceled: Abandon
    InProgress --> Canceled: Abandon
```

## Sub-Issue: Data Models

For issues involving database schema or entity relationships.

### Entity Relationship Diagram

```mermaid
erDiagram
    USER ||--o{ ORDER : places
    USER {
        uuid id PK
        string email
        string name
        timestamp created_at
    }
    ORDER ||--|{ ORDER_ITEM : contains
    ORDER {
        uuid id PK
        uuid user_id FK
        decimal total
        string status
    }
    ORDER_ITEM {
        uuid id PK
        uuid order_id FK
        uuid product_id FK
        int quantity
    }
    PRODUCT ||--o{ ORDER_ITEM : "ordered in"
    PRODUCT {
        uuid id PK
        string name
        decimal price
    }
```

### Simple Schema

```mermaid
erDiagram
    PROFILES ||--o{ EXERCISES : creates
    PROFILES {
        uuid id PK
        string role
        string name
    }
    EXERCISES {
        uuid id PK
        uuid trainer_id FK
        string name
        text description
    }
```

## Sub-Issue: Component Hierarchy

For UI-related issues.

### Component Tree (Left to Right)

```mermaid
flowchart LR
    App --> Layout
    Layout --> Header
    Layout --> Main
    Layout --> Footer
    Main --> Sidebar
    Main --> Content
    Content --> List
    Content --> Detail
```

### Atomic Design Structure

```mermaid
flowchart TD
    subgraph Organisms
        O1[UserCard]
        O2[NavigationBar]
    end
    subgraph Molecules
        M1[Avatar + Name]
        M2[NavItem + Icon]
    end
    subgraph Atoms
        A1[Avatar]
        A2[Text]
        A3[Icon]
        A4[Button]
    end
    O1 --> M1
    M1 --> A1
    M1 --> A2
    O2 --> M2
    M2 --> A3
    M2 --> A4
```

## Bug Issues: Expected vs Actual

For bug reports, show the difference between expected and actual behavior.

### Side-by-Side Comparison

```mermaid
flowchart LR
    subgraph Actual["Actual (BUG)"]
        A1[User Submits] --> A2[Validation]
        A2 --> A3[Silent Failure]
    end

    subgraph Expected["Expected"]
        E1[User Submits] --> E2[Validation]
        E2 --> E3[Success Message]
    end
```

### With Error Path

```mermaid
flowchart TD
    subgraph Expected
        E1[Click Button] --> E2[API Call]
        E2 --> E3[Show Result]
    end

    subgraph Actual["Actual - BUG"]
        A1[Click Button] --> A2[API Call]
        A2 --> A3[Error 500]
        A3 --> A4[No User Feedback]
    end
```

## Quick Reference

| Use Case | Diagram Type | Key Syntax |
|----------|--------------|------------|
| User flows | `flowchart TD` | `A --> B`, `A -->|label| B` |
| API calls | `sequenceDiagram` | `A->>B: message`, `B-->>A: response` |
| States | `stateDiagram-v2` | `State1 --> State2: action` |
| Data models | `erDiagram` | `TABLE1 ||--o{ TABLE2 : relation` |
| Components | `flowchart LR` | Left-to-right hierarchy |

## Tips

1. **Keep it simple** - Diagrams should clarify, not complicate
2. **Label edges** - Use `-->|label|` to explain transitions
3. **Use subgraphs** - Group related items with `subgraph Name ... end`
4. **Direction matters** - `TD` (top-down) for flows, `LR` (left-right) for hierarchies
5. **Test rendering** - Linear renders Mermaid natively, but preview in VS Code first
