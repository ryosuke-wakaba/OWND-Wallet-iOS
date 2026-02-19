# OID4VCI v1 Credential Response Format Fix

## Overview

Update the wallet to support the OpenID4VCI v1 credential response format.

## Issue

The credential endpoint now returns responses in the OpenID4VCI v1 format, which uses `credentials` (plural) as an array of objects instead of `credential` (singular) as a string.

### Old format (pre-v1):
```json
{"credential":"eyJ0eXAiOiJkYytzZC..." }
```

### New format (OID4VCI v1):
```json
{ "credentials" : [ {"credential":"eyJ0eXAiOiJkYytzZC..."} ] }
```

## Changes Required

### 1. VCIClient.swift

- Add `CredentialItem` struct for array elements
- Add `credentials` field to `CredentialResponse`
- Add computed property `credentialString` for backward compatibility

### 2. CredentialStorageService.swift

- Update to use `credentialResponse.credentialString`

### 3. CredentialRequestService.swift

- Update to use `credentialResponse.credentialString`

### 4. Tests

- Update existing tests
- Add tests for new format

## Status

- [x] Create branch
- [x] Create work document
- [x] Update CredentialResponse struct
- [x] Update CredentialStorageService
- [x] Update CredentialRequestService
- [x] Update tests
- [x] Build and test

## Changes Made

### VCIClient.swift
- Added `CredentialItem` struct for array elements in v1 format
- Added `credentials: [CredentialItem]?` field to `CredentialResponse`
- Added `credentialString` computed property that returns credential from either format (v1 preferred)

### CredentialStorageService.swift
- Changed `credentialResponse.credential` to `credentialResponse.credentialString`

### CredentialRequestService.swift
- Changed `credentialResponse.credential` to `credentialResponse.credentialString`

### Tests
- Updated `credential_response_mock.json` to use v1 format
- Added 3 new tests:
  - `testDecodeV1CredentialsArray` - tests v1 format parsing
  - `testCredentialStringFallbackToLegacy` - tests fallback to legacy format
  - `testV1TakesPrecedenceOverLegacy` - tests precedence when both formats present
- Fixed test mock responses to include Content-Type headers
