/**
 * AliCaps - Live Caption Preview
 * @format
 */

import React, { useState } from 'react';
import {
  StatusBar,
  StyleSheet,
  useColorScheme,
  View,
  Text,
  TextInput,
  TouchableOpacity,
  SafeAreaView,
  ScrollView,
  KeyboardAvoidingView,
  Platform,
  ActivityIndicator,
} from 'react-native';
import ImagePicker from 'react-native-image-crop-picker';
import Video from 'react-native-video';

const DG_URL = 'https://api.deepgram.com/v1/listen?model=nova-3&smart_format=true&punctuate=true';
const DG_KEY = '65774809e8fdb3317afb3ec6dec8913202e05bd7';

type W = { word: string; start: number; end: number; punctuated_word?: string };

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
      setWords(j
?.results?.channels?.[0]?.alternatives?.[0]?.words || []);
    } catch (e: any) {
      setErr('Could not generate captions. You can type them manually.');
    } finally { setLoading(false); }
  };

  const pickVideo = () => {
    ImagePicker.openPicker({ mediaType: 'video' })
      .then((v: any) => { setVideoPath(v.path); setShowEdit(false); setCaptionText(''); setWords([]); setCap(''); transcribe(v.path); })
      .catch((e: any) => { console.log(e); });
  };

  return (
    <KeyboardAvoidingView style={styles.flexFull} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
      <ScrollView contentContainerStyle={styles.content}>
        <Text style={styles.title}>AliCaps</Text>
        {videoPath ? (
          <View style={styles.previewContainer}>
            <View style={styles.videoWrapper}>
              <Video source={{ uri: videoPath }} style={styles.videoPreview} controls={true} resizeMode="contain" repeat={true} onProgress={onProgress} />
              {cap.length > 0 && (
                <View style={styles.capOverlay} pointerEvents="none">
                  <View style={styles.capBubble}>
                    <Text style={styles.capText}>{cap}</Text>
                  </View>
                </View>
              )}
            </View>
            <TouchableOpacity style={styles.btn} onPress={pickVideo}><Text style={styles.btnTxt}>Choose a different video</Text></TouchableOpacity>
            {loading && <View style={styles.infoBox}><ActivityIndicator color="#FFD700" size="small" /><Text style={styles.infoTxt}>Listening to your video...</Text></View>}
            {err && <View style={styles.errBox}><Text style={styles.errTxt}>{err}</Text></View>}
            {!loading && words.length > 0 && <View style={styles.okBox}><Text style={styles.okTxt}>{words.length} words timed — play video to see live captions!</Text></View>}
            {!loading && !showEdit && <TouchableOpacity style={[styles.btn, styles.editBtn]} onPress={() => setShowEdit(true)}><Text style={styles.btnTxt}>{captionText ? 'Edit Captions' : 'Add Captions Manually'}</Text></TouchableOpacity>}
            {showEdit && <View style={styles.editBox}>
              <Text style={styles.label}>Edit your caption text below:</Text>
              <TextInput style={styles.input} multiline placeholder="Type captions..." placeholderTextColor="#7A8499" value={captionText} onChangeText={setCaptionText} textAlignVertical="top" />
              <TouchableOpacity style={[styles.btn, styles.doneBtn]} onPress={() => setShowEdit(false)}><Text style={styles.btnTxt}>Done</Text></TouchableOpacity>
            </View>}
          </View>
        ) : (
          <TouchableOpacity style={styles.btn} onPress={pickVideo}><Text style={styles.btnTxt}>Select Video</Text></TouchableOpacity>
        )}
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#0B132B' },
  flexFull: { flex: 1 },
  content: { alignItems: 'center', justifyContent: 'flex-start', padding: 20, paddingTop: 40 },
  title: { fontSize: 28, fontWeight: 'bold', color: '#FFD700', marginBottom: 30 },
  btn: { backgroundColor: '#FFD700', paddingVertical: 14, paddingHorizontal: 28, borderRadius: 10, marginTop: 16 },
  editBtn: { backgroundColor: '#4CC3FF' },
  doneBtn: { backgroundColor: '#4CD964', alignSelf: 'flex-end' },
  btnTxt: { color: '#0B132B', fontSize: 16, fontWeight: '600' },
  previewContainer: { width: '100%', alignItems: 'center' },
  videoWrapper: { width: '100%', height: 380, position: 'relative', backgroundColor: '#000', borderRadius: 12, overflow: 'hidden' },
  videoPreview: { width: '100%', height: '100%' },
  capOverlay: { position: 'absolute', bottom: 40, left: 0, right: 0, alignItems: 'center', paddingHorizontal: 12 },
  capBubble: { backgroundColor: 'rgba(0,0,0,0.75)', borderRadius: 8, paddingHorizontal: 14, paddingVertical: 8, maxWidth: '90%' },
  capText: { color: '#FFFFFF', fontSize: 18, fontWeight: '700', textAlign: 'center', lineHeight: 26 },
  infoBox: { width: '100%', marginTop: 20, backgroundColor: '#1C2541', borderRadius: 10, padding: 16, flexDirection: 'row', alignItems: 'center' },
  infoTxt: { color: '#FFFFFF', fontSize: 14, marginLeft: 12, flex: 1 },
  errBox: { width: '100%', marginTop: 20, backgroundColor: '#3A1F1F', borderRadius: 10, padding: 14 },
  errTxt: { color: '#FFB4A2', fontSize: 13 },
  okBox: { width: '100%', marginTop: 16, backgroundColor: '#1A3A1A', borderRadius: 10, padding: 14 },
  okTxt: { color: '#88FF88', fontSize: 13 },
  editBox: { width: '100%', marginTop: 20 },
  label: { color: '#FFFFFF', fontSize: 13, marginBottom: 10, opacity: 0.8 },
  input: { width: '100%', minHeight: 140, backgroundColor: '#1C2541', color: '#FFFFFF', borderRadius: 10, padding: 14, fontSize: 16, borderWidth: 1, borderColor: '#3A4374' },
});

export default App;
