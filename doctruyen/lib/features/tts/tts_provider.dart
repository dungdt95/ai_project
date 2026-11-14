import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/data_providers.dart';
import '../../services/tts_audio_handler.dart';

/// Trạng thái TTS theo thời gian thực.
final ttsStateProvider = StreamProvider<TtsUiState>((ref) async* {
  final handler = ref.watch(ttsHandlerProvider);
  yield handler.state;
  yield* handler.uiStream;
});
