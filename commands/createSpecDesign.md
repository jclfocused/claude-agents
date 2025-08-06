# Create Specification Design Command

Generate a comprehensive design document based on requirements and project architecture.

## Usage

```bash
/createSpecDesign <spec_name>
```

## Arguments

1. **spec_name** (required) - Name of the specification that has requirements (e.g., "user-authentication")

## Command Overview

This command generates a design document that:

1. Translates requirements into technical architecture
2. Defines component structure and data models
3. Includes visual diagrams and API specifications
4. Maintains traceability to requirements

## Process

### 1. Requirements Analysis

The command will:
- Read requirements from `.kiro/specs/[spec_name]/requirements.md`
- Analyze all steering documents
- Review existing design patterns in other specs
- Identify affected components and systems
- Map requirements to technical solutions

### 2. Design Generation

Creates design document in `.kiro/specs/[spec_name]/design.md`:

#### Document Structure
```markdown
# Design Document

## Overview

[High-level design description]
[How it fulfills the requirements]
[Integration with existing systems]

**Key Design Decisions:**
- [Decision 1 with rationale]
- [Decision 2 with rationale]

## Architecture

### High-Level Architecture

```mermaid
[Architecture diagram]
```

### Technology Stack

[Specific versions and libraries based on tech.md]

## Components and Interfaces

### [Component Name]

**Structure:**
```
[File/folder structure]
```

**Key Features:**
- [Feature list]

### API Endpoints (if applicable)

```typescript
// Endpoint definitions with types
```

## Data Models

### Database Schema

```sql
-- SQL schema definitions
```

### Generated TypeScript Types

```typescript
// Type definitions
```

## [Additional sections based on requirements]

## Error Handling

### [Error Scenario]

[How errors are handled]

## Testing Strategy

[Testing approach for each component]

## Development Workflow

### Setup Process
[Step-by-step setup]

### Daily Development
[Workflow steps]
```

### 3. Update Strategy

If design document already exists:
- Compares against current requirements
- Identifies design gaps for new requirements
- Updates affected components
- Preserves architectural decisions
- Adds new sections as needed

## Key Features

### Architecture Visualization
- Mermaid diagrams for system architecture
- Component relationship diagrams
- Data flow visualization
- Sequence diagrams for complex flows

### Technology Alignment
- References specific versions from tech.md
- Uses established patterns from structure.md
- Follows naming conventions
- Integrates with existing architecture

### Requirements Traceability
- Links each design element to requirements
- Shows how each requirement is addressed
- Identifies cross-cutting concerns
- Maps user stories to components

### Code Structure Preview
- File and folder organization
- Component hierarchies
- Import relationships
- Type definitions

## Example Usage

```bash
# Create design for existing requirements
/createSpecDesign user-authentication

# Create design for hello-world-setup
/createSpecDesign hello-world-setup
```

## Design Patterns Applied

Based on steering documents, applies patterns like:

1. **Component Organization**
   - Role-based component structure
   - Feature-based organization
   - Shared component libraries

2. **State Management**
   - Store patterns (Pinia, Redux, etc.)
   - Data flow architecture
   - Real-time synchronization

3. **API Design**
   - RESTful patterns
   - Type-safe contracts
   - Error handling standards

4. **Database Design**
   - Normalized schemas
   - Migration strategies
   - Type generation workflow

## Validation Checks

The command ensures:
- All requirements have corresponding design elements
- Technology choices align with tech.md
- File structure follows structure.md patterns
- API designs include proper typing
- Database schemas support all data requirements
- Error scenarios from requirements are addressed

## Generated Artifacts

### 1. Architecture Diagrams
- System overview
- Component relationships
- Data flow
- Integration points

### 2. API Specifications
- Endpoint definitions
- Request/response types
- Authentication flows
- Error responses

### 3. Database Schemas
- Table definitions
- Relationships
- Indexes
- Migration scripts

### 4. Type Definitions
- Database types
- API contracts
- Component props
- Store interfaces

## Output Location

Document is created in:
```
.kiro/specs/[spec_name]/
├── requirements.md (existing)
└── design.md (generated)
```

## Design Principles

Follows these principles:
- **Modularity**: Components are self-contained
- **Type Safety**: Full typing throughout
- **Testability**: Design supports testing
- **Scalability**: Architecture allows growth
- **Maintainability**: Clear separation of concerns

## Related Commands

- `/createSteering` - Create or update steering documents
- `/createSpecReq` - Create requirements document
- `/createSpecTask` - Create implementation tasks from design

## Notes

- Requires existing requirements.md file
- Generates realistic, implementable designs
- Includes latest framework features
- Considers multi-platform requirements
- Backs up existing design before updating