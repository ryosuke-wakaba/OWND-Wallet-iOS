# Credential Issuance リファクタリング計画

## 概要

このドキュメントは、Credential Issuance (OID4VCI) 機能のリファクタリング計画を定義します。主な目的は、コードの保守性、テスタビリティ、拡張性を向上させることです。

## 背景

現在の実装は機能的には動作していますが、以下の課題があります：

1. **責務の集中**: `CredentialOfferViewModel`が多くの責務を持っている
2. **重複コード**: JWT解析、メタデータデコードなどのロジックが複数箇所に存在
3. **エラーハンドリングの不統一**: タイポや不明確なエラーメッセージ
4. **テストカバレッジ不足**: ViewModelのUnit Testが存在しない
5. **マジックストリング**: フォーマット名などがハードコード

## 改善項目と優先度

### フェーズ1: 基盤改善（高優先度）

#### 1.1 エラーハンドリングの統一

**目的**: エラー型を統一し、ユーザーフレンドリーなメッセージを提供

**対象ファイル**:
- `tw2023_wallet/Feature/IssueCredential/ViewModels/CredentialOfferViewModel.swift`

**新規作成**:
- `tw2023_wallet/Errors/CredentialIssuanceErrors.swift`

**変更内容**:
1. `CredentialOfferViewModelError`を`CredentialIssuanceError`にリネーム
2. `LoadDataDidNotFinishuccessfully`のタイポを修正
3. `LocalizedError`プロトコルを実装
4. `errorDescription`と`recoverySuggestion`を提供

**影響範囲**:
- CredentialOfferViewModel
- PinCodeInput (エラー表示)
- テストコード

**見積工数**: 2-3時間

**完了条件**:
- [ ] CredentialIssuanceError.swiftを作成
- [ ] 全てのエラーケースにerrorDescriptionを実装
- [ ] 既存のエラー処理を新しいエラー型に移行
- [ ] エラーメッセージが適切に表示されることを確認

---

#### 1.2 定数の管理

**目的**: マジックストリングを除去し、型安全性を向上

**新規作成**:
- `tw2023_wallet/Constants/CredentialFormats.swift`
- `tw2023_wallet/Constants/CryptographyConstants.swift`

**変更内容**:
1. `CredentialFormat` enumを作成
2. フォーマット関連のヘルパーメソッド実装
3. Cryptography関連の定数をenumに集約
4. 既存のハードコードされた文字列を定数に置換

**影響範囲**:
- CredentialOfferViewModel
- CredentialDataManager
- VCIMetadataUtil
- すべてのフォーマット判定箇所

**見積工数**: 3-4時間

**完了条件**:
- [ ] CredentialFormats.swiftを作成
- [ ] CryptographyConstants.swiftを作成
- [ ] 全てのハードコードされたフォーマット名を置換
- [ ] コンパイルエラーがないことを確認
- [ ] 既存テストが全てパス

---

#### 1.3 重複コードの除去

**目的**: DRY原則に準拠し、保守性を向上

**新規作成**:
- `tw2023_wallet/Utils/JWTParsingUtil.swift`
- `tw2023_wallet/Utils/MetadataDecoder.swift`

**変更内容**:
1. JWT解析ロジックを`JWTParsingUtil`に集約
2. メタデータデコードロジックを`MetadataDecoder`に集約
3. 既存コードを新しいUtilを使用するように変更

**影響範囲**:
- CredentialOfferViewModel (`extractInfoFromJwt`, `extractSDJwtInfo`)
- CredentialDataManager (`parsedMetaData`, `getDisclosure`)
- VCIMetadataUtil

**見積工数**: 4-5時間

**完了条件**:
- [ ] JWTParsingUtil.swiftを作成
- [ ] MetadataDecoder.swiftを作成
- [ ] 重複していたJWT解析ロジックを削除
- [ ] 重複していたメタデータデコードロジックを削除
- [ ] Unit Testを作成
- [ ] 既存の全テストがパス

---

### フェーズ2: アーキテクチャ改善（中優先度）

#### 2.1 責務の分離 - Service層導入

**目的**: Single Responsibility Principleに準拠し、ViewModelを簡素化

**新規作成**:
- `tw2023_wallet/Services/CredentialIssuance/CredentialIssuanceService.swift`
- `tw2023_wallet/Services/CredentialIssuance/TokenIssuanceService.swift`
- `tw2023_wallet/Services/CredentialIssuance/ProofGenerationService.swift`
- `tw2023_wallet/Services/CredentialIssuance/CredentialRequestService.swift`
- `tw2023_wallet/Services/CredentialIssuance/CredentialStorageService.swift`

**変更内容**:
1. トークン発行ロジックを`TokenIssuanceService`に移動
2. Proof生成ロジックを`ProofGenerationService`に移動
3. Credential要求ロジックを`CredentialRequestService`に移動
4. ストレージロジックを`CredentialStorageService`に移動
5. これらを統合する`CredentialIssuanceService`を作成
6. `CredentialOfferViewModel`を簡素化

**影響範囲**:
- CredentialOfferViewModel (大幅な簡素化)
- 新規Serviceクラス

**見積工数**: 8-10時間

**完了条件**:
- [x] 全Serviceインターフェースを定義
- [x] 各Service実装を作成
- [x] ViewModelをService使用に変更
- [x] 依存性注入をサポート
- [x] 既存の全機能が動作することを確認
- [x] 既存テストが全てパス

**実装完了**: 2025-01-15
**コミット**: `6432463` - refactor: Phase 2.1 - Introduce Service layer for credential issuance

---

#### 2.2 データ変換ロジックの分離

**目的**: Mapper/Converterパターンを導入し、変換ロジックを分離

**新規作成**:
- `tw2023_wallet/Mappers/CredentialMapper.swift`
- `tw2023_wallet/Parsers/JWTParser.swift`
- `tw2023_wallet/Parsers/SDJWTParser.swift`

**変更内容**:
1. `CredentialMapper`プロトコルを定義
2. JWT/SD-JWT固有のParserを作成
3. `convertToProtoBuf`ロジックをMapperに移動
4. ViewModelから変換ロジックを削除

**影響範囲**:
- CredentialOfferViewModel
- CredentialStorageService (フェーズ2.1で作成)

**見積工数**: 5-6時間

**完了条件**:
- [ ] CredentialMapper.swiftを作成
- [ ] JWTParser.swiftを作成
- [ ] SDJWTParser.swiftを作成
- [ ] ViewModelから変換ロジックを削除
- [ ] Unit Testを作成
- [ ] 既存テストが全てパス

---

### フェーズ3: テスト強化（中優先度）

#### 3.1 ViewModelのUnit Tests作成

**目的**: テストカバレッジを向上し、回帰を防止

**新規作成**:
- `tw2023_walletTests/Feature/IssueCredential/ViewModels/CredentialOfferViewModelTests.swift`
- `tw2023_walletTests/Mocks/MockCredentialIssuanceService.swift`
- `tw2023_walletTests/Mocks/MockCredentialStorageService.swift`

**テストケース**:
1. `testSendRequestWithValidData` - 正常系
2. `testSendRequestWithMissingData` - データ不足時のエラー
3. `testSendRequestWithUnsupportedProofType` - 未サポートProof Type
4. `testLoadDataSuccess` - メタデータ読み込み成功
5. `testLoadDataFailure` - メタデータ読み込み失敗
6. `testCancelIssuance` - キャンセル処理
7. `testDeferredIssuanceNotSupported` - Deferred発行エラー

**見積工数**: 6-8時間

**完了条件**:
- [ ] CredentialOfferViewModelTests.swiftを作成
- [ ] Mock実装を作成
- [ ] 全テストケースを実装
- [ ] コードカバレッジ80%以上
- [ ] 全テストがパス

---

#### 3.2 Integration Tests作成

**目的**: End-to-endフローをテストし、統合の問題を早期発見

**新規作成**:
- `tw2023_walletTests/Integration/CredentialIssuanceFlowTests.swift`

**テストケース**:
1. `testEndToEndPreAuthorizedCodeFlow` - Pre-Authorized Code Flow全体
2. `testEndToEndWithTxCode` - TX Code付きフロー
3. `testEndToEndWithoutProofs` - Proofsなしフロー
4. `testErrorHandlingInFlow` - エラーハンドリング
5. `testNetworkErrorRecovery` - ネットワークエラーからの回復

**見積工数**: 6-8時間

**完了条件**:
- [ ] CredentialIssuanceFlowTests.swiftを作成
- [ ] MockURLProtocolを使用したネットワークモック
- [ ] 全テストケースを実装
- [ ] CI/CDパイプラインに統合
- [ ] 全テストがパス

---

#### 3.3 Service層のUnit Tests作成

**目的**: 各Serviceの動作を個別に検証

**新規作成**:
- `tw2023_walletTests/Services/CredentialIssuance/TokenIssuanceServiceTests.swift`
- `tw2023_walletTests/Services/CredentialIssuance/ProofGenerationServiceTests.swift`
- `tw2023_walletTests/Services/CredentialIssuance/CredentialRequestServiceTests.swift`
- `tw2023_walletTests/Services/CredentialIssuance/CredentialStorageServiceTests.swift`

**見積工数**: 8-10時間

**完了条件**:
- [ ] 各Service用のテストファイルを作成
- [ ] 各Serviceの主要機能をテスト
- [ ] エラーケースもカバー
- [ ] コードカバレッジ80%以上
- [ ] 全テストがパス

---

### フェーズ4: ドキュメント・最適化（低優先度）

#### 4.1 ドキュメントコメント追加

**目的**: コードの理解を容易にし、新規開発者のオンボーディングを改善

**対象ファイル**:
- 全ての新規作成したService、Mapper、Parser
- CredentialOfferViewModel

**変更内容**:
1. 主要クラスにクラスレベルのドキュメント
2. 公開メソッドにメソッドレベルのドキュメント
3. 複雑なロジックにインラインコメント

**見積工数**: 4-5時間

**完了条件**:
- [ ] 全てのpublicクラスにドキュメント
- [ ] 全てのpublicメソッドにドキュメント
- [ ] パラメータ、戻り値、例外を記載
- [ ] 使用例を含む

---

#### 4.2 パフォーマンス最適化

**目的**: 不要な処理を削減し、レスポンス時間を改善

**新規作成**:
- `tw2023_wallet/Cache/MetadataCache.swift`

**変更内容**:
1. メタデータキャッシュ機構を導入
2. 不要なJSON変換を削減
3. パフォーマンスメトリクスを計測

**見積工数**: 4-6時間

**完了条件**:
- [ ] MetadataCache.swiftを作成
- [ ] 重複するJSON変換を削除
- [ ] パフォーマンステストで改善を確認
- [ ] メモリリーク無し

---

## 実装スケジュール

```
Week 1-2: フェーズ1 (基盤改善) ✅ 完了
├─ Day 1-2:   エラーハンドリング統一
├─ Day 3-4:   定数管理
└─ Day 5-10:  重複コード除去

Week 3-5: フェーズ2 (アーキテクチャ改善)
├─ Day 11-20: Service層導入 ✅ 完了 (2025-01-15)
└─ Day 21-26: データ変換分離

Week 6-8: フェーズ3 (テスト強化)
├─ Day 27-34: ViewModelテスト
├─ Day 35-42: Integration Tests
└─ Day 43-52: Serviceテスト

Week 9-10: フェーズ4 (ドキュメント・最適化)
├─ Day 53-57: ドキュメント
└─ Day 58-63: パフォーマンス最適化
```

## リスクと軽減策

### リスク1: 大規模な変更による既存機能の破壊

**軽減策**:
- 各フェーズ後に既存の全テストを実行
- 段階的なリファクタリング
- フィーチャーフラグの使用

### リスク2: 開発スケジュールの遅延

**軽減策**:
- 各タスクに十分なバッファを設定
- 高優先度タスクを先に実施
- 定期的な進捗レビュー

### リスク3: 新しいバグの混入

**軽減策**:
- 包括的なテストカバレッジ
- コードレビューの徹底
- QAテストの実施

## 成功基準

以下の基準を満たした場合、リファクタリングは成功とみなします：

1. **機能性**: 既存の全機能が正常に動作
2. **テストカバレッジ**: 新規コードのカバレッジ80%以上
3. **パフォーマンス**: Credential発行時間が10秒以内（変更なし）
4. **保守性**: Cyclomatic Complexity が10以下
5. **ドキュメント**: 全ての公開APIにドキュメントコメント

## Future Work（今後の対応）

以下の改善項目は、現在のフェーズには含まれず、将来的に検討・実装する予定です：

### 非同期処理のキャンセルサポート

**目的**: ユーザーが処理をキャンセルできるようにする

**対象ファイル**:
- `tw2023_wallet/Feature/IssueCredential/ViewModels/CredentialOfferViewModel.swift`
- `tw2023_wallet/Feature/ShareCredential/Views/PinCodeInput.swift`

**変更内容**:
1. `Task`のキャンセル機能を実装
2. UI上のキャンセルボタンと連携
3. 適切なタイミングで`Task.checkCancellation()`を呼び出し

**影響範囲**:
- CredentialOfferViewModel
- PinCodeInput
- CredentialOfferView

**見積工数**: 3-4時間

**完了条件**:
- [ ] Task cancellation機能を実装
- [ ] キャンセルボタンから呼び出し
- [ ] 処理がキャンセルされることを確認
- [ ] リソースが適切にクリーンアップされることを確認

---

## 参照

- [Credential Issuance Feature Document](../features/credential-issuance.md)
- [OID4VCI 1.0 Specification](https://openid.net/specs/openid-4-verifiable-credential-issuance-1_0.html)
- [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)

## 変更履歴

| 日付 | 版 | 変更内容 | 作成者 |
|------|------|----------|--------|
| 2025-01-14 | 1.0 | 初版作成 | Claude |
| 2025-01-14 | 1.1 | フェーズ2から2.3（キャンセルサポート）をFuture Workに移動 | Claude |
| 2025-01-15 | 1.2 | Phase 2.1（Service層導入）完了を記録 | Claude |
