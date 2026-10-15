import WidgetKit
import SwiftUI

@main
struct MepoWidgetsBundle: WidgetBundle {
    var body: some Widget {
        RemindersWidget()
        MemoriesWidget()
    }
}
