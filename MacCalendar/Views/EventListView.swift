//
//  EventListView.swift
//  MacCalendar
//
//  Created by ruihelin on 2025/9/28.
//

import SwiftUI

struct ContentHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct EventListView: View {
    @ObservedObject var calendarManager: CalendarManager

    @State private var contentHeight: CGFloat = 0
    

    var body: some View {
        if calendarManager.selectedDayEvents.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack{
                    Text("\(DateHelper.formatDate(date: calendarManager.selectedDay, format: "yyyy年MM月dd日（第w周）"))")
                        .font(.system(size: 11)) // 默认 body 是 17，这里设为 11
                        .foregroundColor(.secondary) // 使用系统辅助灰色，或者用 .gray
                    Spacer()
                    Text(calendarManager.selectedDayLunar)
                        .font(.system(size: 11)) // 默认 body 是 17，这里设为 11
                        .foregroundColor(.secondary) // 使用系统辅助灰色，或者用 .gray
                }
//                Text("今天无日程")
//                    .frame(maxWidth: .infinity, alignment: .center)
//                    .font(.system(size: 11)) // 默认 body 是 17，这里设为 11
//                    .foregroundColor(.secondary) // 使用系统辅助灰色，或者用 .gray
            }
        }
        else{
            VStack(alignment: .leading, spacing: 8) {
                HStack{
                    Text("\(DateHelper.formatDate(date: calendarManager.selectedDay, format: "yyyy年MM月dd日（第w周）"))")
                        .font(.system(size: 11)) // 默认 body 是 17，这里设为 11
                        .foregroundColor(.secondary) // 使用系统辅助灰色，或者用 .gray
                    Spacer()
                    Text(calendarManager.selectedDayLunar)
                        .font(.system(size: 11)) // 默认 body 是 17，这里设为 11
                        .foregroundColor(.secondary) // 使用系统辅助灰色，或者用 .gray
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(calendarManager.selectedDayEvents, id: \.id) { event in
                            EventListItemView(event: event)
                        }
                    }
                    .background(
                        // 测量高度
                        GeometryReader { geometry in
                            Color.clear
                                .preference(key: ContentHeightPreferenceKey.self,
                                            value: geometry.size.height)
                        }
                    )
                }
                .onPreferenceChange(ContentHeightPreferenceKey.self) { height in
                    self.contentHeight = height
                }
                .frame(height: min(contentHeight, 500))
                .animation(.easeInOut, value: contentHeight)
            }
        }
    }
}
