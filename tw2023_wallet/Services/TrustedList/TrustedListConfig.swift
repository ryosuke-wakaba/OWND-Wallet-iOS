//
//  TrustedListConfig.swift
//  tw2023_wallet
//
//  Configuration models for trusted list (LoTE) settings.
//

import Foundation

// MARK: - New Configuration Models (context-based)

/// LoTE設定ファイルのルート構造（新形式）
struct TrustedListConfig: Codable {
    let lotes: [String: LoTEConfig]
}

/// 個別のLoTE設定（新形式）
/// - url: トラストリストのURL
/// - context: 検索コンテキスト（用途別の検索条件）
/// - services: (後方互換性) 旧形式のサービス設定
struct LoTEConfig: Codable {
    let url: String
    let context: [String: ContextConfig]?
    let services: [String: ServiceConfig]?  // 後方互換性のため残す
}

/// コンテキスト設定
/// 各コンテキストは特定の用途（例: AccessCertificateVerification）を表す
struct ContextConfig: Codable {
    let condition: ConditionConfig
}

/// 検索条件
/// トラストリストからサービスを特定するための条件
struct ConditionConfig: Codable {
    let loteType: String?
    let serviceTypeIdentifier: String?
    let status: String?
}

/// サービス設定（後方互換性のため残す）
struct ServiceConfig: Codable {
    let identifier: String
}

// MARK: - Search Info Models

/// VCIMetadataClient等に渡すLoTE検索情報（後方互換性のため残す）
struct LoTESearchInfo {
    let url: URL
    let serviceType: String?  // nil = フィルタリングなし

    init(url: URL, serviceType: String? = nil) {
        self.url = url
        self.serviceType = serviceType
    }
}

/// 新しいLoTE検索情報（複数条件対応）
struct LoTEContextSearchInfo {
    let url: URL
    let contextName: String
    let condition: SearchCondition

    struct SearchCondition {
        let loteType: String?
        let serviceTypeIdentifier: String?
        let status: String?

        init(loteType: String? = nil, serviceTypeIdentifier: String? = nil, status: String? = nil) {
            self.loteType = loteType
            self.serviceTypeIdentifier = serviceTypeIdentifier
            self.status = status
        }
    }
}

// MARK: - Configuration Loader

enum TrustedListConfigLoader {
    /// 設定ファイル名
    static let configFileName = "TrustedListConfig.json"

    /// 設定ファイルを読み込む
    static func loadConfig() -> TrustedListConfig? {
        guard let resourcePath = Bundle.main.resourcePath else {
            print("TrustedListConfigLoader: [ERROR] Unable to get resource path")
            return nil
        }

        let configPath = (resourcePath as NSString).appendingPathComponent(configFileName)

        guard FileManager.default.fileExists(atPath: configPath) else {
            print("TrustedListConfigLoader: [WARN] \(configFileName) not found")
            return nil
        }

        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: configPath))
            let config = try JSONDecoder().decode(TrustedListConfig.self, from: data)
            print("TrustedListConfigLoader: Loaded config with \(config.lotes.count) LoTE(s)")
            return config
        } catch {
            print("TrustedListConfigLoader: [ERROR] Failed to parse config: \(error)")
            return nil
        }
    }

    // MARK: - New API (context-based)

    /// 指定されたLoTE名とコンテキスト名からLoTEContextSearchInfo配列を生成
    /// - Parameter loteContextPairs: (LoTE名, コンテキスト名)のペア配列
    /// - Returns: LoTEContextSearchInfo配列
    static func createContextSearchInfos(
        _ loteContextPairs: [(loteName: String, contextName: String)]
    ) -> [LoTEContextSearchInfo] {
        guard let config = loadConfig() else {
            return []
        }

        var searchInfos: [LoTEContextSearchInfo] = []

        for (loteName, contextName) in loteContextPairs {
            guard let loteConfig = config.lotes[loteName] else {
                print("TrustedListConfigLoader: [WARN] LoTE '\(loteName)' not found in config")
                continue
            }

            guard let url = URL(string: loteConfig.url) else {
                print("TrustedListConfigLoader: [WARN] Invalid URL for LoTE '\(loteName)': \(loteConfig.url)")
                continue
            }

            guard let contexts = loteConfig.context,
                  let contextConfig = contexts[contextName] else {
                print("TrustedListConfigLoader: [WARN] Context '\(contextName)' not found in LoTE '\(loteName)'")
                continue
            }

            let condition = LoTEContextSearchInfo.SearchCondition(
                loteType: contextConfig.condition.loteType,
                serviceTypeIdentifier: contextConfig.condition.serviceTypeIdentifier,
                status: contextConfig.condition.status
            )

            searchInfos.append(LoTEContextSearchInfo(
                url: url,
                contextName: contextName,
                condition: condition
            ))
        }

        return searchInfos
    }

    // MARK: - Legacy API (for backward compatibility)

    /// 指定されたLoTE名とサービス名のペア配列からLoTESearchInfo配列を生成
    /// - Parameter loteServicePairs: (LoTE名, サービス名)のペア配列（例: [("jp-lote", "oid4vci")]）
    /// - Returns: LoTESearchInfo配列
    @available(*, deprecated, message: "Use createContextSearchInfos instead")
    static func createSearchInfos(
        _ loteServicePairs: [(loteName: String, serviceName: String)]
    ) -> [LoTESearchInfo] {
        guard let config = loadConfig() else {
            return []
        }

        var searchInfos: [LoTESearchInfo] = []

        for (loteName, serviceName) in loteServicePairs {
            guard let loteConfig = config.lotes[loteName] else {
                print("TrustedListConfigLoader: [WARN] LoTE '\(loteName)' not found in config")
                continue
            }

            guard let url = URL(string: loteConfig.url) else {
                print("TrustedListConfigLoader: [WARN] Invalid URL for LoTE '\(loteName)': \(loteConfig.url)")
                continue
            }

            let serviceType = loteConfig.services?[serviceName]?.identifier

            searchInfos.append(LoTESearchInfo(url: url, serviceType: serviceType))
        }

        return searchInfos
    }

    /// 全てのLoTEからLoTESearchInfo配列を生成（サービスタイプ指定なし）
    @available(*, deprecated, message: "Use createContextSearchInfos instead")
    static func createAllSearchInfos() -> [LoTESearchInfo] {
        guard let config = loadConfig() else {
            return []
        }

        return config.lotes.compactMap { (_, loteConfig) in
            guard let url = URL(string: loteConfig.url) else {
                return nil
            }
            return LoTESearchInfo(url: url, serviceType: nil)
        }
    }
}
