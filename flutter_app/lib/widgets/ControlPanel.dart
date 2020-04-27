import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:np_plus/GetItInstance.dart';
import 'package:np_plus/services/PartyService.dart';
import 'package:np_plus/vaults/DefaultsVault.dart';
import 'package:np_plus/domains/media-controls/VideoState.dart';
import 'package:np_plus/domains/server/ServerInfo.dart';
import 'package:np_plus/domains/user/LocalUser.dart';
import 'package:np_plus/pages/UserSettingsPage.dart';
import 'package:np_plus/services/SocketMessengerService.dart';
import 'package:np_plus/store/LocalUserStore.dart';
import 'package:np_plus/store/PartySessionStore.dart';
import 'package:np_plus/store/PlaybackInfoStore.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

class ControlPanel extends StatefulWidget {
  ControlPanel({Key key}) : super(key: key);

  @override
  _ControlPanelState createState() => _ControlPanelState(key: key);
}

class _ControlPanelState extends State<ControlPanel> {
  final _partySessionStore = getIt.get<PartySessionStore>();
  final _localUserStore = getIt.get<LocalUserStore>();
  final _playbackInfoStore = getIt.get<PlaybackInfoStore>();
  final _messengerService = getIt.get<SocketMessengerService>();
  final _partyService = getIt.get<PartyService>();
  final _panelController = PanelController();

  _ControlPanelState({Key key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
        stream: _partySessionStore.stream$,
        builder: (context, AsyncSnapshot<PartySession> partySessionSnapshot) {
          bool isSessionActive = partySessionSnapshot.data != null &&
              partySessionSnapshot.data.isSessionActive();
          return SlidingUpPanel(
            backdropEnabled: true,
            parallaxEnabled: true,
            controller: _panelController,
            maxHeight: isSessionActive ? 400 : 80,
            minHeight: isSessionActive ? 100 : 80,
            panelBuilder: (sc) => _panel(sc, isSessionActive),
            isDraggable: isSessionActive,
          );
        });
  }

  Widget _panel(ScrollController scrollController, bool isSessionActive) {
    return MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: Container(
          color: Theme.of(context).bottomAppBarColor,
          child: ListView(
            controller: scrollController,
            children: <Widget>[
              SizedBox(
                height: 12.0,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Visibility(
                    visible: isSessionActive,
                    child: Container(
                      width: 30,
                      height: 5,
                      decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius:
                              BorderRadius.all(Radius.circular(12.0))),
                    ),
                  )
                ],
              ),
              SizedBox(
                height: 8,
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Visibility(
                    visible: isSessionActive,
                    child: CupertinoButton(
                      child: Text(
                        "Disconnect",
                        style: TextStyle(color: Theme.of(context).primaryColor),
                      ),
                      onPressed: () {
                        _onDisconnectButtonPressed();
                      },
                    ),
                  ),
                  StreamBuilder(
                      stream: _localUserStore.stream$,
                      initialData: LocalUser(),
                      builder: (context, localUserSnapshot) {
                        LocalUser localUser = localUserSnapshot.data;
                        return IconButton(
                          icon: SvgPicture.asset(
                              localUserSnapshot.data.icon != null
                                  ? 'assets/avatars/${localUser?.icon ?? DefaultsVault.DEFAULT_AVATAR}'
                                  : 'assets/avatars/Batman.svg',
                              height: 85),
                          onPressed: () {
                            _navigateToAccountSettings(context);
                          },
                        );
                      }),
                ],
              ),
              SizedBox(
                height: 5.0,
              ),
              Visibility(
                  visible: isSessionActive,
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: <Widget>[
                        CupertinoButton(
                          child: Icon(
                            Icons.replay_10,
                            color: Theme.of(context).primaryColor,
                            size: 45,
                          ),
                          onPressed: _onReplay10Pressed,
                        ),
                        _getPlaybackControlButton(),
                        CupertinoButton(
                            child: Icon(
                              Icons.forward_10,
                              color: Theme.of(context).primaryColor,
                              size: 45,
                            ),
                            onPressed: _onForward10Pressed),
                      ]))
            ],
          ),
        ));
  }

  void _onReplay10Pressed() {
    HapticFeedback.lightImpact();
    _partyService.updateVideoState(_playbackInfoStore.getVideoState(),
        diff: -10000);
  }

  void _onForward10Pressed() {
    HapticFeedback.lightImpact();
    _partyService.updateVideoState(_playbackInfoStore.getVideoState(),
        diff: 10000);
  }

  Widget _getPlaybackControlButton() {
    return StreamBuilder(
        stream: _playbackInfoStore.stream$,
        builder: (context, playbackInfoSnapshot) {
          return CupertinoButton(
              child: Icon(
                  playbackInfoSnapshot.hasData
                      ? (playbackInfoSnapshot.data.isPlaying
                          ? CupertinoIcons.pause_solid
                          : CupertinoIcons.play_arrow_solid)
                      : CupertinoIcons.play_arrow_solid,
                  size: 40),
              color: Theme.of(context).primaryColor,
              padding: EdgeInsets.fromLTRB(35, 0, 30, 4),
              minSize: 55,
              borderRadius: BorderRadius.circular(500),
              onPressed: playbackInfoSnapshot.hasData
                  ? (_playbackInfoStore.playbackInfo.isPlaying
                      ? _onPausePressed
                      : _onPlayPressed)
                  : _onPlayPressed);
        });
  }

  void _onDisconnectButtonPressed() {
    try {
      _messengerService.closeConnection();
    } on Exception {
      debugPrint("Failed to disconnect");
    }
    _panelController.close();
    _messengerService.closeConnection();
    _partySessionStore.setAsSessionInactive();
  }

  void _onPlayPressed() {
    HapticFeedback.lightImpact();
    _partyService.updateVideoState(VideoState.PLAYING);
  }

  void _onPausePressed() {
    HapticFeedback.lightImpact();
    _partyService.updateVideoState(VideoState.PAUSED);
  }

  void _navigateToAccountSettings(buildContext) async {
    await _panelController.close();
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => UserSettingsPage()),
    );
  }
}
