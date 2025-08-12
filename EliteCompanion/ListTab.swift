import SwiftUI

// Model for a single note/item
struct NoteItem: Identifiable, Codable {
    let id: UUID
    var content: String
    
    init(id: UUID = UUID(), content: String) {
        self.id = id
        self.content = content
    }
}

// Model for a list of notes
struct NoteList: Identifiable, Codable {
    let id: UUID
    var name: String
    var notes: [NoteItem]
    
    init(id: UUID = UUID(), name: String, notes: [NoteItem] = []) {
        self.id = id
        self.name = name
        self.notes = notes
    }
}

struct ListsTab: View {
    @State private var lists: [NoteList] = []
    @State private var selectedListID: UUID? = nil
    @State private var newListName: String = ""
    @State private var newNoteContent: String = ""
    @State private var showNewListAlert = false
    
    let highlightColor: Color

    
    // UserDefaults key for persistence
    private let storageKey = "SavedNoteLists"
    
    var body: some View {
        NavigationView {
            VStack {
                // List selector + add list field
                HStack {
                    TextField("New List Name", text: $newListName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button(action: addNewList) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                    .disabled(newListName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .help("Add a new list")
                }
                .padding()
                
                // Lists sidebar
                List(selection: $selectedListID) {
                    ForEach(lists) { list in
                        Text(list.name)
                            .tag(list.id)
                    }
                    .onDelete(perform: deleteLists)
                }
                .listStyle(SidebarListStyle())
                .frame(minWidth: 200, maxWidth: 300)
                
                Divider()
                
                // Notes area
                if let selectedID = selectedListID,
                   let selectedIndex = lists.firstIndex(where: { $0.id == selectedID }) {
                    VStack(alignment: .leading) {
                        Text("Notes for '\(lists[selectedIndex].name)'")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        List {
                            ForEach(lists[selectedIndex].notes) { note in
                                Text(note.content)
                            }
                            .onDelete { indexSet in
                                deleteNotes(at: indexSet, for: selectedIndex)
                            }
                        }
                        
                        HStack {
                            TextField("Add new note", text: $newNoteContent)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            Button(action: {
                                addNote(to: selectedIndex)
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                            }
                            .disabled(newNoteContent.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                        .padding()
                    }
                } else {
                    Text("Select a list to view notes")
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
            .navigationTitle("Lists & Notes")
            .onAppear(perform: loadLists)
            .toolbar {
                EditButton()
            }
        }
    }
    
    // MARK: - List management
    
    func addNewList() {
        let trimmed = newListName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let newList = NoteList(name: trimmed)
        lists.append(newList)
        selectedListID = newList.id
        newListName = ""
        saveLists()
    }
    
    func deleteLists(at offsets: IndexSet) {
        lists.remove(atOffsets: offsets)
        // Update selection if needed
        if let selected = selectedListID, !lists.contains(where: { $0.id == selected }) {
            selectedListID = lists.first?.id
        }
        saveLists()
    }
    
    // MARK: - Notes management
    
    func addNote(to listIndex: Int) {
        let trimmed = newNoteContent.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let newNote = NoteItem(content: trimmed)
        lists[listIndex].notes.append(newNote)
        newNoteContent = ""
        saveLists()
    }
    
    func deleteNotes(at offsets: IndexSet, for listIndex: Int) {
        lists[listIndex].notes.remove(atOffsets: offsets)
        saveLists()
    }
    
    // MARK: - Persistence
    
    func saveLists() {
        do {
            let data = try JSONEncoder().encode(lists)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("Failed to save lists:", error)
        }
    }
    
    func loadLists() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        do {
            let decoded = try JSONDecoder().decode([NoteList].self, from: data)
            self.lists = decoded
            if selectedListID == nil {
                selectedListID = lists.first?.id
            }
        } catch {
            print("Failed to load lists:", error)
        }
    }
}
