import SwiftUI
import ARKit
import RealityKit

struct ScanView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var scanCoordinator = ScanCoordinator()
    @State private var showRoomList = false
    @State private var showCreateRoom = false
    @State private var newRoomName = ""

    var body: some View {
        NavigationStack {
            VStack {
                if appState.currentRoom == nil {
                    VStack(spacing: 20) {
                        Image(systemName: "cube.transparent")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)
                        Text("选择或创建房间开始扫描")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Button("创建新房间") { showCreateRoom = true }
                            .buttonStyle(.borderedProminent)
                        Button("选择已有房间") { showRoomList = true }
                            .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if appState.isScanning {
                    ScanningView(scanCoordinator: scanCoordinator, room: appState.currentRoom!)
                } else {
                    scannedRoomView
                }
            }
            .navigationTitle("扫描房间")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("新建房间") { showCreateRoom = true }
                        Button("选择房间") { showRoomList = true }
                    } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showRoomList) { RoomListView() }
            .alert("新建房间", isPresented: $showCreateRoom) {
                TextField("房间名称", text: $newRoomName)
                Button("取消", role: .cancel) { newRoomName = "" }
                Button("创建") {
                    if !newRoomName.isEmpty {
                        _ = appState.createRoom(name: newRoomName)
                        newRoomName = ""
                    }
                }
            }
        }
    }

    private var scannedRoomView: some View {
        VStack(spacing: 20) {
            if let room = appState.currentRoom {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "house.fill").foregroundStyle(.blue)
                        Text(room.name).font(.title2.bold())
                        Spacer()
                        Text("\(room.objects.count) 个物体")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Text("更新于 \(room.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)

                Button(appState.isScanning ? "正在扫描..." : "继续扫描") {
                    appState.isScanning = true
                }
                .disabled(appState.isScanning)
                .buttonStyle(.borderedProminent)

                List {
                    Section("已识别物体 (\(room.objects.count))") {
                        ForEach(room.objects) { object in
                            HStack {
                                Rectangle()
                                    .fill(Color(.systemGray4))
                                    .frame(width: 50, height: 50)
                                    .cornerRadius(8)
                                    .overlay { Image(systemName: "photo").foregroundStyle(.secondary) }
                                VStack(alignment: .leading) {
                                    Text(object.name).font(.headline)
                                    Text(object.category).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .padding()
    }
}