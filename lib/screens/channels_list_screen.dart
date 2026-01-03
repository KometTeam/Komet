import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gwid/api/api_service.dart';
import 'package:gwid/models/channel.dart';
import 'package:gwid/screens/search_channels_screen.dart';
import 'package:gwid/app_sizes.dart';

class ChannelsListScreen extends StatefulWidget {
  const ChannelsListScreen({super.key});

  @override
  State<ChannelsListScreen> createState() => _ChannelsListScreenState();
}

class _ChannelsListScreenState extends State<ChannelsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  StreamSubscription? _apiSubscription;
  bool _isLoading = false;
  List<Channel> _channels = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _listenToApiMessages();
    _loadPopularChannels();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _apiSubscription?.cancel();
    super.dispose();
  }

  void _listenToApiMessages() {
    _apiSubscription = ApiService.instance.messages.listen((message) {
      if (!mounted) return;

      if (message['type'] == 'channels_found') {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = null;
        });

        final payload = message['payload'];
        final channelsData = payload['contacts'] as List<dynamic>?;

        if (channelsData != null) {
          _channels = channelsData
              .map((channelJson) => Channel.fromJson(channelJson))
              .toList();
        }
      }

      if (message['type'] == 'channels_not_found') {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _channels.clear();
        });

        final payload = message['payload'];
        String errorMessage = 'Каналы не найдены';

        if (payload != null) {
          if (payload['localizedMessage'] != null) {
            errorMessage = payload['localizedMessage'];
          } else if (payload['message'] != null) {
            errorMessage = payload['message'];
          }
        }
        if (!mounted) return;
        setState(() {
          _errorMessage = errorMessage;
        });
      }
    });
  }

  void _loadPopularChannels() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ApiService.instance.searchChannels('каналы');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка загрузки каналов: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(10),
        ),
      );
    }
  }

  void _searchChannels() async {
    final searchQuery = _searchController.text.trim();

    if (searchQuery.isEmpty) {
      _loadPopularChannels();
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ApiService.instance.searchChannels(searchQuery);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка поиска каналов: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(10),
        ),
      );
    }
  }

  void _viewChannel(Channel channel) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChannelDetailsScreen(channel: channel),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Каналы'),
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const SearchChannelsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Поиск каналов...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _loadPopularChannels();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onSubmitted: (_) => _searchChannels(),
              onChanged: (value) {
                if (!mounted) return;
                setState(() {});
              },
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _channels.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.broadcast_on_personal,
                          size: 64,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage ?? 'Каналы не найдены',
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadPopularChannels,
                          child: const Text('Обновить'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _channels.length,
                    itemBuilder: (context, index) {
                      final channel = _channels[index];
                      return _buildChannelCard(channel);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelCard(Channel channel) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          radius: 24,
          backgroundImage: channel.photoBaseUrl != null
              ? NetworkImage(channel.photoBaseUrl!)
              : null,
          child: channel.photoBaseUrl == null
              ? Text(
                  channel.name.isNotEmpty ? channel.name[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                )
              : null,
        ),
        title: Text(
          channel.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (channel.description?.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Text(
                channel.description!,
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (channel.options.contains('BOT'))
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Бот',
                      style: TextStyle(
                        color: colors.onPrimaryContainer,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                if (channel.options.contains('HAS_WEBAPP'))
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colors.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Веб-приложение',
                      style: TextStyle(
                        color: colors.onSecondaryContainer,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: colors.onSurfaceVariant,
        ),
        onTap: () => _viewChannel(channel),
      ),
    );
  }
}
