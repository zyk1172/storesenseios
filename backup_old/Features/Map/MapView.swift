import SwiftUI
import ARKit
import RealityKit

struct MapView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedObject: DetectedObject?

    var body: some View {
        NavigationStack {
            VStack {
                if let room = appState.currentRoom {
                    if room.objects.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "cube.transparent").font(.system(size: 60)).foregroundStyle(.secondary)
                            Text("暂无物体").font(.headline)
                            Text("请先扫描识别").font(.subheadline).foregroundStyle(.secondary)
                        }.frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        VStack(spacing: 0) {
                            Text(room.name).font(.headline).padding()

                            List {
                                ForEach(room.objects) { obj in
                                    HStack {
                                        if let thumb = obj.thumbnail {
                                            thumb.resizable().scaledToFill().frame(width: 50, height: 50).cornerRadius(8)
                                        } else {
                                            Rectangle().fill(Color(.systemGray4))
                                                .frame(width: 50, height: 50).cornerRadius(8)
                                                .overlay { Image(systemName: "cube").foregroundStyle(.secondary) }
                                        }
                                        VStack(alignment: .leading) {
                                            Text(obj.name).font(.headline)
                                            Text("\(obj.category) · (\(String(format: "%.1f", obj.position.x)), \(String(format: "%.1f", obj.position.y)), \(String(format: "%.1f", obj.position.z)))")
                                                .font(.caption).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                    }
                                    .onTapGesture { selectedObject = obj }
                                }
                            }
                        }
                    }
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "house.slash").font(.system(size: 60)).foregroundStyle(.secondary)
                        Text("未选择房间").font(.headline)
                        Text("请先选择房间").font(.subheadline).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("三维地图")
            .sheet(item: $selectedObject) { ObjectDetailView(object: $0) }
        }
    }
}

struct ObjectDetailView: View {
    let object: DetectedObject
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let data = object.imageData, let img = UIImage(data: data) {
                        Image(uiImage: img).resizable().scaledToFit().cornerRadius(12)
                    }

                    GroupBox("基本信息") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack { Text("名称").bold().frame(width: 80); Text(object.name) }
                            HStack { Text("描述").bold().frame(width: 80); Text(object.description) }
                            HStack { Text("分类").bold().frame(width: 80); Text(object.category) }
                            HStack { Text("置信度").bold().frame(width: 80); Text(String(format: "%.0f%%", object.confidence * 100)) }
                        }.font(.subheadline)
                    }

                    GroupBox("位置坐标") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("X: \(String(format: "%.2f", object.position.x)) m")
                            Text("Y: \(String(format: "%.2f", object.position.y)) m")
                            Text("Z: \(String(format: "%.2f", object.position.z)) m")
                        }.font(.subheadline)
                    }

                    if !object.additionalInfo.isEmpty {
                        GroupBox("附加信息") {
                            ForEach(Array(object.additionalInfo.sorted(by: { $0.key < $1.key })), id: \.key) { k, v in
                                HStack { Text(k).bold().frame(width: 80); Text(v) }.font(.subheadline)
                            }
                        }
                    }

                    GroupBox("时间") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("创建: \(object.createdAt.formatted(date: .abbreviated, time: .shortened))")
                            Text("更新: \(object.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                        }.font(.subheadline)
                    }
                }
                .padding()
            }
            .navigationTitle(object.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } }
            }
        }
    }
}