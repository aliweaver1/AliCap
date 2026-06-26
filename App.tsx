/**
 * AliCaps
 * Video upload + auto speech-to-text captions + editing
 *
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

const BACKEND_URL = 'https://alicaps-backend.mrayyynjaffar.workers.dev/';

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
  const [videoPath, setVideoPath] = useState<string | null>(null);
  const [captionText, setCaptionText] = useState<string>('');
  const [wordTimings, setWordTimings] = useState<WordTiming[]>([]);
  const [showCaptionInput, setShowCaptionInput] = useState<boolean>(false);
  const [isTranscribing, setIsTranscribing] = useState<boolean>(false);
  const [transcribeError, setTranscribeError] = useState<string | null>(null);

  const transcribeVideo = async (path: string) => {
    setIsTranscribing(true);
    setTranscribeError(null);

    try {
      const fileUri = path.startsWith('file://') ? path : `file://${path}`;

      const formData = new FormData();
      formData.append('file', {
        uri: fileUri,
        type: 'video/mp4',
        name: 'video.mp4',
      } as any);

      const backendResponse = await fetch(BACKEND_URL, {
        method: 'POST',
        body: formData,
      });

      const result = await backendResponse.json();

      if (result.error) {
        console.log('Backend error:', result.error, result.details);
        setTranscribeError(
          'Could not generate captions automatically. You can type them in manually.'
        );
      } else {
        setCaptionText(result.transcript || '');
        setWordTimings(result.words || []);
      }
    } catch (error) {
      console.log('Transcription failed:', error);
      setTranscribeError(
        'Could not generate captions automatically. You can type them in manually.'
      );
    } finally {
      setIsTranscribing(false);
    }
  };

  const pickVideo = () => {
    ImagePicker.openPicker({
      mediaType: 'video',
    })
      .then(video => {
        setVideoPath(video.path);
        setShowCaptionInput(false);
        setCaptionText('');
        setWordTimings([]);
        transcribeVideo(video.path);
      })
      .catch(error => {
        console.log('Video pick cancelled or failed:', error);
      });
  };

  return (
    <KeyboardAvoidingView
      style={styles.flexFull}
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
    >
      <ScrollView contentContainerStyle={styles.content}>
        <Text style={styles.title}>AliCaps</Text>

        {videoPath ? (
          <View style={styles.previewContainer}>
            <Video
              source={{ uri: videoPath }}
              style={styles.videoPreview}
              controls={true}
              resizeMode="contain"
              repeat={true}
            />

            <TouchableOpacity style={styles.button} onPress={pickVideo}>
              <Text style={styles.buttonText}>Choose a different video</Text>
            </TouchableOpacity>

            {isTranscribing && (
              <View style={styles.transcribingBox}>
                <ActivityIndicator color="#FFD700" size="small" />
                <Text style={styles.transcribingText}>
                  Listening to your video and generating captions...
                </Text>
              </View>
            )}

            {!isTranscribing && transcribeError && (
              <View style={styles.errorBox}>
                <Text style={styles.errorText}>{transcribeError}</Text>
              </View>
            )}

            {!isTranscribing && !showCaptionInput && (
              <TouchableOpacity
                style={[styles.button, styles.captionButton]}
                onPress={() => setShowCaptionInput(true)}
              >
                <Text style={styles.buttonText}>
                  {captionText ? 'Edit Captions' : 'Add Captions Manually'}
                </Text>
              </TouchableOpacity>
            )}

            {showCaptionInput && (
              <View style={styles.captionInputContainer}>
                <Text style={styles.label}>
                  Edit your caption text below. Press Enter / Return to
                  control where each line breaks.
                </Text>
                <TextInput
                  style={styles.textInput}
                  multiline={true}
                  placeholder="Type your captions here..."
                  placeholderTextColor="#7A8499"
                  value={captionText}
                  onChangeText={setCaptionText}
                  textAlignVertical="top"
                />
                <TouchableOpacity
                  style={[styles.button, styles.doneButton]}
                  onPress={() => setShowCaptionInput(false)}
                >
                  <Text style={styles.buttonText}>Done</Text>
                </TouchableOpacity>
              </View>
            )}

            {!showCaptionInput && !isTranscribing && captionText.length > 0 && (
              <View style={styles.captionPreviewBox}>
                <Text style={styles.captionPreviewLabel}>
                  Caption preview ({wordTimings.length} words timed):
                </Text>
                <Text style={styles.captionPreviewText}>{captionText}</Text>
              </View>
            )}
          </View>
        ) : (
          <TouchableOpacity style={styles.button} onPress={pickVideo}>
            <Text style={styles.buttonText}>Select Video</Text>
          </TouchableOpacity>
        )}
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#0B132B',
  },
  flexFull: {
    flex: 1,
  },
  content: {
    alignItems: 'center',
    justifyContent: 'flex-start',
    padding: 20,
    paddingTop: 40,
  },
  title: {
    fontSize: 28,
    fontWeight: 'bold',
    color: '#FFD700',
    marginBottom: 30,
  },
  button: {
    backgroundColor: '#FFD700',
    paddingVertical: 14,
    paddingHorizontal: 28,
    borderRadius: 10,
    marginTop: 16,
  },
  captionButton: {
    backgroundColor: '#4CC3FF',
  },
  doneButton: {
    backgroundColor: '#4CD964',
    alignSelf: 'flex-end',
  },
  buttonText: {
    color: '#0B132B',
    fontSize: 16,
    fontWeight: '600',
  },
  previewContainer: {
    width: '100%',
    alignItems: 'center',
  },
  videoPreview: {
    width: '100%',
    height: 350,
    backgroundColor: '#000',
    borderRadius: 12,
  },
  transcribingBox: {
    width: '100%',
    marginTop: 20,
    backgroundColor: '#1C2541',
    borderRadius: 10,
    padding: 16,
    flexDirection: 'row',
    alignItems: 'center',
  },
  transcribingText: {
    color: '#FFFFFF',
    fontSize: 14,
    marginLeft: 12,
    flex: 1,
  },
  errorBox: {
    width: '100%',
    marginTop: 20,
    backgroundColor: '#3A1F1F',
    borderRadius: 10,
    padding: 14,
  },
  errorText: {
    color: '#FFB4A2',
    fontSize: 13,
  },
  captionInputContainer: {
    width: '100%',
    marginTop: 20,
  },
  label: {
    color: '#FFFFFF',
    fontSize: 13,
    marginBottom: 10,
    opacity: 0.8,
  },
  textInput: {
    width: '100%',
    minHeight: 140,
    backgroundColor: '#1C2541',
    color: '#FFFFFF',
    borderRadius: 10,
    padding: 14,
    fontSize: 16,
    borderWidth: 1,
    borderColor: '#3A4374',
  },
  captionPreviewBox: {
    width: '100%',
    marginTop: 20,
    backgroundColor: '#1C2541',
    borderRadius: 10,
    padding: 14,
  },
  captionPreviewLabel: {
    color: '#FFD700',
    fontSize: 13,
    fontWeight: '600',
    marginBottom: 8,
  },
  captionPreviewText: {
    color: '#FFFFFF',
    fontSize: 15,
    lineHeight: 22,
  },
});

export default App;
