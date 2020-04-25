import 'dart:async';

import 'package:dash_chat/dash_chat.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:np_plus/domains/messages/outgoing-messages/chat-message/SendMessageBody.dart';
import 'package:np_plus/domains/messages/outgoing-messages/chat-message/SendMessageContent.dart';
import 'package:np_plus/domains/messages/outgoing-messages/chat-message/SendMessageMessage.dart';
import 'package:np_plus/domains/messages/outgoing-messages/typing/TypingContent.dart';
import 'package:np_plus/domains/messages/outgoing-messages/typing/TypingMessage.dart';
import 'package:np_plus/domains/messenger/SocketMessenger.dart';
import 'package:np_plus/domains/user/LocalUser.dart';
import 'package:np_plus/main.dart';
import 'package:np_plus/store/LocalUserStore.dart';
import 'package:np_plus/store/NPServerInfoStore.dart';
import 'package:np_plus/store/ChatMessagesStore.dart';
import 'package:np_plus/store/PlaybackInfoStore.dart';
import 'package:np_plus/services/SomeoneIsTypingService.dart';
import 'package:np_plus/theming/AvatarColors.dart';
import 'package:np_plus/utilities/TimeUtility.dart';
import 'package:rxdart/rxdart.dart';

class Chat extends StatefulWidget {
  Chat({Key key}) : super(key: key);

  @override
  _ChatState createState() => _ChatState(key: key);
}

class _ChatState extends State<Chat> {
  final _messenger = getIt.get<SocketMessenger>();

  final npServerInfoStore = getIt.get<NPServerInfoStore>();
  final _playbackInfoStore = getIt.get<PlaybackInfoStore>();
  final _chatMessagesStore =
      getIt.get<ChatMessagesStore>();
  final _localUserStore = getIt.get<LocalUserStore>();

  final ScrollController _chatScrollController = ScrollController();

  final ServerTimeUtility _serverTimeUtility = ServerTimeUtility();

  final BehaviorSubject<bool> _showUserBubbleAsAvatar =
      BehaviorSubject.seeded(true);

  int _lastMessagesCount = 0;

  _ChatState({Key key}) {
    _setupNewChatMessagesListener();
  }

  void _setupNewChatMessagesListener() {
    _chatMessagesStore.stream$.listen(_onChatMessagesChanged);
  }

  void _onChatMessagesChanged(List<ChatMessage> chatMessages) {
    if (chatMessages.length > _lastMessagesCount) {
      if (_chatScrollController != null) {
        _scrollToBottomOfChatStream();
      }
      HapticFeedback.mediumImpact();
    }
    _lastMessagesCount = chatMessages.length;
  }

  void _scrollToBottomOfChatStream() {
    _chatScrollController.animateTo(
        _chatScrollController.position.maxScrollExtent + 80,
        duration: Duration(milliseconds: 300),
        curve: Curves.linear);
  }

  String _messageInputText = '';
  TextEditingController _messageInputTextEditingController =
      TextEditingController();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _chatMessagesStore.stream$.withLatestFrom(_localUserStore.stream$, (chatMessages, localUser) => {
        'chatMessages': chatMessages,
        'localUser': localUser
      }),
      builder: (context, streamSnapshot) {
        LocalUser localUser = streamSnapshot.data['localUser'];
        return DashChat(
          messages: streamSnapshot.data['chatMessages'],
          scrollController: _chatScrollController,
          scrollToBottom: false,
          user: ChatUser(
              name: localUser?.username,
              uid: localUser?.id,
              avatar: localUser?.icon ?? 'Batman.svg',
              containerColor: AvatarColors.getColor(localUser?.icon ?? '')),
          text: _messageInputText,
          textController: _messageInputTextEditingController,
          onTextChange: (newText) {
            _messenger.sendMessage(TypingMessage(TypingContent(true)));
            Future.delayed(Duration(milliseconds: 1500), () async {
              _messenger.sendMessage(TypingMessage(TypingContent(false)));
            });
            _setChatInputTextState(newText);
          },
          inputToolbarPadding: EdgeInsets.fromLTRB(0, 0, 10, 0),
          inputContainerStyle: BoxDecoration(
              color: Theme.of(context).dialogBackgroundColor,
              borderRadius: BorderRadius.circular(30)),
          sendButtonBuilder: (onPressed) {
            return CupertinoButton(
                child: Icon(CupertinoIcons.up_arrow),
                color: Theme.of(context).primaryColor,
                padding: EdgeInsets.all(3),
                minSize: 30,
                borderRadius: BorderRadius.circular(500),
                onPressed: onPressed);
          },
          onSend: (chatMessage) {
            HapticFeedback.lightImpact();
            _sendChatMessage(chatMessage);
          },
          showUserAvatar: true,
          avatarBuilder: (chatUser) => StreamBuilder(
            stream: _showUserBubbleAsAvatar.stream,
            builder: (context, showUserBubbleAsAvatarSnapshot) {
              if (showUserBubbleAsAvatarSnapshot.data == false) {
                debugPrint('username ${chatUser.name}');
                String firstTwoLettersOfUsername = chatUser.name != null &&
                        chatUser.name.isNotEmpty
                    ? '${chatUser.name[0].toUpperCase()}${chatUser.name.length > 1 ? '${chatUser.name[1]}' : ''}'
                    : '?';
                return Container(
                  width: 35,
                  height: 35,
                  child: Align(
                    alignment: Alignment.center,
                    child: Text(
                      firstTwoLettersOfUsername,
                      style: TextStyle(fontSize: 15),
                    ),
                  ),
                  decoration: BoxDecoration(
                      color: AvatarColors.getColor(chatUser.avatar),
                      shape: BoxShape.circle),
                );
              }
              return SvgPicture.asset('assets/avatars/${chatUser?.avatar}',
                  height: 35);
            },
          ),
          onLongPressAvatar: (user) {
            HapticFeedback.lightImpact();
            _showUserBubbleAsAvatar.add(!_showUserBubbleAsAvatar.value);
          },
          messageTextBuilder: (text) {
            return Text(
              text,
              style: TextStyle(color: Colors.white),
            );
          },
          messageTimeBuilder: (time) {
            return Text(
              time,
              style: TextStyle(color: Colors.white, fontSize: 10),
            );
          },
          messageContainerDecoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(15)),
        );
      },
    );
  }

  void _sendChatMessage(ChatMessage chatMessage) {
    _messenger.sendMessage(SendMessageMessage(SendMessageContent(
        SendMessageBody(
            chatMessage.text,
            false,
            _serverTimeUtility.getCurrentServerTimeAdjustedForCurrentTime(
                npServerInfoStore.npServerInfo.getServerTime(),
                _playbackInfoStore
                    .playbackInfo.serverTimeAtLastVideoStateUpdate),
            _localUserStore.localUser.id,
            _localUserStore.localUser.id,
            _localUserStore.localUser.icon,
            _localUserStore.localUser.username))));
  }

  void _setChatInputTextState(String text) {
    setState(() {
      _messageInputText = text;
    });
  }
}