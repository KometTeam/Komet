import 'package:flutter/material.dart';

class ChatInfoScreen extends StatefulWidget {
  final int chatId;
  final String name;
  final String imageUrl;
  final String chatType;

  const ChatInfoScreen({
    super.key,
    required this.chatId,
    required this.name,
    required this.imageUrl,
    required this.chatType,
  });
  @override
  State<ChatInfoScreen> createState() => _ChatInfoScreenState();
}
class _ChatInfoScreenState extends State<ChatInfoScreen>{

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(

      ),
      body: 
      SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (widget.imageUrl.isNotEmpty)
              CircleAvatar(
                radius: 36,
                backgroundImage: NetworkImage(widget.imageUrl),
              )
            else
              CircleAvatar(
                radius: 36,
                backgroundColor: cs.primaryContainer,
                child: Text(
                  widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?',
                  style: TextStyle(color: cs.onPrimaryContainer, fontSize: 12),
                ),
              ),
            Text(
              widget.name,
              style: TextStyle(color: Colors.white, fontSize: 24, height: 1.3),
            ),
            
          ],
        ),
      ),
    );
  }
}

