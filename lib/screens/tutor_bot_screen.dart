import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TutorBotScreen extends StatefulWidget {
  final String? word;
  const TutorBotScreen({super.key, this.word});

  @override
  State<TutorBotScreen> createState() => _TutorBotScreenState();
}

class _TutorBotScreenState extends State<TutorBotScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  void _initializeChat() {
    if (widget.word != null) {
      _messages.add({
        'isBot': true,
        'text': 'Merhaba! Kelime Dedektifi oyununda takıldığını gördüm. Başarıyla bulmaya çalıştığın kelime: **${widget.word}**.',
      });
      _messages.add({
        'isBot': true,
        'text': 'Bu kelime hakkında ne öğrenmek istersin? Anlamını, örnek cümlelerini veya telaffuz ipuçlarını verebilirim.',
      });
    } else {
      _messages.add({
        'isBot': true,
        'text': 'Merhaba! Ben senin sanal İngilizce öğretmeninim. İngilizce kelimeler, gramer veya cümle yapıları hakkında merak ettiğin her şeyi bana sorabilirsin!',
      });
    }
  }

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add({'isBot': false, 'text': text});
      _isTyping = true;
    });

    _messageController.clear();
    _scrollToBottom();

    // Mock bot response
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      
      String botResponse = 'Harika bir soru! İngilizce öğreniminde merak etmek en önemli adımdır. ';
      final query = text.toLowerCase();

      if (query.contains('anlam') || query.contains('nedir') || query.contains('ne demek')) {
        if (widget.word != null) {
          botResponse = '🔍 **"${widget.word}"** kelimesinin temel İngilizce anlamı ve Türkçe karşılıkları hakkında konuşalım.\n\nEğer daha fazla ipucuna ihtiyacın varsa harf sayılarını veya ilk harfini incelemeyi unutma!';
        } else {
          botResponse = 'Sormak istediğin spesifik bir kelime var mı? Kelimeyi bana yazarsan hemen anlamını açıklayabilirim!';
        }
      } else if (query.contains('örnek') || query.contains('cümle')) {
        if (widget.word != null) {
          final cleanWord = widget.word ?? '';
          botResponse = '📝 **"$cleanWord"** ile ilgili örnek cümleler:\n\n1. *I saw a beautiful ${cleanWord.toLowerCase()} yesterday.*\n2. *Can you explain how this ${cleanWord.toLowerCase()} works?*';
        } else {
          botResponse = 'İngilizce cümle yapıları çok esnektir. Örnek cümle görmek istediğin kelimeyi iletmen yeterli!';
        }
      } else if (query.contains('türkçe') || query.contains('çeviri')) {
        botResponse = 'Tabii ki! Kelimeleri Türkçe karşılıklarıyla öğrenmek ilk aşamada faydalıdır, ancak onları cümle içinde İngilizce düşünerek kullanmaya çalışmak akıcılığını artıracaktır.';
      } else {
        botResponse = 'Bunu sorduğun için teşekkürler! İngilizce pratik yapmak, kelimeleri hafızada tutmanın en iyi yoludur. Oyunları düzenli oynayarak kelime dağarcığını hızla geliştirebilirsin!';
      }

      setState(() {
        _isTyping = false;
        _messages.add({'isBot': true, 'text': botResponse});
      });
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFFEF4444);
    final cardBg = Theme.of(context).colorScheme.surface;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Scaffold(
        backgroundColor: isDark
            ? Colors.black.withValues(alpha: 0.6)
            : Colors.white.withValues(alpha: 0.8),
        appBar: AppBar(
          title: Row(
            children: [
              CircleAvatar(
                backgroundColor: primaryColor.withValues(alpha: 0.15),
                child: Icon(Icons.psychology, color: primaryColor, size: 24),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'EngTutor',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Çevrimiçi',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    final isBot = msg['isBot'];
                    return _buildChatBubble(msg['text'], isBot, isDark, primaryColor);
                  },
                ),
              ),
              if (_isTyping) _buildTypingIndicator(isDark),
              _buildQuickActionChips(),
              _buildInputArea(isDark, cardBg, primaryColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatBubble(String text, bool isBot, bool isDark, Color primaryColor) {
    final alignment = isBot ? Alignment.centerLeft : Alignment.centerRight;
    final bubbleColor = isBot
        ? (isDark ? const Color(0xFF1E1E2C) : Colors.grey.shade100)
        : primaryColor;
    final textColor = isBot
        ? (isDark ? Colors.white : Colors.black87)
        : Colors.white;

    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isBot ? 0 : 16),
            bottomRight: Radius.circular(isBot ? 16 : 0),
          ),
          border: isBot
              ? Border.all(
                  color: isDark ? Colors.white10 : Colors.grey.shade200,
                  width: 1,
                )
              : null,
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Text(
          text,
          style: GoogleFonts.outfit(
            fontSize: 15,
            color: textColor,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 24.0, bottom: 8.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Text(
              'Tutor yazıyor',
              style: GoogleFonts.outfit(
                color: Colors.grey,
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(width: 4),
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionChips() {
    if (widget.word == null) return const SizedBox.shrink();

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          _actionChip('Kelime Anlamı Nedir?', 'Kelimenin anlamını açıklar mısın?'),
          _actionChip('Örnek Cümle Ver', 'Bu kelimeyle örnek cümle kurabilir misin?'),
          _actionChip('İpucu Al', 'Bana biraz daha ipucu verir misin?'),
        ],
      ),
    );
  }


  Widget _actionChip(String label, String message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ActionChip(
        label: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        backgroundColor: isDark ? const Color(0xFF181824) : Colors.grey.shade100,
        side: BorderSide(
          color: isDark ? Colors.white10 : Colors.grey.shade300,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        onPressed: () => _sendMessage(message),
      ),
    );
  }

  Widget _buildInputArea(bool isDark, Color cardBg, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              onSubmitted: _sendMessage,
              style: GoogleFonts.outfit(fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Bir şeyler sor...',
                hintStyle: GoogleFonts.outfit(color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                fillColor: isDark ? const Color(0xFF12121A) : Colors.grey.shade200,
                filled: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: () => _sendMessage(_messageController.text),
            icon: const Icon(Icons.send_rounded),
            color: primaryColor,
            iconSize: 28,
          ),
        ],
      ),
    );
  }
}
