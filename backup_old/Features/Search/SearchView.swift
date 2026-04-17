import SwiftUI

struct SearchView: View {
    @EnvironmentObject var appState: AppState
    @State private var searchText = ""
    @State private var results: [(room: Room, object: DetectedObject)] = []
    @State private var selected: (room: Room, object: DetectedObject)?

    private let storage = ObjectStorageService()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("搜索物体...", text: $searchText)
                        .textFieldStyle(.plain)
                        .onSubmit { search() }
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            results = []
                        } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                    }
                }
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
                .padding()

                if searchText.isEmpty {
                    if appState.rooms.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "magnifyingglass").font(.system(size: 60)).foregroundStyle(.secondary)
                            Text("搜索你的物品").font(.headline)
                            Text("输入物体名称、描述或分类").font(.subheadline).foregroundStyle(.secondary)
                        }.frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List {
                            ForEach(appState.rooms) { room in
                                Section(room.name) {
                                    ForEach(room.objects) { obj in
                                        HStack {
                                            Rectangle().fill(Color(.systemGray4))
                                                .frame(width: 50, height: 50).cornerRadius(8)
                                                .overlay { Image(systemName: "photo").foregroundStyle(.secondary) }
                                            VStack(alignment: .leading) {
                                                Text(obj.name).font(.headline)
                                                Text(obj.category).font(.caption).foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                        }
                                        .onTapGesture { selected = (room, obj) }
                                    }
                                }
                            }
                        }
                    }
                } else if results.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "magnifyingglass").font(.system(size: 60)).foregroundStyle(.secondary)
                        Text("未找到 \"\(searchText)\"").font(.headline)
                        Text("尝试其他关键词").font(.subheadline).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(results, id: \.object.id) { r in
                            HStack {
                                if let thumb = r.object.thumbnail {
                                    thumb.resizable().scaledToFill().frame(width: 50, height: 50).cornerRadius(8)
                                } else {
                                    Rectangle().fill(Color(.systemGray4))
                                        .frame(width: 50, height: 50).cornerRadius(8)
                                        .overlay { Image(systemName: "cube").foregroundStyle(.secondary) }
                                }
                                VStack(alignment: .leading) {
                                    Text(r.object.name).font(.headline)
                                    Text("\(r.room.name) · \(r.object.category)").font(.caption).foregroundStyle(.secondary)
                                    Text(r.object.description).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(.secondary)
                            }
                            .onTapGesture { selected = r }
                        }
                    }
                }
            }
            .navigationTitle("搜索")
            .sheet(item: $selected) { ObjectDetailView(object: $0.object) }
        }
    }

    private func search() {
        guard !searchText.isEmpty else { results = []; return }
        results = storage.searchObjects(query: searchText)
    }
}