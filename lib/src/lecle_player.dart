import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'package:lecle_player/src/lecle_player_controls.dart';
import 'package:lecle_player/src/lecle_player_options.dart';
import 'package:lecle_player/src/others/lecle_players_enums.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Lecle Player gives you a controller for flutter_vlc_player.
///
/// For displaying the video in Flutter, You can create video player widget by calling [createPlayer].
///
/// To customize video player controls or theme you can add [controlsOptions] and [themeOptions]
/// when calling [createPlayer]
class LeclePlayer extends StatefulWidget {
  const LeclePlayer._(
      {required this.video,
        required this.subtitles,
        required this.audioTracks,
        this.defaultSelectionOptions,
        this.options,
        this.controlsOptions,
        this.themeOptions,
        this.translationOptions,
        this.callbackOptions});

  /// Video quality options for multiple qualities. If you have only one quality video just add one in list.
  final LeclePlayerVideo video;

  /// Lecle player can detect subtitle from the video on supported formats like .mkv.
  ///
  /// But if you wish to add subtitle from [file] or [network], you can use this [subtitles].
  final List<LeclePlayerSubtitleOptions> subtitles;

  /// If you wish to add audio from [file] or [network], you can use this [audioTracks].
  final List<LeclePlayerAudioTrackOptions> audioTracks;

  /// Default selection options for subtitles and audio tracks.
  final LeclePlayerDefaultSelectionOptions? defaultSelectionOptions;

  // Lecle player options gives you some basic controls for video
  final LeclePlayerOptions? options;

  /// Lecle player controls option.
  final LeclePlayerControlsOptions? controlsOptions;

  /// Control theme of controls.
  final LeclePlayerThemeOptions? themeOptions;

  /// With [translationOptions] option you can give translated text or custom to menu item.
  final LeclePlayerTranslationOptions? translationOptions;

  /// With [callbackOptions] option you can perform custom actions on callback.
  final LeclePlayerCallbackOptions? callbackOptions;

  static Widget createPlayer(
      {required LeclePlayerVideo video,
        List<LeclePlayerSubtitleOptions>? subtitles,
        List<LeclePlayerAudioTrackOptions>? audioTracks,
        LeclePlayerDefaultSelectionOptions? defaultSelectionOptions,
        LeclePlayerOptions? options,
        LeclePlayerControlsOptions? controlsOptions,
        LeclePlayerThemeOptions? themeOptions,
        LeclePlayerTranslationOptions? translationOptions,
        LeclePlayerCallbackOptions? callbackOptions}) {
    return LeclePlayer._(
      video: video,
      subtitles: subtitles ?? [],
      audioTracks: audioTracks ?? [],
      options: options,
      controlsOptions: controlsOptions,
      defaultSelectionOptions: defaultSelectionOptions,
      themeOptions: themeOptions,
      translationOptions: translationOptions,
      callbackOptions: callbackOptions,
    );
  }

  @override
  State<LeclePlayer> createState() => _LeclePlayerState();
}

class _LeclePlayerState extends State<LeclePlayer> {
  late VlcPlayerController _playerController;

  bool isDisposed = false;
  bool canDisplayVideo = false;

  double visibilityFraction = 1;
  String? youtubeId;

  late LeclePlayerVideoData selectedQuality;

  List<LeclePlayerVideoData> videosData = List.empty(growable: true);

  @override
  void initState() {
    super.initState();

    if (widget.options?.allowScreenSleep ?? false == false) {
      WakelockPlus.enable();
    }

    videosData = widget.video.videosData;
    _setPlayer();
  }

  void _setPlayer() async {
    LeclePlayerVideoData defaultSource = videosData.length > 1
        ? _getDefaultTrackSource(
        selectors:
        widget.defaultSelectionOptions?.defaultQualitySelectors,
        trackEntries: videosData) ??
        videosData.first
        : videosData.first;

    selectedQuality = defaultSource;

    // Network
    if (defaultSource.sourceType == LeclePlayerSourceType.network) {
      _playerController = VlcPlayerController.network(defaultSource.source,
          autoPlay: true,
          autoInitialize: true,
          hwAcc: HwAcc.auto,
          options: VlcPlayerOptions(
            subtitle: VlcSubtitleOptions(
                [VlcSubtitleOptions.color(VlcSubtitleColor.white)]),
          ));
    }
    // File
    else if (defaultSource.sourceType == LeclePlayerSourceType.file) {
      _playerController = VlcPlayerController.file(File(defaultSource.source),
          autoPlay: true, autoInitialize: true, hwAcc: HwAcc.auto);
    }
    // Youtube
    else if (defaultSource.sourceType == LeclePlayerSourceType.youtube) {
      var yt = YoutubeExplode();
      youtubeId = defaultSource.source;
      StreamManifest manifest =
      await yt.videos.streamsClient.getManifest(youtubeId);

      if (widget.video.fetchQualities ?? false) {
        List<LeclePlayerVideoData> ytVideos = List.empty(growable: true);

        for (var element in manifest.videoOnly) {
          LeclePlayerVideoData videoData =
          LeclePlayerVideoDataYoutube.network(
              label: element.qualityLabel,
              url: element.url.toString(),
              audioOverride:
              manifest.audioOnly.withHighestBitrate().url.toString());

          if (ytVideos
              .where((element) => element.label == videoData.label)
              .isEmpty) {
            ytVideos.insert(0, videoData);
          }
        }

        videosData = ytVideos;

        widget.audioTracks.add(LeclePlayerAudioTrackOptions(
            source: manifest.audioOnly.withHighestBitrate().url.toString(),
            sourceType: LeclePlayerAudioSourceType.network));

        LeclePlayerVideoData? defaultSourceYt = _getDefaultTrackSource(
            selectors: widget.defaultSelectionOptions?.defaultQualitySelectors,
            trackEntries: ytVideos);

        selectedQuality = defaultSourceYt ?? defaultSource;

        _playerController = VlcPlayerController.network(
            defaultSourceYt?.source ?? ytVideos.first.source,
            autoPlay: true,
            autoInitialize: true,
            hwAcc: HwAcc.auto);
      } else {
        _playerController = VlcPlayerController.network(
            manifest.muxed.withHighestBitrate().url.toString(),
            autoPlay: true,
            autoInitialize: true,
            hwAcc: HwAcc.auto);
      }

      yt.close();
    }
    // Asset
    else {
      _playerController = VlcPlayerController.asset(defaultSource.source,
          autoPlay: true, autoInitialize: true, hwAcc: HwAcc.full);
    }

    _playerController.addOnInitListener(_onInitialize);
    _playerController.addListener(_checkVideoLoaded);

    setState(() {
      canDisplayVideo = true;
    });
  }

  /// Helper function to set default track for subtitle, audio, etc
  LeclePlayerVideoData? _getDefaultTrackSource(
      {required List<DefaultSelector>? selectors,
        required List<LeclePlayerVideoData>? trackEntries}) {
    if (selectors == null || trackEntries == null || trackEntries.isEmpty) {
      return null;
    }

    for (final selector in selectors) {
      switch (selector) {
        case DefaultSelectorCustom():
          LeclePlayerVideoData? selected;
          for (int i = 0; i < trackEntries.length; i++) {
            if (selector.shouldUseTrack(i, trackEntries[i].label)) {
              selected = trackEntries[i];
              break;
            }
          }

          if (selected != null) {
            return selected;
            // Else, if no track is found, loop to the next selector
          }
        case DefaultSelectorOff():
          return null;
      }
    }
    return null;
  }

  void _onInitialize() async {
    _videoStartAt();
    _addSubtitles();
    _addAudioTracks();
  }

  void _videoStartAt() async {
    if (widget.options?.videoStartAt != null) {
      do {
        await Future.delayed(const Duration(milliseconds: 100));
      } while (_playerController.value.playingState != PlayingState.playing);

      await _playerController
          .seekTo(Duration(milliseconds: widget.options!.videoStartAt!));
    }
  }

  void _addSubtitles() async {
    for (var subtitle in widget.subtitles) {
      if (subtitle.sourceType == LeclePlayerSubtitleSourceType.file) {
        if (await File(subtitle.source).exists()) {
          _playerController.addSubtitleFromFile(File(subtitle.source),
              isSelected: subtitle.isSelected);
        } else {
          throw Exception("${subtitle.source} is not exist in local file.");
        }
      } else {
        _playerController.addSubtitleFromNetwork(subtitle.source,
            isSelected: subtitle.isSelected);
      }
    }
  }

  void _addAudioTracks() async {
    for (var audio in widget.audioTracks) {
      if (audio.sourceType == LeclePlayerAudioSourceType.file) {
        if (await File(audio.source).exists()) {
          _playerController.addAudioFromFile(File(audio.source),
              isSelected: audio.isSelected);
        } else {
          throw Exception("${audio.source} is not exist in local file.");
        }
      } else {
        _playerController.addAudioFromNetwork(audio.source,
            isSelected: audio.isSelected);
      }
    }
  }

  void _checkVideoLoaded() {
    if (_playerController.value.isPlaying) {
      setState(() {});
    }
  }

  void _onChangeVisibility(double visibility) {
    visibilityFraction = visibility;
    _checkPlayPause();
  }

  void _checkPlayPause() {
    if (visibilityFraction == 0) {
      if (_playerController.value.isInitialized && !isDisposed) {
        _playerController.pause();
      }
    } else {
      if (_playerController.value.isInitialized && !isDisposed) {
        _playerController.play();
      }
    }
  }

  @override
  void dispose() async {
    super.dispose();
    if (_playerController.value.isInitialized) {
      _playerController.dispose();
    }

    _playerController.removeListener(_checkVideoLoaded);
    _playerController.removeOnInitListener(_onInitialize);

    if (widget.options?.allowScreenSleep ?? false == false) {
      WakelockPlus.disable();
    }

    isDisposed = true;
  }

  @override
  Widget build(BuildContext context) {
    return canDisplayVideo
        ? Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: VisibilityDetector(
            key: const ValueKey<int>(0),
            onVisibilityChanged: (info) {
              if (widget.options?.autoVisibilityPause ?? true) {
                _onChangeVisibility(info.visibleFraction);
              }
            },
            child: VlcPlayer(
              controller: _playerController,
              aspectRatio: _playerController.value.aspectRatio,
            ),
          ),
        ),
        if (widget.controlsOptions?.showControls ?? true)
          LeclePlayerControls(
            player: _playerController,
            videos: videosData,
            controlsOptions:
            widget.controlsOptions ?? LeclePlayerControlsOptions(),
            defaultSelectionOptions: widget.defaultSelectionOptions ??
                LeclePlayerDefaultSelectionOptions(),
            themeOptions:
            widget.themeOptions ?? LeclePlayerThemeOptions(),
            translationOptions: widget.translationOptions ??
                LeclePlayerTranslationOptions.menu(),
            viewSize: Size(MediaQuery.of(context).size.width,
                MediaQuery.of(context).size.height),
            callbackOptions:
            widget.callbackOptions ?? LeclePlayerCallbackOptions(),
            selectedQuality: selectedQuality,
          )
      ],
    )
        : Center(
      child: SizedBox(
        height: 50,
        width: 50,
        child: widget.themeOptions?.customLoadingWidget ??
            CircularProgressIndicator(
              color:
              widget.themeOptions?.loadingColor ?? Colors.greenAccent,
              strokeCap: StrokeCap.round,
            ),
      ),
    );
  }
}
