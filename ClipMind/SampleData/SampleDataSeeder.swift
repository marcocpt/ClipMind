import Foundation

/// 示例数据注入器。
///
/// 在首启引导完成后调用，生成覆盖 11 种 ContentType 的示例 ClipItem，
/// 通过 LocalEmbeddingService 实时计算 embeddings，写入 EncryptedStore。
///
/// 幂等：注入前检查 countSamples()，已有示例则跳过。
final class SampleDataSeeder {
    /// 注入示例数据（幂等）。
    ///
    /// - Parameters:
    ///   - store: 加密存储
    ///   - embeddingService: 嵌入服务（用于实时计算 embeddings）
    static func seedIfNeeded(store: EncryptedStore, embeddingService: LocalEmbeddingService) {
        do {
            let existing = try store.countSamples()
            if existing > 0 {
                LogCategory.app.info("示例数据已存在（\(existing) 条），跳过注入")
                return
            }

            let samples = ClipTestData.sampleClipsForSeeding
            LogCategory.app.info("开始注入示例数据，共 \(samples.count) 条")

            let startTime = Date()

            for item in samples {
                // 实时计算 embeddings，保证与设备 CoreML/NLEmbedding 模型一致
                // 示例数据全部为 .text，通过模式匹配提取文本
                var seededItem = item
                if case .text(let text) = item.content {
                    if let doubleEmbeddings = embeddingService.embed(text) {
                        // LocalEmbeddingService.embed 返回 [Double]?，需转为 [Float] 存入 ClipItem.embeddings
                        seededItem.embeddings = doubleEmbeddings.map { Float($0) }
                    } else {
                        // 单条 embeddings 失败不阻塞，该条仍入库（搜索时自动跳过无 embeddings 的条目）
                        LogCategory.app.warning("示例数据 embeddings 计算失败: \(item.id)")
                    }
                }
                try store.save(seededItem)
            }

            let elapsed = Date().timeIntervalSince(startTime) * 1000
            LogCategory.app.info("示例数据注入完成，耗时 \(Int(elapsed))ms")

            // 全部注入完成后统一发一次通知（非每条发一次，避免 ClipStore 多次 loadClips 抖动）
            NotificationCenter.default.post(
                name: ClipCaptureService.clipDidUpdateNotification,
                object: nil
            )
        } catch {
            // 注入失败仅记录 error 日志，不阻塞主窗口显示，不影响真实捕获
            LogCategory.app.error("示例数据注入失败: \(error.localizedDescription)")
        }
    }
}
