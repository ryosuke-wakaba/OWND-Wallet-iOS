# X509カスタム信頼アンカー実装計画

## ステータス
- [x] 調査完了
- [x] 計画策定
- [x] 実装
- [x] テスト
- [ ] レビュー

## 概要

Request Object JWTのX.509証明書検証において、ビルトインの中間証明書・ルート証明書を使用したカスタム信頼アンカー検証機能を実装する。

## 現状分析

### 既存実装

| ファイル | 機能 |
|---------|------|
| `JWTUtil.verifyJwtByX5C()` | x5cヘッダーからの証明書抽出・JWT署名検証 |
| `SignatureUtil.validateCertificateChain()` | SecTrustによる証明書チェーン検証 |
| `OpenIdProvider.processAuthRequest()` | x509_san_dns/x509_hashスキーム対応 |

### 現在の制限

1. **信頼アンカー**: iOSシステムCAストアのみ使用
2. **証明書チェーン検証**: `verifyCertChain: false`で無効化されている

## 実装計画

### Phase 1: リソースバンドル対応

**タスク:**
1. 証明書ファイルをXcodeリソースとして追加
2. 証明書読み込みユーティリティを作成

**実装ファイル:**
- `tw2023_wallet/Resources/Certificates/` - 証明書ファイル配置
- `tw2023_wallet/Signature/TrustAnchorManager.swift` - 新規作成

```swift
// TrustAnchorManager.swift
class TrustAnchorManager {
    static let shared = TrustAnchorManager()

    private var customAnchors: [SecCertificate] = []

    func loadBuiltInCertificates() {
        // Bundle.mainから証明書を読み込み
    }

    func getAnchorCertificates() -> [SecCertificate] {
        return customAnchors
    }
}
```

### Phase 2: 証明書チェーン検証の拡張

**タスク:**
1. `SignatureUtil.validateCertificateChain()`を拡張
2. `SecTrustSetAnchorCertificates()`でカスタムアンカーを設定

**変更ファイル:**
- `tw2023_wallet/Signature/SignatureUtil.swift`

```swift
// 拡張版
static func validateCertificateChain(
    certificates: [Certificate],
    customAnchors: [SecCertificate]? = nil
) throws -> Bool {
    // ... 既存処理 ...

    if let anchors = customAnchors {
        SecTrustSetAnchorCertificates(trust, anchors as CFArray)
        SecTrustSetAnchorCertificatesOnly(trust, true)  // カスタムアンカーのみ使用
    }

    // ... 検証処理 ...
}
```

### Phase 3: OpenIdProvider統合

**タスク:**
1. `verifyCertChain: false` → `true` に変更
2. カスタムアンカーを使用した検証に切り替え

**変更ファイル:**
- `tw2023_wallet/Services/OID/Provider/OpenIdProvider.swift`

### Phase 4: テストコード作成

**タスク:**
1. 自己署名ルート証明書の生成
2. 中間証明書・リーフ証明書の生成
3. x5cヘッダー付きJWTの生成
4. 検証テストの実装

**テストファイル:**
- `tw2023_walletTests/Signature/TrustAnchorManagerTests.swift` - 新規
- `tw2023_walletTests/Signature/X509ChainValidationTests.swift` - 新規

## テスト計画

### テスト証明書構成

```
Test Root CA (自己署名)
    └── Test Intermediate CA
            └── Test Leaf Certificate
```

### テストケース

| # | テストケース | 期待結果 |
|---|------------|---------|
| 1 | 有効な証明書チェーン（ビルトインルートCA使用） | 検証成功 |
| 2 | 有効な証明書チェーン（テストルートCA使用） | 検証成功 |
| 3 | 不正な証明書チェーン（中間証明書欠落） | 検証失敗 |
| 4 | 期限切れ証明書 | 検証失敗 |
| 5 | 未知のルートCA | 検証失敗 |
| 6 | x5cヘッダー付きJWT署名検証 | 検証成功 |

### テスト用JWT生成

```swift
// テスト用JWTの構造
// x5cにはリーフ証明書のみ（中間証明書はウォレットにビルトイン）
{
    "header": {
        "alg": "ES256",
        "typ": "JWT",
        "x5c": [
            "<leaf_cert_base64>"
        ]
    },
    "payload": { ... },
    "signature": "<signature>"
}
```

### 証明書配置パターン

**x5c (JWT内):** リーフ証明書のみ
**ウォレット (ビルトイン):** 中間証明書 + ルート証明書

```
JWT x5c:           [Leaf]
                      ↓ 署名検証
Wallet Built-in:   [Intermediate] → [Root]
                      ↓ チェーン構築・検証
Trust Anchor:      [Root]
```

## ファイル構成（予定）

```
tw2023_wallet/
├── Resources/
│   └── Certificates/       # .gitignoreで除外
│       ├── *.cer           # 実際の証明書ファイル
│       └── .gitkeep        # ディレクトリ維持用（コミット対象）
├── Signature/
│   ├── SignatureUtil.swift (変更)
│   └── TrustAnchorManager.swift (新規)
└── Services/OID/Provider/
    └── OpenIdProvider.swift (変更)

tw2023_walletTests/
└── Signature/
    ├── TrustAnchorManagerTests.swift (新規)
    └── X509ChainValidationTests.swift (新規)
```

## 証明書ファイルのコミット除外方法

`.gitignore`に以下を追加:

```gitignore
# Custom trust anchor certificates (local only)
tw2023_wallet/Resources/Certificates/*.cer
tw2023_wallet/Resources/Certificates/*.pem
!tw2023_wallet/Resources/Certificates/.gitkeep
```

**運用:**
1. `Certificates/`ディレクトリは`.gitkeep`でリポジトリに維持
2. 実際の証明書ファイル（`.cer`, `.pem`）はローカルのみ
3. 各開発者・デプロイ環境で個別に証明書を配置
4. Xcodeプロジェクトには`Certificates/`フォルダを参照として追加（ファイルは動的に読み込み）

## 依存関係

- Security.framework (SecTrust, SecCertificate)
- X509 (Apple's Swift X.509 library)
- SwiftASN1

## セキュリティ考慮事項

1. **証明書の保護**: リソースとしてバンドルされた証明書は読み取り専用
2. **アンカー制限**: `SecTrustSetAnchorCertificatesOnly(true)`でカスタムアンカーのみ使用
3. **証明書更新**: 新しい証明書が必要な場合はアプリ更新が必要

## 進捗

- [x] Phase 1: リソースバンドル対応
  - `TrustAnchorManager.swift` 作成
  - `Resources/Certificates/.gitkeep` 作成
- [x] Phase 2: 証明書チェーン検証の拡張
  - `SignatureUtil.validateCertificateChainWithCustomAnchors()` 追加
- [x] Phase 3: OpenIdProvider統合
  - `JWTUtil.verifyJwtByX5C()` でカスタムアンカー検証使用
  - `JWTUtil.verifyJwtByX5U()` でカスタムアンカー検証使用
  - `OpenIdProvider` で `verifyCertChain: true` に変更
- [x] Phase 4: テストコード作成
  - `TrustAnchorManagerTests.swift` 作成
  - `X509ChainValidationTests.swift` 作成
