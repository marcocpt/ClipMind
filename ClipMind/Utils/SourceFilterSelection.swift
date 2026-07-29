import Foundation

/// 来源过滤选中状态管理。
///
/// 管理「全部」选项与各应用 Checkbox 的联动逻辑。
struct SourceFilterSelection
{
    /// 所有可用的来源应用名称集合。
    let allApps: Set<String>

    /// 当前选中的来源应用名称集合。
    var selectedSources: Set<String>

    /// 是否处于「全部」选中状态。
    var isAllSelected: Bool
    {
        selectedSources == allApps
    }

    /// 初始化，默认「全部」选中。
    init(allApps: Set<String>)
    {
        self.allApps = allApps
        self.selectedSources = allApps
    }

    /// 切换「全部」选项。
    mutating func toggleAll()
    {
        selectedSources = allApps
    }

    /// 切换某个来源应用的选中状态。
    mutating func toggleSource(_ app: String)
    {
        if isAllSelected
        {
            selectedSources = [app]
        } else {
            if selectedSources.contains(app)
            {
                selectedSources.remove(app)
            } else {
                selectedSources.insert(app)
            }
        }
    }

    /// 取消选中某个来源应用。
    mutating func deselectSource(_ app: String)
    {
        selectedSources.remove(app)
    }

    /// 重置为「全部」选中。
    mutating func resetToAll()
    {
        selectedSources = allApps
    }
}
