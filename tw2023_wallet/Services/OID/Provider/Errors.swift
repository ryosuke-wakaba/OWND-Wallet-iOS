//
//  Errors.swift
//  tw2023_wallet
//
//  Created by katsuyoshi ozaki on 2024/10/01.
//

enum NetworkError: Error {
    case invalidResponse
    case statusCodeNotSuccessful(Int)
    case decodingError
    case other(Error)
}

enum OpenIdProviderRequestException: Error {
    case badAuthRequest
    // already consumed request, failed to get client additinal info(request jwt, client metada, etc), etc
    case unavailableAuthRequest
    case validateRequestJwtFailure
}

enum OpenIdProviderIllegalInputException: Error {
    case illegalClientIdInput
    case illegalJsonInputInput
    case illegalResponseTypeInput
    case illegalResponseModeInput
    case illegalNonceInput
    case illegalPresentationDefinitionInput
    case illegalRedirectUriInput
    case illegalDisclosureInput
    case illegalCredentialInput
}

enum OpenIdProviderIllegalStateException: Error {
    case illegalAuthRequestProcessedDataState
    case illegalClientIdState
    case illegalResponseModeState
    case illegalNonceState
    case illegalPresentationDefinitionState
    case illegalRedirectUriState
    case illegalKeypairState
    case illegalKeyBindingState
    case illegalJwkThumbprintState
    case illegalJsonState
    case illegalState
}
