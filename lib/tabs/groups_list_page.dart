// lib/tabs/groups_list_page.dart
// FIXED VERSION - Resolves join visibility issues

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'group_study.dart';

class GroupsListPage extends StatefulWidget {
  final String uid;
  final String? displayName;
  final String? email;

  const GroupsListPage({
    super.key,
    required this.uid,
    this.displayName,
    this.email,
  });

  @override
  State<GroupsListPage> createState() => _GroupsListPageState();
}

class _GroupsListPageState extends State<GroupsListPage> {
  final FirebaseFirestore _fire = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Generate 6-digit group code
  String _generateGroupCode() {
    final r = Random();
    return (100000 + r.nextInt(900000)).toString();
  }

  // ✨ Create Group
  Future<void> _createGroup(String name, String description) async {
    try {
      final code = _generateGroupCode();

      final groupRef = await _fire.collection('groups').add({
        'name': name,
        'description': description,
        'code': code,
        'createdBy': widget.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'memberIds': [widget.uid], // ⭐ REQUIRED
      });

      // Add creator to members collection
      await groupRef.collection('members').doc(widget.uid).set({
        'displayName': widget.displayName ?? 'User',
        'email': widget.email ?? '',
        'role': 'admin',
        'joinedAt': FieldValue.serverTimestamp(),
      });

      // Add to user's group list
      await _fire.collection('users').doc(widget.uid).set({
        'groups': FieldValue.arrayUnion([groupRef.id])
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Group created! Code: $code')),
        );
      }
    } catch (e) {
      _showSnack('Error creating group: $e');
    }
  }

  // ✨ Join Group - FIXED VERSION
  Future<void> _joinGroup(String code) async {
    if (code.isEmpty) {
      return _showSnack('Please enter a group code');
    }

    try {
      // Show loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Joining group...'), duration: Duration(seconds: 1)),
        );
      }

      // Find group by code
      final snap = await _fire
          .collection('groups')
          .where('code', isEqualTo: code)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        return _showSnack('Group not found. Check the code and try again.');
      }

      final groupDoc = snap.docs.first;
      final groupRef = groupDoc.reference;
      final groupId = groupDoc.id;
      final groupName = groupDoc.data()['name'] ?? 'Group';

      // Check if already a member
      final memberDoc = await groupRef.collection('members').doc(widget.uid).get();
      
      if (memberDoc.exists) {
        // User is already a member, but ensure memberIds array is correct
        await groupRef.update({
          'memberIds': FieldValue.arrayUnion([widget.uid])
        });

        // Ensure user document has this group
        await _fire.collection('users').doc(widget.uid).set({
          'groups': FieldValue.arrayUnion([groupId])
        }, SetOptions(merge: true));

        return _showSnack('You are already a member of "$groupName"');
      }

      // Perform all writes in sequence to ensure consistency
      
      // 1. Add member document
      await groupRef.collection('members').doc(widget.uid).set({
        'displayName': widget.displayName ?? 'User',
        'email': widget.email ?? '',
        'role': 'member',
        'joinedAt': FieldValue.serverTimestamp(),
      });

      // 2. Update group's memberIds array
      await groupRef.update({
        'memberIds': FieldValue.arrayUnion([widget.uid]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 3. Update user's groups array
      await _fire.collection('users').doc(widget.uid).set({
        'groups': FieldValue.arrayUnion([groupId])
      }, SetOptions(merge: true));

      _showSnack('Successfully joined "$groupName"!');
    } catch (e) {
      _showSnack('Error joining group: $e');
      debugPrint('Join group error: $e');
    }
  }

  // ✨ Leave Group
  Future<void> _leaveGroup(String groupId, String groupName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Leave "$groupName"?'),
        content: const Text('Are you sure you want to leave this group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final groupRef = _fire.collection('groups').doc(groupId);

    try {
      // Remove member document
      await groupRef.collection('members').doc(widget.uid).delete();

      // Remove from memberIds array
      await groupRef.update({
        'memberIds': FieldValue.arrayRemove([widget.uid]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Remove from user's groups list
      await _fire.collection('users').doc(widget.uid).update({
        'groups': FieldValue.arrayRemove([groupId])
      });

      _showSnack('Left "$groupName"');
    } catch (e) {
      _showSnack('Error leaving group: $e');
    }
  }

  void _showSnack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  // ✨ Open Group Page
  void _openGroup(String id, String name) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupStudyPage(
          groupId: id,
          uid: widget.uid,
          displayName: widget.displayName,
          email: widget.email,
        ),
      ),
    );
  }

  // ✨ Create Dialog
  Future<void> _showCreateGroupDialog() async {
    final nameCtl = TextEditingController();
    final descCtl = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Create New Group'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtl,
              decoration: const InputDecoration(labelText: 'Group Name *'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtl,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            child: const Text('Create'),
            onPressed: () async {
              final name = nameCtl.text.trim();
              if (name.isEmpty) {
                _showSnack('Group name is required');
                return;
              }
              Navigator.pop(context);
              await _createGroup(name, descCtl.text.trim());
            },
          )
        ],
      ),
    );
  }

  // ✨ Join Dialog
  Future<void> _showJoinGroupDialog() async {
    final codeCtl = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Join Group'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeCtl,
              decoration: const InputDecoration(
                labelText: 'Group Code',
                prefixIcon: Icon(Icons.key),
                hintText: '6-digit code',
              ),
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 8),
            Text(
              'Enter the 6-digit code shared by the group admin',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            child: const Text('Join'),
            onPressed: () {
              final code = codeCtl.text.trim();
              Navigator.pop(context);
              _joinGroup(code);
            },
          )
        ],
      ),
    );
  }

  // ============================================================
  //                     MAIN UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Groups'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              setState(() {}); // Trigger rebuild
              _showSnack('Refreshed');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search groups...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
            ),
          ),

          // ⭐ Load groups with memberIds - NO INDEX REQUIRED
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _fire
                  .collection('groups')
                  .where('memberIds', arrayContains: widget.uid)
                  .snapshots(),
              builder: (_, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                        const SizedBox(height: 16),
                        Text('Error: ${snap.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => setState(() {}),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var groups = snap.data!.docs;

                // Sort by updatedAt manually (no index needed)
                groups.sort((a, b) {
                  final aTime = (a.data()['updatedAt'] as Timestamp?)?.toDate();
                  final bTime = (b.data()['updatedAt'] as Timestamp?)?.toDate();
                  if (aTime == null && bTime == null) return 0;
                  if (aTime == null) return 1;
                  if (bTime == null) return -1;
                  return bTime.compareTo(aTime); // Most recent first
                });

                // Apply search filter
                if (_searchQuery.isNotEmpty) {
                  groups = groups.where((g) {
                    final data = g.data();
                    final name = (data['name'] ?? '').toString().toLowerCase();
                    final desc = (data['description'] ?? '').toString().toLowerCase();
                    final code = (data['code'] ?? '').toString().toLowerCase();
                    return name.contains(_searchQuery) || 
                           desc.contains(_searchQuery) || 
                           code.contains(_searchQuery);
                  }).toList();
                }

                if (groups.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.group_outlined, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty 
                              ? 'No groups yet' 
                              : 'No groups match your search',
                          style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 8),
                        if (_searchQuery.isEmpty)
                          Text(
                            'Create a new group or join one!',
                            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                          ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: groups.length,
                  itemBuilder: (_, i) {
                    final g = groups[i];
                    final data = g.data();
                    return _GroupCard(
                      groupDoc: g,
                      uid: widget.uid,
                      onTap: () => _openGroup(g.id, data['name'] ?? 'Group'),
                      onLeave: () => _leaveGroup(g.id, data['name'] ?? 'Group'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),

      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: "join_group_fab",
            onPressed: _showJoinGroupDialog,
            icon: const Icon(Icons.login),
            label: const Text('Join Group'),
            backgroundColor: Colors.green,
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: "create_group_fab",
            onPressed: _showCreateGroupDialog,
            icon: const Icon(Icons.add),
            label: const Text('Create Group'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
//                     GROUP CARD WIDGET
// ============================================================

class _GroupCard extends StatelessWidget {
  final DocumentSnapshot<Map<String, dynamic>> groupDoc;
  final String uid;
  final VoidCallback onTap;
  final VoidCallback onLeave;

  const _GroupCard({
    required this.groupDoc,
    required this.uid,
    required this.onTap,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    final data = groupDoc.data()!;
    final name = data['name'] ?? 'Group';
    final desc = data['description'] ?? '';
    final code = data['code'] ?? '';
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final isAdmin = data['createdBy'] == uid;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.blue.shade100,
                    child: Text(
                      name[0].toUpperCase(),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (isAdmin)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Admin',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.amber.shade900,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.key, size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(
                              'Code: $code',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'copy') {
                        Clipboard.setData(ClipboardData(text: code));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Code copied to clipboard')),
                        );
                      } else if (v == 'leave') {
                        onLeave();
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'copy',
                        child: Row(
                          children: [
                            Icon(Icons.copy, size: 20),
                            SizedBox(width: 12),
                            Text('Copy Code'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'leave',
                        child: Row(
                          children: [
                            Icon(Icons.exit_to_app, size: 20, color: Colors.red),
                            SizedBox(width: 12),
                            Text('Leave Group', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (desc.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    desc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ),
              if (createdAt != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade500),
                      const SizedBox(width: 6),
                      Text(
                        "Created ${DateFormat('MMM d, y').format(createdAt)}",
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}