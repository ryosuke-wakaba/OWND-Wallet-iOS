# Credential Management - Security Considerations

## Threat Model

### 1. Unauthorized Deletion

**Threat**: 意図しないCredentialの削除

**Mitigation**:
- 確認ダイアログ表示
- 機密Credential削除時の認証要求（将来実装）

### 2. Data Leakage

**Threat**: 画面キャプチャによる情報漏洩

**Mitigation**:
- スクリーンキャプチャ防止（将来実装）

## Security Checklist

| Check | Status | Notes |
|-------|--------|-------|
| 削除前の確認 | ✅ | 確認ダイアログ表示 |
| 機密Credential削除時の認証 | ⬜ | 将来実装 |
| スクリーンキャプチャ防止 | ⬜ | 将来実装 |
| セキュアなデータ保存 | ✅ | CoreData + Protocol Buffers |

## Data Protection

- Credentialは CoreData に保存
- Protocol Buffers でシリアライズ
- iOS Data Protection によるファイル暗号化
