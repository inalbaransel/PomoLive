import SwiftUI
import WidgetKit

@main
struct PomoLiveWidgetsBundle: WidgetBundle {
    var body: some Widget {
        FocusTodayWidget()
        FocusLiveActivityWidget()
    }
}
