# Architecture

## Overview

OWND Wallet iOSは、国際標準に準拠したデジタルアイデンティティウォレットであり、セキュアで相互運用可能なVerifiable Credentialsの管理を実現します。

### Design Principles

1. **標準準拠**: OpenID (OID4VCI/OID4VP/SIOPv2)、W3C Verifiable Credentials準拠
2. **セキュリティファースト**: Keychain/Secure Enclave、エンドツーエンド暗号化
3. **ユーザープライバシー**: 選択的開示、最小限の情報開示
4. **相互運用性**: 標準プロトコルの厳格な実装
5. **拡張性**: プラグイン可能なアーキテクチャ

### Technology Stack

- **Language**: Swift 5.x
- **UI Framework**: SwiftUI
- **Persistence**: CoreData + Protocol Buffers
- **Cryptography**: swift-crypto, CryptoSwift, JOSESwift
- **Key Dependencies**: JWTDecode, web3swift, SwiftyJSON

## System Architecture

### 3-Layer Architecture

```
┌─────────────────────────────────────────────────────────┐
│              Presentation Layer (SwiftUI)                │
│  Views, ViewModels, UI Components                       │
└─────────────────────────────────────────────────────────┘
                      ↓↑
┌─────────────────────────────────────────────────────────┐
│               Service Layer                              │
│  OID4VCI, OID4VP, SIOPv2, Crypto Services               │
└─────────────────────────────────────────────────────────┘
                      ↓↑
┌─────────────────────────────────────────────────────────┐
│                Data Layer                                │
│  CoreData, Protocol Buffers, Keychain, UserDefaults    │
└─────────────────────────────────────────────────────────┘
```

### Layer 1: Presentation Layer

**責務**: UI表示、ユーザー入力処理、ナビゲーション

**主要コンポーネント**:
- `tw2023_wallet/Feature/*/` - SwiftUIビュー
- Home, Credentials, IssueCredential, ShareCredential, Settings

**設計原則**:
```swift
// ✅ Good: ViewはServiceを呼び出す
struct CredentialListView: View {
    @State private var credentials: [Credential] = []
    private let dataManager = CredentialDataManager.shared

    var body: some View {
        List(credentials) { credential in
            CredentialRow(credential: credential)
        }
        .task {
            credentials = await dataManager.fetchAll()
        }
    }
}
```

### Layer 2: Service Layer

**責務**: ビジネスロジック、プロトコル実装、暗号化処理

**主要サービス**:
- **OID4VCI Service** (`tw2023_wallet/Services/OID/VCI/`): Credential発行
- **OID4VP Service** (`tw2023_wallet/Services/OID/`): Presentation提示
- **SIOPv2 Service** (`tw2023_wallet/Services/OID/Provider/`): 認証
- **Presentation Exchange** (`PresentationExchange.swift`): Input Descriptor照合
- **Crypto Service** (`tw2023_wallet/Signature/`): 暗号化・署名

**API例**:
```swift
protocol CredentialIssuanceService {
    func parseOffer(_ offer: String) async throws -> CredentialOffer
    func requestCredential(offer: CredentialOffer) async throws -> Credential
}

protocol PresentationService {
    func matchCredentials(for definition: PresentationDefinition) async throws -> [Credential]
    func generatePresentation(credentials: [Credential]) async throws -> String
}
```

### Layer 3: Data Layer

**責務**: データ永続化、セキュアストレージ

**コンポーネント**:
- **CoreData** (`tw2023_wallet/datastore/`): Credentials、履歴
- **Protocol Buffers** (`*.pb.swift`): シリアライゼーション
- **Keychain** (`Helper/KeychainManager.swift`): 秘密鍵
- **UserDefaults** (`PreferencesDataStore.swift`): アプリ設定

**データ管理**:
```swift
class CredentialDataManager {
    static let shared = CredentialDataManager()

    func save(_ credential: Credential) async throws
    func fetchAll() async throws -> [Credential]
    func delete(id: UUID) async throws
}
```

### Layer Communication Rules

**✅ 許可される依存関係**:
```
Presentation → Service → Data
```

**❌ 禁止される依存関係**:
```
Data → Service (Data層はService層を知らない)
Service → Presentation (Service層はUI層を知らない)
```

## Security Architecture

### Multi-Layer Security

```
Application Security    → App Lock, Jailbreak Detection
     ↓
Communication Security  → HTTPS, TLS 1.3
     ↓
Cryptographic Security  → ES256/ES384, AES-256-GCM
     ↓
Data Security          → Keychain, Encrypted CoreData
```

### Key Management

**鍵の種類**:
- **Signing Keys**: VP/ID Token署名用（ES256）
- **Pairwise Keys**: RP別識別子用

**Secure Enclave使用**:
```swift
let attributes: [String: Any] = [
    kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
    kSecAttrKeySizeInBits: 256,
    kSecAttrTokenID: kSecAttrTokenIDSecureEnclave,
    kSecAttrAccessControl: accessControl
]
```

**Access Control**:
```swift
let access = SecAccessControlCreateWithFlags(
    kCFAllocatorDefault,
    kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
    [.privateKeyUsage, .biometryCurrentSet],
    nil
)
```

### Data Protection

| Data Type | Storage | Encryption |
|-----------|---------|------------|
| Private Keys | Keychain/Secure Enclave | Hardware |
| Credentials | CoreData | File-level (iOS) |
| Sharing History | CoreData | File-level (iOS) |
| Preferences | UserDefaults | None |

### Authentication & Authorization

**Local Authentication**:
```swift
class AuthenticationManager: ObservableObject {
    @Published var isUnlocked = false

    func authenticate() async throws {
        let success = try await LAContext().evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "Unlock OWND Wallet"
        )
        isUnlocked = success
    }
}
```

**Session Management**:
- アプリバックグラウンド時に自動ロック
- タイムアウト設定（30秒〜5分）

### Threat Model (STRIDE)

| Threat | Mitigation | Status |
|--------|------------|--------|
| **Spoofing** | Certificate validation, Metadata verification | ✅ |
| **Tampering** | Digital signatures, Signature verification | ✅ |
| **Repudiation** | Sharing history, ID token history | ✅ |
| **Information Disclosure** | Keychain, Encrypted storage | ✅ |
| **Denial of Service** | Rate limiting, Timeouts | ⚠️ Partial |
| **Elevation of Privilege** | Jailbreak detection, Sandboxing | ✅ |

### Security Best Practices

**✅ Do**:
- Use Secure Enclave for key generation
- Require biometric authentication for sensitive operations
- Use kSecAttrAccessibleWhenUnlockedThisDeviceOnly
- Validate all inputs
- Never log sensitive data

**❌ Don't**:
- Store keys in UserDefaults
- Hard-code secrets
- Disable access control in production
- Log private keys or credentials
