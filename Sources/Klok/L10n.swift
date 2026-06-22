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
