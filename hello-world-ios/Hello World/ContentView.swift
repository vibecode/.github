//
//  ContentView.swift
//  Hello World
//

import SwiftUI

struct NotebookNote: Identifiable, Hashable {
    let id: UUID
    var title: String
    var body: String
    var updatedAt: Date
    var folder: String

    var preview: String {
        body
            .split(separator: "\n")
            .first
            .map(String.init) ?? "No additional text"
    }
}

struct ContentView: View {
    @State private var notes: [NotebookNote] = NotebookNote.samples
    @State private var selectedFolder = "Notes"
    @State private var selectedNoteId: NotebookNote.ID?
    @State private var searchText = ""

    private let folders = ["Notes", "Cursor Mobile", "Recently Deleted"]

    var body: some View {
        NavigationSplitView {
            FolderSidebar(
                folders: folders,
                selectedFolder: $selectedFolder,
                notes: notes
            )
        } content: {
            NotesList(
                notes: filteredNotes,
                selectedNoteId: $selectedNoteId,
                searchText: $searchText,
                addNote: addNote,
                deleteNotes: deleteNotes
            )
        } detail: {
            if let note = selectedNoteBinding {
                NoteEditor(note: note)
            } else {
                EmptyNotesDetail()
            }
        }
        .tint(.yellow)
        .onAppear {
            selectedNoteId = filteredNotes.first?.id
        }
    }

    private var filteredNotes: [NotebookNote] {
        notes
            .filter { note in
                selectedFolder == "Notes" || note.folder == selectedFolder
            }
            .filter { note in
                searchText.isEmpty ||
                note.title.localizedCaseInsensitiveContains(searchText) ||
                note.body.localizedCaseInsensitiveContains(searchText)
            }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private var selectedNoteBinding: Binding<NotebookNote>? {
        guard let selectedNoteId,
              let index = notes.firstIndex(where: { $0.id == selectedNoteId }) else {
            return nil
        }

        return Binding(
            get: { notes[index] },
            set: { updatedNote in
                notes[index] = updatedNote
                notes[index].updatedAt = .now
            }
        )
    }

    private func addNote() {
        let note = NotebookNote(
            id: UUID(),
            title: "New Note",
            body: "",
            updatedAt: .now,
            folder: selectedFolder == "Notes" ? "Cursor Mobile" : selectedFolder
        )
        notes.insert(note, at: 0)
        selectedNoteId = note.id
    }

    private func deleteNotes(at offsets: IndexSet) {
        let visibleNotes = filteredNotes
        let idsToDelete = offsets.map { visibleNotes[$0].id }
        notes.removeAll { idsToDelete.contains($0.id) }
        selectedNoteId = filteredNotes.first?.id
    }
}

struct FolderSidebar: View {
    let folders: [String]
    @Binding var selectedFolder: String
    let notes: [NotebookNote]

    var body: some View {
        List {
            Section("iCloud") {
                ForEach(folders, id: \.self) { folder in
                    Button {
                        selectedFolder = folder
                    } label: {
                        Label {
                            HStack {
                                Text(folder)
                                Spacer()
                                Text("\(count(for: folder))")
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: icon(for: folder))
                                .foregroundStyle(.yellow)
                        }
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(selectedFolder == folder ? Color.yellow.opacity(0.14) : Color.clear)
                }
            }
        }
        .navigationTitle("Folders")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }

    private func count(for folder: String) -> Int {
        folder == "Notes" ? notes.count : notes.filter { $0.folder == folder }.count
    }

    private func icon(for folder: String) -> String {
        switch folder {
        case "Recently Deleted":
            return "trash"
        default:
            return "folder"
        }
    }
}

struct NotesList: View {
    let notes: [NotebookNote]
    @Binding var selectedNoteId: NotebookNote.ID?
    @Binding var searchText: String
    let addNote: () -> Void
    let deleteNotes: (IndexSet) -> Void

    var body: some View {
        List {
            Section {
                ForEach(notes) { note in
                    Button {
                        selectedNoteId = note.id
                    } label: {
                        NoteRow(note: note, isSelected: selectedNoteId == note.id)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(selectedNoteId == note.id ? Color.yellow.opacity(0.14) : Color.clear)
                }
                .onDelete(perform: deleteNotes)
            } header: {
                Text("\(notes.count) Notes")
                    .textCase(nil)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.plain)
        .navigationTitle("Notes")
        .searchable(text: $searchText, prompt: "Search")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: addNote) {
                    Image(systemName: "square.and.pencil")
                }
                .accessibilityLabel("New note")
            }
        }
    }
}

struct NoteRow: View {
    let note: NotebookNote
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(note.title.isEmpty ? "Untitled Note" : note.title)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(1)

            HStack(spacing: 6) {
                Text(note.updatedAt, style: .date)
                    .fontWeight(.semibold)
                Text(note.preview)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .font(.subheadline)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

struct NoteEditor: View {
    @Binding var note: NotebookNote

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                TextField("Title", text: $note.title, axis: .vertical)
                    .font(.largeTitle.bold())
                    .textFieldStyle(.plain)

                Text(note.updatedAt, format: .dateTime.month(.wide).day().year().hour().minute())
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)

                TextEditor(text: $note.body)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 420)
            }
            .padding(24)
        }
        .background(Color(uiColor: .systemBackground))
        .navigationTitle(note.title.isEmpty ? "Untitled Note" : note.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                } label: {
                    Image(systemName: "checklist")
                }
                Button {
                } label: {
                    Image(systemName: "camera")
                }
                Button {
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
    }
}

struct EmptyNotesDetail: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "note.text")
                .font(.system(size: 56))
                .foregroundStyle(.yellow)

            Text("Select or create a note")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}

extension NotebookNote {
    static let samples: [NotebookNote] = [
        NotebookNote(
            id: UUID(),
            title: "made on cursor mobile",
            body: "This notes app was built from the Hello World demo and installed through Chorus.\n\nIt has folders, search, note previews, editing, and the familiar warm yellow note-taking feel.",
            updatedAt: .now,
            folder: "Cursor Mobile"
        ),
        NotebookNote(
            id: UUID(),
            title: "Shopping List",
            body: "Apples\nCoffee\nSparkling water\nNotebook",
            updatedAt: Calendar.current.date(byAdding: .hour, value: -3, to: .now) ?? .now,
            folder: "Notes"
        ),
        NotebookNote(
            id: UUID(),
            title: "Ideas",
            body: "Try a compact note composer, quick folders, and a polished iPhone install flow.",
            updatedAt: Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now,
            folder: "Notes"
        )
    ]
}
