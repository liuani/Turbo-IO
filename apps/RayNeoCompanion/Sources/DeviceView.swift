import SwiftUI

struct DeviceView: View {
    @EnvironmentObject private var store: CompanionStore
    @EnvironmentObject private var runtime: CompanionVoiceRuntime
    @EnvironmentObject private var automaticWeather: AutomaticWeather
    @EnvironmentObject private var qweather: QWeatherDashboard
    @State private var showSettings = false
    @State private var showConnection = false

    var body: some View {
        Screen(title: "我的眼镜", eyebrow: "Turbo IO · 你的本地智能眼镜助手", headerIcon: "gearshape", headerAction: { showSettings = true }) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text("RayNeo iO").font(.system(size: 28, weight: .bold))
                    Spacer()
                    if store.demoMode {
                        Text("演示界面").font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Color.white.opacity(0.16), in: Capsule())
                    }
                }
                HStack(spacing: 7) {
                    Circle().fill(runtime.ready ? Color(.systemGreen) : Color.white.opacity(0.45)).frame(width: 8, height: 8)
                    Text(runtime.ready ? "已认证连接" : "尚未连接").font(.system(size: 14, weight: .semibold))
                }
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Color.white.opacity(0.14), in: Capsule())
                GlassesIllustration().padding(.horizontal, 15).padding(.vertical, 24)
                Text("眼镜轮廓示意 · 非设备实时状态").font(.system(size: 11)).foregroundStyle(Color.white.opacity(0.6))
            }
            .padding(24).foregroundStyle(.white)
            .background(Palette.heroGradient, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay {
                // Specular rim: a thin light edge that reads as polished glass.
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(LinearGradient(colors: [.white.opacity(0.35), .white.opacity(0.05), .white.opacity(0.12)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.18), radius: 24, y: 12)

            if runtime.supportsDevice {
                PrimaryButton(title: "发现配对中的眼镜", icon: "antenna.radiowaves.left.and.right", enabled: !runtime.enabled) { runtime.discover() }
                HStack(spacing: 10) {
                    Button { runtime.connect() } label: { Text("连接唯一发现的眼镜").font(.system(size: 14, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.8).frame(maxWidth: .infinity).padding(.vertical, 4) }
                        .secondaryGlassButton().disabled(runtime.enabled)
                    Button { runtime.reconnectBonded() } label: { Text("重连本 App 已绑定眼镜").font(.system(size: 14, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.8).frame(maxWidth: .infinity).padding(.vertical, 4) }
                        .secondaryGlassButton()
                        .accessibilityIdentifier("reconnect-bonded")
                }
                Text(runtime.latestEvent).font(.caption).foregroundStyle(Palette.muted)
            } else {
                PrimaryButton(title: "模拟器不连接眼镜", icon: "link", enabled: false) {}
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                Button { store.selectedTab = 1 } label: { shortcut("mic", title: "语音助手", subtitle: "语音识别与对话") }.buttonStyle(.plain)
                Button { store.selectedTab = 2 } label: { shortcut("folder", title: "录音归档", subtitle: "管理本地音频") }.buttonStyle(.plain)
                NavigationLink { PrompterView() } label: { shortcut("text.alignleft", title: "提词器", subtitle: "编辑与手机预览") }.buttonStyle(.plain)
                NavigationLink { TodoView() } label: { shortcut("checkmark.circle", title: "待办清单", subtitle: "记录与管理任务") }.buttonStyle(.plain)
            }
            .glassGroup(spacing: 12)
            NavigationLink { QWeatherDashboardView() } label: {
                Label(qweather.status, systemImage: "cloud.sun")
                    .font(.system(size: 13, weight: .medium)).foregroundStyle(Palette.accentText)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 4)
            }.accessibilityIdentifier("device-weather-status")
            Button { showConnection = true } label: {
                Label("本地功能可用，眼镜控制待验证", systemImage: "info.circle")
                    .font(.system(size: 13, weight: .medium)).foregroundStyle(Palette.accentText).padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading).accentNote(cornerRadius: 18)
            }.buttonStyle(.plain)
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .onAppear { runtime.prepare() }
        .sheet(isPresented: $showConnection) { ConnectionBoundaryView() }
    }

    private func shortcut(_ icon: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon).font(.system(size: 19, weight: .semibold)).foregroundStyle(Palette.accent)
                .frame(width: 40, height: 40).background(Palette.accent.opacity(0.13), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 16, weight: .semibold)).foregroundStyle(Palette.ink)
                Text(subtitle).font(.system(size: 12)).foregroundStyle(Palette.muted)
            }
        }.padding(16).frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
            .liquidGlass(in: RoundedRectangle(cornerRadius: 24, style: .continuous), interactive: true)
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

struct ConnectionBoundaryView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Image(systemName: "link.badge.plus").font(.system(size: 34, weight: .regular)).foregroundStyle(Palette.accent)
                        .frame(width: 68, height: 68).liquidGlass(in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    Text("连接，有清晰的边界。").font(.title2.bold()).foregroundStyle(Palette.ink)
                    Text("Turbo IO使用独立 Bundle 与沙盒。真机构建已接入原型通信核心与语音链路；模拟器构建不加载厂商库或发蓝牙指令。新 App 的配对、后台与镜片效果还需真机复验。")
                        .font(.subheadline).foregroundStyle(Palette.muted).lineSpacing(5)
                    Card {
                        FeatureRow(icon: "iphone", title: "手机侧本地功能", subtitle: "草稿、导入、配置与状态演示", status: "可使用", active: true)
                        FeatureRow(icon: "link", title: "连接、认证与解绑", subtitle: "真机复用原型核心；不自动解绑或重置")
                        FeatureRow(icon: "eyeglasses", title: "镜片显示与反向事件", subtitle: "必须在实际眼镜上逐项验收")
                        FeatureRow(icon: "signature", title: "非越狱签名设备", subtitle: "模拟器构建不代表非越狱通道已验证", status: "待实机")
                    }
                    Text("不会操作固件、解绑官方账号、自动打开麦克风或上传录音。")
                        .font(.footnote.weight(.medium)).foregroundStyle(Palette.accentText)
                }.padding(24)
            }.background(GlassBackdrop()).navigationTitle("连接进度").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }
    }
}
