import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_chat_app/constants.dart';

class GroupSearchDelegate extends SearchDelegate<String> {
  final AsyncValue<List<dynamic>> groupsAsync;
  final ColorScheme colorScheme;

  GroupSearchDelegate({required this.groupsAsync, required this.colorScheme});

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      textTheme: GoogleFonts.poppinsTextTheme(theme.textTheme),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: GoogleFonts.poppins(),
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) => [
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
        ),
      ];

  @override
  Widget? buildLeading(BuildContext context) => BackButton(
        color: colorScheme.primary,
        onPressed: () => close(context, ''),
      );

  @override
  Widget buildResults(BuildContext context) => buildSuggestions(context);

  @override
  Widget buildSuggestions(BuildContext context) {
    if (groupsAsync is! AsyncData<List<dynamic>>) {
      return const Center(child: CircularProgressIndicator());
    }
    final groups = (groupsAsync as AsyncData<List<dynamic>>).value;
    final filtered = groups
        .where((g) => g.name.toLowerCase().contains(query.toLowerCase()))
        .toList();
    if (filtered.isEmpty) {
      return Center(
        child: Text(
          "No groups found",
          style: GoogleFonts.poppins(),
        ),
      );
    }
    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final group = filtered[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: group.photoUrl != null && group.photoUrl!.isNotEmpty
                ? NetworkImage(group.photoUrl!)
                : null,
            backgroundColor: colorScheme.primaryContainer,
            child: group.photoUrl == null || group.photoUrl!.isEmpty
                ? Icon(Icons.groups, color: colorScheme.primary)
                : null,
          ),
          title: Text(group.name, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          onTap: () {
            close(context, query);
            Navigator.pushNamed(
              context,
              AppRoutes.groupChatRoom,
              arguments: {'groupId': group.id},
            );
          },
        );
      },
    );
  }
}