import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'dart:ui' as ui;

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  String _selectedCategory = 'Все чаты';
  int _currentNavIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D12),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Подключение...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Outfit',
                          ),
                        ),
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(
                            Symbols.more_vert,
                            color: Colors.white54,
                            weight: 400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 96,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        _buildStoryItem('Даша', 'https://i.pravatar.cc/150?u=dasha', true),
                        _buildStoryItem('Мастика', 'https://i.pravatar.cc/150?u=mastika', false),
                      ],
                    ),
                  ),
                ),

                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  sliver: SliverToBoxAdapter(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E2A),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: const Row(
                        children: [
                          Icon(Symbols.search, color: Colors.white38, size: 20, weight: 400),
                          SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              style: TextStyle(color: Colors.white, fontSize: 15),
                              decoration: InputDecoration(
                                hintText: 'Поиск',
                                hintStyle: TextStyle(color: Colors.white38, fontSize: 15),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 48,
                    child: ScrollConfiguration(
                      behavior: ScrollConfiguration.of(context).copyWith(
                        dragDevices: {
                          ui.PointerDeviceKind.touch,
                          ui.PointerDeviceKind.mouse,
                          ui.PointerDeviceKind.trackpad,
                        },
                      ),
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        physics: const BouncingScrollPhysics(),
                        children: [
                          _buildFolderChip('Все чаты'),
                          const SizedBox(width: 8),
                          _buildFolderChip('Контакты'),
                          const SizedBox(width: 8),
                          _buildFolderChip('Пидоры'),
                          const SizedBox(width: 8),
                          _buildFolderChip('Каналы'),
                          const SizedBox(width: 8),
                          _buildFolderChip('Группы'),
                          const SizedBox(width: 8),
                          _buildFolderChip('Боты'),
                          const SizedBox(width: 8),
                          _buildFolderChip('Избранное'),
                          const SizedBox(width: 8),
                          _buildFolderChip('Архив'),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildListDelegate([
                    _buildChatItem(
                      'Станислав',
                      'Хорошо',
                      '10:07',
                      'https://i.pravatar.cc/150?u=stas',
                      isOnline: true,
                      isRead: true,
                    ),
                    _buildChatItem(
                      'Илья',
                      'печатает...',
                      '10:07',
                      'https://i.pravatar.cc/150?u=ilya',
                      isOnline: true,
                      isTyping: true,
                      unreadCount: 1,
                    ),
                    _buildChatItem(
                      'Вероника',
                      'Спасибо',
                      '09:56',
                      'https://i.pravatar.cc/150?u=veronika',
                      isRead: true,
                    ),
                    _buildChatItem(
                      'Komet Client',
                      'Кстати. Смотрите, какую шту...',
                      '09:56',
                      'https://i.pravatar.cc/150?u=komet',
                      unreadCount: 5,
                      isMuted: true,
                    ),
                    _buildChatItem(
                      '4-й подъезд',
                      'Людмила: Сколько?',
                      '09:34',
                      'https://i.pravatar.cc/150?u=podezd',
                      unreadCount: 78,
                      isMuted: true,
                    ),
                    const SizedBox(height: 100),
                  ]),
                ),
              ],
            ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 24,
              child: Container(
                height: 68,
                padding: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E28),
                  borderRadius: BorderRadius.circular(34),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    double totalWidth = constraints.maxWidth;
                    
                    double totalWeight = 5.2;
                    double unitWidth = totalWidth / totalWeight;
                    double activeWidth = unitWidth * 2.2;
                    double inactiveWidth = unitWidth * 1.0;
                    
                    double leftOffset = 0;
                    for (int i = 0; i < _currentNavIndex; i++) {
                      leftOffset += inactiveWidth;
                    }
                    
                    return Stack(
                      children: [
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeOutCubic,
                          left: leftOffset + 4,
                          top: 8,
                          bottom: 8,
                          width: activeWidth - 8,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFBEC2FF),
                              borderRadius: BorderRadius.circular(26),
                            ),
                          ),
                        ),
                        Row(
                          children: List.generate(4, (index) {
                            IconData icon;
                            String label;
                            switch (index) {
                              case 0: icon = Symbols.chat_bubble; label = 'Чаты'; break;
                              case 1: icon = Symbols.call; label = 'Звонки'; break;
                              case 2: icon = Symbols.person_pin; label = 'Контакты'; break;
                              default: icon = Symbols.settings; label = 'Настройки';
                            }
                            
                            bool isSelected = _currentNavIndex == index;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 350),
                              curve: Curves.easeOutCubic,
                              width: isSelected ? (activeWidth - 0.5) : (inactiveWidth - 0.5),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(26),
                                child: _buildNavItem(index, icon, label),
                              ),
                            );
                          }),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            Positioned(
              right: 20,
              bottom: 110,
              child: FloatingActionButton(
                onPressed: () {},
                backgroundColor: const Color(0xFFC1C4FF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Symbols.add, color: Colors.black, size: 28, weight: 400),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryItem(String name, String imageUrl, bool hasUpdate) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: hasUpdate
                  ? Border.all(color: const Color(0xFFC1C4FF), width: 2)
                  : Border.all(color: Colors.white10),
            ),
            child: CircleAvatar(
              radius: 26,
              backgroundImage: NetworkImage(imageUrl),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFolderChip(String title) {
    bool isSelected = _selectedCategory == title;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = title),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFC1C4FF) : const Color(0xFF1E1E2A),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white54,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildChatItem(
    String name,
    String message,
    String time,
    String imageUrl, {
    bool isOnline = false,
    bool isTyping = false,
    bool isRead = false,
    int unreadCount = 0,
    bool isMuted = false,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundImage: NetworkImage(imageUrl),
          ),
          if (isOnline)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: const Color(0xFFC1C4FF),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF0D0D12), width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (isMuted)
            const Icon(Symbols.notifications_off, color: Colors.white24, size: 14, weight: 400),
          const SizedBox(width: 8),
          Text(
            time,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 12,
            ),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: isTyping ? const Color(0xFFC1C4FF) : Colors.white54,
                  fontSize: 14,
                  fontWeight: isTyping ? FontWeight.w500 : FontWeight.w400,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (unreadCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isMuted ? Colors.white10 : const Color(0xFF1E1E2A),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  unreadCount.toString(),
                  style: TextStyle(
                    color: isMuted ? Colors.white38 : Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else if (isRead)
              const Icon(Symbols.done_all, color: Color(0xFFC1C4FF), size: 16, weight: 400),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    bool isSelected = _currentNavIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentNavIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.black : Colors.white,
                size: 20,
                weight: 400,
                fill: isSelected ? 1.0 : 0.0,
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
                width: isSelected ? null : 0,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: isSelected ? 1.0 : 0.0,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: 4),
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
