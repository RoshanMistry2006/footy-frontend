import 'package:flutter/material.dart';
import 'debate_requests_page.dart';
import 'sent_debate_requests_page.dart';

class AllDebateRequestsPage extends StatefulWidget {
  const AllDebateRequestsPage({super.key});

  @override
  State<AllDebateRequestsPage> createState() => _AllDebateRequestsPageState();
}

class _AllDebateRequestsPageState extends State<AllDebateRequestsPage>
    with TickerProviderStateMixin {
  late final TabController _tabController;
  late final AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _animationController.animateTo(
          _tabController.index.toDouble(),
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0D0D),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(96), // Avoids overflow
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF00BFA5), Color(0xFF00796B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SafeArea(
                bottom: false,
                child: Padding(
                  padding:
                      const EdgeInsets.only(left: 8, right: 8, bottom: 2), // small tweak
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Center(
                          child: Text(
                            'Debate Requests',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 20,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
              ),

              // 💡 Animated glow bar under the tab titles
              SizedBox(
                height: 44,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final tabBarWidth = constraints.maxWidth;
                    final tabWidth = tabBarWidth / 2;

                    return Stack(
                      children: [
                        AnimatedBuilder(
                          animation: _animationController,
                          builder: (context, _) {
                            final position =
                                _animationController.value * tabWidth;
                            return Transform.translate(
                              offset: Offset(position, 0),
                              child: Container(
                                width: tabWidth,
                                height: 40,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF00E5C2),
                                      Color(0xFF00BFA5),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.tealAccent.withOpacity(0.5),
                                      blurRadius: 20,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),

                        // 🏷️ TabBar
                        TabBar(
                          controller: _tabController,
                          indicatorColor: Colors.transparent,
                          dividerColor: Colors.transparent,
                          labelColor: Colors.white,
                          unselectedLabelColor: Colors.white70,
                          labelStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          tabs: const [
                            Tab(text: "Incoming"),
                            Tab(text: "Sent"),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),

      // 🌊 Smooth sliding + fading tab transitions
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 450),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final offsetAnimation = Tween<Offset>(
            begin: const Offset(0.15, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutQuart,
          ));

          return SlideTransition(
            position: offsetAnimation,
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        child: TabBarView(
          controller: _tabController,
          physics: const BouncingScrollPhysics(),
          key: ValueKey(_tabController.index),
          children: const [
            DebateRequestsPage(),
            SentDebateRequestsPage(),
          ],
        ),
      ),
    );
  }
}
