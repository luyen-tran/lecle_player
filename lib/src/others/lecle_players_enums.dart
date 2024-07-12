/// Source Type for Lecle Player
///
/// This can define type of data source of Lecle Player.
enum LeclePlayerSourceType {
  /// The video is downloaded from the internet.
  network,

  /// The video is load from the local filesystem.
  file,

  /// The video is load from the youtube.
  youtube,

  /// The video is load from asset
  asset
}

/// Source Type for Lecle Player Subtitle
///
/// This can define type of data source of Lecle Player Subtitle.
enum LeclePlayerSubtitleSourceType {
  /// The subtitle file is downloaded from the internet.
  network,

  /// The subtitle file is load from the local filesystem.
  file
}

/// Source Type for Lecle Player Audio
///
/// This can define type of data source of Lecle Player Audio.
enum LeclePlayerAudioSourceType {
  /// The audio file is downloaded from the internet.
  network,

  /// The audio file is load from the local filesystem.
  file
}
