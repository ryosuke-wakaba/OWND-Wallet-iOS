//
//  TrustedListConfig.swift
//  tw2023_wallet
//
//  Configuration models for trusted list (LoTE) settings.
//

import Foundation

/// LoTE設定ファイルのルート構造
struct TrustedListConfig: Codable {
    let lotes: [String: LoTEConfig]
}

/// 個別のLoTE設定
struct LoTEConfig: Codable {
    let url: String
    let services: [String: ServiceConfig]
}

/// サービス設定
struct ServiceConfig: Codable {
    let identifier: String
}

/// VCIMetadataClient等に渡すLoTE検索情報
struct LoTESearchInfo {
    let url: URL
    let serviceType: String?  // nil = フィルタリングなし

    init(url: URL, serviceType: String? = nil) {
        self.url = url
        self.serviceType = serviceType
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

    /// 指定されたLoTE名とサービス名のペア配列からLoTESearchInfo配列を生成
    /// - Parameter loteServicePairs: (LoTE名, サービス名)のペア配列（例: [("jp-lote", "oid4vci")]）
    /// - Returns: LoTESearchInfo配列
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

            let serviceType = loteConfig.services[serviceName]?.identifier

            searchInfos.append(LoTESearchInfo(url: url, serviceType: serviceType))
        }

        return searchInfos
    }

    /// 全てのLoTEからLoTESearchInfo配列を生成（サービスタイプ指定なし）
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
