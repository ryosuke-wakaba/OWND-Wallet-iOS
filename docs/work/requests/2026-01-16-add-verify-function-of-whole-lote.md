# 作業依頼
## 機能追加
- tw2023_wallet/Services/TrustedList/TrustedListManager.swift

こちらのモジュールでダウンロードしたリストのjwtを検証する機能を実装してください。

署名検証に関する処理は専用のモジュールを作成して、そちらを使用する設計にしてください。

### デジタル署名に関する仕様
```
TS 119 602に基づくTrusted Listのバインディング（XML/JSON）では、リスト全体に対してデジタル署名を施すことで、リストの真正性と完全性を保証します。ここでは、それぞれのバインディングで使用される署名規格について詳しく説明します。

- **ETSI TS 119 182-1 (JAdES)**
    
    **タイトル**: JAdES digital signatures; Part 1: Building blocks and JAdES baseline signatures
    
    
    **概要**
    
    - **技術基盤**: IETF RFC 7515 で定義されている **JSON Web Signature (JWS)** を拡張したものです
    - **特徴**: JSON形式であるため、Web API (REST API) やマイクロサービス、モバイルアプリなど、モダンなWeb環境でのデータ交換との親和性が非常に高いです
    - **目的**: 従来のPDF署名 (PAdES) やXML署名 (XAdES) と同等の法的な証拠能力（否認防止性や長期検証性）を、JSONデータに対しても持たせることを目的としています
    
    **主な内容**
    
    - JWSヘッダーに追加する署名属性（署名時刻、証明書参照情報など）の定義
    - 相互運用性を高めるための「ベースライン署名（Baseline Signatures）」のプロファイル定義
    
    **TS 119 602との関係**
    
    - TS 119 602のJSONバインディングにおいて、リスト全体に対する署名形式として使用されます
    - EUDIウォレットなどモバイル環境での軽量な署名検証を実現します
```

### 実装レベルの仕様
#### 必須ヘッダー属性
compact JAdES Baseline B として認められるために、JOSEヘッダーに以下を含めることが必須：

1. **`sigT`** (Signing Time): 署名作成日時
2. **`x5t#S256`** (Certificate Hash): 署名に使用したX.509証明書のSHA-256ハッシュ値
3. **`crit`** (Critical): 重要ヘッダーパラメータ。`["sigT", "x5t#S256"]` などを指定し、検証者がこれらの拡張フィールドを必ず検証することを強制

#### `sigT` 検証ロジック

`jose` ライブラリの `critical` オプションでエラーを回避した後、アプリケーション側で行うべき **JAdES固有の時刻検証ロジック（`sigT` 検証）** の実装が必要である。

JAdES Baseline-B における `sigT` (Signing Time) の検証とは、主に以下の3点を確認することである：

1. **存在確認:** `protectedHeader` 内に `sigT` が確実に含まれているか
2. **形式確認:** フォーマットが正しいか（通常は ISO 8601 / RFC 3339 形式）
3. **矛盾の確認:** 署名時刻が「未来」になっていないか、または「証明書の有効期間外」ではないか

実装サンプルコード (TypeScript)

```tsx
import * as jose from 'jose';

/**
 * JAdES署名を検証し、かつ独自のsigT検証を行う関数
 */
async function verifyJadesSignature(jws: string, publicKey: jose.KeyLike | Uint8Array) {
  // 1. joseライブラリによる暗号学的な署名検証
  const { payload, protectedHeader } = await jose.compactVerify(
    jws,
    publicKey,
    {
      critical: {
        'sigT': true,      // 署名時刻
        'x5t#S256': true   // 証明書ハッシュ
      }
    }
  );

  // 2. アプリケーション側でのカスタム検証 (sigT)
  validateSigningTime(protectedHeader);

  return { payload, protectedHeader };
}

/**
 * sigT (Signing Time) の妥当性を検証するロジック
 */
function validateSigningTime(header: jose.ProtectedHeaderParameters) {
  // --- A. 存在確認 ---
  if (!header.sigT || typeof header.sigT !== 'string') {
    throw new Error("JAdES Verification Failed: 'sigT' header is missing or invalid.");
  }

  // --- B. 形式確認 (ISO 8601 / RFC 3339) ---
  const signingDate = new Date(header.sigT);
  if (isNaN(signingDate.getTime())) {
    throw new Error(`JAdES Verification Failed: Invalid 'sigT' format (${header.sigT}).`);
  }

  // --- C. 時刻の妥当性確認 (Future Check) ---
  const now = new Date();
  const CLOCK_SKEW_MS = 5 * 60 * 1000; // 5分のクロック・スキュー許容
  
  if (signingDate.getTime() > (now.getTime() + CLOCK_SKEW_MS)) {
    throw new Error(
      `JAdES Verification Failed: 'sigT' is in the future. Claimed: ${header.sigT}, Server Time: ${now.toISOString()}`
    );
  }
  
  return signingDate;
}
```

**なぜこのロジックが必要か**:

- **`crit` ヘッダーの意味を守るため**: `crit: ["sigT"]` は「署名検証者は sigT の意味を理解し、その値を評価しなければならない」という命令である。ライブラリのオプションでエラーをスルーしただけでは「無視」したことになってしまうため、値を取り出して評価する必要がある
- **リプレイ攻撃や誤った時刻の排除**: 攻撃者がサーバーの時計を狂わせて未来の日付で署名を作ったりした場合の混乱を防ぐ

**さらに厳密に行う場合（本番運用向け）**:

X.509証明書を使って検証している場合、`sigT` の値が署名に使われた証明書の有効期間内（NotBefore と NotAfter の間）に収まっているかも確認すべきである。

#### `x5t#S256` 検証ロジック

`sigT` が「いつ署名したか」を保証するのに対し、`x5t#S256` は **「どの証明書を使って署名したか」** を保証するためのパラメータである。

**`x5t#S256` とは**:

- **正式名称:** X.509 Certificate SHA-256 Thumbprint
- **定義:** IETF RFC 7515 (JWS) Section 4.1.8
- **値:** 署名に使用された X.509証明書（DER形式）の SHA-256 ハッシュ値を計算し、Base64URLエンコードした文字列

**なぜ必要なのか**:

JAdES Baseline-B では、「署名の作成に使用された証明書への参照」を署名データ自体に保護された状態で含めることが必須である。`x5t#S256` をヘッダーに含め、それを署名対象（Protected Header）にすることで、「この特定の証明書を使って行った署名である」という事実を固定し、後から証明書がすり替えられること（証明書の置換攻撃）を防ぐ。

実装サンプルコード (TypeScript)

```tsx
import * as jose from 'jose';
import * as crypto from 'crypto';

/**
 * JAdES署名検証（sigT と x5t#S256 の両方を検証）
 * @param jws 受信したJWS文字列
 * @param signingCertificateX509Pem 署名者のX.509証明書(PEM形式)
 */
async function verifyJadesSignatureFull(jws: string, signingCertificateX509Pem: string) {
  // PEMから公開鍵オブジェクトを生成
  const publicKey = await jose.importX509(signingCertificateX509Pem, 'ES256');

  // 1. joseライブラリによる検証
  const { payload, protectedHeader } = await jose.compactVerify(
    jws,
    publicKey,
    {
      critical: {
        'sigT': true,
        'x5t#S256': true
      }
    }
  );

  // 2. カスタム検証: sigT (時刻)
  validateSigningTime(protectedHeader);

  // 3. カスタム検証: x5t#S256 (証明書の指紋一致確認)
  validateCertificateThumbprint(protectedHeader, signingCertificateX509Pem);

  return { payload, protectedHeader };
}

/**
 * ヘッダー内の x5t#S256 が、実際に使われた証明書のハッシュと一致するか検証する
 */
function validateCertificateThumbprint(header: jose.ProtectedHeaderParameters, certPem: string) {
  // A. ヘッダーに x5t#S256 があるか
  if (!header['x5t#S256']) {
    throw new Error("JAdES Verification Failed: 'x5t#S256' header is missing.");
  }

  // B. 実際の証明書からハッシュ値を計算する
  // 1. PEMのヘッダー/フッターと改行を削除してBase64本文だけにする
  const certBody = certPem
    .replace(/-----BEGIN CERTIFICATE-----/g, '')
    .replace(/-----END CERTIFICATE-----/g, '')
    .replace(/\s/g, '');
  
  // 2. Base64をデコードしてバイナリ(DER)にする
  const certDer = Buffer.from(certBody, 'base64');

  // 3. SHA-256ハッシュを計算
  const hash = crypto.createHash('sha256').update(certDer).digest();

  // 4. Base64URLエンコードする
  const calculatedThumbprint = hash.toString('base64url');

  // C. 比較 (ヘッダーの値 vs 計算値)
  if (calculatedThumbprint !== header['x5t#S256']) {
    throw new Error(
      `JAdES Verification Failed: Certificate thumbprint mismatch.\n` +
      `Header: ${header['x5t#S256']}\n` +
      `Actual: ${calculatedThumbprint}`
    );
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

## 作業ドキュメント
対応内容がまとまったら、まずは進捗が把握できるように作業ドキュメントを作成して下さい。
- docs/work/yyyy-mm-dd-xxx.md