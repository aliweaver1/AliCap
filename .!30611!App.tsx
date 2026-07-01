/**
 * AliCaps - Direct Deepgram Integration
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
import { readFile } from '@dr.pogodin/react-native-fs';

const DEEPGRAM_URL = 'https://api.deepgram.com/v1/listen?model=nova-3&smart_format=true&punctuate=true';
const DEEPGRAM_KEY = '65774809e8fdb3317afb3ec6dec8913202e05bd7';
const CHUNK_SIZE = 250000;

type WordTiming = {
  word: string;
  start: number;
  end: number;
  punctuated_word?: string;
};

function App() {
  const isDarkMode = useColorScheme() === 'dark';
  return (
    <SafeAreaView style={styles.container}>
      <StatusBar barStyle={isDarkMode ? 'light-content' : 'dark-content'} />
      <AppContent />
    </SafeAreaView>
  );
}

function AppContent() {
  const [startupTest, setStartupTest] = useState<string>('Testing connectivity...');
  const [videoPath, setVideoPath] = useState<string | null>(null);
  const [captionText, setCaptionText] = useState<string>('');
  const [wordTimings, setWordTimings] = useState<WordTiming[]>([]);
  const [showCaptionInput, setShowCaptionInput] = useState<boolean>(false);
  const [isTranscribing, setIsTranscribing] = useState<boolean>(false);
  const [transcribeError, setTranscribeError] = useState<string | null>(null);
  const [debugInfo, setDebugInfo] = useState<string>('');

  React.useEffect(() => {
    fetch('https://api.deepgram.com/v1/projects', {
      method: 'GET',
      headers: {
