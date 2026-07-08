/**
 * AliCaps - Live Captions + 10 Styles + Export
 * @format
 */

import React, { useState } from 'react';
import {
  StatusBar, StyleSheet, useColorScheme, View, Text, TextInput,
  TouchableOpacity, SafeAreaView, ScrollView, KeyboardAvoidingView,
  Platform, ActivityIndicator, Alert, Modal,
} from 'react-native';
import ImagePicker from 'react-native-image-crop-picker';
import Video from 'react-native-video';
import CaptionEditor from './CaptionEditor';

const DG_URL = 'https://api.deepgram.com/v1/listen?model=nova-3&smart_format=true&punctuate=true';
const DG_KEY = '65774809e8fdb3317afb3ec6dec8913202e05bd7';

type W = { word: string; start: number; end: number; punctuated_word?: string };

const STYLES = [
  { id: 'ali_bold', name: 'Ali Bold', bg: 'rgba(0,0,0,0.8)', br: 8, color: '#FFFFFF', fs: 20, fw: '800' },
  { id: 'midnight_bar', name: 'Midnight Bar', bg: 'rgba(0,0,0,0.9)', br: 0, color: '#FFFFFF', fs: 18, fw: '600' },
  { id: 'pulse_highlight', name: 'Pulse Highlight', bg: '#FFD700', br: 6, color: '#0B132B', fs: 18, fw: '800' },
  { id: 'editorial', name: 'Editorial', bg: 'transparent', br: 8, color: '#FFFFFF', fs: 18, fw: '400' },
  { id: 'neon_edge', name: 'Neon Edge', bg: 'rgba(0,0,0,0.6)', br: 8, color: '#00FFFF', fs: 18, fw: '700' },
  { id: 'stacked_bold', name: 'Stacked Bold', bg: 'rgba(0,0,0,0.75)', br: 8, color: '#FFFFFF', fs: 26, fw: '900' },
  { id: 'soft_glass', name: 'Soft Glass', bg: 'rgba(255,255,255,0.15)', br: 12, color: '#FFFFFF', fs: 18, fw: '600' },
  { id: 'typewriter', name: 'Typewriter', bg: 'rgba(0,0,0,0.85)', br: 4, color: '#00FF41', fs: 16, fw: '400' },
  { id: 'gradient_pop', name: 'Gradient Pop', bg: '#FF4081', br: 20, color: '#FFFFFF', fs: 18, fw: '800' },
  { id: 'golden_hour', name: 'Golden Hour', bg: 'transparent', br: 8, color: '#FFD700', fs: 20, fw: '800' },
];

function App() {
  const dark = useColorScheme() === 'dark';
  return (
    <SafeAreaView style={styles.container}>
      <StatusBar barStyle={dark ? 'light-content' : 'dark-content'} />
      <AppContent />
    </SafeAreaView>
  );
}

function AppContent() {
  const [videoPath, setVideoPath] = useState<string | null>(null);
  const [captionText, setCaptionText] = useState<string>('');
  const [words, setWords] = useState<W[]>([]);
  const [showEdit, setShowEdit] = useState<boolean>(false);
  const [loading, setLoading] = useState<boolean>(false);
  const [err, setErr] = useState<string | null>(null);
  const [cap, setCap] = useState<string>('');
  const [styleId, setStyleId] = useState<string>('ali_bold');
  const [showStylePicker, setShowStylePicker] = useState<boolean>(false);
  const [showExport, setShowExport] = useState<boolean>(false);
  const [showCaptionEditor, setShowCaptionEditor] = useState<boolean>(false);
  const [captionGroups, setCaptionGroups] = useState<any[]>([]);
  const [captionStyle, setCaptionStyle] = useState<any>(null);
  const [resolution, setResolution] = useState<string>('1080p');
  const [fps, setFps] = useState<number>(30);

  const currentStyle = STYLES.find(s => s.id === styleId) || STYLES[0];

  const onProgress = (d: any) => {
    if (words.length === 0) return;
    const t = d.currentTime;
    const visible = words.filter((w: W) => w.start >= t - 0.1 && w.start <= t + 2.5);
    setCap(visible.map((w: W) => w.punctuated_word || w.word).join(' '));
  };

  const transcribe = async (path: string) => {
    setLoading(true); setErr(null); setCap(''); setWords([]);
    try {
      const uri = path.startsWith('file://') ? path : 'file://' + path;
      const fileResp = await fetch(uri);
      const blob = await fileResp.blob();
      const res = await fetch(DG_URL, {
        method: 'POST',
        headers: { Authorization: 'Token ' + DG_KEY, 'Content-Type': 'video/mp4' },
        body: blob,
      });
      const j = await res.json();
      setCaptionText(j?.results?.channels?.[0]?.alternatives?.[0]?.transcript || '');
      setWords(j?.results?.channels?.[0]?.alternatives?.[0]?.words || []);
    } catch (e: any) {
      setErr('Could not generate captions. You can type them manually.');
    } finally { setLoading(false); }
  };

  const pickVideo = () => {
    ImagePicker.openPicker({ mediaType: 'video' })
      .then((v: any) => { setVideoPath(v.path); setShowEdit(false); setCaptionText(''); setWords([]); setCap(''); transcribe(v.path); })
      .catch((e: any) => { console.log(e); });
  };

  const exportVideo = async () => {
    const { NativeModules } = require('react-native');
    const exporter = NativeModules.AliCapsExporter;
    if (!exporter) {
      Alert.alert('Error', 'Export module not loaded');
      return;
    }
    setShowExport(false);
    Alert.alert('Exporting...', 'Please wait while your video is being exported.');
    try {
      const cleanPath = videoPath ? (videoPath.startsWith('file://') ? videoPath.replace('file://', '') : videoPath) : '';
      // Group words into 2-second caption windows
      const captions: any[] = [];
      let i = 0;
      while (i < words.length) {
        const windowStart = words[i].start;
        const windowEnd = windowStart + 2.0;
        const chunk: W[] = [];
        while (i < words.length && words[i].start < windowEnd) {
          chunk.push(words[i]);
          i++;
        }
        if (chunk.length > 0) {
          captions.push({
            text: chunk.map((w: W) => w.punctuated_word || w.word).join(' '),
            start: chunk[0].start,
            end: chunk[chunk.length-1].end
          });
        }
      }
      const styleInfo = {
        color: currentStyle.color,
        fontSize: currentStyle.fs,
        bgColor: currentStyle.bg,
        fontWeight: currentStyle.fw,
      };
      await exporter.exportVideo(cleanPath, captions, resolution, fps, styleInfo);
      Alert.alert('Done!', 'Video saved to Camera Roll!');
    } catch (e: any) {
      Alert.alert('Export Failed', String(e?.message || e));
    }
  };

  return (
    <SafeAreaView style={styles.container}>
      <KeyboardAvoidingView style={styles.flexFull} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
        <ScrollView contentContainerStyle={styles.content}>
          <Text style={styles.title}>AliCaps</Text>
          {videoPath ? (
            <View style={styles.previewContainer}>
              <View style={styles.videoWrapper}>
                <Video source={{ uri: videoPath }} style={styles.videoPreview} controls={true} resizeMode="contain" repeat={true} onProgress={onProgress} />
                {cap.length > 0 && (
                  <View style={styles.capOverlay} pointerEvents="none">
                    <View style={{ backgroundColor: currentStyle.bg, borderRadius: currentStyle.br, paddingHorizontal: 14, paddingVertical: 8, maxWidth: '90%' }}>
                      <Text style={{ color: currentStyle.color, fontSize: currentStyle.fs, fontWeight: currentStyle.fw as any, textAlign: 'center', lineHeight: currentStyle.fs + 8 }}>{cap}</Text>
                    </View>
                  </View>
                )}
              </View>
              <TouchableOpacity style={[styles.btn, styles.styleBtn]} onPress={() => setShowStylePicker(!showStylePicker)}>
                <Text style={styles.btnTxt}>Style: {currentStyle.name} {showStylePicker ? 'A' : 'V'}</Text>
              </TouchableOpacity>
              {showStylePicker && (
                <View style={styles.stylePicker}>
                  {STYLES.map(s => (
                    <TouchableOpacity key={s.id} style={[styles.styleOption, s.id === styleId && styles.styleOptionActive]} onPress={() => { setStyleId(s.id); setShowStylePicker(false); }}>
                      <Text style={[styles.styleOptionTxt, s.id === styleId && styles.styleOptionTxtActive]}>{s.name}</Text>
                    </TouchableOpacity>
                  ))}
                </View>
              )}
            {!loading && words.length > 0 && (
              <TouchableOpacity style={[styles.btn, {backgroundColor: '#9B59B6'}]} onPress={() => setShowCaptionEditor(true)}>
                <Text style={styles.btnTxt}>Edit Captions</Text>
              </TouchableOpacity>
            )}
            {!loading && words.length > 0 && (
              <TouchableOpacity style={[styles.btn, styles.exportBtn]} onPress={() => setShowExport(true)}>
                <Text style={styles.btnTxt}>Export Video</Text>
              </TouchableOpacity>
            )}
              <TouchableOpacity style={styles.btn} onPress={pickVideo}><Text style={styles.btnTxt}>Choose a different video</Text></TouchableOpacity>
              {loading && <View style={styles.infoBox}><ActivityIndicator color="#FFD700" size="small" /><Text style={styles.infoTxt}>Listening to your video...</Text></View>}
              {err && <View style={styles.errBox}><Text style={styles.errTxt}>{err}</Text></View>}
              {!loading && words.length > 0 && <View style={styles.okBox}><Text style={styles.okTxt}>{words.length} words timed - play video to see live captions!</Text></View>}
              {!loading && !showEdit && <TouchableOpacity style={[styles.btn, styles.editBtn]} onPress={() => setShowEdit(true)}><Text style={styles.btnTxt}>{captionText ? 'Edit Captions' : 'Add Captions Manually'}</Text></TouchableOpacity>}
              {showEdit && (
                <View style={styles.editBox}>
                  <Text style={styles.label}>Edit your caption text below:</Text>
                  <TextInput style={styles.input} multiline placeholder="Type captions..." placeholderTextColor="#7A8499" value={captionText} onChangeText={setCaptionText} textAlignVertical="top" />
                  <TouchableOpacity style={[styles.btn, styles.doneBtn]} onPress={() => setShowEdit(false)}><Text style={styles.btnTxt}>Done</Text></TouchableOpacity>
                </View>
              )}
            </View>
          ) : (
            <TouchableOpacity style={styles.btn} onPress={pickVideo}><Text style={styles.btnTxt}>Select Video</Text></TouchableOpacity>
          )}
        </ScrollView>
      </KeyboardAvoidingView>
      <Modal visible={showExport} transparent animationType="slide" onRequestClose={() => setShowExport(false)}>
        <View style={styles.modalOverlay}>
          <View style={styles.modalBox}>
            <Text style={styles.modalTitle}>Export Video</Text>
            <Text style={styles.modalLabel}>Resolution:</Text>
            <View style={styles.optRow}>
              {['1080p', '4K'].map(r => (
                <TouchableOpacity key={r} onPress={() => setResolution(r)} style={[styles.optBtn, r === resolution && styles.optBtnActive]}>
                  <Text style={[styles.optTxt, r === resolution && styles.optTxtActive]}>{r}</Text>
                </TouchableOpacity>
              ))}
            </View>
            <Text style={styles.modalLabel}>Frame Rate:</Text>
            <View style={styles.optRow}>
              {[10, 20, 30, 40, 50, 60].map(f => (
                <TouchableOpacity key={f} onPress={() => setFps(f)} style={[styles.optBtn, f === fps && styles.optBtnActive]}>
                  <Text style={[styles.optTxt, f === fps && styles.optTxtActive]}>{f}</Text>
                </TouchableOpacity>
              ))}
            </View>
            <View style={styles.modalBtns}>
              <TouchableOpacity onPress={() => setShowExport(false)} style={[styles.btn, { backgroundColor: '#888' }]}>
                <Text style={styles.btnTxt}>Cancel</Text>
              </TouchableOpacity>
              <TouchableOpacity onPress={exportVideo} style={[styles.btn, styles.exportBtn]}>
                <Text style={styles.btnTxt}>Export {resolution} {fps}fps</Text>
              </TouchableOpacity>
            </View>
          </View>
        </View>
      </Modal>
      <CaptionEditor
        visible={showCaptionEditor}
        words={words}
        onClose={() => setShowCaptionEditor(false)}
        onSave={(groups, settings) => {
          setCaptionGroups(groups);
          setCaptionStyle(settings);
          setShowCaptionEditor(false);
        }}
      />
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#0B132B' },
  flexFull: { flex: 1 },
  content: { alignItems: 'center', justifyContent: 'flex-start', padding: 20, paddingTop: 40 },
  title: { fontSize: 28, fontWeight: 'bold', color: '#FFD700', marginBottom: 30 },
  btn: { backgroundColor: '#FFD700', paddingVertical: 14, paddingHorizontal: 28, borderRadius: 10, marginTop: 16 },
  styleBtn: { backgroundColor: '#3A4374' },
  editBtn: { backgroundColor: '#4CC3FF' },
  exportBtn: { backgroundColor: '#4CD964' },
  doneBtn: { backgroundColor: '#4CD964', alignSelf: 'flex-end' },
  btnTxt: { color: '#FFFFFF', fontSize: 15, fontWeight: '600', textAlign: 'center' },
  previewContainer: { width: '100%', alignItems: 'center' },
  videoWrapper: { width: '100%', height: 380, position: 'relative', backgroundColor: '#000', borderRadius: 12, overflow: 'hidden' },
  videoPreview: { width: '100%', height: '100%' },
  capOverlay: { position: 'absolute', bottom: 40, left: 0, right: 0, alignItems: 'center', paddingHorizontal: 12 },
  stylePicker: { width: '100%', backgroundColor: '#1C2541', borderRadius: 12, marginTop: 8, padding: 8 },
  styleOption: { paddingVertical: 12, paddingHorizontal: 16, borderRadius: 8, marginVertical: 2 },
  styleOptionActive: { backgroundColor: '#FFD700' },
  styleOptionTxt: { color: '#FFFFFF', fontSize: 15, fontWeight: '500' },
  styleOptionTxtActive: { color: '#0B132B', fontWeight: '700' },
  infoBox: { width: '100%', marginTop: 20, backgroundColor: '#1C2541', borderRadius: 10, padding: 16, flexDirection: 'row', alignItems: 'center' },
  infoTxt: { color: '#FFFFFF', fontSize: 14, marginLeft: 12, flex: 1 },
  errBox: { width: '100%', marginTop: 20, backgroundColor: '#3A1F1F', borderRadius: 10, padding: 14 },
  errTxt: { color: '#FFB4A2', fontSize: 13 },
  okBox: { width: '100%', marginTop: 16, backgroundColor: '#1A3A1A', borderRadius: 10, padding: 14 },
  okTxt: { color: '#88FF88', fontSize: 13 },
  editBox: { width: '100%', marginTop: 20 },
  label: { color: '#FFFFFF', fontSize: 13, marginBottom: 10, opacity: 0.8 },
  input: { width: '100%', minHeight: 140, backgroundColor: '#1C2541', color: '#FFFFFF', borderRadius: 10, padding: 14, fontSize: 16, borderWidth: 1, borderColor: '#3A4374' },
  modalOverlay: { flex: 1, backgroundColor: 'rgba(0,0,0,0.8)', justifyContent: 'flex-end' },
  modalBox: { backgroundColor: '#0B132B', borderTopLeftRadius: 24, borderTopRightRadius: 24, padding: 24 },
  modalTitle: { color: '#FFD700', fontSize: 22, fontWeight: '800', marginBottom: 20, textAlign: 'center' },
  modalLabel: { color: '#FFFFFF', fontSize: 15, fontWeight: '600', marginBottom: 10, marginTop: 16 },
  optRow: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  optBtn: { backgroundColor: '#1C2541', paddingVertical: 10, paddingHorizontal: 16, borderRadius: 8, borderWidth: 1, borderColor: '#3A4374' },
  optBtnActive: { backgroundColor: '#FFD700', borderColor: '#FFD700' },
  optTxt: { color: '#FFFFFF', fontSize: 14, fontWeight: '600' },
  optTxtActive: { color: '#0B132B' },
  modalBtns: { flexDirection: 'row', justifyContent: 'space-between', marginTop: 24 },
});

export default App;
