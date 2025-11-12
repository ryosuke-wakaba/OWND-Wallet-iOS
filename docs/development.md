# Development Guide

## Setup

### Prerequisites

- macOS 13.0+
- Xcode 15.0+
- iOS 17.2+ SDK
- Git

### Getting Started

```bash
# Clone repository
git clone https://github.com/OWND-Project/OWND-Wallet-iOS.git
cd OWND-Wallet-iOS

# Open in Xcode
open tw2023_wallet.xcodeproj

# Build and Run
# Select target device → ⌘ + R
```

### Dependencies

Swift Package Manager が依存関係を自動解決します。

手動更新:
```
File > Packages > Update to Latest Package Versions
```

主要ライブラリ（`tw2023_wallet.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`参照）:
- JOSESwift (JWT/JWS/JWE)
- swift-crypto (暗号化)
- SwiftyJSON (JSON処理)
- web3swift (Web3連携)
- CryptoSwift (暗号化)
- swift-protobuf (Protocol Buffers)

## Coding Standards

### Swift Style Guide

[Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)に準拠。

### Naming Conventions

```swift
// ✅ Good
struct CredentialOffer { }           // PascalCase for types
func parseCredentialOffer() { }      // camelCase for functions
var credentialList: [Credential]     // camelCase for variables
let maxRetryCount = 3                // camelCase for constants

// ❌ Bad
struct credential_offer { }
func ParseCredentialOffer() { }
let MAX_RETRY_COUNT = 3
```

### Code Organization

```swift
// 1. Imports
import SwiftUI
import Combine

// 2. Type Definition
struct CredentialListView: View {
    // 3. Properties
    @State private var credentials: [Credential] = []

    // 4. Computed Properties
    var body: some View { }

    // 5. Methods
    private func fetchCredentials() async { }
}

// 6. Extensions
extension CredentialListView { }
```

### SwiftUI Best Practices

```swift
// ✅ Good: Small, focused views
struct CredentialCard: View {
    let credential: Credential

    var body: some View {
        VStack {
            CredentialHeader(credential: credential)
            CredentialBody(credential: credential)
        }
    }
}

// ✅ Good: Proper state management (iOS 17+)
@Observable
class CredentialViewModel {
    var isLoading = false
    var credentials: [Credential] = []
}

// 使用例
struct CredentialListView: View {
    @State private var viewModel = CredentialViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List(viewModel.credentials) { credential in
            CredentialRow(credential: credential)
        }
    }
}
```

### Async/Await

```swift
// ✅ Good: Use async/await
func fetchCredentials() async throws -> [Credential] {
    let data = try await networkClient.fetch(endpoint)
    return try decode(data)
}

// ❌ Bad: Avoid completion handlers in new code
func fetchCredentials(completion: @escaping (Result<[Credential], Error>) -> Void) {
    // ...
}
```

### Error Handling

```swift
// ✅ Good: Specific error types
enum CredentialError: Error {
    case invalidFormat(String)
    case networkError(Error)
}

// ✅ Good: Proper error propagation
func parseOffer(_ offer: String) throws -> CredentialOffer {
    guard !offer.isEmpty else {
        throw CredentialError.invalidFormat("Empty offer")
    }
    // ...
}

// ❌ Bad: Ignoring errors
try? riskyOperation()
```

### Security Practices

```swift
// ✅ Good: No hardcoded secrets
let apiKey = ProcessInfo.processInfo.environment["API_KEY"]

// ✅ Good: Safe logging
logger.debug("Generated key with tag: \(keyTag)")

// ❌ Bad: Logging sensitive data
logger.debug("Private key: \(privateKey)")  // Never!
```

### Code Formatting

プロジェクトルートの `.swift-format` 設定を使用:

```bash
# Install
brew install swift-format

# Format
swift-format format -i -r tw2023_wallet/
```

設定:
- インデント: 4スペース
- 行長: 100文字

## Testing Strategy

### Testing Pyramid

```
      ┌─────────┐
      │UI Tests │  (Few)
      ├─────────┤
      │Integration│ (Some)
      ├─────────┤
      │Unit Tests│ (Many)
      └─────────┘
```

### Unit Tests

**対象**: Service層、Data層、ユーティリティ

```swift
class CredentialDataManagerTests: XCTestCase {
    var inMemoryContainer: NSPersistentContainer!
    var manager: CredentialDataManager!

    override func setUp() {
        super.setUp()

        // In-memory CoreData setup
        inMemoryContainer = NSPersistentContainer(name: "DataModel")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        inMemoryContainer.persistentStoreDescriptions = [description]

        inMemoryContainer.loadPersistentStores { _, error in
            XCTAssertNil(error)
        }

        manager = CredentialDataManager(container: inMemoryContainer)
    }

    func testSaveAndFetchCredential() throws {
        // Arrange
        var testCredentialData = Datastore_CredentialData()
        testCredentialData.id = "test-id"
        testCredentialData.format = "jwt_vc_json"
        testCredentialData.credential = "test-credential"

        // Act
        manager.saveCredential(credentialData: testCredentialData)
        let fetched = manager.getCredential(id: "test-id")

        // Assert
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.id, "test-id")
    }
}
```

**Mock Objects**:
```swift
class MockNetworkClient: NetworkClient {
    var mockResponse: Data?
    var mockError: Error?

    func fetch(_ url: URL) async throws -> Data {
        if let error = mockError { throw error }
        return mockResponse ?? Data()
    }
}
```

### Integration Tests

**対象**: End-to-endフロー、複数レイヤー連携

```swift
class CredentialIssuanceIntegrationTests: XCTestCase {
    func testCompleteIssuanceFlow() async throws {
        let testIssuer = TestIssuer()
        try await testIssuer.start()

        let service = OID4VCIService()
        let credential = try await service.issueCredential(from: testIssuer.offer)

        XCTAssertNotNil(credential)
        try await testIssuer.stop()
    }
}
```

### UI Tests

**対象**: ユーザーフロー、ナビゲーション

```swift
class CredentialListUITests: XCTestCase {
    func testCredentialListDisplay() {
        let app = XCUIApplication()
        app.launch()

        app.tabBars.buttons["Credentials"].tap()
        let credentialList = app.collectionViews["CredentialList"]
        XCTAssertTrue(credentialList.exists)
    }
}
```

### Running Tests

```bash
# All tests
xcodebuild test -scheme tw2023_wallet

# Unit tests only
⌘ + U in Xcode

# Specific test
xcodebuild test -scheme tw2023_wallet -only-testing:CredentialDataManagerTests
```

### Code Coverage

**目標**: 70%以上、理想は80%+

```bash
xcodebuild test -scheme tw2023_wallet -enableCodeCoverage YES
```

Xcodeで確認: `Product > Test > Show Code Coverage`

## Workflow

### Git Flow

ブランチ戦略:
- **main**: 本番環境
- **develop**: 開発環境
- **feature/\***: 新機能
- **bugfix/\***: バグ修正
- **hotfix/\***: 緊急修正

### Feature Development

```bash
# 1. Create feature branch
git checkout develop
git pull origin develop
git checkout -b feature/credential-search

# 2. Documentation First (推奨)
# - docs/features/credential-search.md を作成/更新
# - 関連architectureドキュメント更新

# 3. Implementation
# コード実装

# 4. Format & Test
swift-format format -i -r tw2023_wallet/
xcodebuild test -scheme tw2023_wallet

# 5. Commit
git add .
git commit -m "feat: Add credential search functionality

- Implement full-text search
- Add search UI
- Update tests

Refs #123"

# 6. Push & Create PR
git push origin feature/credential-search
# GitHub上でPR作成 (base: develop)
```

### Commit Message Format

**推奨フォーマット** (Conventional Commits):

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types**:
- `feat`: 新機能
- `fix`: バグ修正
- `docs`: ドキュメントのみ
- `style`: コードスタイル
- `refactor`: リファクタリング
- `test`: テスト追加
- `chore`: ビルド/ツール変更

**例**:
```
feat(credential): Add search functionality

Implement full-text search for credentials using
SQLite FTS5.

Closes #123
```

**注**: 現在のプロジェクトでは厳密には適用されていませんが、新規コミットでは可能な限りこのフォーマットを使用することを推奨します。

### Pull Request

**PR作成時**:
- Base: `develop`
- Title: 明確な説明
- Description: 変更内容、テスト方法、スクリーンショット
- Reviewers: チームメンバー指定

**レビュー観点**:
- [ ] コーディング規約準拠
- [ ] テストカバレッジ
- [ ] ドキュメント更新
- [ ] セキュリティ考慮
- [ ] パフォーマンス

### Release Process

```bash
# 1. Create release branch
git checkout develop
git checkout -b release/1.2.0

# 2. Version bump (Info.plist等の更新)
# 必要に応じてCHANGELOGを更新

# 3. Testing
xcodebuild test -scheme tw2023_wallet

# 4. Merge to main
git checkout main
git merge --no-ff release/1.2.0
git tag -a v1.2.0 -m "Version 1.2.0"
git push origin main --tags

# 5. Back-merge to develop
git checkout develop
git merge --no-ff main
git push origin develop
```

### Documentation-First Workflow

新機能実装時の推奨フロー:

1. **設計**: `docs/features/` に仕様作成（Draft）
2. **レビュー**: チームレビュー（Review → Approved）
3. **実装**: コード実装（Implemented）
4. **検証**: テスト完了（Verified）

各ドキュメントのStatusフィールドで進捗管理。

## Troubleshooting

### Build Errors

```bash
# Clean build
⌘ + Shift + K

# Delete derived data
rm -rf ~/Library/Developer/Xcode/DerivedData

# Reset package caches
File > Packages > Reset Package Caches
```

### Simulator Issues

```bash
# Reset all simulators
xcrun simctl erase all

# List simulators
xcrun simctl list devices
```

### Common Issues

**Issue**: "Cannot find type 'X' in scope"
**Solution**: File > Packages > Resolve Package Versions

**Issue**: SwiftUI preview not working
**Solution**: ⌘ + Option + P (refresh preview)

## References

- [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [XCTest Documentation](https://developer.apple.com/documentation/xctest)
- [Git-Flow](https://nvie.com/posts/a-successful-git-branching-model/)
