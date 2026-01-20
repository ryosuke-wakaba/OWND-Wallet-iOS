# 作業依頼
## 機能追加
TrustedListConfig.jsonの設定を利用してトラストリストから上位のサーバー証明書を取得する処理を改修します。
以下を確認してください。

### AsIs
設定ファイル
```JSON
{
  "lotes": {
    "jp-lote": {
      "url": "https://tl.eujp.ownd-project.com/api/trusted-list.jwt",
      "services": {
        "oid4vci": {
          "identifier": "http://tl.eujp.ownd-project.com/TrstSvc/Svctype/LearningCredential/Issuer"
        },
        "oid4vp": {
          "identifier": "http://tl.eujp.ownd-project.com/TrstSvc/Svctype/LearningCredential/Verifier"
        },
        "diw": {
          "identifier": "http://tl.eujp.ownd-project.com/SvcType/WalletSolution/WalletProvider"
        }
      }
    }
  }
}
```
上記の設定ファイルを以下の様に読み込み検索条件をセット
```swift
            // Load LoTE configuration for OID4VCI
            // Domain knowledge: jp-lote + oid4vci service type
            let loteSearchInfos = TrustedListConfigLoader.createSearchInfos([
                (loteName: "jp-lote", serviceName: "oid4vci")
            ])
```

リーフ証明書をx5cヘッダーに保持するjwtと検索条件を合わせて検証開始
```swift
        // Validate signed metadata (async version with TrustedList support)
        let validationResult = await SignedMetadataValidator.validate(
            jwt: jwtString,
            expectedIssuerIdentifier: issuerIdentifier,
            loteSearchInfos: loteSearchInfos
        )
```

jwt検証後、証明書リストの取り出し証明書チェーンの検証を実行する
```swift
                let additionalCerts = try await TrustedListManager.shared.getCertificates(
                    forServiceURL: issuerURL,
                    loteInfos: loteSearchInfos
                )
```

#### 問題点
トラストリストの構成方法の理解が誤っていたことが判明した。

現在は、トラストリストに含まれるサービスをリーフ証明書を発行されたサービスの情報として設計、実装しているが、正しくは、リーフ証明書を発行した主体がリストに含まれる。

そして、サービスの特定条件としてサービスURLを使用しているが、上記の理解をもとに考察すると、リーフ証明書に含まれる発行者の情報と、リストに含まれる上位の証明書のサブジェクトを一致させる方法が適切であると考えられる。

### ToBe
1. 証明書(ServiceDigitalIdentity)を使った検索方法に変更する
    1. AKIとSKIの一致で確認する
    2. もし上記フィールドが存在しない場合は、Distinguidhed Nameによる一致で確認する
2. 設定ファイルの構造を以下の様に変更する
    1. 検索条件を取り出す際はcontext名を指定する
    2. トラストリストからサービスを特定する際はconditionの条件を全て満たすことを確認する

```JSON
{
  "lotes": {
    "jp-lote": {
      "url": "https://tl.eujp.ownd-project.com/api/trusted-list.jwt",
      "context": {
        "AccessCertificateVefification": {
          "condition": {
              "loteType": "https://tl.eujp.ownd-project.com/LoTELType/JPWRPACProvidersList",
              "serviceTypeIdentifier": "http://tl.eujp.ownd-project.com/19602/SvcType/WRPAC/Issuance",
              "status": "http://tl.eujp.ownd-project.com/TrstSvc/TrustedList/Svcstatus/granted"
          }
        },
        "AccessCertificateStatusConfirmation": {
          "condition": {
              "loteType": "https://tl.eujp.ownd-project.com/LoTELType/JPWRPACProvidersList",
              "serviceTypeIdentifier": "http://tl.eujp.ownd-project.com/19602/SvcType/WRPAC/Revocation",
              "status": "http://tl.eujp.ownd-project.com/TrstSvc/TrustedList/Svcstatus/granted"
          }
        },
      }
    },
    "eu-lote": {
      "url": "https://tl.eujp.ownd-project.com/api/trusted-list.jwt",
      "context": {
        "AccessCertificateVefification": {
          "condition": {
              "loteType": "https://tl.eujp.ownd-project.com/LoTELType/EUWRPACProvidersList",
              "serviceTypeIdentifier": "http://tl.eujp.ownd-project.com/19602/SvcType/WRPAC/Issuance",
              "status": "http://tl.eujp.ownd-project.com/TrstSvc/TrustedList/Svcstatus/granted"
          }
        }
      }
    }
  }
}
```

### 基本情報
- docs/architecture.md
- docs/development.md
- docs/features/credential-issuance

### ブランチ
- 新しいブランチで対応して下さい。
    - 派生元ブランチ: 現在のブランチ
    - 派生元ブランチ: develop

### 作業ドキュメント
対応内容がまとまったら、まずは進捗が把握できるように作業ドキュメントを作成して下さい。

作業ドキュメントのパスとファイル名の形式

- docs/work/yyyy-mm-dd-xxx.md