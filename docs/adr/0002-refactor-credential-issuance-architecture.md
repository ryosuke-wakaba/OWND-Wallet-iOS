# ADR 0002: Credential Issuance Architecture Refactoring

## Status

Proposed

## Context

現在のCredential Issuance実装（OID4VCI）は機能的には動作していますが、以下の課題があります：

### 課題1: 責務の集中

`CredentialOfferViewModel`が以下の多くの責務を持っている：
- トークン発行処理
- Nonce取得
- Proof JWT生成
- Credential要求
- データ変換（ProtoBuf）
- データ保存

これにより：
- クラスが肥大化（240行超）
- テストが困難
- 変更の影響範囲が不明確

### 課題2: 重複コード

同様のロジックが複数箇所に存在：
- JWT解析: `extractInfoFromJwt()`, `extractSDJwtInfo()`, `extractJwtVcJsonInfo()`
- メタデータデコード: `CredentialDataManager.parsedMetaData()`, ViewModel内のデコード

### 課題3: エラーハンドリングの不統一

- タイポ: `LoadDataDidNotFinishuccessfully`
- 不明確なエラーメッセージ
- ユーザーフレンドリーでない

### 課題4: テストカバレッジ不足

- `CredentialOfferViewModel`のUnit Testが存在しない
- Integration Testが不足
- Mock化が困難

### 課題5: 拡張性の欠如

今後の要件：
- Authorization Code Flow対応
- バッチCredential発行
- Deferred Credential対応

現状のアーキテクチャでは、これらの機能追加が困難。

## Decision

以下のアーキテクチャ変更を実施します：

### 1. Service層の導入（Clean Architecture / Domain-Driven Design）

ViewModelとデータ層の間にService層を導入します：

```
┌─────────────────┐
│   View          │
└────────┬────────┘
         │
┌────────▼────────┐
│   ViewModel     │ ← 簡素化（UIロジックのみ）
└────────┬────────┘
         │
┌────────▼─────────────────────────────┐
│   Service Layer (Business Logic)    │
│  ┌──────────────────────────────┐   │
│  │ CredentialIssuanceService    │   │
│  └──┬────┬────┬────┬────────────┘   │
│     │    │    │    │                │
│  ┌──▼─┐┌▼──┐┌▼──┐┌▼────────┐       │
│  │Token││Proof││Req││Storage │       │
│  │Svc  ││Svc ││Svc││Service │       │
│  └─────┘└───┘└───┘└────────┘       │
└────────┬─────────────────────────────┘
         │
┌────────▼────────┐
│   Data Layer    │
│  (VCIClient,    │
│   CoreData)     │
└─────────────────┘
```

**利点**:
- 各Serviceが単一の責務を持つ（SRP）
- テストが容易（Mock化が簡単）
- 再利用可能
- ViewModelが簡素化

### 2. Mapper/Converterパターン

データ変換ロジックを専用クラスに分離：

- `CredentialMapper`: CredentialResponse → ProtoBuf
- `JWTParser`: JWT文字列 → 構造化データ
- `SDJWTParser`: SD-JWT文字列 → 構造化データ
- `MetadataDecoder`: JSON文字列 ⇔ Metadata

**利点**:
- 変換ロジックが一箇所に集約
- 再利用可能
- テストが容易

### 3. エラーハンドリングの標準化

`CredentialIssuanceError` enumを導入し、`LocalizedError`を実装：

```swift
enum CredentialIssuanceError: Error, LocalizedError {
    case metadataLoadFailed(reason: String)
    case unsupportedProofType(supported: [String], requested: String?)
    // ...

    var errorDescription: String? { /* user-friendly message */ }
    var recoverySuggestion: String? { /* recovery suggestion */ }
}
```

**利点**:
- 一貫したエラー型
- ユーザーフレンドリーなメッセージ
- デバッグが容易

### 4. 定数の型安全な管理

`enum`を使用した定数管理：

```swift
enum CredentialFormat: String {
    case sdJwtVC = "vc+sd-jwt"
    case dcSDJWT = "dc+sd-jwt"
    case jwtVCJson = "jwt_vc_json"

    var isSDJWT: Bool { /* ... */ }
}
```

**利点**:
- タイポ防止
- コンパイル時チェック
- 補完が効く

### 5. 依存性注入（Dependency Injection）

ViewModelにServiceを注入可能にする：

```swift
class CredentialOfferViewModel {
    init(
        issuanceService: CredentialIssuanceService,
        storageService: CredentialStorageService
    ) {
        self.issuanceService = issuanceService
        self.storageService = storageService
    }
}
```

**利点**:
- テストが容易（Mock注入可能）
- 疎結合
- 実装の差し替えが容易

## Alternatives Considered

### Alternative 1: MVVMのまま最小限の改善のみ

**却下理由**:
- 根本的な課題（責務の集中）が解決されない
- 将来の拡張に対応困難

### Alternative 2: VIPERアーキテクチャへの全面移行

**却下理由**:
- 過剰に複雑
- 学習コストが高い
- 既存コードとの一貫性が失われる

### Alternative 3: Repository パターンのみ導入

**却下理由**:
- ビジネスロジックの問題が解決されない
- Service層がないと責務の分離が不十分

## Consequences

### Positive

1. **保守性向上**
   - コードの見通しが良くなる
   - バグ修正が容易になる
   - 新規開発者のオンボーディングが改善

2. **テスタビリティ向上**
   - Unit Testが書きやすくなる
   - Mock化が容易になる
   - テストカバレッジが向上

3. **拡張性向上**
   - Authorization Code Flow追加が容易
   - 新しいCredentialフォーマットへの対応が簡単
   - ビジネスロジックの再利用が可能

4. **エラーハンドリング改善**
   - ユーザーフレンドリーなメッセージ
   - デバッグが容易

5. **コード品質向上**
   - DRY原則に準拠
   - SRP準拠
   - Cyclomatic Complexityの低減

### Negative

1. **初期コスト**
   - リファクタリングに時間が必要（見積: 10週間）
   - 学習コスト（新しいパターン）

2. **一時的な複雑性増加**
   - ファイル数が増加
   - クラス間の関係が増加

3. **移行期の混乱**
   - 新旧コードの混在期間が発生
   - ドキュメント更新が必要

### Mitigation

Negativeな影響を軽減するため：

1. **段階的な移行**
   - フェーズ分けして実施
   - 各フェーズ後にテストを実行
   - 既存機能を破壊しない

2. **包括的なドキュメント**
   - アーキテクチャ図の作成
   - コードコメントの充実
   - オンボーディングガイド作成

3. **テストの充実**
   - 各フェーズでテスト作成
   - カバレッジ80%以上を維持
   - CI/CDパイプライン統合

## Implementation Plan

詳細は [Credential Issuance リファクタリング計画](../refactoring/credential-issuance-refactoring.md) を参照。

### フェーズ概要

1. **フェーズ1**: 基盤改善（2週間）
   - エラーハンドリング統一
   - 定数管理
   - 重複コード除去

2. **フェーズ2**: アーキテクチャ改善（3週間）
   - Service層導入
   - Mapper分離
   - キャンセルサポート

3. **フェーズ3**: テスト強化（3週間）
   - ViewModel Tests
   - Integration Tests
   - Service Tests

4. **フェーズ4**: ドキュメント・最適化（2週間）
   - ドキュメント追加
   - パフォーマンス最適化

## Success Metrics

以下のメトリクスで成功を測定：

| メトリクス | 現状 | 目標 |
|----------|------|------|
| Test Coverage | ~30% | 80%+ |
| ViewModel LOC | 240行 | 100行以下 |
| Cyclomatic Complexity (max) | 15+ | 10以下 |
| Public API Documentation | ~10% | 100% |
| Build Time | - | 変化なし |
| Credential Issuance Time | ~8秒 | 10秒以内（変化なし） |

## References

- [Clean Architecture by Robert C. Martin](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
- [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- [SOLID Principles](https://en.wikipedia.org/wiki/SOLID)
- [Refactoring Catalog](https://refactoring.com/catalog/)
- [OID4VCI 1.0 Specification](https://openid.net/specs/openid-4-verifiable-credential-issuance-1_0.html)

## Related ADRs

- [ADR 0001: OID4VCI 1.0 Upgrade](./0001-upgrade-oid4vci-to-version-1.0.md)

## Approval

- [ ] iOS Lead Developer
- [ ] Tech Lead
- [ ] Product Owner

## Notes

このADRは、Credential Issuance機能のリファクタリングにのみ適用されます。他の機能（Credential Presentation, Authenticationなど）への適用は別途検討が必要です。

ただし、このリファクタリングで得られた知見（Service層パターン、エラーハンドリングなど）は、他の機能にも適用可能です。
