# KeyBindingTests.swift

**パス**: `tw2023_walletTests/KeyBindingTests.swift`

**対応実装**: `tw2023_wallet/Services/OID/Provider/KeyBindingImpl.swift`

**概要**: Key Binding JWT（KB-JWT）の生成をテストします。SD-JWTのVP Token提示時に必要なKey Bindingの署名生成と`_sd_alg`対応を検証します。

---

## テストケース

| テストメソッド | 説明 | 検証内容 |
|--------------|------|---------|
| `testGenerateJwtSignature` | JWT署名生成・検証 | KB-JWTが正しく署名され、公開鍵で検証できること（`sdAlg: "sha-256"`） |
| `testGenerateJwtWithSha256UpperCase` | 大文字SHA-256拒否 | `sdAlg: "SHA-256"`（大文字）で`UnsupportedHashAlgorithm`エラーが発生すること（case-sensitive） |
| `testGenerateJwtWithUnsupportedAlgorithm` | サポート外アルゴリズム | `sha-512`等のサポート外アルゴリズムで`UnsupportedHashAlgorithm`エラーが発生すること |

---

## _sd_alg対応（SD-JWT draft-22）

KB-JWT生成時の`_sd_hash`計算は、SD-JWTペイロードの`_sd_alg`クレームで指定されたハッシュアルゴリズムを使用する必要があります。

| アルゴリズム | サポート状況 | 備考 |
|------------|:----------:|------|
| `sha-256` | ✅ | 必須、デフォルト（IANA登録値） |
| `SHA-256` | ❌ | エラー（case-sensitive、IANAレジストリに存在しない） |
| `sha-384` | ❌ | エラー（将来対応予定） |
| `sha-512` | ❌ | エラー（将来対応予定） |

**参考**: [SD-JWT Section 7.1 - Creating a Key Binding JWT](https://datatracker.ietf.org/doc/html/draft-ietf-oauth-selective-disclosure-jwt#section-7.1)
