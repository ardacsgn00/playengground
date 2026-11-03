import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/analytics_service.dart';

class AdminStatsScreen extends StatefulWidget {
  const AdminStatsScreen({super.key});

  @override
  State<AdminStatsScreen> createState() => _AdminStatsScreenState();
}

class _AdminStatsScreenState extends State<AdminStatsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<VisitRecord> _allVisits = [];
  String _selectedFilter = 'Tümü';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await AnalyticsService.instance.fetchVisits();
      if (mounted) {
        setState(() {
          _allVisits = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Veriler yüklenirken bir sorun oluştu: $e';
          _isLoading = false;
        });
      }
    }
  }

  List<VisitRecord> get _filteredVisits {
    final now = DateTime.now();
    final todayStr =
        '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}';

    return _allVisits.where((item) {
      // Filtreleme
      if (_selectedFilter == 'Mobil' && item.deviceType != 'Mobil')
        return false;
      if (_selectedFilter == 'Masaüstü' && item.deviceType != 'Masaüstü')
        return false;
      if (_selectedFilter == 'Android' &&
          !item.os.toLowerCase().contains('android'))
        return false;
      if (_selectedFilter == 'iOS' && !item.os.toLowerCase().contains('ios'))
        return false;
      if (_selectedFilter == 'Windows' &&
          !item.os.toLowerCase().contains('windows'))
        return false;
      if (_selectedFilter == 'Bugün' &&
          !item.formattedDate.startsWith(todayStr))
        return false;

      // Arama
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final match =
            item.os.toLowerCase().contains(q) ||
            item.deviceType.toLowerCase().contains(q) ||
            item.formattedDate.toLowerCase().contains(q) ||
            item.deviceId.toLowerCase().contains(q) ||
            item.resolution.toLowerCase().contains(q);
        if (!match) return false;
      }

      return true;
    }).toList();
  }

  // --- İstatistik Hesaplamaları ---
  int get _totalVisits => _allVisits.length;

  int get _uniqueDevices {
    return _allVisits.map((e) => e.deviceId).toSet().length;
  }

  int get _todayVisits {
    final now = DateTime.now();
    final todayStr =
        '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}';
    return _allVisits.where((e) => e.formattedDate.startsWith(todayStr)).length;
  }

  double get _mobilePercentage {
    if (_allVisits.isEmpty) return 0;
    final mobileCount = _allVisits.where((e) => e.deviceType == 'Mobil').length;
    return (mobileCount / _allVisits.length) * 100;
  }

  Map<String, int> get _osCounts {
    final counts = <String, int>{};
    for (final v in _allVisits) {
      counts[v.os] = (counts[v.os] ?? 0) + 1;
    }
    return counts;
  }

  IconData _getOsIcon(String os) {
    final o = os.toLowerCase();
    if (o.contains('android')) return Icons.android_rounded;
    if (o.contains('ios') || o.contains('iphone') || o.contains('ipad')) {
      return Icons.phone_iphone_rounded;
    }
    if (o.contains('mac') || o.contains('apple')) {
      return Icons.laptop_mac_rounded;
    }
    if (o.contains('windows')) return Icons.window_rounded;
    if (o.contains('linux')) return Icons.terminal_rounded;
    return Icons.devices_rounded;
  }

  Color _getOsColor(String os) {
    final o = os.toLowerCase();
    if (o.contains('android')) return const Color(0xFF10B981); // Green
    if (o.contains('ios') || o.contains('apple') || o.contains('iphone'))
      return const Color(0xFF00E5FF); // Cyan
    if (o.contains('windows')) return const Color(0xFF3B82F6); // Blue
    if (o.contains('linux')) return const Color(0xFFF59E0B); // Amber
    if (o.contains('mac')) return const Color(0xFFA855F7); // Purple
    return const Color(0xFF8B5CF6);
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16162A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Geri Dön',
        ),
        titleSpacing: isMobile ? 0 : null,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.insights_rounded,
                color: Color(0xFFC4B5FD),
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'İstatistik & Ziyaretçi Paneli',
                style: GoogleFonts.outfit(
                  fontSize: isMobile ? 16 : 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF8B5CF6),
                    ),
                  )
                : const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: _isLoading ? null : _loadStats,
            tooltip: 'Yenile',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
            )
          : _errorMessage != null
          ? _buildErrorView()
          : RefreshIndicator(
              onRefresh: _loadStats,
              color: const Color(0xFF8B5CF6),
              backgroundColor: const Color(0xFF16162A),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 14 : 32,
                  vertical: isMobile ? 14 : 20,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Gizlilik Güvencesi Rozeti
                        _buildPrivacyBanner(isMobile),
                        const SizedBox(height: 16),

                        // 2. Özet KPI Kartları (4 adet)
                        _buildKpiGrid(isMobile),
                        const SizedBox(height: 20),

                        // 3. İşletim Sistemi Dağılım Kartı
                        if (_allVisits.isNotEmpty) ...[
                          _buildOsDistributionCard(isMobile),
                          const SizedBox(height: 20),
                        ],

                        // 4. Arama ve Filtre Çipleri
                        _buildFilterBar(isMobile),
                        const SizedBox(height: 16),

                        // 5. Ziyaretçi Günlüğü Listesi Başlığı
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Ziyaretçi Günlüğü (${_filteredVisits.length})',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            if (_filteredVisits.length != _allVisits.length)
                              Flexible(
                                child: Text(
                                  'Toplam ${_allVisits.length} kayıttan filtrelendi',
                                  style: GoogleFonts.outfit(
                                    fontSize: isMobile ? 11.5 : 12.5,
                                    color: Colors.white54,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.end,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // 6. Ziyaretçi Kartları
                        if (_filteredVisits.isEmpty)
                          _buildEmptyState()
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _filteredVisits.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final visit = _filteredVisits[index];
                              return _buildVisitCard(visit, isMobile);
                            },
                          ),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildPrivacyBanner(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 14 : 18,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(
            Icons.verified_user_rounded,
            color: Color(0xFF10B981),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '%100 Kişisel Veri Güvenliği: Sistemde IP adresi, isim, e-posta veya kişisel veri tutulmaz. Yalnızca anonim cihaz türü, işletim sistemi ve ziyaret saati listelenir.',
              style: GoogleFonts.outfit(
                fontSize: isMobile ? 12.5 : 13.5,
                color: const Color(0xFFD1FAE5),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiGrid(bool isMobile) {
    final kpis = [
      _KpiItem(
        title: 'Toplam Ziyaret',
        value: '$_totalVisits',
        subtitle: 'Kayıtlı toplam oturum',
        icon: Icons.bar_chart_rounded,
        color: const Color(0xFF8B5CF6),
      ),
      _KpiItem(
        title: 'Tekil Kullanıcı',
        value: '$_uniqueDevices',
        subtitle: 'Farklı cihaz kimliği',
        icon: Icons.people_alt_rounded,
        color: const Color(0xFF00E5FF),
      ),
      _KpiItem(
        title: 'Bugünkü Ziyaret',
        value: '$_todayVisits',
        subtitle: 'Bugün bağlananlar',
        icon: Icons.calendar_today_rounded,
        color: const Color(0xFF10B981),
      ),
      _KpiItem(
        title: 'Mobil Oranı',
        value: '%${_mobilePercentage.toStringAsFixed(0)}',
        subtitle: 'Akıllı telefon / tablet',
        icon: Icons.smartphone_rounded,
        color: const Color(0xFFF59E0B),
      ),
    ];

    if (isMobile) {
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.38,
        children: kpis.map((k) => _buildKpiCard(k, isMobile)).toList(),
      );
    }

    return Row(
      children: kpis.map((k) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: _buildKpiCard(k, isMobile),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildKpiCard(_KpiItem kpi, bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 18,
        vertical: isMobile ? 10 : 16,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF16162A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A4A), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  kpi.title,
                  style: GoogleFonts.outfit(
                    fontSize: isMobile ? 11.5 : 13.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF94A3B8),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Icon(kpi.icon, size: isMobile ? 16 : 22, color: kpi.color),
            ],
          ),
          Text(
            kpi.value,
            style: GoogleFonts.outfit(
              fontSize: isMobile ? 22 : 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            kpi.subtitle,
            style: GoogleFonts.outfit(
              fontSize: isMobile ? 10 : 12,
              color: const Color(0xFF64748B),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildOsDistributionCard(bool isMobile) {
    final osMap = _osCounts;
    final total = _totalVisits;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 14 : 20),
      decoration: BoxDecoration(
        color: const Color(0xFF16162A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A4A), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.devices_rounded,
                color: Color(0xFF8B5CF6),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'İşletim Sistemi Dağılımı',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Çubuk Dağılımı
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: osMap.entries.map((entry) {
                  final ratio = total > 0 ? entry.value / total : 0.0;
                  final color = _getOsColor(entry.key);
                  return Expanded(
                    flex: (ratio * 1000).toInt(),
                    child: Container(color: color),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Dağılım Etiketleri
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: osMap.entries.map((entry) {
              final color = _getOsColor(entry.key);
              final pct = total > 0
                  ? (entry.value / total * 100).toStringAsFixed(1)
                  : '0';
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${entry.key}: ${entry.value} (%$pct)',
                    style: GoogleFonts.outfit(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFCBD5E1),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(bool isMobile) {
    final filters = [
      'Tümü',
      'Bugün',
      'Mobil',
      'Masaüstü',
      'Windows',
      'Android',
      'iOS',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Arama Kutusu
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF16162A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF2A2A4A)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: TextField(
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              icon: const Icon(
                Icons.search_rounded,
                color: Colors.white54,
                size: 20,
              ),
              hintText: isMobile
                  ? 'Cihaz, sistem veya tarih ara...'
                  : 'Cihaz, işletim sistemi veya tarihe göre ara...',
              hintStyle: GoogleFonts.outfit(
                color: Colors.white38,
                fontSize: isMobile ? 12.5 : 13.5,
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onChanged: (val) {
              setState(() => _searchQuery = val.trim());
            },
          ),
        ),
        const SizedBox(height: 10),

        // Filtre Çipleri
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: filters.map((f) {
              final isSelected = _selectedFilter == f;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(f),
                  selected: isSelected,
                  onSelected: (val) {
                    if (val) setState(() => _selectedFilter = f);
                  },
                  labelStyle: GoogleFonts.outfit(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                  ),
                  backgroundColor: const Color(0xFF16162A),
                  selectedColor: const Color(0xFF8B5CF6),
                  side: BorderSide(
                    color: isSelected
                        ? const Color(0xFF8B5CF6)
                        : const Color(0xFF2A2A4A),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildVisitCard(VisitRecord visit, bool isMobile) {
    final osColor = _getOsColor(visit.os);
    final osIcon = _getOsIcon(visit.os);

    if (isMobile) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF16162A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF2A2A4A), width: 1.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Üst Satır: [İkon] + [OS & Device + Rozet] + [Tarih & Saat]
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Sol OS İkon Rozeti
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: osColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: osColor.withValues(alpha: 0.35)),
                  ),
                  child: Center(child: Icon(osIcon, color: osColor, size: 19)),
                ),
                const SizedBox(width: 10),

                // Orta: OS • Device ve Ziyaret Rozeti
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              '${visit.os} • ${visit.deviceType}',
                              style: GoogleFonts.outfit(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF8B5CF6,
                              ).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              visit.visitNumber > 1
                                  ? '${visit.visitNumber}. Ziyaret'
                                  : 'Yeni',
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFC4B5FD),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        visit.formattedDate,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFFCBD5E1),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Alt Kutu: Ekran çözünürlüğü, anonim cihaz ID, sürüm ve Anonim etiketi
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D14),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF2A2A4A), width: 0.8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Ekran: ${visit.resolution} • Tarayıcı: ${visit.browser} • #${visit.deviceId.replaceAll('dev_', '').take(5)} • ${visit.appVersion}',
                      style: GoogleFonts.outfit(
                        fontSize: 10.5,
                        color: const Color(0xFF94A3B8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Anonim',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Masaüstü için geniş yerleşim
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF16162A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A4A), width: 1.0),
      ),
      child: Row(
        children: [
          // Sol: OS İkon Rozeti
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: osColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: osColor.withValues(alpha: 0.35)),
            ),
            child: Center(child: Icon(osIcon, color: osColor, size: 22)),
          ),
          const SizedBox(width: 16),

          // Orta: Cihaz ve Çözünürlük Detayı
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${visit.os} • ${visit.deviceType}',
                      style: GoogleFonts.outfit(
                        fontSize: 15.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        visit.visitNumber > 1
                            ? '${visit.visitNumber}. Ziyaret'
                            : 'Yeni Ziyaretçi',
                        style: GoogleFonts.outfit(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFC4B5FD),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Ekran: ${visit.resolution} • Tarayıcı: ${visit.browser} • Cihaz: #${visit.deviceId.replaceAll('dev_', '').take(5)} • Sürüm: ${visit.appVersion}',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: const Color(0xFF94A3B8),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // Sağ: Tarih & Saat
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                visit.formattedDate,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFE2E8F0),
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Anonim Kayıt',
                    style: GoogleFonts.outfit(
                      fontSize: 10.5,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF16162A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A4A)),
      ),
      child: Column(
        children: [
          const Icon(Icons.search_off_rounded, size: 48, color: Colors.white24),
          const SizedBox(height: 12),
          Text(
            'Kriterlere uygun ziyaretçi kaydı bulunamadı.',
            style: GoogleFonts.outfit(
              fontSize: 14.5,
              color: Colors.white60,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFEF4444),
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Veriler Alınamadı',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? '',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 13.5, color: Colors.white60),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadStats,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Tekrar Dene'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension _StringTakeExt on String {
  String take(int n) {
    if (length <= n) return this;
    return substring(0, n);
  }
}

class _KpiItem {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _KpiItem({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}
