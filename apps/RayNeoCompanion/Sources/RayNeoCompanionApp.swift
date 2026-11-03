import SwiftUI

@main
struct RayNeoCompanionApp: App {
    @StateObject private var store = CompanionStore.forCurrentLaunch()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(store.archive)
                .environmentObject(store.archive.audioInspection)
                .environmentObject(store.books)
                .environmentObject(store.voice)
                .environmentObject(store.codex)
                .environmentObject(store.codexPush)
                .environmentObject(store.timeline)
                .environmentObject(store.recordingASR)
                .environmentObject(store.features)
                .environmentObject(store.notifications)
                .environmentObject(store.headControlTest)
                .environmentObject(store.automaticWeather)
                .environmentObject(store.qweather)
                .tint(Palette.accent)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var store: CompanionStore
    @State private var hideTabBar = false
    @State private var didApplyLaunchArguments = false
    @State private var incomingBook: URL?
    @State private var confirmBook = false
    @State private var showBooks = false
    @Namespace private var tabSelection

    var body: some View {
        Group {
            switch store.selectedTab {
            case 1: ConversationView()
            case 2: ArchiveView()
            case 3: ToolsView()
            default: DeviceView()
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !hideTabBar {
            HStack(spacing: 2) {
                tabButton(0, "设备", "eyeglasses")
                tabButton(1, "会话", "bubble.left")
                tabButton(2, "归档", "folder")
                tabButton(3, "工具", "case")
            }
            .padding(5)
            .liquidGlass(in: Capsule())
            .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
            .animation(.spring(response: 0.38, dampingFraction: 0.78), value: store.selectedTab)
            .frame(maxWidth: 440)
            .padding(.horizontal, 22).padding(.bottom, 6)
            }
        }
        .onPreferenceChange(CompanionTabBarHiddenPreference.self) { hideTabBar = $0 }
        .task {
            while !Task.isCancelled {
                await store.codexPush.tick()
                do { try await Task.sleep(nanoseconds: 2_000_000_000) } catch { break }
            }
        }
        .onOpenURL { url in
            guard url.isFileURL, ["txt", "epub"].contains(url.pathExtension.lowercased()) else { return }
            incomingBook = url; confirmBook = true
        }
        .confirmationDialog("将这份书籍复制为Turbo IO本地文字？不上传、不修改原文件。", isPresented: $confirmBook) {
            Button("导入书籍") {
                guard let url = incomingBook else { return }
                incomingBook = nil
                Task { await store.books.importFile(url); showBooks = true }
            }
            Button("取消", role: .cancel) { incomingBook = nil }
        }
        .sheet(isPresented: $showBooks) {
            NavigationStack { BookShelfView().toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { showBooks = false } } } }
        }
        .onAppear {
            guard !didApplyLaunchArguments else { return }
            didApplyLaunchArguments = true
            let arguments = ProcessInfo.processInfo.arguments
            if let index = arguments.firstIndex(of: "--ui-tab"), arguments.indices.contains(index + 1) {
                store.selectedTab = Int(arguments[index + 1]) ?? 0
            }
        }
    }

    private func tabButton(_ index: Int, _ title: String, _ icon: String) -> some View {
        Button { store.selectedTab = index } label: {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 20, weight: .medium))
                    .symbolVariant(store.selectedTab == index ? .fill : .none)
                Text(title).font(.system(size: 11, weight: store.selectedTab == index ? .semibold : .medium))
            }
            .foregroundStyle(store.selectedTab == index ? Palette.accentText : Palette.ink.opacity(0.75))
            .frame(maxWidth: .infinity).frame(height: 54)
            .background {
                if store.selectedTab == index {
                    Capsule().fill(Palette.ink.opacity(0.09))
                        .matchedGeometryEffect(id: "tab-selection", in: tabSelection)
                }
            }
            .contentShape(Capsule())
        }.buttonStyle(.plain)
            .accessibilityIdentifier("tab-\(index)").accessibilityLabel(title)
            .accessibilityAddTraits(store.selectedTab == index ? .isSelected : [])
    }
}

struct CompanionTabBarHiddenPreference: PreferenceKey {
    static var defaultValue = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) { value = value || nextValue() }
}
