// lib/tabs/groups_list_page.dart
// Clean, optimized Group List Page — FINAL VERSION

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
  }

 Future<void> _joinGroup(String code) async {
  try {
    final snap = await _fire
        .collection('groups')
        .where('code', isEqualTo: code)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) {
      return _showSnack('Group not found');
    }

    final groupDoc = snap.docs.first;
    final groupRef = groupDoc.reference;

    // Already a member?
    final memberDoc =
        await groupRef.collection('members').doc(widget.uid).get();
    if (memberDoc.exists) {
      // Fix missing memberIds array
      await groupRef.set({
        'memberIds': FieldValue.arrayUnion([widget.uid])
      }, SetOptions(merge: true));

      return _showSnack('Already a member');
    }

    // Add member doc
    await groupRef.collection('members').doc(widget.uid).set({
      'displayName': widget.displayName ?? 'User',
      'email': widget.email ?? '',
      'role': 'member',
      'joinedAt': FieldValue.serverTimestamp(),
    });

    // ALWAYS ensure memberIds exists
    await groupRef.set({
      'memberIds': FieldValue.arrayUnion([widget.uid])
    }, SetOptions(merge: true));

    // Add to user's group list
    await _fire.collection('users').doc(widget.uid).set({
      'groups': FieldValue.arrayUnion([groupRef.id])
    }, SetOptions(merge: true));

    _showSnack('Joined group successfully!');
  } catch (e) {
    _showSnack('Error: $e');
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
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
      await groupRef.collection('members').doc(widget.uid).delete();

      await groupRef.update({
        'memberIds': FieldValue.arrayRemove([widget.uid])
      });

      await _fire.collection('users').doc(widget.uid).update({
        'groups': FieldValue.arrayRemove([groupId])
      });

      _showSnack('Left group');
    } catch (e) {
      _showSnack('Error: $e');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            child: const Text('Create'),
            onPressed: () async {
              final name = nameCtl.text.trim();
              if (name.isEmpty) return _showSnack('Name required');
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
        content: TextField(
          controller: codeCtl,
          decoration: const InputDecoration(
            labelText: 'Group Code',
            prefixIcon: Icon(Icons.key),
          ),
          keyboardType: TextInputType.number,
          maxLength: 6,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            child: const Text('Join'),
            onPressed: () {
              Navigator.pop(context);
              _joinGroup(codeCtl.text.trim());
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
              ),
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
            ),
          ),

          // ⭐ Load groups instantly with memberIds
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _fire
                  .collection('groups')
                  .where('memberIds', arrayContains: widget.uid)
                  .snapshots(),
              builder: (_, snap) {
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var groups = snap.data!.docs;

                // Apply search
                if (_searchQuery.isNotEmpty) {
                  groups = groups.where((g) {
                    final n = (g['name'] ?? '').toString().toLowerCase();
                    final d = (g['description'] ?? '').toString().toLowerCase();
                    return n.contains(_searchQuery) || d.contains(_searchQuery);
                  }).toList();
                }

                if (groups.isEmpty) {
                  return const Center(child: Text('No groups found'));
                }

                return ListView.builder(
                  itemCount: groups.length,
                  itemBuilder: (_, i) {
                    final g = groups[i];
                    return _GroupCard(
                      groupDoc: g,
                      uid: widget.uid,
                      onTap: () => _openGroup(g.id, g['name']),
                      onLeave: () => _leaveGroup(g.id, g['name']),
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
            heroTag: "join",
            onPressed: _showJoinGroupDialog,
            icon: const Icon(Icons.login),
            label: const Text('Join'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: "create",
            onPressed: _showCreateGroupDialog,
            icon: const Icon(Icons.add),
            label: const Text('Create'),
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

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black12, blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
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
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue.shade700),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'copy') {
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code copied')));
                    } else if (v == 'leave') {
                      onLeave();
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'copy', child: Text('Copy Code')),
                    PopupMenuItem(value: 'leave', child: Text('Leave Group')),
                  ],
                ),
              ],
            ),
            if (desc.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
            if (createdAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  "Created ${DateFormat('MMM d, y').format(createdAt)}",
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
