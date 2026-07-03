//
//  ProfileEditorView.swift
//  unisnap
//
//  Created by unisnap on 3/7/2026.
//

import SwiftUI

struct ProfileEditorView: View {
    @ObservedObject var store: ProfileStore
    @Binding var selectedProfileID: UUID?
    @State private var selectedZoneIndex: Int?

    var body: some View {
        if let id = selectedProfileID,
           let idx = store.profiles.firstIndex(where: { $0.id == id }) {
            ScrollView {
                profileDetail(idx: idx)
            }
        } else {
            Text("Select a profile")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Profile Detail

    @ViewBuilder
    private func profileDetail(idx: Int) -> some View {
        let profile = store.profiles[idx]

        VStack(alignment: .leading, spacing: 16) {
            glassCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Button(action: {
                            store.profiles[idx].isFavourite.toggle()
                            store.save()
                        }) {
                            Image(systemName: store.profiles[idx].isFavourite ? "star.fill" : "star")
                                .foregroundColor(store.profiles[idx].isFavourite ? .yellow : .secondary)
                                .font(.system(size: 16))
                        }
                        .buttonStyle(.borderless)

                        TextField("Profile Name", text: $store.profiles[idx].name)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: store.profiles[idx].name) { _, _ in
                                store.save()
                            }
                        Button(action: { deleteProfile(at: idx) }) {
                            Image(systemName: "trash").foregroundColor(.red)
                        }
                        .buttonStyle(.borderless)
                    }

                    HotkeyRecorderRow(
                        displayString: profile.hotkey?.displayString,
                        set: { combo in
                            store.profiles[idx].hotkey = combo
                            store.save()
                        },
                        clear: {
                            store.profiles[idx].hotkey = nil
                            store.save()
                        }
                    )
                }
            }

            glassCard {
                gridWithControls(idx: idx, profile: profile)
            }

            glassCard(padding: 12) {
                zoneList(idx: idx)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }

    // MARK: - Grid with Controls

    @ViewBuilder
    private func gridWithControls(idx: Int, profile: LayoutProfile) -> some View {
        let colCount = profile.columns
        let rowCount = profile.rows

        VStack(alignment: .leading, spacing: 8) {
            Text("Grid")
                .font(.subheadline).fontWeight(.medium)

            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    Button(action: { addRow(idx: idx) }) {
                        Image(systemName: "plus").frame(width: 24, height: 24)
                    }
                    .buttonStyle(.borderless).disabled(rowCount >= 3)

                    Text("\(rowCount)")
                        .font(.system(.caption, design: .monospaced))
                        .frame(width: 24, height: 24)

                    Button(action: { removeRow(idx: idx) }) {
                        Image(systemName: "minus").frame(width: 24, height: 24)
                    }
                    .buttonStyle(.borderless).disabled(rowCount <= 1)
                }
                .frame(width: 24)

                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        Button(action: { addColumn(idx: idx) }) {
                            Image(systemName: "plus").frame(width: 24, height: 24)
                        }
                        .buttonStyle(.borderless).disabled(colCount >= 4)

                        Text("\(colCount)")
                            .font(.system(.caption, design: .monospaced))
                            .frame(width: 24, height: 24)

                        Button(action: { removeColumn(idx: idx) }) {
                            Image(systemName: "minus").frame(width: 24, height: 24)
                        }
                        .buttonStyle(.borderless).disabled(colCount <= 1)
                    }
                    .frame(height: 24)

                    DragGrid(profile: profile, idx: idx, store: store, selectedZoneIndex: $selectedZoneIndex)
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(.white.opacity(0.1), lineWidth: 0.5)
                        }
                }
            }
        }
    }

    // MARK: - Zone List

    @ViewBuilder
    private func zoneList(idx: Int) -> some View {
        let profile = store.profiles[idx]

        VStack(alignment: .leading, spacing: 6) {
            Text("Zones")
                .font(.subheadline).fontWeight(.medium)

            ForEach(Array(profile.zones.enumerated()), id: \.element.id) { i, zone in
                HStack {
                    Text("\(i + 1)")
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 20)
                        .foregroundStyle(.secondary)
                    Text("\(zone.columnSpan)×\(zone.rowSpan)")
                        .font(.system(.body, design: .monospaced))
                    Spacer()

                    if profile.zones.count > 1 {
                        Button(action: { deleteZone(idx: idx, zoneIndex: i) }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.quaternary)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .padding(.vertical, 2)
            }

            Text("Drag on the grid above to create zones")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.top, 2)
        }
    }

    // MARK: - Actions

    private func deleteProfile(at index: Int) {
        let id = store.profiles[index].id
        store.profiles.remove(at: index)
        store.save()
        if selectedProfileID == id { selectedProfileID = store.profiles.first?.id }
    }

    private func addColumn(idx: Int) {
        var p = store.profiles[idx]
        guard p.columns < 4 else { return }
        p.columns += 1
        store.profiles[idx] = p
        store.save()
    }

    private func addRow(idx: Int) {
        var p = store.profiles[idx]
        guard p.rows < 3 else { return }
        p.rows += 1
        store.profiles[idx] = p
        store.save()
    }

    private func removeColumn(idx: Int) {
        var p = store.profiles[idx]
        guard p.columns > 1 else { return }
        p.columns -= 1
        p.zones = p.zones.filter { $0.column < p.columns }
        for i in p.zones.indices {
            if p.zones[i].column + p.zones[i].columnSpan > p.columns {
                p.zones[i].columnSpan = max(1, p.columns - p.zones[i].column)
            }
        }
        store.profiles[idx] = p
        store.save()
    }

    private func removeRow(idx: Int) {
        var p = store.profiles[idx]
        guard p.rows > 1 else { return }
        p.rows -= 1
        p.zones = p.zones.filter { $0.row < p.rows }
        for i in p.zones.indices {
            if p.zones[i].row + p.zones[i].rowSpan > p.rows {
                p.zones[i].rowSpan = max(1, p.rows - p.zones[i].row)
            }
        }
        store.profiles[idx] = p
        store.save()
    }

    private func deleteZone(idx: Int, zoneIndex: Int) {
        var p = store.profiles[idx]
        guard p.zones.indices.contains(zoneIndex) else { return }
        p.zones.remove(at: zoneIndex)
        if p.zones.isEmpty {
            p.zones = [Zone(column: 0, row: 0, columnSpan: p.columns, rowSpan: p.rows)]
        }
        store.profiles[idx] = p
        store.save()
        selectedZoneIndex = nil
    }
}

// MARK: - Drag Grid

struct DragGrid: View {
    let profile: LayoutProfile
    let idx: Int
    @ObservedObject var store: ProfileStore
    @Binding var selectedZoneIndex: Int?

    @State private var dragStart: (col: Int, row: Int)?
    @State private var dragEnd: (col: Int, row: Int)?

    var body: some View {
        GeometryReader { geo in
            let cellW = geo.size.width / CGFloat(profile.columns)
            let cellH = geo.size.height / CGFloat(profile.rows)

            ZStack {
                Color.gray.opacity(0.04)

                ForEach(1..<profile.columns, id: \.self) { c in
                    let x = CGFloat(c) * cellW
                    Path { p in
                        p.move(to: CGPoint(x: x, y: 0))
                        p.addLine(to: CGPoint(x: x, y: geo.size.height))
                    }
                    .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                }
                ForEach(1..<profile.rows, id: \.self) { r in
                    let y = CGFloat(r) * cellH
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: geo.size.width, y: y))
                    }
                    .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                }

                ForEach(Array(profile.zones.enumerated()), id: \.element.id) { i, zone in
                    let rect = zone.cellRect(cellW: cellW, cellH: cellH, rows: profile.rows)

                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(selectedZoneIndex == i ? Color.accentColor.opacity(0.35) : Color.accentColor.opacity(0.18))
                        .overlay {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .stroke(Color.accentColor.opacity(selectedZoneIndex == i ? 0.7 : 0.4), lineWidth: selectedZoneIndex == i ? 1.5 : 1)
                        }
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                        .onTapGesture { selectedZoneIndex = i }

                    Text("\(i + 1)")
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.4), radius: 1)
                        .position(x: rect.midX, y: rect.midY)
                        .allowsHitTesting(false)
                }

                if let start = dragStart, let end = dragEnd {
                    let sel = dragSelection(start: start, end: end)
                    let rect = cellRect(col: sel.minCol, row: sel.maxRow,
                                        colSpan: sel.maxCol - sel.minCol + 1,
                                        rowSpan: sel.maxRow - sel.minRow + 1,
                                        cellW: cellW, cellH: cellH, rows: profile.rows)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.accentColor.opacity(0.3))
                        .overlay {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .stroke(Color.accentColor.opacity(0.6), lineWidth: 1.5)
                        }
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                        .allowsHitTesting(false)
                }

                ForEach(0..<profile.rows, id: \.self) { row in
                    ForEach(0..<profile.columns, id: \.self) { col in
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .frame(width: cellW, height: cellH)
                            .position(x: CGFloat(col) * cellW + cellW / 2,
                                      y: CGFloat(profile.rows - 1 - row) * cellH + cellH / 2)
                            .gesture(
                                DragGesture(minimumDistance: 1)
                                    .onChanged { value in
                                        let c = colFor(x: value.location.x, cellW: cellW)
                                        let r = rowFor(y: value.location.y, cellH: cellH, rows: profile.rows)
                                        if dragStart == nil { dragStart = (col, row) }
                                        dragEnd = (c, r)
                                    }
                                    .onEnded { _ in
                                        if let start = dragStart, let end = dragEnd {
                                            applyDrag(start: start, end: end)
                                        }
                                        dragStart = nil
                                        dragEnd = nil
                                    }
                            )
                    }
                }
            }
        }
    }

    private func colFor(x: CGFloat, cellW: CGFloat) -> Int {
        max(0, min(Int(x / cellW), profile.columns - 1))
    }

    private func rowFor(y: CGFloat, cellH: CGFloat, rows: Int) -> Int {
        max(0, min(rows - 1 - Int(y / cellH), rows - 1))
    }

    private func dragSelection(start: (col: Int, row: Int), end: (col: Int, row: Int)) -> (minCol: Int, maxCol: Int, minRow: Int, maxRow: Int) {
        (min(start.col, end.col), max(start.col, end.col), min(start.row, end.row), max(start.row, end.row))
    }

    private func cellRect(col: Int, row: Int, colSpan: Int, rowSpan: Int, cellW: CGFloat, cellH: CGFloat, rows: Int) -> CGRect {
        CGRect(
            x: CGFloat(col) * cellW,
            y: CGFloat(rows - 1 - row - rowSpan + 1) * cellH,
            width: cellW * CGFloat(colSpan),
            height: cellH * CGFloat(rowSpan)
        )
    }

    private func applyDrag(start: (col: Int, row: Int), end: (col: Int, row: Int)) {
        let sel = dragSelection(start: start, end: end)
        let newCol = sel.minCol
        let newRow = sel.minRow
        let newColSpan = sel.maxCol - sel.minCol + 1
        let newRowSpan = sel.maxRow - sel.minRow + 1

        var p = store.profiles[idx]

        p.zones = p.zones.filter { zone in
            let zMinCol = zone.column
            let zMaxCol = zone.column + zone.columnSpan - 1
            let zMinRow = zone.row
            let zMaxRow = zone.row + zone.rowSpan - 1
            return newCol > zMaxCol || (newCol + newColSpan - 1) < zMinCol || newRow > zMaxRow || (newRow + newRowSpan - 1) < zMinRow
        }

        p.zones.append(Zone(column: newCol, row: newRow, columnSpan: newColSpan, rowSpan: newRowSpan))
        store.profiles[idx] = p
        store.save()
        selectedZoneIndex = p.zones.count - 1
    }
}
