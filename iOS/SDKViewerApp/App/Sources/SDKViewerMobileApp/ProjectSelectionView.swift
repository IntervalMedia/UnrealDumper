import SwiftUI

struct ProjectSelectionView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var newProjectName: String = ""

    var body: some View {
        Form {
            Section("Create Project") {
                TextField("Project name", text: $newProjectName)
                Button("Create") {
                    viewModel.createProject(named: newProjectName)
                    newProjectName = ""
                }
                .disabled(newProjectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Section("Load Existing Project") {
                if viewModel.projects.isEmpty {
                    Text("No saved projects yet.")
                } else {
                    ForEach(viewModel.projects, id: \.name) { project in
                        Button(project.name) {
                            viewModel.loadProject(project)
                        }
                    }
                }
            }
        }
        .navigationTitle("SDK Viewer")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Refresh") { viewModel.reloadProjects() }
            }
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "Unknown error")
        }
    }
}
