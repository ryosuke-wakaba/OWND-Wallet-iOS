//
//  ProofGenerationService.swift
//  tw2023_wallet
//
//  Created by Claude on 2025/01/14.
//

import Foundation

/// Default implementation of ProofGenerationServiceProtocol
class ProofGenerationService: ProofGenerationServiceProtocol {

    private let keyAlias: String

    init(keyAlias: String = Constants.Cryptography.KEY_BINDING) {
        self.keyAlias = keyAlias
    }

    func generateProof(
        credentialConfig: CredentialConfiguration,
        credentialIssuer: String,
        nonce: String
    ) throws -> Proofs? {
        // Ensure binding key exists
        ensureKeyPairExists()

        // Determine if proofs should be included based on proof_types_supported
        guard let proofTypesSupported = credentialConfig.proofTypesSupported,
              !proofTypesSupported.isEmpty else {
            // proof_types_supported is nil or empty - no proofs required
            return nil
        }

        // proof_types_supported exists and is not empty
        let supportedTypes = Array(proofTypesSupported.keys)
        guard let jwtProofType = proofTypesSupported["jwt"] else {
            throw CredentialIssuanceError.unsupportedProofType(supportedTypes: supportedTypes)
        }

        // Generate jwt proof with supported signing algorithms
        let proofJwt = try KeyPairUtil.createProofJwt(
            keyAlias: keyAlias,
            audience: credentialIssuer,
            nonce: nonce,
            proofSigningAlgValuesSupported: jwtProofType.proofSigningAlgValuesSupported
        )

        return Proofs(jwt: [proofJwt], cwt: nil, ldpVp: nil)
    }

    // MARK: - Private Methods

    private func ensureKeyPairExists() {
        let isKeyPairExist = KeyPairUtil.isKeyPairExist(alias: keyAlias)
        if !isKeyPairExist {
            try? KeyPairUtil.generateSignVerifyKeyPair(alias: keyAlias)
        }
    }
}
