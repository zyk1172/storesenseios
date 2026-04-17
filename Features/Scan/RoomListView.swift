import SwiftUI

struct RoomListView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    private var groupedRooms: [String: [StorageLocation]] {
        Dictionary(grouping: appState.rooms, by: { $0.groupName })
    }

    var body: some View {
        NavigationView {
            List {
                if appState.rooms.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "house.slash").font(.system(size: 40)).foregroundStyle(.secondary)
                        Text("暂无房间").font(.headline)
                        Text("请创建新房间").font(.subheadline).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    ForEach(groupedRooms.keys.sorted(), id: \.self) { groupName in
                        Section(groupName) {
                            ForEach(groupedRooms[groupName] ?? []) { room in
                                HStack {
                                    Image(systemName: appState.currentRoom?.id == room.id ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(appState.currentRoom?.id == room.id ? .blue : .secondary)
                                    VStack(alignment: .leading) {
                                        Text(room.name).font(.headline)
                                        Text("\(room.items.count) 个物品 · \(room.updatedAt.formatted(date: .abbreviated, time: .omitted))")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                                .onTapGesture {
                                    appState.currentRoom = room
                                    dismiss()
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("选择房间")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("关闭") { dismiss() } }
            }
        }
        .navigationViewStyle(.stack)
    }
}
