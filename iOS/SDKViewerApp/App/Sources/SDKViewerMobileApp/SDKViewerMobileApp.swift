import SwiftUI

@main
struct SDKViewerMobileApp: App {
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                if viewModel.currentProject == nil {
                    ProjectSelectionView(viewModel: viewModel)
                } else {
                    ProjectWorkspaceView(viewModel: viewModel)
                }
            }
        }
    }
}
