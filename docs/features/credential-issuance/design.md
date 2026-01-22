# Credential Issuance - Design

## UI/UX Design

### Screens

1. **QR Scanner Screen**
   - カメラビュー
   - スキャンガイド
   - キャンセルボタン

2. **Issuer Information Screen**
   - Issuer名
   - Issuerロゴ
   - Credential種類
   - 発行されるデータの説明
   - Accept/Declineボタン

3. **Processing Screen**
   - ローディングインジケーター
   - 現在の処理ステップ表示
   - キャンセルボタン

4. **Success Screen**
   - 成功メッセージ
   - 発行されたCredentialのプレビュー
   - "View Credential" ボタン
   - "Done" ボタン

5. **Error Screen**
   - エラーメッセージ
   - 詳細（開発者向け）
   - Retryボタン
   - Closeボタン

## Class Diagram

```mermaid
classDiagram
    namespace ViewLayer {
        class CredentialOfferViewModel {
            <<ViewModel>>
        }
    }

    namespace ServiceLayer {
        class CredentialIssuanceService {
            <<Facade>>
            +issueCredential()
        }
        class TokenIssuanceService {
            +issueToken()
            +fetchNonce()
        }
        class ProofGenerationService {
            +generateProof()
        }
        class CredentialRequestService {
            +requestCredential()
        }
        class CredentialStorageService {
            +saveCredential()
        }
    }

    namespace VCILayer {
        class VCIClient {
            +issueToken()
            +fetchNonce()
            +issueCredential()
        }
        class DPoPService {
            <<enum>>
            +createProof()
            +createProofWithAccessToken()
        }
        class WalletAttestationService {
            <<Singleton>>
            +getClientAttestation()
            +generateClientAttestationPoP()
        }
    }

    namespace DataLayer {
        class CredentialDataManager
        class PreferencesDataStore {
            <<Singleton>>
            +getUseDPoP()
            +getUseClientAttestation()
        }
    }

    %% View -> Service
    CredentialOfferViewModel --> CredentialIssuanceService : uses
    CredentialOfferViewModel --> PreferencesDataStore : reads settings

    %% Facade Dependencies
    CredentialIssuanceService --> TokenIssuanceService
    CredentialIssuanceService --> ProofGenerationService
    CredentialIssuanceService --> CredentialRequestService
    CredentialIssuanceService --> CredentialStorageService
    CredentialIssuanceService --> VCIClient : creates

    %% Service -> VCI Layer
    TokenIssuanceService --> VCIClient
    TokenIssuanceService --> DPoPService
    CredentialRequestService --> VCIClient
    CredentialRequestService --> DPoPService
    VCIClient --> WalletAttestationService : optional

    %% Data Layer
    CredentialStorageService --> CredentialDataManager
    WalletAttestationService --> PreferencesDataStore
```

## Layer Architecture

| レイヤー | 責務 |
|---------|------|
| View Layer | UI表示、ユーザー操作処理 |
| Service Layer (Facade) | 発行フロー全体のオーケストレーション |
| Service Layer (Individual) | 個別機能（トークン発行、Proof生成、リクエスト、保存） |
| VCI Layer | OID4VCI プロトコル通信、DPoP Proof生成、Client Attestation |
| Data Layer | CoreDataへの永続化、UserDefaultsへの設定保存 |

## Settings

設定画面から以下のオプションを制御可能：

| 設定 | 説明 | デフォルト |
|------|------|-----------|
| Use DPoP | DPoP (RFC 9449) によるSender-Constrained Token | ON |
| Use Client Authentication | OAuth 2.0 Attestation-Based Client Authentication | OFF |
| Require Server Authentication | 署名付きメタデータを要求 | OFF |
| Use Trust List | トラストリストによる証明書検証 | ON |

## Data Flow

**注**: 現在はPre-Authorized Code Flowのみ実装済み。Authorization Code Flowは将来対応予定。

```mermaid
graph TD
    A[Scan QR Code] --> B{Parse Offer}
    B -->|Success| C[Get Issuer Metadata]
    B -->|Error| Z[Show Error]
    C --> D[Display Issuer Info]
    D --> E{User Accept?}
    E -->|No| Y[Cancel]
    E -->|Yes| F{Flow Type?}
    F -->|Pre-Authorized| G[Exchange Pre-Auth Code]
    F -->|Authorization| H[Authorization Flow - 未実装]
    G --> I[Get Access Token]
    H -.-> I
    I --> J[Fetch Nonce + DPoP-Nonce]
    J --> K[Generate Key Pair]
    K --> L[Create KB-JWT]
    L --> M[Request Credential]
    M --> N[Validate Credential]
    N --> O[Store in CoreData]
    O --> P[Show Success]

    subgraph Token Request Options
        I --> I1{DPoP Enabled?}
        I1 -->|Yes| I2[Add DPoP Header]
        I --> I3{Client Auth Enabled?}
        I3 -->|Yes| I4[Add Attestation Headers]
    end
```

## Token Request Authentication

トークンリクエストでは、設定に応じて以下の認証方式を使用：

### DPoP (RFC 9449)
- 設定: `Use DPoP`
- HTTPヘッダー: `DPoP: <dpop-proof-jwt>`
- Sender-Constrained Tokenを実現

### Client Attestation (OAuth 2.0 Attestation-Based Client Authentication)
- 設定: `Use Client Authentication`
- HTTPヘッダー:
  - `OAuth-Client-Attestation: <client-attestation-jwt>`
  - `OAuth-Client-Attestation-PoP: <client-attestation-pop-jwt>`

#### Client Attestation JWT構造
```
Header:
  typ: oauth-client-attestation+jwt
  alg: ES256
  x5c: [certificate-chain]

Payload:
  iss: <wallet-provider-identifier>
  sub: <client-id>
  exp: <expiration>
  nbf: <not-before>
  cnf: { jwk: <wallet-public-key> }
  wallet_name: "OWND Wallet"
  wallet_link: <url>
```

#### Client Attestation PoP JWT構造
```
Header:
  typ: oauth-client-attestation-pop+jwt
  alg: ES256

Payload:
  iss: <client-id>
  aud: <authorization-server-issuer>
  jti: <unique-identifier>
  iat: <issued-at>
```

### 関連仕様
- [OID4VCI Appendix E - Wallet Attestations](https://openid.net/specs/openid-4-verifiable-credential-issuance-1_0.html#appendix-E)
- [OAuth 2.0 Attestation-Based Client Authentication](https://drafts.oauth.net/draft-ietf-oauth-attestation-based-client-auth/draft-ietf-oauth-attestation-based-client-auth.html)
- [HAIP 4.4.1 - Wallet Attestation](https://openid.net/specs/openid4vc-high-assurance-interoperability-profile-1_0-05.html#name-wallet-attestation)

## Sequence Diagram

```mermaid
sequenceDiagram
    participant U as User
    participant W as Wallet
    participant WP as Wallet Provider
    participant I as Issuer

    U->>W: Scan QR Code
    W->>I: GET /.well-known/openid-credential-issuer
    I-->>W: Credential Issuer Metadata
    W->>I: GET /.well-known/oauth-authorization-server
    I-->>W: Authorization Server Metadata

    W->>U: Display Issuer Info
    U->>W: Accept

    opt Client Attestation Enabled
        W->>WP: Request Client Attestation
        Note over W,WP: 現在はテスト目的で<br/>Wallet Provider処理を内部実装
        WP-->>W: Client Attestation JWT
        W->>W: Generate Client Attestation PoP
    end

    W->>I: POST /token
    Note over W,I: Headers: DPoP, OAuth-Client-Attestation (optional)
    I-->>W: Access Token

    W->>I: POST /nonce
    I-->>W: c_nonce, DPoP-Nonce

    W->>W: Generate KB-JWT with c_nonce
    W->>I: POST /credential (with DPoP)
    I-->>W: Credential

    W->>W: Store Credential
    W->>U: Show Success
```

## Accessibility

- VoiceOver対応
- Dynamic Type対応
- カラーコントラスト確保
- キーボードナビゲーション

## Localization

- 英語
- 日本語
- その他（将来）
