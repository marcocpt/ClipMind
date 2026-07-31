#if CLIPMIND_DEV
import Foundation

/// Phase 5/6：Sandbox upgrade seed 支持。
///
/// 仅在 `CLIPMIND_DEV + --UITEST_UPGRADE_SEED_DEFAULT_PATH` 下启用，用于在 disposable
/// 测试账号中向旧生产默认路径 `${ApplicationSupport}/ClipMind` 写入 upgrade fixture，
/// 供 `SandboxUpgradeUITests` 验证 App Sandbox 启用后的容器迁移。
///
/// 启用条件（缺一项立即以固定错误码退出）：
/// 1. `CLIPMIND_DEV` 编译条件；
/// 2. `--UITEST_UPGRADE_SEED_DEFAULT_PATH` 启动参数；
/// 3. 环境变量 `CLIPMIND_ALLOW_DEFAULT_PATH_SEED=1`；
/// 4. 当前 home 存在 `.clipmind-f114-disposable-upgrade-account` marker；
/// 5. app 当前没有 Sandbox entitlement（Phase 5 已提交 unsandboxed SHA）。
///
/// 普通 Phase 2～5 Smoke 永远使用隔离 DB，不设置这组 marker/env，不能污染开发者真实数据。
enum SandboxUpgradeSeedSupport
{
    /// 固定退出错误码：条件不满足时使用。
    static let exitCodeMissingCondition: Int32 = 42

    /// 固定 marker 文件名。
    static let disposableMarkerName = ".clipmind-f114-disposable-upgrade-account"

    /// 环境变量名。
    static let allowSeedEnvKey = "CLIPMIND_ALLOW_DEFAULT_PATH_SEED"

    /// 检查是否满足 upgrade seed 条件。
    ///
    /// 必须同时满足：启动参数、环境变量、marker 文件、无 Sandbox entitlement。
    static var canSeedDefaultPath: Bool
    {
        guard TagUITestSupport.shouldSeedUpgradeDefaultPath else
        {
            return false
        }
        guard ProcessInfo.processInfo.environment[allowSeedEnvKey] == "1" else
        {
            return false
        }
        let home = NSHomeDirectory()
        let markerPath = (home as NSString).appendingPathComponent(disposableMarkerName)
        guard FileManager.default.fileExists(atPath: markerPath) else
        {
            return false
        }
        // Phase 5 提交时未启用 Sandbox，entitlement 为 false。
        // Phase 6 启用 Sandbox 后此路径不再可用，由调用方在 unsandboxed worktree 构建。
        return !isSandboxed
    }

    /// 当前进程是否启用 App Sandbox。
    private static var isSandboxed: Bool
    {
        // App Sandbox 启用后，Bundle.main 有 com.apple.security.app-sandbox entitlement。
        // 这里通过文件系统路径判断：Sandbox 下 NSHomeDirectory 指向容器目录。
        // 更可靠的方式是检查 entitlement，但 Phase 5 的 unsandboxed 构建无此 entitlement。
        // 简化判断：检查是否存在 Sandbox 容器目录。
        let home = NSHomeDirectory()
        return home.contains("/Library/Containers/")
    }

    /// 在旧默认路径写入 upgrade fixture，执行 SQLite checkpoint，关闭连接并退出。
    ///
    /// 调用方必须在 disposable 账号中运行，且当前 worktree 构建的是 unsandboxed SHA。
    /// 写入成功后以退出码 0 退出；条件不满足以 `exitCodeMissingCondition` 退出。
    static func seedDefaultPathAndExit()
    {
        guard canSeedDefaultPath else
        {
            LogCategory.app.error("SandboxUpgradeSeedSupport condition not met")
            exit(exitCodeMissingCondition)
        }

        // 向旧默认路径写入 fixture。
        // 使用生产 EncryptedStore() 构造，它解析 NSHomeDirectory/ApplicationSupport/ClipMind。
        do
        {
            let store = try EncryptedStore()
            for clip in ClipTestData.tagMigrationFixtureClips
            {
                try store.save(clip)
            }
            // SQLite checkpoint：关闭连接前确保 WAL 写入主数据库。
            // EncryptedStore 的 deinit 会关闭连接；这里显式触发 checkpoint。
            try store.checkpoint()
        } catch
        {
            LogCategory.app.error("SandboxUpgradeSeedSupport seed failed")
            exit(exitCodeMissingCondition)
        }

        LogCategory.app.info("SandboxUpgradeSeedSupport seed completed")
        exit(0)
    }
}
#endif
