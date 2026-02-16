---
name: curl-api
description: Make HTTP API requests with curl. Use when calling REST APIs, making HTTP requests, testing endpoints, or working with web services via curl.
---

# curl API Requests

## Overview

Guidelines for making curl requests that work reliably in Claude Code's shell environment.

## Critical Rules

**NEVER use backslash line continuations (`\`)** - They don't work reliably in this environment.

**ALWAYS write single-line commands** or use shell variables for complex requests.

## Patterns

### Simple GET

```bash
curl -s https://api.example.com/endpoint | jq
```

### GET with Auth Header

```bash
curl -s -H "Authorization: Bearer $TOKEN" https://api.example.com/endpoint | jq
```

### POST with Form Data

Use multiple `-d` flags on a single line:

```bash
curl -s -X POST https://api.example.com/endpoint -H "Authorization: Bearer $TOKEN" -d "name=value" -d "other=data" | jq
```

### POST with JSON Body

```bash
curl -s -X POST https://api.example.com/endpoint -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{"key":"value"}' | jq
```

### Using Variables for Readability

When commands get long, use variables:

```bash
TOKEN="your_api_key_here"
BASE="https://api.example.com"

# Then use them
curl -s -X POST "$BASE/products" -H "Authorization: Bearer $TOKEN" -d "name=Test" | jq
```

### Chaining Requests

Store IDs from responses:

```bash
TOKEN="your_key"

# Create and capture ID
PRODUCT_ID=$(curl -s -X POST https://api.stripe.com/v1/products -H "Authorization: Bearer $TOKEN" -d "name=My Product" | jq -r '.id')
echo "Created: $PRODUCT_ID"

# Use ID in next request
curl -s -X POST https://api.stripe.com/v1/prices -H "Authorization: Bearer $TOKEN" -d "product=$PRODUCT_ID" -d "unit_amount=999" -d "currency=usd" | jq
```

## Common Headers

| Purpose | Flag |
|---------|------|
| Bearer Auth | `-H "Authorization: Bearer $TOKEN"` |
| Basic Auth | `-u "user:pass"` or `-u "$KEY:"` (colon for password-less) |
| JSON Content | `-H "Content-Type: application/json"` |
| Accept JSON | `-H "Accept: application/json"` |

## Useful Flags

| Flag | Purpose |
|------|---------|
| `-s` | Silent mode (no progress) |
| `-X POST` | HTTP method |
| `-d "k=v"` | Form data (multiple allowed) |
| `-H "..."` | Header (multiple allowed) |
| `-o file` | Output to file |
| `-w '%{http_code}'` | Print status code |

## Anti-Patterns (Don't Do This)

```bash
# BAD - Line continuations break
curl -s \
  -X POST \
  -H "Auth: Bearer $TOKEN" \
  https://api.example.com

# GOOD - Single line
curl -s -X POST -H "Auth: Bearer $TOKEN" https://api.example.com
```

## Stripe API Example

```bash
SK="sk_test_your_key"

# Create product
PROD=$(curl -s -X POST https://api.stripe.com/v1/products -H "Authorization: Bearer $SK" -d "name=My Product" -d "description=A great product" | jq -r '.id')

# Create price for product
PRICE=$(curl -s -X POST https://api.stripe.com/v1/prices -H "Authorization: Bearer $SK" -d "product=$PROD" -d "unit_amount=999" -d "currency=eur" -d "recurring[interval]=month" | jq -r '.id')

echo "Product: $PROD, Price: $PRICE"
```
