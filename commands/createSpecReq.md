# Create Specification Requirements Command

Generate a comprehensive requirements document for a specific feature based on project context and steering documents.

## Usage

```bash
/createSpecReq <spec_name> <description>
```

## Arguments

1. **spec_name** (required) - Name of the specification (e.g., "user-authentication", "payment-processing")
2. **description** (required) - Detailed description of what's being built

## Command Overview

This command generates a requirements document that:

1. Analyzes steering documents and project context
2. Defines clear user stories with acceptance criteria
3. Creates testable requirements using WHEN/THEN format
4. References existing patterns and constraints

## Process

### 1. Context Analysis

The command will:
- Read all steering documents from `.kiro/steering/`
- Analyze existing specifications in `.kiro/specs/`
- Review README.md and CLAUDE.md
- Understand domain model and user roles
- Consider previous conversation context

### 2. Requirements Generation

Creates requirements document in `.kiro/specs/[spec_name]/requirements.md`:

#### Document Structure
```markdown
# Requirements Document

## Introduction

[Feature description and context]
[Primary goal and user value]
[Relationship to existing features]

## Requirements

### Requirement 1

**User Story:** As a [role], I want [feature], so that [benefit].

#### Acceptance Criteria

1. WHEN [condition] THEN [system behavior] SHALL [specific outcome]
2. WHEN [condition] THEN [system behavior] SHALL [specific outcome]
...

### Requirement 2
...
```

### 3. Update Strategy

If requirements document already exists:
- Analyzes current requirements
- Identifies completed vs pending items
- Adds new requirements based on description
- Preserves existing acceptance criteria
- Updates introduction with new context

## Key Features

### User Story Format
Each requirement follows the standard format:
- **As a** [user role from product.md]
- **I want** [specific capability]
- **So that** [business value/benefit]

### Acceptance Criteria Rules
- Uses SHALL for mandatory requirements
- WHEN/THEN format for testability
- Specific, measurable outcomes
- No implementation details
- User-facing behavior focus

### Cross-Reference Integration
- References user roles from product.md
- Follows patterns from structure.md
- Considers tech constraints from tech.md
- Builds on existing specifications

## Example Usage

```bash
# Create requirements for user authentication
/createSpecReq user-authentication "Allow users to securely log in and manage their sessions across web and mobile platforms"

# Create requirements for incident reporting
/createSpecReq incident-reporting "Enable drivers to report vehicle incidents with photos and location data"
```

## Generated Content Examples

### Good Requirement Example
```markdown
### Requirement 1

**User Story:** As a driver, I want to report incidents with photos, so that managers can review and approve them.

#### Acceptance Criteria

1. WHEN the driver opens incident report form THEN the app SHALL display fields for description, photos, and location
2. WHEN the driver attempts to submit without photos THEN the app SHALL display validation error
3. WHEN the driver submits valid incident report THEN the system SHALL save to database and notify assigned manager
4. WHEN the incident is saved THEN the driver SHALL see confirmation with incident ID
```

### Bad Requirement Example (Avoided)
```markdown
### Requirement 1

**User Story:** Set up incident database tables

#### Acceptance Criteria
1. Create incidents table with proper schema
2. Add foreign keys and indexes
```

## Requirements Categories

Based on feature type, may include:

1. **Functional Requirements**
   - User actions and system responses
   - Data validation rules
   - Business logic constraints

2. **Interface Requirements**
   - Platform-specific needs (web/mobile)
   - Accessibility requirements
   - Responsive design needs

3. **Data Requirements**
   - Required fields and formats
   - Persistence requirements
   - Synchronization needs

4. **Integration Requirements**
   - External service dependencies
   - API requirements
   - Authentication/authorization

5. **Performance Requirements**
   - Response time constraints
   - Concurrent user support
   - Data volume handling

## Output Location

Document is created in:
```
.kiro/specs/[spec_name]/
└── requirements.md
```

## Validation Checks

The command ensures:
- All user roles referenced exist in product.md
- Requirements align with architecture in structure.md
- Technical constraints from tech.md are considered
- No duplicate requirements across specifications
- Each requirement has measurable acceptance criteria

## Related Commands

- `/createSteering` - Create or update steering documents
- `/createSpecDesign` - Create design document from requirements
- `/createSpecTask` - Create implementation tasks from design

## Notes

- Creates spec directory structure if needed
- Backs up existing requirements before updating
- Numbers requirements for easy reference
- Includes traceability for design phase
- Considers feature flag requirements from steering docs