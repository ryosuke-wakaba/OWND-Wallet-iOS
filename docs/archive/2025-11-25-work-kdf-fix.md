# JWE暗号化修正作業計画

## 概要

JWE暗号化の以下2点を修正する：
1. 鍵導出関数（KDF）をHKDFからConcat KDF（RFC 7518 Section 4.6準拠）に変更
2. AES-GCM暗号化にAAD（Additional Authenticated Data）を追加（RFC 7516準拠）

## 背景

### 問題点1: KDF

Wallet側の`JWEUtil.swift`でHKDFを使用しているが、JOSE/RFC 7518はConcat KDF（NIST SP 800-56A）を要求している。

| 項目 | Wallet側（現状） | JOSE/RFC 7518要求 |
|------|------------------|-------------------|
| KDF | HKDF (RFC 5869) | Concat KDF (NIST SP 800-56A) |

HKDFとConcat KDFは異なる鍵導出関数であるため、同じ共有秘密（shared secret）から異なる鍵を生成する。結果として、Verifier側（Concat KDFを使用するjoseライブラリ）とWallet側（HKDFを使用）で導出される対称鍵が一致せず、復号化が失敗する。

### 問題点2: AAD欠落

AES-GCM暗号化時にAAD（Additional Authenticated Data）が設定されていなかった。RFC 7516では、Protected HeaderをAADとして使用する必要がある。AADがないと認証タグが一致せず、Verifier側での復号化が失敗する。

### 対象ファイル

- `tw2023_wallet/Signature/JWEUtil.swift`

## 作業内容

### 1. AADの追加（AES-GCM暗号化）

**修正前:**
```swift
// Encrypt with AES-GCM
let symmetricKey = CryptoKit.SymmetricKey(data: derivedKey)
let nonce = try AES.GCM.Nonce(data: iv)
let sealedBox = try AES.GCM.seal(payloadData, using: symmetricKey, nonce: nonce)

// Build JWE Protected Header (暗号化の後に構築)
// ...
```

**修正後:**
```swift
// Build JWE Protected Header (must be built BEFORE encryption for AAD)
// ...
let protectedHeader = headerData.base64URLEncodedString()

// AAD is the ASCII bytes of the Protected Header (RFC 7516)
let aad = protectedHeader.data(using: .ascii)!

// Encrypt with AES-GCM using AAD
let symmetricKey = CryptoKit.SymmetricKey(data: derivedKey)
let nonce = try AES.GCM.Nonce(data: iv)
let sealedBox = try AES.GCM.seal(payloadData, using: symmetricKey, nonce: nonce, authenticating: aad)
```

### 2. deriveKey関数の修正（KDF）

**修正前（HKDF使用）:**
```swift
private static func deriveKey(sharedSecret: SharedSecret, algorithmId: String, keyLength: Int) -> Data {
    // ... otherInfo構築 ...

    // Use HKDF with SHA-256
    let derivedKey = sharedSecret.hkdfDerivedSymmetricKey(
        using: SHA256.self,
        salt: Data(),
        sharedInfo: otherInfo,
        outputByteCount: keyLength
    )
    return derivedKey.withUnsafeBytes { Data($0) }
}
```

**修正後（Concat KDF使用）:**
```swift
private static func deriveKey(sharedSecret: SharedSecret, algorithmId: String, keyLength: Int) -> Data {
    // ... otherInfo構築 ...

    // Concat KDF: Single-step KDF using SHA-256 (RFC 7518 Section 4.6.2)
    let sharedSecretData = sharedSecret.withUnsafeBytes { Data($0) }
    var counter = UInt32(1).bigEndian
    let counterData = Data(bytes: &counter, count: 4)

    var hash = SHA256()
    hash.update(data: counterData)
    hash.update(data: sharedSecretData)
    hash.update(data: otherInfo)
    let digest = hash.finalize()

    return Data(digest.prefix(keyLength))
}
```

### 2. 技術詳細

#### Concat KDFの構造（RFC 7518 Section 4.6.2）

```
DerivedKey = Hash(counter || Z || OtherInfo)
```

- `counter`: 1から始まる32ビットビッグエンディアンのカウンタ
- `Z`: ECDH共有秘密
- `OtherInfo`: 以下の連結
  - AlgorithmID（長さプレフィックス付き）
  - PartyUInfo（長さプレフィックス付き、空）
  - PartyVInfo（長さプレフィックス付き、空）
  - SuppPubInfo（鍵長をビット単位で表現）

#### 主な違い

| 特徴 | HKDF | Concat KDF |
|------|------|------------|
| 標準 | RFC 5869 | NIST SP 800-56A |
| 構造 | Extract-Expand | Single-step |
| salt使用 | あり | なし |
| カウンタ | なし | あり |

## 進捗状況

- [x] 作業計画ドキュメント作成
- [x] deriveKey関数の修正（Concat KDF）
- [x] AADの追加（AES-GCM暗号化）
- [x] 動作確認方法の記載

## テスト方法

修正後、以下を確認する：

1. JWE暗号化が正常に動作すること
2. Verifier側（joseライブラリ使用）で復号化が成功すること
3. 既存のOID4VPフローが正常に動作すること

## 参考資料

- [RFC 7518 Section 4.6 - Key Agreement with Elliptic Curve Diffie-Hellman Ephemeral Static](https://datatracker.ietf.org/doc/html/rfc7518#section-4.6)
- [NIST SP 800-56A - Recommendation for Pair-Wise Key-Establishment Schemes Using Discrete Logarithm Cryptography](https://csrc.nist.gov/publications/detail/sp/800-56a/rev-3/final)
