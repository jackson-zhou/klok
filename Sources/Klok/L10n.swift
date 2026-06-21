import Foundation

enum L10n {

    enum Lang { case zh, zhTW, ja, en }

    static var lang: Lang {
        switch Settings.shared.language {
        case "zh-TW": return .zhTW
        case "ja":    return .ja
        case "en":    return .en
        default:      return .zh
        }
    }

    // true for either Chinese variant — handy for CJK layout decisions
    static var isChinese: Bool { lang == .zh || lang == .zhTW }

    private static func s(_ zh: String, _ zhTW: String, _ ja: String, _ en: String) -> String {
        switch lang {
        case .zh:   return zh
        case .zhTW: return zhTW
        case .ja:   return ja
        case .en:   return en
        }
    }

    // MARK: - Window / tab titles

    static var prefsTitle:    String { s("Klok 设置",       "Klok 設定",       "Klok 環境設定",      "Klok Preferences") }
    static var tabGeneral:    String { s("通用",             "一般",             "一般",               "General") }
    static var tabAppearance: String { s("外观",             "外觀",             "外観",               "Appearance") }
    static var tabAlarms:     String { s("提醒",             "提醒",             "リマインダー",        "Reminders") }
    static var tabMenuBar:    String { s("日历",             "日曆",             "カレンダー",          "Calendar") }

    // MARK: - General tab

    static var clockSize:       String { s("时钟大小：",     "時鐘大小：",       "時計サイズ：",        "Clock Size:") }
    static var opacity:         String { s("不透明度：",     "不透明度：",       "不透明度：",          "Opacity:") }
    static var alwaysOnTop:     String { s("总在最前面",     "總在最前面",       "常に最前面",          "Always on Top") }
    static var pinToDesktop:    String { s("固定到桌面",     "固定到桌面",       "デスクトップに固定",  "Pin to Desktop") }
    static var embedInDesktop:  String { s("嵌入桌面",       "嵌入桌面",         "デスクトップに埋め込む", "Embed in Desktop") }
    static var clickThrough:    String { s("点击无动作",     "點擊無動作",       "クリックスルー",      "Click-through") }
    static var hoverTransparent:String { s("鼠标经过时透明", "滑鼠經過時透明",   "ホバー時に透明",      "Transparent on Hover") }
    static var launchAtLogin:   String { s("登录时启动",     "登入時啟動",       "ログイン時に起動",    "Launch at Login") }
    static var showSecondHand:  String { s("显示秒针",       "顯示秒針",         "秒針を表示",          "Show Second Hand") }
    static var secondHandJump:  String { s("秒针跳跃",       "秒針跳動",         "秒針をジャンプ",      "Jumping Second") }
    static var showAmPm:        String { s("显示 AM/PM",     "顯示 AM/PM",       "AM/PM を表示",        "Show AM/PM") }
    static var showDate:        String { s("显示日期",       "顯示日期",         "日付を表示",          "Show Date") }
    static var language:        String { s("语言：",         "語言：",           "言語：",              "Language:") }

    // Language option labels (shown in segmented control)
    static var langZH:   String { "简体" }
    static var langZHTW: String { "繁體" }
    static var langJA:   String { "日本語" }
    static var langEN:   String { "EN" }

    // MARK: - Appearance tab

    static var searchSkins: String { s("搜索皮肤…", "搜尋皮膚…", "スキンを検索…", "Search skins…") }

    // Style button sublabels (icon style picker)
    static var styleCircle:  String { s("圆圈",   "圓圈",   "丸",          "Circle") }
    static var stylePage:    String { s("日历页", "日曆頁", "カレンダー",  "Page") }
    static var styleSymbol:  String { s("图标",   "圖示",   "アイコン",    "Symbol") }
    static var styleBadge:   String { s("日期牌", "日期牌", "バッジ",      "Badge") }

    // Badge weekday abbreviation used in the style preview thumbnail
    static var badgeSatPreview: String { s("周六", "週六", "土", "SAT") }

    // MARK: - Menu bar / calendar tab

    static var menuBarSection:       String { s("菜单栏",         "選單列",           "メニューバー",        "Menu Bar") }
    static var menuBarClockSection:  String { s("菜单栏时钟",     "選單列時鐘",       "メニューバー時計",    "Menu Bar Clock") }
    static var menuBarShowSeconds:   String { s("显示秒数",       "顯示秒數",         "秒を表示",            "Show Seconds") }
    static var menuBar24Hour:        String { s("24 小时制",      "24 小時制",        "24時間表示",          "24-Hour Time") }
    static var menuBarFmtLabel:      String { s("格式：",         "格式：",           "フォーマット：",      "Format:") }
    static var menuBarFmtPreview:    String { s("预览：",         "預覽：",           "プレビュー：",        "Preview:") }
    static var menuBarFmtReset:      String { s("重置",           "重設",             "リセット",            "Reset") }
    static var menuBarFmtHelp:       String { s("格式说明",       "格式說明",         "フォーマット記号",    "Format Tokens") }
    static var menuBarFmtDefault:    String { s("M月d日 EEE HH:mm", "M月d日 EEE HH:mm", "M月d日 EEE HH:mm", "E M/d HH:mm") }
    static var menuBarIconPosLabel:  String { s("图标位置：",     "圖示位置：",       "アイコン位置：",      "Icon position:") }
    static var menuBarIconPosLeft:   String { s("文字左侧",       "文字左側",         "テキストの左",        "Left of text") }
    static var menuBarIconPosRight:  String { s("文字右侧",       "文字右側",         "テキストの右",        "Right of text") }
    static var menuBarIconPosHidden: String { s("不显示",         "不顯示",           "非表示",              "Hidden") }

    // MARK: - Calendar section

    static var calSection:          String { s("日历",           "日曆",             "カレンダー",          "Calendar") }
    static var calShowEventDots:    String { s("显示事件标记",   "顯示事件標記",     "イベントマーカーを表示", "Show event markers") }
    static var calColorfulDots:     String { s("使用日历颜色",   "使用日曆顏色",     "カレンダーカラーを使用", "Use calendar colors") }
    static var calShowEventLoc:     String { s("显示事件地点",   "顯示事件地點",     "イベント場所を表示",  "Show event location") }
    static var calShowInactiveDays: String { s("显示非本月日期", "顯示非本月日期",   "月外の日付を表示",    "Show days outside month") }
    static var calShowWeekNumbers:  String { s("显示周数",       "顯示週數",         "週番号を表示",        "Show week numbers") }
    static var calFontSize:         String { s("日历大小",       "日曆大小",         "カレンダーサイズ",    "Calendar size") }
    static var calToday:            String { s("今天",           "今天",             "今日",                "Today") }

    static var calWeekdays: [String] {
        switch lang {
        case .zh, .zhTW: return ["日", "一", "二", "三", "四", "五", "六"]
        case .ja:        return ["日", "月", "火", "水", "木", "金", "土"]
        case .en:        return ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
        }
    }

    static var calWeekdaysFull: [String] {
        switch lang {
        case .zh:   return ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        case .zhTW: return ["週日", "週一", "週二", "週三", "週四", "週五", "週六"]
        case .ja:   return ["日曜", "月曜", "火曜", "水曜", "木曜", "金曜", "土曜"]
        case .en:   return ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        }
    }

    static var calWeekdaysSingle: [String] {
        switch lang {
        case .zh, .zhTW: return ["日", "一", "二", "三", "四", "五", "六"]
        case .ja:        return ["日", "月", "火", "水", "木", "金", "土"]
        case .en:        return ["S", "M", "T", "W", "T", "F", "S"]
        }
    }

    // MARK: - Reminder list

    static var remindersSorted: String { s("提醒信息按时间先后排列", "提醒訊息按時間先後排列",
                                           "リマインダーは時刻順に並んでいます",  "Reminders sorted by time") }
    static var reminderColName: String { s("名称",      "名稱",      "名前",    "Name") }
    static var reminderColTime: String { s("时间",      "時間",      "時刻",    "Time") }
    static var reminderColDate: String { s("日期",      "日期",      "日付",    "Date") }
    static var reminderAdd:     String { s("添加(I)…",  "新增(I)…",  "追加(I)…", "Add(I)…") }
    static var reminderEdit:    String { s("编辑(E)…",  "編輯(E)…",  "編集(E)…", "Edit(E)…") }
    static var reminderDelete:  String { s("删除(D)",   "刪除(D)",   "削除(D)",  "Delete(D)") }
    static var reminderTest:    String { s("测试(T)",   "測試(T)",   "テスト(T)", "Test(T)") }

    // MARK: - Reminder editor

    static var reminderEditorTitle: String { s("提醒信息编辑器", "提醒訊息編輯器",
                                               "リマインダーエディター", "Reminder Editor") }
    static var reminderName:     String { s("名称：",       "名稱：",       "名前：",          "Name:") }
    static var reminderType:     String { s("类型：",       "類型：",       "種類：",          "Type:") }
    static var reminderTime:     String { s("时间：",       "時間：",       "時刻：",          "Time:") }
    static var reminderDate:     String { s("日期：",       "日期：",       "日付：",          "Date:") }
    static var reminderShowWin:  String { s("显示提醒窗口", "顯示提醒視窗", "リマインダーウィンドウを表示", "Show reminder window") }
    static var reminderMessage:  String { s("提醒内容：",   "提醒內容：",   "メッセージ：",    "Message:") }
    static var reminderInterval: String { s("间隔：",       "間隔：",       "間隔：",          "Interval:") }
    static var reminderMinutes:  String { s("分钟",         "分鐘",         "分",              "min(s)") }
    static var reminderMonthDay: String { s("几日：",       "幾日：",       "日：",            "Day:") }
    static var reminderYearMonth:String { s("月：",         "月：",         "月：",            "Month:") }
    static var reminderYearDay:  String { s("日：",         "日：",         "日：",            "Day:") }
    static var reminderWeekOn:   String { s("周几：",       "週幾：",       "曜日：",          "On:") }
    static var repeatOnce:       String { s("一次",         "一次",         "1回",             "Once") }
    static var repeatDaily:      String { s("每天",         "每天",         "毎日",            "Daily") }
    static var repeatWeekly:     String { s("每周",         "每週",         "毎週",            "Weekly") }
    static var repeatMonthly:    String { s("每月",         "每月",         "毎月",            "Monthly") }
    static var repeatYearly:     String { s("每年",         "每年",         "毎年",            "Yearly") }
    static var repeatMinutely:   String { s("每分钟",       "每分鐘",       "毎分",            "Every Minute") }
    static var btnOK:            String { s("确定",         "確定",         "OK",              "OK") }
    static var btnCancel:        String { s("取消",         "取消",         "キャンセル",      "Cancel") }

    // MARK: - Reminder popup

    static var alarmTitle:      String { s("Klok 提醒",  "Klok 提醒",  "Klok リマインダー", "Klok Reminder") }
    static var reminderDismiss: String { s("关闭",        "關閉",        "閉じる",            "Dismiss") }

    // MARK: - Context / status menus

    static var menuPrefs:       String { s("设置…",         "設定…",         "環境設定…",          "Preferences…") }
    static var menuReminders:   String { s("提醒…",         "提醒…",         "リマインダー…",      "Reminders…") }
    static var menuAlwaysOnTop: String { s("总在最前面",    "總在最前面",    "常に最前面",          "Always on Top") }
    static var menuPinDesktop:  String { s("固定到桌面",    "固定到桌面",    "デスクトップに固定", "Pin to Desktop") }
    static var menuQuit:        String { s("退出 Klok",     "結束 Klok",     "Klok を終了",         "Quit Klok") }

    // MARK: - Format token help descriptions

    static var fmtTokenYear:    String { s("年 (26 / 2026)",       "年 (26 / 2026)",       "年 (26 / 2026)",       "Year (26 / 2026)") }
    static var fmtTokenMonth:   String { s("月 (数字/缩写/全称)",   "月 (數字/縮寫/全稱)",   "月 (6/06/6月)",        "Month (6/06/Jun/June)") }
    static var fmtTokenDay:     String { s("日 (5 / 05)",           "日 (5 / 05)",           "日 (5 / 05)",          "Day (5 / 05)") }
    static var fmtTokenWeekday: String { s("星期 (缩写 / 全称)",    "星期 (縮寫 / 全稱)",    "曜日 (土 / 土曜日)",   "Weekday (Sat / Saturday)") }
    static var fmtTokenHour24:  String { s("小时 24h (9 / 09)",     "小時 24h (9 / 09)",     "時 24h (9 / 09)",      "Hour 24h (9 / 09)") }
    static var fmtTokenHour12:  String { s("小时 12h (9 / 09)",     "小時 12h (9 / 09)",     "時 12h (9 / 09)",      "Hour 12h (9 / 09)") }
    static var fmtTokenMinute:  String { s("分钟 (5 / 05)",         "分鐘 (5 / 05)",         "分 (5 / 05)",          "Minute (5 / 05)") }
    static var fmtTokenSecond:  String { s("秒 (3 / 03)",           "秒 (3 / 03)",           "秒 (3 / 03)",          "Second (3 / 03)") }
    static var fmtTokenAmPm:    String { s("上午/下午",             "上午/下午",             "午前/午後",            "AM / PM") }
    static var fmtTokenWeek:    String { s("周数 (25)",             "週數 (25)",             "週番号 (25)",          "Week of year (25)") }
    static var fmtTokenLiteral: String { s("字面文字",              "字面文字",              "リテラルテキスト",     "Literal text") }

    // Legacy alias kept for any callers outside L10n
    static var langChinese: String { "中文" }
    static var langEnglish: String { "English" }
}
