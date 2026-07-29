class SurahAudioInfoModel {
  final int recitersAvailable;
  final String exampleAudio;

  const SurahAudioInfoModel({
    required this.recitersAvailable,
    required this.exampleAudio,
  });

  factory SurahAudioInfoModel.fromJson(Map<String, dynamic> json) {
    return SurahAudioInfoModel(
      recitersAvailable: json['reciters_available'] as int,
      exampleAudio: json['example_audio'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'reciters_available': recitersAvailable,
    'example_audio': exampleAudio,
  };
}
