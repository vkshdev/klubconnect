import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/club_model.dart';
import '../../models/event_model.dart';
import '../../models/user_model.dart';
import '../../widgets/glass_card.dart';
import '../clubs/club_details_screen.dart';
import '../events/event_details_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  String _selectedFilter = "Clubs"; // 'Clubs', 'Events', 'Users'

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).primaryColor.withOpacity(0.1),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: GlassCard(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          controller: _searchController,
                          autofocus: true,
                          decoration: const InputDecoration(
                            hintText: "Search here...",
                            border: InputBorder.none,
                            icon: Icon(Icons.search),
                          ),
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value.toLowerCase();
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: ["Clubs", "Events", "Users"].map((filter) {
                    final isSelected = _selectedFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(filter),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) setState(() => _selectedFilter = filter);
                        },
                        selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
                        labelStyle: TextStyle(
                          color: isSelected ? Theme.of(context).primaryColor : Colors.black,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              Expanded(
                child: _searchQuery.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_rounded, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            const Text("Explore clubs and events"),
                          ],
                        ),
                      )
                    : _buildSearchResults(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    String collection;
    switch (_selectedFilter) {
      case "Clubs": collection = "clubs"; break;
      case "Events": collection = "events"; break;
      case "Users": collection = "users"; break;
      default: return Container();
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection(collection).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No results found."));
        }

        final filteredDocs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['name'] ?? data['title'] ?? data['full_name'] ?? "").toString().toLowerCase();
          return name.contains(_searchQuery);
        }).toList();

        if (filteredDocs.isEmpty) {
          return const Center(child: Text("No matches found."));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            final doc = filteredDocs[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildResultItem(doc),
            );
          },
        );
      },
    );
  }

  Widget _buildResultItem(DocumentSnapshot doc) {
    if (_selectedFilter == "Clubs") {
      final club = ClubModel.fromFirestore(doc);
      return GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ClubDetailsScreen(clubId: club.clubId))),
        child: GlassCard(
          padding: const EdgeInsets.all(12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundImage: club.logoUrl.isNotEmpty ? NetworkImage(club.logoUrl) : null,
              child: club.logoUrl.isEmpty ? Text(club.name[0]) : null,
            ),
            title: Text(club.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(club.category),
            trailing: const Icon(Icons.chevron_right),
          ),
        ),
      );
    } else if (_selectedFilter == "Events") {
      final event = EventModel.fromFirestore(doc);
      return GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => EventDetailsScreen(eventId: event.eventId))),
        child: GlassCard(
          padding: const EdgeInsets.all(12),
          child: ListTile(
            leading: const Icon(Icons.event, color: Colors.blue),
            title: Text(event.title, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(event.clubName),
            trailing: const Icon(Icons.chevron_right),
          ),
        ),
      );
    } else {
      final user = UserModel.fromFirestore(doc);
      return GlassCard(
        padding: const EdgeInsets.all(12),
        child: ListTile(
          leading: CircleAvatar(
            backgroundImage: user.profileImageUrl != null ? NetworkImage(user.profileImageUrl!) : null,
            child: user.profileImageUrl == null ? Text(user.firstName[0]) : null,
          ),
          title: Text(user.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(user.userType),
        ),
      );
    }
  }
}
