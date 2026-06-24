import Foundation

enum L10n {

    enum Lang { case zh, zhTW, en }

    static var lang: Lang {
        switch Settings.shared.language {
        case "zh-TW": return .zhTW
        case "en":    return .en
        default:      return .zh
        }
    }

    // true for either Chinese variant — handy for CJK layout decisions
    static var isChinese: Bool { lang == .zh || lang == .zhTW }

    private static func s(_ zh: String, _ zhTW: String, _ en: String) -> String {
        switch lang {
        case .zh:   return zh
        case .zhTW: return zhTW
        case .en:   return en
        }
    }

    // MARK: - Window / tab titles

    static var prefsTitle:    String { s("Klok 设置",    "Klok 設定",    "Klok Preferences") }
    static var tabGeneral:    String { s("通用",          "一般",          "General") }
    static var tabAppearance: String { s("外观",          "外觀",          "Appearance") }
    static var tabAlarms:     String { s("提醒",          "提醒",          "Reminders") }
    static var tabMenuBar:    String { s("日历",          "日曆",          "Calendar") }
    static var tabPlugins:    String { s("插件",          "外掛",          "Plugins") }

    // MARK: - General tab

    static var clockSize:        String { s("时钟大小：",     "時鐘大小：",     "Clock Size:") }
    static var opacity:          String { s("不透明度：",     "不透明度：",     "Opacity:") }
    static var alwaysOnTop:      String { s("总在最前面",     "總在最前面",     "Always on Top") }
    static var pinToDesktop:     String { s("固定到桌面",     "固定到桌面",     "Pin to Desktop") }
    static var embedInDesktop:   String { s("嵌入桌面",       "嵌入桌面",       "Embed in Desktop") }
    static var clickThrough:     String { s("点击无动作",     "點擊無動作",     "Click-through") }
    static var hoverTransparent: String { s("鼠标经过时透明", "滑鼠經過時透明", "Transparent on Hover") }
    static var launchAtLogin:    String { s("登录时启动",     "登入時啟動",     "Launch at Login") }
    static var showSecondHand:   String { s("显示秒针",       "顯示秒針",       "Show Second Hand") }
    static var secondHandJump:   String { s("秒针跳跃",       "秒針跳動",       "Jumping Second") }
    static var showAmPm:         String { s("显示 AM/PM",     "顯示 AM/PM",     "Show AM/PM") }
    static var showDate:         String { s("显示日期",       "顯示日期",       "Show Date") }
    static var language:         String { s("语言：",         "語言：",         "Language:") }

    // Language option labels (shown in segmented control)
    static var langZH:   String { "简体" }
    static var langZHTW: String { "繁體" }
    static var langEN:   String { "EN" }

    // MARK: - Appearance tab

    static var searchSkins:     String { s("搜索皮肤…",       "搜尋皮膚…",       "Search skins…") }
    static var skinDirLabel:    String { s("皮肤目录：",       "皮膚目錄：",       "Skin directory:") }
    static var skinDirNone:     String { s("（使用内置皮肤）", "（使用內建皮膚）", "(using built-in skins)") }
    static var skinDirBrowse:   String { s("浏览…",           "瀏覽…",           "Browse…") }
    static var skinDirClear:    String { s("清除",             "清除",             "Clear") }
    static var styleCircle:   String { s("圆圈",      "圓圈",      "Circle") }
    static var stylePage:     String { s("日历页",    "日曆頁",    "Page") }
    static var styleSymbol:   String { s("图标",      "圖示",      "Symbol") }
    static var styleBadge:    String { s("日期牌",    "日期牌",    "Badge") }
    static var badgeSatPreview: String { s("周六",    "週六",      "SAT") }

    // MARK: - Menu bar / calendar tab

    static var menuBarSection:       String { s("菜单栏",            "選單列",            "Menu Bar") }
    static var menuBarClockSection:  String { s("菜单栏时钟",        "選單列時鐘",        "Menu Bar Clock") }
    static var menuBarShowSeconds:   String { s("显示秒数",          "顯示秒數",          "Show Seconds") }
    static var menuBar24Hour:        String { s("24 小时制",         "24 小時制",         "24-Hour Time") }
    static var menuBarFmtLabel:      String { s("格式：",            "格式：",            "Format:") }
    static var menuBarFmtPreview:    String { s("预览：",            "預覽：",            "Preview:") }
    static var menuBarFmtReset:      String { s("重置",              "重設",              "Reset") }
    static var menuBarFmtHelp:       String { s("格式说明",          "格式說明",          "Format Tokens") }
    static var menuBarFmtDefault:    String { s("M月d日 EEE HH:mm", "M月d日 EEE HH:mm", "E M/d HH:mm") }
    static var menuBarIconPosLabel:  String { s("图标位置：",        "圖示位置：",        "Icon position:") }
    static var menuBarIconPosLeft:   String { s("文字左侧",          "文字左側",          "Left of text") }
    static var menuBarIconPosRight:  String { s("文字右侧",          "文字右側",          "Right of text") }
    static var menuBarIconPosHidden: String { s("不显示",            "不顯示",            "Hidden") }

    // MARK: - Calendar section

    static var calSection:          String { s("日历",           "日曆",           "Calendar") }
    static var calShowEventDots:    String { s("显示事件标记",   "顯示事件標記",   "Show event markers") }
    static var calColorfulDots:     String { s("使用日历颜色",   "使用日曆顏色",   "Use calendar colors") }
    static var calShowEventLoc:     String { s("显示事件地点",   "顯示事件地點",   "Show event location") }
    static var calShowInactiveDays: String { s("显示非本月日期", "顯示非本月日期", "Show days outside month") }
    static var calShowWeekNumbers:  String { s("显示周数",       "顯示週數",       "Show week numbers") }
    static var calFontSize:         String { s("日历大小",       "日曆大小",       "Calendar size") }
    static var calToday:            String { s("今天",           "今天",           "Today") }

    static var calWeekdays: [String] {
        switch lang {
        case .zh, .zhTW: return ["日", "一", "二", "三", "四", "五", "六"]
        case .en:        return ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
        }
    }

    static var calWeekdaysFull: [String] {
        switch lang {
        case .zh:   return ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        case .zhTW: return ["週日", "週一", "週二", "週三", "週四", "週五", "週六"]
        case .en:   return ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        }
    }

    static var calWeekdaysSingle: [String] {
        switch lang {
        case .zh, .zhTW: return ["日", "一", "二", "三", "四", "五", "六"]
        case .en:        return ["S", "M", "T", "W", "T", "F", "S"]
        }
    }

    // MARK: - Reminder list

    static var remindersSorted: String { s("提醒信息按时间先后排列", "提醒訊息按時間先後排列", "Reminders sorted by time") }
    static var reminderColName: String { s("名称",     "名稱",     "Name") }
    static var reminderColTime: String { s("时间",     "時間",     "Time") }
    static var reminderColDate: String { s("日期",     "日期",     "Date") }
    static var reminderAdd:     String { s("添加(I)…", "新增(I)…", "Add(I)…") }
    static var reminderEdit:    String { s("编辑(E)…", "編輯(E)…", "Edit(E)…") }
    static var reminderDelete:  String { s("删除(D)",  "刪除(D)",  "Delete(D)") }
    static var reminderTest:    String { s("测试(T)",  "測試(T)",  "Test(T)") }

    // MARK: - Reminder editor

    static var reminderEditorTitle: String { s("提醒信息编辑器", "提醒訊息編輯器", "Reminder Editor") }
    static var reminderName:      String { s("名称：",       "名稱：",       "Name:") }
    static var reminderType:      String { s("类型：",       "類型：",       "Type:") }
    static var reminderTime:      String { s("时间：",       "時間：",       "Time:") }
    static var reminderDate:      String { s("日期：",       "日期：",       "Date:") }
    static var reminderShowWin:   String { s("显示提醒窗口", "顯示提醒視窗", "Show reminder window") }
    static var reminderMessage:   String { s("提醒内容：",   "提醒內容：",   "Message:") }
    static var reminderInterval:  String { s("间隔：",       "間隔：",       "Interval:") }
    static var reminderMinutes:   String { s("分钟",         "分鐘",         "min(s)") }
    static var reminderMonthDay:  String { s("几日：",       "幾日：",       "Day:") }
    static var reminderYearMonth: String { s("月：",         "月：",         "Month:") }
    static var reminderYearDay:   String { s("日：",         "日：",         "Day:") }
    static var reminderWeekOn:    String { s("周几：",       "週幾：",       "On:") }
    static var repeatOnce:        String { s("一次",         "一次",         "Once") }
    static var repeatDaily:       String { s("每天",         "每天",         "Daily") }
    static var repeatWeekly:      String { s("每周",         "每週",         "Weekly") }
    static var repeatMonthly:     String { s("每月",         "每月",         "Monthly") }
    static var repeatYearly:      String { s("每年",         "每年",         "Yearly") }
    static var repeatMinutely:    String { s("每分钟",       "每分鐘",       "Every Minute") }
    static var btnOK:             String { s("确定",         "確定",         "OK") }
    static var btnCancel:         String { s("取消",         "取消",         "Cancel") }

    // MARK: - Reminder popup

    static var alarmTitle:      String { s("Klok 提醒", "Klok 提醒", "Klok Reminder") }
    static var reminderDismiss: String { s("关闭",       "關閉",       "Dismiss") }

    // MARK: - Context / status menus

    static var menuPrefs:       String { s("设置…",      "設定…",      "Preferences…") }
    static var menuReminders:   String { s("提醒…",      "提醒…",      "Reminders…") }
    static var menuAlwaysOnTop: String { s("总在最前面", "總在最前面", "Always on Top") }
    static var menuPinDesktop:  String { s("固定到桌面", "固定到桌面", "Pin to Desktop") }
    static var menuQuit:        String { s("退出 Klok",  "結束 Klok",  "Quit Klok") }

    // MARK: - Plugins

    static var pluginListTitle:              String { s("插件列表", "外掛列表", "List of plugins") }
    static var pluginConfigure:              String { s("配置", "設定", "Configure") }
    static var pluginRestartHint:            String { s("插件启用或停用将在下次启动 Klok 后生效。", "外掛啟用或停用將在下次啟動 Klok 後生效。", "Plugin enablement changes take effect the next time you run Klok.") }
    static var pluginRestartTitle:           String { s("插件设置已更改", "外掛設定已變更", "Plugin settings changed") }
    static var pluginRestartMessage:         String { s("插件启用或停用需要重启 Klok 后生效。", "外掛啟用或停用需要重新啟動 Klok 後生效。", "Plugin enablement changes require restarting Klok.") }
    static var pluginRestartNow:             String { s("立即重启", "立即重新啟動", "Restart Now") }
    static var pluginRestartLater:           String { s("稍后", "稍後", "Later") }
    static var pluginRestartUnavailable:     String { s("当前运行方式不支持自动重启，请手动退出并重新打开 Klok。", "目前執行方式不支援自動重新啟動，請手動結束並重新開啟 Klok。", "Automatic restart is unavailable for this launch mode. Quit and reopen Klok manually.") }
    static var pluginRestartFailed:          String { s("无法重启 Klok", "無法重新啟動 Klok", "Unable to restart Klok") }
    static var pluginNoConfiguration:        String { s("这个插件没有配置项。", "這個外掛沒有設定項。", "This plugin has no configuration.") }
    static var pluginScreenshotMenu:         String { s("截图…", "截圖…", "Screenshot…") }
    static var pluginScreenshotTitle:        String { s("截图", "截圖", "Screenshot") }
    static var pluginScreenshotCopied:       String { s("截图已复制到剪贴板。", "截圖已複製到剪貼簿。", "Screenshot copied to clipboard.") }
    static var pluginScreenshotFailed:       String { s("截图失败", "截圖失敗", "Screenshot failed") }
    static var pluginScreenshotConfigInfo:   String { s("当前版本支持全屏遮罩、拖拽选区、复制和保存。后续版本可增加标注、快捷键和默认保存目录配置。", "目前版本支援全螢幕遮罩、拖曳選區、複製和儲存。後續版本可增加標註、快捷鍵和預設儲存目錄設定。", "This version supports full-screen overlay capture, drag selection, copy, and save. Annotation, shortcuts, and default save location can be added later.") }
    static var pluginScreenshotPermissionHint: String { s("无法读取屏幕内容。请在系统设置中允许当前 Klok.app 进行屏幕录制；开启后请重启 Klok。", "無法讀取螢幕內容。請在系統設定中允許目前的 Klok.app 進行螢幕錄製；開啟後請重新啟動 Klok。", "Unable to read the screen. Allow the current Klok.app to record the screen in System Settings, then restart Klok.") }
    static var pluginScreenshotSelect:       String { s("选择", "選取", "Select") }
    static var pluginScreenshotRect:         String { s("矩形", "矩形", "Rect") }
    static var pluginScreenshotEllipse:      String { s("圆形", "圓形", "Ellipse") }
    static var pluginScreenshotArrow:        String { s("箭头", "箭頭", "Arrow") }
    static var pluginScreenshotBrush:        String { s("画笔", "畫筆", "Brush") }
    static var pluginScreenshotText:         String { s("文字", "文字", "Text") }
    static var pluginScreenshotTextPlaceholder: String { s("输入文字", "輸入文字", "Enter text") }
    static var pluginScreenshotMosaic:       String { s("马赛克", "馬賽克", "Mosaic") }
    static var pluginScreenshotColor:        String { s("颜色", "顏色", "Color") }
    static var pluginScreenshotUndo:         String { s("撤销", "復原", "Undo") }
    static var pluginScreenshotCopy:         String { s("复制", "複製", "Copy") }
    static var pluginScreenshotSave:         String { s("保存", "儲存", "Save") }
    static var pluginScreenshotShortcutEnabled: String { s("启用截图快捷键", "啟用截圖快捷鍵", "Enable screenshot shortcut") }
    static var pluginScreenshotShortcutKey:  String { s("按键：", "按鍵：", "Key:") }
    static var pluginScreenshotShortcutCommand: String { "⌘" }
    static var pluginScreenshotShortcutShift: String { "⇧" }
    static var pluginScreenshotShortcutControl: String { "⌃" }
    static var pluginScreenshotShortcutOption: String { "⌥" }
    static var pluginScreenshotShortcutHint: String { s("默认全局快捷键：⌃⌘A。保存后立即生效；如和系统快捷键冲突，请换一个组合。", "預設全域快捷鍵：⌃⌘A。儲存後立即生效；如和系統快捷鍵衝突，請換一個組合。", "Default global shortcut: ⌃⌘A. Changes take effect immediately; change it if it conflicts with a system shortcut.") }
    static var pluginClipboardMenu:          String { s("剪贴板历史…", "剪貼簿歷史…", "Clipboard History…") }
    static var pluginClipboardTitle:         String { s("剪贴板历史", "剪貼簿歷史", "Clipboard History") }
    static var pluginClipboardSearch:        String { s("搜索剪贴板历史", "搜尋剪貼簿歷史", "Search clipboard history") }
    static var pluginClipboardClear:         String { s("清空历史", "清空歷史", "Clear History") }
    static var pluginClipboardConfigInfo:    String { s("当前版本记录文本剪贴板历史，最多保留 200 条。后续版本可增加持久化、忽略应用、图片和富文本支持。", "目前版本記錄文字剪貼簿歷史，最多保留 200 筆。後續版本可增加持久化、忽略應用程式、圖片和富文字支援。", "This version keeps text clipboard history in memory, up to 200 items. Persistence, ignored apps, images, and rich text can be added later.") }

    // MARK: - Format token help descriptions

    static var fmtTokenYear:    String { s("年 (26 / 2026)",     "年 (26 / 2026)",     "Year (26 / 2026)") }
    static var fmtTokenMonth:   String { s("月 (数字/缩写/全称)", "月 (數字/縮寫/全稱)", "Month (6/06/Jun/June)") }
    static var fmtTokenDay:     String { s("日 (5 / 05)",         "日 (5 / 05)",         "Day (5 / 05)") }
    static var fmtTokenWeekday: String { s("星期 (缩写 / 全称)",  "星期 (縮寫 / 全稱)",  "Weekday (Sat / Saturday)") }
    static var fmtTokenHour24:  String { s("小时 24h (9 / 09)",  "小時 24h (9 / 09)",  "Hour 24h (9 / 09)") }
    static var fmtTokenHour12:  String { s("小时 12h (9 / 09)",  "小時 12h (9 / 09)",  "Hour 12h (9 / 09)") }
    static var fmtTokenMinute:  String { s("分钟 (5 / 05)",      "分鐘 (5 / 05)",      "Minute (5 / 05)") }
    static var fmtTokenSecond:  String { s("秒 (3 / 03)",         "秒 (3 / 03)",         "Second (3 / 03)") }
    static var fmtTokenAmPm:    String { s("上午/下午",           "上午/下午",           "AM / PM") }
    static var fmtTokenWeek:    String { s("周数 (25)",           "週數 (25)",           "Week of year (25)") }
    static var fmtTokenLiteral: String { s("字面文字",            "字面文字",            "Literal text") }

    // Legacy aliases
    static var langChinese: String { "中文" }
    static var langEnglish: String { "English" }
}
