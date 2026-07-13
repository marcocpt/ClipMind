import SwiftUI

/// 黑名单管理视图（T3.5）
///
/// 对应设计规范 3.8 节应用黑名单管理和 UI-AC-17。
/// 支持查看、添加、删除黑名单条目（含默认条目和自定义条目）。
struct BlacklistManagementView: View {
    @State private var blacklistService = BlacklistService()
    @State private var newBundleId = ""
    @State private var newAppName = ""
    @State private var showAddForm = false

    var body: some View {
        Section("应用黑名单") {
            blacklistList

            if showAddForm {
                addForm
            } else {
                Button("添加自定义应用") {
                    showAddForm = true
                }
                .accessibilityIdentifier("addBlacklistButton")
            }
        }
        .onAppear {
            loadDefaultEntriesIfNeeded()
        }
    }

    // MARK: - 黑名单列表

    private var blacklistList: some View {
        Group {
            if blacklistService.getAll().isEmpty {
                Text("暂无黑名单条目")
                    .foregroundColor(.secondary)
                    .font(.caption)
            } else {
                ForEach(blacklistService.getAll()) { entry in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(entry.appName)
                                .font(.body)
                            Text(entry.bundleId)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if entry.isDefault {
                            Text("默认")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        Button(role: .destructive) {
                            removeEntry(entry)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("removeBlacklist-\(entry.id.uuidString)")
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    // MARK: - 添加表单

    private var addForm: some View {
        VStack(alignment: .leading) {
            TextField("Bundle ID（如 com.example.app 或 com.icbc.*）", text: $newBundleId)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("newBlacklistBundleId")

            TextField("应用名称", text: $newAppName)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("newBlacklistAppName")

            HStack {
                Button("添加") {
                    addEntry()
                }
                .disabled(newBundleId.isEmpty || newAppName.isEmpty)
                .accessibilityIdentifier("confirmAddBlacklistButton")

                Button("取消") {
                    showAddForm = false
                    newBundleId = ""
                    newAppName = ""
                }
                .accessibilityIdentifier("cancelAddBlacklistButton")
            }
        }
    }

    // MARK: - 业务逻辑

    /// 首次加载时注入默认黑名单条目
    private func loadDefaultEntriesIfNeeded() {
        guard blacklistService.getAll().isEmpty else { return }
        for entry in DefaultBlacklist.entries {
            blacklistService.add(entry)
        }
        LogCategory.privacy.info("已加载 \(DefaultBlacklist.entries.count) 个默认黑名单条目")
    }

    /// 添加自定义黑名单条目。
    ///
    /// 按 bundleId 去重，已存在相同 bundleId 的条目时跳过添加并记录日志。
    private func addEntry() {
        guard !blacklistService.getAll().contains(where: { $0.bundleId == newBundleId }) else {
            LogCategory.privacy.info("黑名单已存在 bundleId: \(newBundleId)，跳过添加")
            newBundleId = ""
            newAppName = ""
            showAddForm = false
            return
        }
        blacklistService.addCustom(bundleId: newBundleId, appName: newAppName)
        LogCategory.privacy.info("添加自定义黑名单: \(newBundleId)")
        newBundleId = ""
        newAppName = ""
        showAddForm = false
    }

    /// 移除黑名单条目
    private func removeEntry(_ entry: BlacklistEntry) {
        blacklistService.remove(id: entry.id)
        LogCategory.privacy.info("移除黑名单: \(entry.bundleId)")
    }
}
