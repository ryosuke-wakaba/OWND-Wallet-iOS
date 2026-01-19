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

/// 個別のLoTE設定
/// - url: トラストリストのURL
/// - context: 検索コンテキスト（用途別の検索条件）
struct LoTEConfig: Codable {
    let url: String
    let context: [String: ContextConfig]?
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

// MARK: - Search Info Models

/// LoTE検索情報（複数条件対応）
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

    /// 指定されたコンテキスト名からLoTEContextSearchInfo配列を生成
    /// 全てのLoTEを検索して、指定されたコンテキストを持つものを返す
    /// - Parameter contextName: 検索するコンテキスト名（例: "AccessCertificateVerification"）
    /// - Returns: LoTEContextSearchInfo配列
    static func createContextSearchInfos(
        contextName: String
    ) -> [LoTEContextSearchInfo] {
        guard let config = loadConfig() else {
            return []
        }

        var searchInfos: [LoTEContextSearchInfo] = []

        for (loteName, loteConfig) in config.lotes {
            guard let url = URL(string: loteConfig.url) else {
                print("TrustedListConfigLoader: [WARN] Invalid URL for LoTE '\(loteName)': \(loteConfig.url)")
                continue
            }

            guard let contexts = loteConfig.context,
                  let contextConfig = contexts[contextName] else {
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

        if searchInfos.isEmpty {
            print("TrustedListConfigLoader: [WARN] Context '\(contextName)' not found in any LoTE")
        }

        return searchInfos
    }
}
