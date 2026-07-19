import React, { useState, useEffect } from "react";
import {
  View, Text, TouchableOpacity, StyleSheet, ScrollView,
  TextInput, Modal, Dimensions, Switch, Platform, FlatList,
} from "react-native";

const { width: SW } = Dimensions.get("window");

type Word = {
  id: number;
  word: string;
  start: number;
  end: number;
  punctuated_word?: string;
};

type CaptionGroup = {
  id: number;
  words: Word[];
  text: string;
  start: number;
  end: number;
};

type CaptionSettings = {
  position: "top" | "middle" | "bottom";
  fontSize: number;
  lines: 1 | 2 | 3;
  popupEffect: boolean;
  color: string;
  bgColor: string;
};

type Props = {
  visible: boolean;
  words: Word[];
  onClose: () => void;
  onSave: (groups: CaptionGroup[], settings: CaptionSettings) => void;
};

const TEXT_COLORS = ["#FFFFFF", "#FFD700", "#00FFFF", "#FF4081", "#00FF41", "#FF6B00", "#000000"];
const BG_COLORS = [
  { label: "Dark", value: "rgba(0,0,0,0.8)" },
  { label: "None", value: "transparent" },
  { label: "Gold", value: "#FFD700" },
  { label: "Navy", value: "#0B132B" },
  { label: "Pink", value: "#FF4081" },
  { label: "Glass", value: "rgba(255,255,255,0.2)" },
];

export default function CaptionEditor({ visible, words, onClose, onSave }: Props) {
  const [groups, setGroups] = useState<CaptionGroup[]>([]);
  const [settings, setSettings] = useState<CaptionSettings>({
    position: "bottom",
    fontSize: 22,
    lines: 2,
    popupEffect: true,
    color: "#FFFFFF",
    bgColor: "rgba(0,0,0,0.8)",
  });
  const [editingWord, setEditingWord] = useState<{ word: Word; groupId: number } | null>(null);
  const [editText, setEditText] = useState("");
  const [activeTab, setActiveTab] = useState<"captions" | "style">("captions");

  const regenerateGroups = (lineCount: 1 | 2 | 3) => {
    if (words.length === 0) return;
    const wordsPerGroup = lineCount === 1 ? 3 : 7;
    const newGroups: CaptionGroup[] = [];
    let i = 0;
    let id = 0;
    while (i < words.length) {
      const chunk = words.slice(i, i + wordsPerGroup);
      newGroups.push({
        id: id++,
        words: chunk,
        text: chunk.map((w) => w.punctuated_word || w.word).join(" "),
        start: chunk[0].start,
        end: chunk[chunk.length - 1].end,
      });
      i += wordsPerGroup;
    }
    setGroups(newGroups);
  };

  useEffect(() => {
    if (words.length > 0) {
      const wordsPerGroup = settings.lines === 1 ? 3 : 7;
      const newGroups: CaptionGroup[] = [];
      let i = 0;
      let id = 0;
      while (i < words.length) {
        const chunk = words.slice(i, i + wordsPerGroup);
        newGroups.push({
          id: id++,
          words: chunk,
          text: chunk.map((w) => w.punctuated_word || w.word).join(" "),
          start: chunk[0].start,
          end: chunk[chunk.length - 1].end,
        });
        i += wordsPerGroup;
      }
      setGroups(newGroups);
    }
  }, [words, settings.lines]);

  const updateWordText = (groupId: number, wordId: number, newText: string) => {
    setGroups((prev) =>
      prev.map((g) => {
        if (g.id !== groupId) return g;
        const newWords = g.words.map((w) =>
          w.id === wordId ? { ...w, punctuated_word: newText, word: newText } : w
        );
        return { ...g, words: newWords, text: newWords.map((w) => w.punctuated_word || w.word).join(" ") };
      })
    );
  };

  const updateGroupText = (groupId: number, newText: string) => {
    setGroups((prev) => prev.map((g) => (g.id === groupId ? { ...g, text: newText } : g)));
  };

  const deleteGroup = (groupId: number) => {
    setGroups((prev) => prev.filter((g) => g.id !== groupId));
  };

  const splitGroup = (groupId: number) => {
    const group = groups.find((g) => g.id === groupId);
    if (!group || group.words.length < 2) return;
    const mid = Math.floor(group.words.length / 2);
    const first = group.words.slice(0, mid);
    const second = group.words.slice(mid);
    setGroups((prev) =>
      prev.flatMap((g) => {
        if (g.id !== groupId) return [g];
        return [
          { id: g.id, words: first, text: first.map((w) => w.punctuated_word || w.word).join(" "), start: first[0].start, end: first[first.length - 1].end },
          { id: Date.now(), words: second, text: second.map((w) => w.punctuated_word || w.word).join(" "), start: second[0].start, end: second[second.length - 1].end },
        ];
      })
    );
  };

  const fmt = (s: number) => s.toFixed(1) + "s";

  return (
    <Modal visible={visible} animationType="slide" onRequestClose={onClose}>
      <View style={s.container}>
        {/* Header */}
        <View style={s.header}>
          <TouchableOpacity onPress={onClose} style={s.headerBtn}>
            <Text style={s.headerBtnTxt}>Cancel</Text>
          </TouchableOpacity>
          <Text style={s.headerTitle}>Caption Editor</Text>
          <TouchableOpacity onPress={() => onSave(groups, settings)} style={[s.headerBtn, s.saveBtn]}>
            <Text style={[s.headerBtnTxt, { color: "#0B132B" }]}>Save</Text>
          </TouchableOpacity>
        </View>

        {/* Preview */}
        <View style={[s.preview, { backgroundColor: settings.bgColor === "transparent" ? "#1C2541" : settings.bgColor }]}>
          <Text style={[s.previewTxt, { fontSize: settings.fontSize, color: settings.color }]}>
            Preview Caption
          </Text>
        </View>

        {/* Tabs */}
        <View style={s.tabs}>
          <TouchableOpacity style={[s.tab, activeTab === "captions" && s.tabActive]} onPress={() => setActiveTab("captions")}>
            <Text style={[s.tabTxt, activeTab === "captions" && s.tabTxtActive]}>Captions</Text>
          </TouchableOpacity>
          <TouchableOpacity style={[s.tab, activeTab === "style" && s.tabActive]} onPress={() => setActiveTab("style")}>
            <Text style={[s.tabTxt, activeTab === "style" && s.tabTxtActive]}>Style</Text>
          </TouchableOpacity>
        </View>

        {activeTab === "style" ? (
          <ScrollView style={s.stylePanel}>
            {/* Position */}
            <Text style={s.sectionLabel}>Position</Text>
            <View style={s.optRow}>
              {(["top", "middle", "bottom"] as const).map((p) => (
                <TouchableOpacity key={p} style={[s.optBtn, settings.position === p && s.optBtnActive]} onPress={() => setSettings((st) => ({ ...st, position: p }))}>
                  <Text style={[s.optTxt, settings.position === p && s.optTxtActive]}>{p.charAt(0).toUpperCase() + p.slice(1)}</Text>
                </TouchableOpacity>
              ))}
            </View>

            {/* Lines */}
            <Text style={s.sectionLabel}>Lines per Caption</Text>
            <View style={s.optRow}>
              {([1, 2] as const).map((l) => (
                <TouchableOpacity key={l} style={[s.optBtn, settings.lines === l && s.optBtnActive]} onPress={() => { setSettings((st) => ({ ...st, lines: l })); regenerateGroups(l); }}>
                  <Text style={[s.optTxt, settings.lines === l && s.optTxtActive]}>{l} Line{l > 1 ? "s" : ""}</Text>
                </TouchableOpacity>
              ))}
            </View>

            {/* Font Size */}
            <Text style={s.sectionLabel}>Font Size</Text>
            <View style={s.optRow}>
              {[16, 18, 22, 26, 30, 36].map((sz) => (
                <TouchableOpacity key={sz} style={[s.optBtn, settings.fontSize === sz && s.optBtnActive]} onPress={() => setSettings((st) => ({ ...st, fontSize: sz }))}>
                  <Text style={[s.optTxt, settings.fontSize === sz && s.optTxtActive]}>{sz}</Text>
                </TouchableOpacity>
              ))}
            </View>

            {/* Pop Effect */}
            <View style={s.switchRow}>
              <Text style={s.sectionLabel}>Pop Effect</Text>
              <Switch value={settings.popupEffect} onValueChange={(v) => setSettings((st) => ({ ...st, popupEffect: v }))} trackColor={{ true: "#FFD700" }} thumbColor="#FFFFFF" />
            </View>

            {/* Text Color */}
            <Text style={s.sectionLabel}>Text Color</Text>
            <View style={s.colorRow}>
              {TEXT_COLORS.map((c) => (
                <TouchableOpacity key={c} onPress={() => setSettings((st) => ({ ...st, color: c }))} style={[s.colorDot, { backgroundColor: c }, settings.color === c && s.colorDotActive]} />
              ))}
            </View>

            {/* Background */}
            <Text style={s.sectionLabel}>Background</Text>
            <View style={s.optRow}>
              {BG_COLORS.map((bg) => (
                <TouchableOpacity key={bg.value} style={[s.optBtn, settings.bgColor === bg.value && s.optBtnActive]} onPress={() => setSettings((st) => ({ ...st, bgColor: bg.value }))}>
                  <Text style={[s.optTxt, settings.bgColor === bg.value && s.optTxtActive]}>{bg.label}</Text>
                </TouchableOpacity>
              ))}
            </View>
          </ScrollView>
        ) : (
          <FlatList
            data={groups}
            keyExtractor={(item) => item.id.toString()}
            style={s.captionsList}
            contentContainerStyle={{ paddingBottom: 40 }}
            renderItem={({ item: group }) => (
              <View style={s.groupCard}>
                <View style={s.groupHeader}>
                  <Text style={s.groupTime}>{fmt(group.start)} — {fmt(group.end)}</Text>
                  <View style={s.groupBtns}>
                    <TouchableOpacity onPress={() => splitGroup(group.id)} style={s.smallBtn}>
                      <Text style={s.smallBtnTxt}>Split</Text>
                    </TouchableOpacity>
                    <TouchableOpacity onPress={() => deleteGroup(group.id)} style={[s.smallBtn, s.deleteBtn]}>
                      <Text style={s.smallBtnTxt}>Delete</Text>
                    </TouchableOpacity>
                  </View>
                </View>

                {/* Word chips */}
                <View style={s.wordsRow}>
                  {group.words.map((word) => (
                    <TouchableOpacity
                      key={word.id}
                      style={s.wordChip}
                      onPress={() => { setEditingWord({ word, groupId: group.id }); setEditText(word.punctuated_word || word.word); }}
                    >
                      <Text style={s.wordChipTxt}>{word.punctuated_word || word.word}</Text>
                    </TouchableOpacity>
                  ))}
                </View>

                {/* Full text edit */}
                <TextInput
                  style={s.groupInput}
                  value={group.text}
                  onChangeText={(t) => updateGroupText(group.id, t)}
                  multiline
                  placeholderTextColor="#7A8499"
                />
              </View>
            )}
          />
        )}

        {/* Word edit modal */}
        <Modal visible={!!editingWord} transparent animationType="fade">
          <View style={s.wordEditOverlay}>
            <View style={s.wordEditBox}>
              <Text style={s.wordEditTitle}>Edit Word</Text>
              <TextInput style={s.wordEditInput} value={editText} onChangeText={setEditText} autoFocus selectTextOnFocus />
              <View style={s.wordEditBtns}>
                <TouchableOpacity onPress={() => setEditingWord(null)} style={s.wordEditBtn}>
                  <Text style={{ color: "#fff", fontWeight: "600" }}>Cancel</Text>
                </TouchableOpacity>
                <TouchableOpacity
                  onPress={() => {
                    if (editingWord) {
                      updateWordText(editingWord.groupId, editingWord.word.id, editText);
                      setEditingWord(null);
                    }
                  }}
                  style={[s.wordEditBtn, { backgroundColor: "#FFD700" }]}
                >
                  <Text style={{ color: "#0B132B", fontWeight: "700" }}>Save</Text>
                </TouchableOpacity>
              </View>
            </View>
          </View>
        </Modal>
      </View>
    </Modal>
  );
}

const s = StyleSheet.create({
  container: { flex: 1, backgroundColor: "#0B132B" },
  header: { flexDirection: "row", alignItems: "center", justifyContent: "space-between", padding: 16, paddingTop: Platform.OS === "ios" ? 56 : 16, borderBottomWidth: 1, borderBottomColor: "#1C2541" },
  headerBtn: { paddingHorizontal: 14, paddingVertical: 8, borderRadius: 8, backgroundColor: "#1C2541" },
  saveBtn: { backgroundColor: "#FFD700" },
  headerBtnTxt: { color: "#FFFFFF", fontWeight: "600", fontSize: 14 },
  headerTitle: { color: "#FFD700", fontSize: 18, fontWeight: "800" },
  preview: { padding: 20, alignItems: "center", minHeight: 70, justifyContent: "center", marginHorizontal: 16, marginTop: 12, borderRadius: 12 },
  previewTxt: { fontWeight: "800", textAlign: "center" },
  tabs: { flexDirection: "row", marginHorizontal: 16, marginTop: 12, backgroundColor: "#1C2541", borderRadius: 10, padding: 4 },
  tab: { flex: 1, paddingVertical: 8, alignItems: "center", borderRadius: 8 },
  tabActive: { backgroundColor: "#FFD700" },
  tabTxt: { color: "#FFFFFF", fontWeight: "600" },
  tabTxtActive: { color: "#0B132B" },
  stylePanel: { flex: 1, paddingHorizontal: 16, paddingTop: 16 },
  sectionLabel: { color: "#AAAAAA", fontSize: 12, fontWeight: "600", marginBottom: 8, marginTop: 16 },
  optRow: { flexDirection: "row", flexWrap: "wrap", gap: 8 },
  optBtn: { paddingHorizontal: 14, paddingVertical: 8, borderRadius: 8, backgroundColor: "#1C2541", borderWidth: 1, borderColor: "#3A4374" },
  optBtnActive: { backgroundColor: "#FFD700", borderColor: "#FFD700" },
  optTxt: { color: "#FFFFFF", fontSize: 13, fontWeight: "600" },
  optTxtActive: { color: "#0B132B" },
  switchRow: { flexDirection: "row", alignItems: "center", justifyContent: "space-between", marginTop: 16 },
  colorRow: { flexDirection: "row", gap: 10, flexWrap: "wrap" },
  colorDot: { width: 32, height: 32, borderRadius: 16, borderWidth: 2, borderColor: "#3A4374" },
  colorDotActive: { borderColor: "#FFD700", borderWidth: 3 },
  captionsList: { flex: 1, paddingHorizontal: 12, paddingTop: 8 },
  groupCard: { backgroundColor: "#1C2541", borderRadius: 12, padding: 12, marginBottom: 10 },
  groupHeader: { flexDirection: "row", justifyContent: "space-between", alignItems: "center", marginBottom: 8 },
  groupTime: { color: "#FFD700", fontSize: 12, fontWeight: "600" },
  groupBtns: { flexDirection: "row", gap: 6 },
  smallBtn: { backgroundColor: "#3A4374", paddingHorizontal: 10, paddingVertical: 4, borderRadius: 6 },
  deleteBtn: { backgroundColor: "#3A1F1F" },
  smallBtnTxt: { color: "#FFFFFF", fontSize: 11, fontWeight: "600" },
  wordsRow: { flexDirection: "row", flexWrap: "wrap", gap: 6, marginBottom: 8 },
  wordChip: { backgroundColor: "#0B132B", paddingHorizontal: 10, paddingVertical: 5, borderRadius: 20, borderWidth: 1, borderColor: "#FFD700" },
  wordChipTxt: { color: "#FFD700", fontSize: 13, fontWeight: "600" },
  groupInput: { color: "#FFFFFF", fontSize: 14, backgroundColor: "#0B132B", borderRadius: 8, padding: 10, minHeight: 44 },
  wordEditOverlay: { flex: 1, backgroundColor: "rgba(0,0,0,0.85)", justifyContent: "center", alignItems: "center" },
  wordEditBox: { backgroundColor: "#1C2541", borderRadius: 16, padding: 24, width: SW * 0.82 },
  wordEditTitle: { color: "#FFD700", fontSize: 18, fontWeight: "800", marginBottom: 16, textAlign: "center" },
  wordEditInput: { backgroundColor: "#0B132B", color: "#FFFFFF", fontSize: 18, padding: 12, borderRadius: 8, borderWidth: 1, borderColor: "#FFD700", marginBottom: 16 },
  wordEditBtns: { flexDirection: "row", gap: 10 },
  wordEditBtn: { flex: 1, padding: 12, borderRadius: 8, backgroundColor: "#3A4374", alignItems: "center" },
});
