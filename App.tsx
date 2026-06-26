/**
 * CaptionApp
 * Video upload + preview screen
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
  TouchableOpacity,
  SafeAreaView,
} from 'react-native';
import ImagePicker from 'react-native-image-crop-picker';
import Video from 'react-native-video';

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

  const pickVideo = () => {
    ImagePicker.openPicker({
      mediaType: 'video',
    })
      .then(video => {
        setVideoPath(video.path);
      })
      .catch(error => {
        // User cancelled the picker, or an error occurred.
        console.log('Video pick cancelled or failed:', error);
      });
  };

  return (
    <View style={styles.content}>
      <Text style={styles.title}>CaptionApp</Text>

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
        </View>
      ) : (
        <TouchableOpacity style={styles.button} onPress={pickVideo}>
          <Text style={styles.buttonText}>Select Video</Text>
        </TouchableOpacity>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#0B132B',
  },
  content: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    padding: 20,
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
    marginTop: 20,
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
    height: 400,
    backgroundColor: '#000',
    borderRadius: 12,
  },
});

export default App;
