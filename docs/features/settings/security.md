# Settings - Security Considerations

## Threat Model

### 1. Unauthorized Backup File Access

**Threat**: バックアップファイルが暗号化されていないため、ファイルが流出すると全データが露出

**Current Mitigation**:
- 生体認証によるSeedアクセス制限

**Future Mitigation**:
- バックアップファイル自体の暗号化実装

### 2. Accidental Data Loss

**Threat**: Seed紛失によるアカウント復元不可

**Mitigation**:
- バックアップ推奨
- 最終バックアップ日時表示

### 3. Backup File Tampering

**Threat**: バックアップファイルの改ざん

**Current Mitigation**:
- インポート時のJSON形式検証
- ZIP整合性チェック

**Future Mitigation**:
- バックアップファイルの署名検証

## Security Checklist

| Check | Status | Notes |
|-------|--------|-------|
| バックアップ暗号化 | ⬜ | 将来実装 |
| Seedアクセス時の生体認証 | ✅ | 実装済み |
| データ削除前の確認 | ⬜ | 機能自体が未実装 |
| エクスポート時の認証 | ✅ | 生体認証 |
| インポート時の検証 | ✅ | ZIP/JSON形式チェック |

## Privacy Considerations

### Data Collection

**現在の実装**:
| Item | Status |
|------|--------|
| Analytics | 未実装 |
| Crash Reports | 未実装 |
| Sharing History | 保存される（保持期間設定は未実装） |

### Data Retention

**現在の実装**:
- Seed: 生体認証で保護、手動バックアップのみ
- 共有履歴: 無制限保存
- Credentials: 手動削除のみ

**将来の実装予定**:
- 共有履歴の保持期間設定（30日、90日、180日、無期限）
- キャッシュクリア機能
- すべてのデータ削除機能

## Future Enhancements

1. **Security**
   - バックアップファイルのパスワード暗号化
   - App Lock設定
   - バックアップファイルの署名検証

2. **Privacy**
   - Analytics設定
   - Crash Reports設定
   - 共有履歴の保持期間設定

3. **Data Management**
   - キャッシュクリア機能
   - 共有履歴削除機能
   - すべてのデータ削除機能
