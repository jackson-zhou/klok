import Foundation

enum L10n {
    static var isChinese: Bool { Settings.shared.language == "zh" }

    static var prefsTitle:      String { isChinese ? "Klok 设置"   : "Klok Preferences" }
    static var tabGeneral:      String { isChinese ? "通用"          : "General" }
    static var tabAppearance:   String { isChinese ? "外观"          : "Appearance" }
    static var tabAlarms:       String { isChinese ? "提醒"          : "Reminders" }

    static var clockSize:       String { isChinese ? "时钟大小："    : "Clock Size:" }
    static var opacity:         String { isChinese ? "不透明度："    : "Opacity:" }
    static var alwaysOnTop:       String { isChinese ? "总在最前面"      : "Always on Top" }
    static var pinToDesktop:      String { isChinese ? "固定到桌面"      : "Pin to Desktop" }
    static var embedInDesktop:    String { isChinese ? "嵌入桌面"        : "Embed in Desktop" }
    static var clickThrough:      String { isChinese ? "点击无动作"      : "Click-through" }
    static var hoverTransparent:  String { isChinese ? "鼠标经过时透明"  : "Transparent on Hover" }
    static var launchAtLogin:     String { isChinese ? "登录时启动"      : "Launch at Login" }
    static var showSecondHand:  String { isChinese ? "显示秒针"      : "Show Second Hand" }
    static var secondHandJump:  String { isChinese ? "秒针跳跃"      : "Jumping Second" }
    static var showAmPm:        String { isChinese ? "显示 AM/PM"    : "Show AM/PM" }
    static var showDate:        String { isChinese ? "显示日期"      : "Show Date" }
    static var language:        String { isChinese ? "语言："        : "Language:" }

    static var searchSkins:     String { isChinese ? "搜索皮肤…"    : "Search skins…" }

    // Reminder list
    static var remindersSorted:   String { isChinese ? "提醒信息按时间先后排列" : "Reminders sorted by time" }
    static var reminderColName:   String { isChinese ? "名称"        : "Name" }
    static var reminderColTime:   String { isChinese ? "时间"        : "Time" }
    static var reminderColDate:   String { isChinese ? "日期"        : "Date" }
    static var reminderAdd:       String { isChinese ? "添加(I)…"    : "Add(I)…" }
    static var reminderEdit:      String { isChinese ? "编辑(E)…"    : "Edit(E)…" }
    static var reminderDelete:    String { isChinese ? "删除(D)"     : "Delete(D)" }
    static var reminderTest:      String { isChinese ? "测试(T)"     : "Test(T)" }

    // Reminder editor
    static var reminderEditorTitle: String { isChinese ? "提醒信息编辑器" : "Reminder Editor" }
    static var reminderName:      String { isChinese ? "名称："       : "Name:" }
    static var reminderType:      String { isChinese ? "类型："       : "Type:" }
    static var reminderTime:      String { isChinese ? "时间："       : "Time:" }
    static var reminderDate:      String { isChinese ? "日期："       : "Date:" }
    static var reminderShowWin:   String { isChinese ? "显示提醒窗口" : "Show reminder window" }
    static var reminderMessage:   String { isChinese ? "提醒内容："   : "Message:" }
    static var reminderInterval:  String { isChinese ? "间隔："       : "Interval:" }
    static var reminderMinutes:   String { isChinese ? "分钟"         : "min(s)" }
    static var reminderMonthDay:  String { isChinese ? "几日："       : "Day:" }
    static var reminderYearMonth: String { isChinese ? "月："         : "Month:" }
    static var reminderYearDay:   String { isChinese ? "日："         : "Day:" }
    static var reminderWeekOn:    String { isChinese ? "周几："       : "On:" }
    static var repeatOnce:        String { isChinese ? "一次"         : "Once" }
    static var repeatDaily:       String { isChinese ? "每天"         : "Daily" }
    static var repeatWeekly:      String { isChinese ? "每周"         : "Weekly" }
    static var repeatMonthly:     String { isChinese ? "每月"         : "Monthly" }
    static var repeatYearly:      String { isChinese ? "每年"         : "Yearly" }
    static var repeatMinutely:    String { isChinese ? "每分钟"       : "Every Minute" }
    static var btnOK:             String { isChinese ? "确定"         : "OK" }
    static var btnCancel:         String { isChinese ? "取消"         : "Cancel" }

    // Reminder popup
    static var alarmTitle:      String { isChinese ? "Klok 提醒"  : "Klok Reminder" }
    static var reminderDismiss: String { isChinese ? "关闭"          : "Dismiss" }

    static var menuPrefs:       String { isChinese ? "设置…"         : "Preferences…" }
    static var menuReminders:   String { isChinese ? "提醒…"         : "Reminders…" }
    static var menuAlwaysOnTop: String { isChinese ? "总在最前面"    : "Always on Top" }
    static var menuPinDesktop:  String { isChinese ? "固定到桌面"    : "Pin to Desktop" }
    static var menuQuit:        String { isChinese ? "退出 Klok"   : "Quit Klok" }

    static var langChinese:     String { "中文" }
    static var langEnglish:     String { "English" }

    // Menu bar clock
    static var menuBarClockSection: String { isChinese ? "菜单栏时钟"       : "Menu Bar Clock" }
    static var menuBarShowSeconds:  String { isChinese ? "显示秒数"         : "Show Seconds" }
    static var menuBar24Hour:       String { isChinese ? "24 小时制"        : "24-Hour Time" }

    // Menu bar tab → now the "日历" tab
    static var tabMenuBar:           String { isChinese ? "日历"             : "Calendar" }
    static var menuBarSection:       String { isChinese ? "菜单栏"           : "Menu Bar" }
    static var menuBarFmtLabel:      String { isChinese ? "格式："           : "Format:" }
    static var menuBarFmtPreview:    String { isChinese ? "预览："           : "Preview:" }
    static var menuBarFmtReset:      String { isChinese ? "重置"             : "Reset" }
    static var menuBarFmtHelp:       String { isChinese ? "格式说明"         : "Format Tokens" }
    static var menuBarFmtDefault:    String { isChinese ? "M月d日 EEE HH:mm" : "E M/d HH:mm" }
    static var menuBarIconPosLabel:  String { isChinese ? "图标位置："        : "Icon position:" }
    static var menuBarIconPosLeft:   String { isChinese ? "文字左侧"          : "Left of text" }
    static var menuBarIconPosRight:  String { isChinese ? "文字右侧"          : "Right of text" }
    static var menuBarIconPosHidden: String { isChinese ? "不显示"            : "Hidden" }

    // Calendar section inside the "日历" tab
    static var calSection:           String { isChinese ? "日历"             : "Calendar" }
    static var calShowEventDots:     String { isChinese ? "显示事件标记"      : "Show event markers" }
    static var calColorfulDots:      String { isChinese ? "使用日历颜色"      : "Use calendar colors" }
    static var calShowEventLoc:      String { isChinese ? "显示事件地点"      : "Show event location" }
    static var calShowInactiveDays:  String { isChinese ? "显示非本月日期"    : "Show days outside month" }
    static var calShowWeekNumbers:   String { isChinese ? "显示周数"          : "Show week numbers" }
    static var calFontSize:          String { isChinese ? "日历大小"          : "Calendar size" }

    // Calendar popover
    static var calToday:     String { isChinese ? "今天" : "Today" }
    static var calWeekdays:  [String] { isChinese
        ? ["日", "一", "二", "三", "四", "五", "六"]
        : ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
    }
    static var calWeekdaysFull: [String] { isChinese
        ? ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        : ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    }
    static var calWeekdaysSingle: [String] { isChinese
        ? ["日", "一", "二", "三", "四", "五", "六"]
        : ["S", "M", "T", "W", "T", "F", "S"]
    }
}
