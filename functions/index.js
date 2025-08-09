/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at
 * https://firebase.google.com/docs/functions
 */

const {onSchedule} = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
admin.initializeApp();

exports.processScheduledMessages = onSchedule({schedule: "every 1 minutes", timeZone: "Etc/UTC"}, async () => {
  const now = admin.firestore.Timestamp.now();

  // Query all pending scheduled messages across chats & groups
  const qSnap = await admin.firestore()
    .collectionGroup("messages")
    .where("type", "==", "scheduled")
    .where("sent", "==", false)
    .where("scheduledTime", "<=", now)
    .get();

  if (qSnap.empty) return null;
  const batch = admin.firestore().batch();

  for (const doc of qSnap.docs) {
    const parent = doc.ref.parent; // messages collection
    const containerRef = parent.parent; // chats/{id} OR groups/{id}
    if (!containerRef) continue;

    const data = doc.data();
    const text = data.text || "";
    const senderId = data.senderId;
    const receiverId = data.receiverId || null;

    // Update the message
    batch.update(doc.ref, {
      sent: true,
      timestamp: now,
      status: "sent",
    });

    // Update last message fields
    batch.set(
      containerRef,
      {
        lastMessage: text,
        lastMessageTime: now,
      },
      {merge: true},
    );

    // Optional: unread counts logic
    // If 1:1 chat
    if (containerRef.path.startsWith("chats/") && receiverId) {
      batch.set(
        containerRef,
        {
          unreadCounts: {
            [receiverId]: admin.firestore.FieldValue.increment(1),
          },
        },
        {merge: true},
      );
    }

    // If group: increment unreadCounts for all members except sender
    if (containerRef.path.startsWith("groups/")) {
      const groupDoc = await containerRef.get();
      const members = groupDoc.exists ? groupDoc.data().members || [] : [];
      members
        .filter((m) => m !== senderId)
        .forEach((m) => {
          batch.set(
            containerRef,
            {
              unreadCounts: {
                [m]: admin.firestore.FieldValue.increment(1),
              },
            },
            {merge: true},
          );
        });
    }
  }

  await batch.commit();
  return null;
});
