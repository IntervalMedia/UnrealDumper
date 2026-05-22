import SwiftUI
import UniformTypeIdentifiers
#if canImport(SDKViewerApp)
import SDKViewerApp
#endif

private enum WorkspaceDetailTab: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case fields = "Fields"
    case source = "Source"
    case graph = "Graph"

    var id: String { rawValue }
}

struct ProjectWorkspaceView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var showImporter = false
    @State private var detailTab: WorkspaceDetailTab = .overview
    @State private var graphDepth: Int = 2

    var body: some View {
        Group {
            if let project = viewModel.currentProject {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        WorkspaceHeaderCard(
                            project: project,
                            packageCount: project.dump?.packages.count ?? 0,
                            onImport: { showImporter = true },
                            onClose: viewModel.closeProject
                        )

                        if let dump = project.dump {
                            PackageRail(
                                packages: dump.packages,
                                selectedPackage: viewModel.selectedPackage,
                                summaryText: viewModel.packageSummaryText(for:),
                                onSelect: viewModel.selectPackage
                            )

                            if let package = viewModel.selectedPackage {
                                AtlasSectionCard(title: "Type Explorer", subtitle: "Search by type, object label, or inheritance") {
                                    VStack(alignment: .leading, spacing: 14) {
                                        SearchField(text: $viewModel.typeSearchText)

                                        if viewModel.filteredBrowserNodes(for: package).isEmpty {
                                            EmptySectionState(
                                                title: "No matching types",
                                                message: "Try a different name, object label, or parent type."
                                            )
                                        } else {
                                            VStack(alignment: .leading, spacing: 10) {
                                                ForEach(viewModel.filteredBrowserNodes(for: package)) { node in
                                                    TypeTreeNodeView(
                                                        node: node,
                                                        selectedTypeID: viewModel.selectedType?.id,
                                                        onSelect: { type in
                                                            detailTab = .overview
                                                            viewModel.selectType(type)
                                                        }
                                                    )
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            if let type = viewModel.selectedType {
                                AtlasSectionCard(title: type.name, subtitle: type.fullName) {
                                    VStack(alignment: .leading, spacing: 16) {
                                        Picker("Detail", selection: $detailTab) {
                                            ForEach(WorkspaceDetailTab.allCases) { tab in
                                                Text(tab.rawValue).tag(tab)
                                            }
                                        }
                                        .pickerStyle(.segmented)

                                        detailContent(for: type)
                                    }
                                }
                            } else {
                                AtlasSectionCard(title: "Type Detail", subtitle: "Select a type from the explorer") {
                                    EmptySectionState(
                                        title: "Nothing selected",
                                        message: "Choose a package and then a type to inspect its layout, source, and inheritance graph."
                                    )
                                }
                            }

                            AtlasSectionCard(title: "Pointer Chain Calculator", subtitle: "Generate C++ pointer traversal code") {
                                PointerGeneratorCard(viewModel: viewModel)
                            }
                        } else {
                            AtlasSectionCard(title: "Import SDK Dump", subtitle: "This workspace becomes interactive after parsing AIOHeader.hpp") {
                                EmptySectionState(
                                    title: "No dump loaded",
                                    message: "Import the ZIP generated by the iOS dumper to explore packages, inheritance, and memory layout."
                                )
                            }
                        }
                    }
                    .padding(16)
                }
                .background(AtlasBackground().ignoresSafeArea())
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        AtlasSectionCard(title: "SDK Atlas", subtitle: "Mobile-first Unreal Engine dump exploration") {
                            EmptySectionState(
                                title: "Open or create a project",
                                message: "Use the navigation bar to create a local project, then import an SDK ZIP to unlock the explorer, graph, and offset views."
                            )
                        }
                    }
                    .padding(16)
                }
                .background(AtlasBackground().ignoresSafeArea())
            }
        }
        .navigationTitle("SDK Atlas")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.zip],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                viewModel.importDumpArchive(from: url)
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

    @ViewBuilder
    private func detailContent(for type: SDKType) -> some View {
        switch detailTab {
        case .overview:
            TypeOverviewPanel(
                type: type,
                package: viewModel.package(containing: type),
                graphSnapshot: viewModel.graphSnapshot(for: type, depth: graphDepth)
            )
        case .fields:
            TypeFieldsPanel(type: type, rows: viewModel.fieldRows(for: type))
        case .source:
            TypeSourcePanel(type: type)
        case .graph:
            TypeGraphPanel(
                snapshot: viewModel.graphSnapshot(for: type, depth: graphDepth),
                graphDepth: $graphDepth,
                onSelect: { nextType in
                    detailTab = .graph
                    viewModel.selectType(nextType)
                }
            )
        }
    }
}

private struct WorkspaceHeaderCard: View {
    let project: SDKProjectRecord
    let packageCount: Int
    let onImport: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(project.metadata.name)
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundColor(.white)

                Text(project.metadata.sourceArchiveName ?? "No archive imported yet")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.78))
            }

            HStack(spacing: 12) {
                MetricBadge(title: "Packages", value: "\(packageCount)")
                MetricBadge(title: "Imported", value: project.metadata.lastImportedAt.map(Self.dateFormatter.string(from:)) ?? "Pending")
            }

            HStack(spacing: 12) {
                Button(action: onImport) {
                    Text("Import SDK ZIP")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(AtlasPrimaryButtonStyle())

                Button(action: onClose) {
                    Text("Close")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(AtlasSecondaryButtonStyle())
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [Color(red: 0.07, green: 0.16, blue: 0.34), Color(red: 0.08, green: 0.45, blue: 0.57)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.16), radius: 18, y: 12)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

private struct PackageRail: View {
    let packages: [SDKPackage]
    let selectedPackage: SDKPackage?
    let summaryText: (SDKPackage) -> String
    let onSelect: (SDKPackage) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Packages")
                .font(.system(.title3, design: .rounded).weight(.bold))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(packages) { package in
                        Button(action: { onSelect(package) }) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(package.name)
                                    .font(.system(.headline, design: .rounded).weight(.semibold))
                                    .multilineTextAlignment(.leading)
                                Text(summaryText(package))
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                            .frame(width: 210, alignment: .leading)
                            .padding(16)
                            .background(cardBackground(isSelected: selectedPackage?.id == package.id))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(selectedPackage?.id == package.id ? Color(red: 0.08, green: 0.41, blue: 0.54) : Color.white.opacity(0), lineWidth: 2)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    @ViewBuilder
    private func cardBackground(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(
                LinearGradient(
                    colors: isSelected
                        ? [Color(red: 0.89, green: 0.96, blue: 0.99), Color.white]
                        : [Color.white.opacity(0.84), Color.white.opacity(0.68)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }
}

private struct TypeOverviewPanel: View {
    let type: SDKType
    let package: SDKPackage?
    let graphSnapshot: TypeGraphSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                OverviewStatCard(title: "Package", value: package?.name ?? "Unknown")
                OverviewStatCard(title: "Kind", value: type.objectLabel)
                OverviewStatCard(title: "Size", value: type.sizeBytes.map(hex) ?? "Unknown")
                OverviewStatCard(title: "Inherited", value: type.inheritedSizeBytes.map(hex) ?? "0x0")
                OverviewStatCard(title: "Parent", value: type.parentTypeName ?? "Root")
                OverviewStatCard(title: "Children", value: "\(graphSnapshot.children.count)")
            }

            if !graphSnapshot.ancestors.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Inheritance chain")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    Text((graphSnapshot.ancestors.map { $0.name } + [type.name]).joined(separator: " -> "))
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private func hex(_ value: UInt64) -> String {
        String(format: "0x%llX", value)
    }
}

private struct TypeFieldsPanel: View {
    let type: SDKType
    let rows: [TypeFieldRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let inherited = type.inheritedSizeBytes, inherited > 0 {
                Text("Inherited layout extends through \(hex(inherited)). Fields below are the declarations present in this type block.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundColor(.secondary)
            }

            if rows.isEmpty {
                EmptySectionState(
                    title: "No parsed fields",
                    message: "Enums and metadata-only objects can legitimately have no field layout rows."
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(rows) { row in
                        FieldRowView(row: row)
                    }
                }
            }
        }
    }

    private func hex(_ value: UInt64) -> String {
        String(format: "0x%llX", value)
    }
}

private struct TypeSourcePanel: View {
    let type: SDKType

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(type.fullName)
                .font(.system(.headline, design: .rounded).weight(.semibold))

            Text(type.body)
                .font(.system(.footnote, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(red: 0.09, green: 0.11, blue: 0.15))
                )
                .foregroundColor(Color(red: 0.9, green: 0.94, blue: 0.96))
        }
    }
}

private struct TypeGraphPanel: View {
    let snapshot: TypeGraphSnapshot
    @Binding var graphDepth: Int
    let onSelect: (SDKType) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Stepper(value: $graphDepth, in: 1...4) {
                Text("Neighborhood depth: \(graphDepth)")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
            }

            Text("Drag to pan, pinch to zoom, and tap any node to re-center the graph on that type.")
                .font(.system(.footnote, design: .rounded))
                .foregroundColor(.secondary)

            ZoomableTypeGraphCanvas(snapshot: snapshot, onSelect: onSelect)
                .frame(height: 420)

            if !snapshot.siblings.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Sibling types")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(snapshot.siblings) { type in
                                GraphNodeButton(type: type, emphasis: .sibling, compact: true, onSelect: onSelect)
                            }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Descendant layers")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))

                if snapshot.descendantLayers.isEmpty {
                    EmptySectionState(
                        title: "Leaf type",
                        message: "This node has no direct parsed children in the current dump."
                    )
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(snapshot.descendantLayers.enumerated()), id: \.offset) { layerIndex, layer in
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Depth \(layerIndex + 1)")
                                    .font(.system(.caption, design: .rounded).weight(.bold))
                                    .foregroundColor(.secondary)

                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                                    ForEach(layer) { type in
                                        GraphNodeButton(type: type, emphasis: .child, compact: true, onSelect: onSelect)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct ZoomableTypeGraphCanvas: View {
    let snapshot: TypeGraphSnapshot
    let onSelect: (SDKType) -> Void

    @State private var persistentScale: CGFloat = 1
    @State private var gestureScale: CGFloat = 1
    @State private var persistentOffset: CGSize = .zero
    @State private var dragOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(0.62))

                GraphGrid()
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                graphContent(in: geometry.size)
                    .scaleEffect(clampedScale)
                    .offset(x: persistentOffset.width + dragOffset.width, y: persistentOffset.height + dragOffset.height)
                    .animation(.spring(response: 0.28, dampingFraction: 0.82), value: snapshot)
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .gesture(dragGesture.simultaneously(with: magnificationGesture))
        }
    }

    private var clampedScale: CGFloat {
        min(max(persistentScale * gestureScale, 0.7), 2.4)
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = value.translation
            }
            .onEnded { value in
                persistentOffset.width += value.translation.width
                persistentOffset.height += value.translation.height
                dragOffset = .zero
            }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                gestureScale = value
            }
            .onEnded { value in
                persistentScale = min(max(persistentScale * value, 0.7), 2.4)
                gestureScale = 1
            }
    }

    @ViewBuilder
    private func graphContent(in size: CGSize) -> some View {
        let centerX = size.width / 2
        let centerY = size.height / 2 - 12
        let rowSpacing: CGFloat = 110
        let siblingSpacing: CGFloat = 150

        ZStack {
            ForEach(Array(snapshot.ancestors.enumerated()), id: \.element.id) { index, type in
                let y = centerY - rowSpacing * CGFloat(snapshot.ancestors.count - index)
                if index == snapshot.ancestors.count - 1 {
                    GraphEdge(start: CGPoint(x: centerX, y: y + 24), end: CGPoint(x: centerX, y: centerY - 28))
                }
                PositionedGraphNode(
                    type: type,
                    emphasis: .ancestor,
                    point: CGPoint(x: centerX, y: y),
                    onSelect: onSelect
                )
            }

            ForEach(Array(snapshot.siblings.enumerated()), id: \.element.id) { index, type in
                let column = CGFloat(index - (snapshot.siblings.count - 1) / 2)
                let x = centerX + column * siblingSpacing
                GraphEdge(start: CGPoint(x: x, y: centerY), end: CGPoint(x: centerX, y: centerY))
                PositionedGraphNode(
                    type: type,
                    emphasis: .sibling,
                    point: CGPoint(x: x, y: centerY),
                    onSelect: onSelect
                )
            }

            PositionedGraphNode(
                type: snapshot.selected,
                emphasis: .selected,
                point: CGPoint(x: centerX, y: centerY),
                onSelect: onSelect
            )

            ForEach(Array(snapshot.descendantLayers.enumerated()), id: \.offset) { layerIndex, layer in
                let y = centerY + rowSpacing * CGFloat(layerIndex + 1)
                ForEach(Array(layer.enumerated()), id: \.element.id) { itemIndex, type in
                    let x = xPosition(for: itemIndex, total: layer.count, centerX: centerX, width: size.width)
                    let parentPoint = parentAnchor(for: type, layerIndex: layerIndex, centerX: centerX, centerY: centerY, rowSpacing: rowSpacing, size: size)
                    GraphEdge(start: parentPoint, end: CGPoint(x: x, y: y - 30))
                    PositionedGraphNode(
                        type: type,
                        emphasis: .child,
                        point: CGPoint(x: x, y: y),
                        onSelect: onSelect
                    )
                }
            }
        }
        .frame(width: size.width * 1.6, height: size.height * 1.5)
    }

    private func xPosition(for index: Int, total: Int, centerX: CGFloat, width: CGFloat) -> CGFloat {
        let spacing = min(max(width / CGFloat(max(total, 2)), 110), 180)
        let offsetIndex = CGFloat(index) - CGFloat(total - 1) / 2
        return centerX + offsetIndex * spacing
    }

    private func parentAnchor(for type: SDKType, layerIndex: Int, centerX: CGFloat, centerY: CGFloat, rowSpacing: CGFloat, size: CGSize) -> CGPoint {
        if layerIndex == 0 {
            return CGPoint(x: centerX, y: centerY + 28)
        }

        let parentNames = Set(snapshot.descendantLayers[layerIndex - 1].map(\.name))
        if let parentName = type.parentTypeName, parentNames.contains(parentName),
           let parentIndex = snapshot.descendantLayers[layerIndex - 1].firstIndex(where: { $0.name == parentName }) {
            let parentY = centerY + rowSpacing * CGFloat(layerIndex)
            let parentX = xPosition(for: parentIndex, total: snapshot.descendantLayers[layerIndex - 1].count, centerX: centerX, width: size.width)
            return CGPoint(x: parentX, y: parentY + 30)
        }

        return CGPoint(x: centerX, y: centerY + rowSpacing * CGFloat(layerIndex) + 30)
    }
}

private struct PositionedGraphNode: View {
    let type: SDKType
    let emphasis: GraphNodeEmphasis
    let point: CGPoint
    let onSelect: (SDKType) -> Void

    var body: some View {
        GraphNodeButton(type: type, emphasis: emphasis, compact: emphasis != .selected, onSelect: onSelect)
            .frame(width: emphasis == .selected ? 180 : 150)
            .position(point)
    }
}

private struct GraphGrid: View {
    var body: some View {
        Canvas { context, size in
            var path = Path()
            let spacing: CGFloat = 28

            stride(from: 0, through: size.width, by: spacing).forEach { x in
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }

            stride(from: 0, through: size.height, by: spacing).forEach { y in
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }

            context.stroke(path, with: .color(Color(red: 0.26, green: 0.43, blue: 0.49).opacity(0.08)), lineWidth: 1)
        }
    }
}

private struct GraphEdge: View {
    let start: CGPoint
    let end: CGPoint

    var body: some View {
        Path { path in
            path.move(to: start)
            path.addCurve(
                to: end,
                control1: CGPoint(x: start.x, y: (start.y + end.y) / 2),
                control2: CGPoint(x: end.x, y: (start.y + end.y) / 2)
            )
        }
        .stroke(Color(red: 0.18, green: 0.42, blue: 0.49).opacity(0.3), style: StrokeStyle(lineWidth: 2, lineCap: .round))
    }
}

private struct PointerGeneratorCard: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AtlasInputField(title: "Base expression", text: $viewModel.pointerBaseExpression)
            AtlasInputField(title: "Offsets", text: $viewModel.pointerOffsetsText)
            AtlasInputField(title: "Result type", text: $viewModel.pointerResultType)
            AtlasInputField(title: "Result variable name", text: $viewModel.pointerResultName)

            Button(action: viewModel.generatePointerCode) {
                Text("Generate C++")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(AtlasPrimaryButtonStyle())

            Text(viewModel.pointerOutput.isEmpty ? "Generated pointer code will appear here." : viewModel.pointerOutput)
                .font(.system(.footnote, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.72))
                )
        }
    }
}

private struct TypeTreeNodeView: View {
    let node: TypeBrowserNode
    let selectedTypeID: String?
    let onSelect: (SDKType) -> Void
    @State private var isExpanded: Bool

    init(node: TypeBrowserNode, selectedTypeID: String?, onSelect: @escaping (SDKType) -> Void) {
        self.node = node
        self.selectedTypeID = selectedTypeID
        self.onSelect = onSelect
        _isExpanded = State(initialValue: node.type == nil)
    }

    var body: some View {
        if let children = node.children, !children.isEmpty {
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(children) { child in
                        TypeTreeNodeView(node: child, selectedTypeID: selectedTypeID, onSelect: onSelect)
                    }
                }
                .padding(.top, 8)
            } label: {
                nodeLabel
            }
            .padding(12)
            .background(treeBackground)
        } else {
            nodeLabel
                .padding(12)
                .background(treeBackground)
        }
    }

    @ViewBuilder
    private var nodeLabel: some View {
        if let type = node.type {
            Button(action: { onSelect(type) }) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(node.title)
                            .font(.system(.body, design: .rounded).weight(.semibold))
                            .foregroundColor(.primary)

                        Text(type.objectLabel + (node.detail.map { " • inherits \($0)" } ?? ""))
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(.secondary)
                    }

                    Spacer(minLength: 8)

                    if type.id == selectedTypeID {
                        Text("Selected")
                            .font(.system(.caption2, design: .rounded).weight(.bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color(red: 0.09, green: 0.42, blue: 0.54).opacity(0.14)))
                            .foregroundColor(Color(red: 0.09, green: 0.42, blue: 0.54))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        } else {
            HStack {
                Text(node.title)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                Spacer()
                if let detail = node.detail {
                    Text(detail)
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var treeBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(node.type?.id == selectedTypeID ? Color(red: 0.9, green: 0.97, blue: 0.99) : Color.white.opacity(0.7))
    }
}

private struct FieldRowView: View {
    let row: TypeFieldRow

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(row.field.name)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))

                Text(row.field.declaration)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
                OffsetBadge(title: "Offset", value: row.field.offsetBytes.map(hex) ?? "-")
                OffsetBadge(title: "Size", value: row.field.sizeBytes.map(hex) ?? "-")
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(row.field.isPadding ? Color(red: 0.95, green: 0.94, blue: 0.9) : Color.white.opacity(0.78))
        )
        .overlay(alignment: .topLeading) {
            if row.field.isPadding {
                TinyTag(text: "Padding", tint: Color(red: 0.54, green: 0.42, blue: 0.08))
                    .padding(10)
            }
        }
    }

    private func hex(_ value: UInt64) -> String {
        String(format: "0x%llX", value)
    }
}

private struct GraphConnector: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 999, style: .continuous)
            .fill(Color(red: 0.35, green: 0.55, blue: 0.61).opacity(0.28))
            .frame(width: 4, height: 18)
            .frame(maxWidth: .infinity)
    }
}

private enum GraphNodeEmphasis {
    case ancestor
    case selected
    case sibling
    case child
}

private struct GraphNodeButton: View {
    let type: SDKType
    let emphasis: GraphNodeEmphasis
    var compact: Bool = false
    let onSelect: (SDKType) -> Void

    var body: some View {
        Button(action: { onSelect(type) }) {
            VStack(alignment: .leading, spacing: 6) {
                Text(type.name)
                    .font(.system(compact ? .caption : .subheadline, design: .rounded).weight(.bold))
                    .foregroundColor(titleColor)
                Text(type.objectLabel + (type.parentTypeName.map { " • \($0)" } ?? ""))
                    .font(.system(compact ? .caption2 : .caption, design: .rounded))
                    .foregroundColor(titleColor.opacity(0.78))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(compact ? 10 : 14)
            .background(background)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var background: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(
                LinearGradient(
                    colors: colors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    private var colors: [Color] {
        switch emphasis {
        case .ancestor:
            return [Color.white.opacity(0.82), Color(red: 0.92, green: 0.94, blue: 0.98)]
        case .selected:
            return [Color(red: 0.08, green: 0.35, blue: 0.5), Color(red: 0.11, green: 0.58, blue: 0.62)]
        case .sibling:
            return [Color(red: 0.98, green: 0.93, blue: 0.84), Color.white]
        case .child:
            return [Color.white, Color(red: 0.89, green: 0.97, blue: 0.95)]
        }
    }

    private var titleColor: Color {
        switch emphasis {
        case .selected:
            return .white
        default:
            return .primary
        }
    }
}

private struct SearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Search types, labels, or parents", text: $text)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)

            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.78))
        )
    }
}

private struct MetricBadge: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(.caption2, design: .rounded).weight(.bold))
                .foregroundColor(Color.white.opacity(0.68))
            Text(value)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct OverviewStatCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(.headline, design: .rounded).weight(.bold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.74))
        )
    }
}

private struct OffsetBadge: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(title)
                .font(.system(.caption2, design: .rounded).weight(.bold))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(.caption, design: .monospaced).weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(red: 0.92, green: 0.95, blue: 0.97))
        )
    }
}

private struct TinyTag: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.system(.caption2, design: .rounded).weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Capsule().fill(tint.opacity(0.14)))
            .foregroundColor(tint)
    }
}

private struct AtlasInputField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundColor(.secondary)

            TextField(title, text: $text)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.78))
                )
        }
    }
}

private struct AtlasSectionCard<Content: View>: View {
    let title: String
    let subtitle: String
    let content: Content

    init(title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                Text(subtitle)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundColor(.secondary)
            }

            content
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.64))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.52), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 20, y: 10)
    }
}

private struct EmptySectionState: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(.headline, design: .rounded).weight(.semibold))
            Text(message)
                .font(.system(.footnote, design: .rounded))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.58))
        )
    }
}

private struct AtlasBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.96, green: 0.94, blue: 0.9), Color(red: 0.88, green: 0.94, blue: 0.96)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.white.opacity(0.4))
                .frame(width: 320, height: 320)
                .offset(x: 150, y: -280)

            Circle()
                .fill(Color(red: 0.78, green: 0.89, blue: 0.93).opacity(0.45))
                .frame(width: 260, height: 260)
                .offset(x: -170, y: 260)
        }
    }
}

private struct AtlasPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, design: .rounded).weight(.bold))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.78 : 0.92))
            )
            .foregroundColor(Color(red: 0.08, green: 0.27, blue: 0.36))
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
    }
}

private struct AtlasSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, design: .rounded).weight(.bold))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.08 : 0.14))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.22), lineWidth: 1)
            )
            .foregroundColor(.white)
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
    }
}
