# Settings - Design

## UI/UX Design

### Screens

1. **Settings Screen**
   - セクション分けされた設定項目
   - Security
   - Backup & Restore
   - Privacy
   - Data Management
   - About
   - Legal

2. **App Lock Settings Screen**
   - Enable/Disable トグル
   - Timeout設定（30秒、1分、5分、10分）
   - 生体認証タイプ表示

3. **Backup Screen**
   - Export Accountボタン
   - Import Accountボタン
   - 最終バックアップ日時表示

4. **Privacy Settings Screen**
   - Analytics トグル
   - Crash Reports トグル
   - History Retention設定

5. **Data Management Screen**
   - Clear Cache ボタン
   - Clear Sharing History ボタン
   - Delete All Data ボタン（赤色）

6. **About Screen**
   - アプリバージョン
   - ビルド番号
   - Licenses ボタン
   - Contact Support ボタン

## Settings Structure

```
Settings
├── Account Info
│   └── Backup & Restore
│       ├── Export Account
│       └── Import Account
├── Issuance Settings
│   ├── Use DPoP (Toggle)
│   └── Use Client Attestation (Toggle)
├── Trust List
│   └── Require Server Authentication (Toggle)
├── Security (未実装)
│   ├── App Lock (Toggle)
│   ├── Lock Timeout (Picker)
│   └── Biometric Type (Display Only)
├── Privacy (未実装)
│   ├── Analytics (Toggle)
│   ├── Crash Reports (Toggle)
│   └── History Retention (Picker)
├── Data Management (未実装)
│   ├── Clear Cache
│   ├── Clear Sharing History
│   └── Delete All Data
├── About
│   ├── Version
│   ├── Build Number (未実装)
│   ├── Open Source Licenses (未実装)
│   └── Contact Support (未実装)
└── Legal
    ├── Terms of Service
    └── Privacy Policy
```

## Accessibility

- VoiceOver対応
- Dynamic Type対応
- 設定項目の明確な説明
- スイッチのラベル

## Localization

- 設定項目名の多言語対応
- 説明文の多言語対応
- エラーメッセージの多言語対応
