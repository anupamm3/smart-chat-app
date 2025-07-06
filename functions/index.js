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

exports.processScheduledMessages =
  onSchedule("every 1 minutes", async (event) => {
    const now = admin.firestore.Timestamp.now();
    const chatsSnapshot = await admin.firestore().collection("chats").get();

    for (const chatDoc of chatsSnapshot.docs) {
      const chatId = chatDoc.id;
      const messagesRef = admin.firestore()
          .collection("chats")
          .doc(chatId)
          .collection("messages");

      const scheduledMessagesSnapshot = await messagesRef
          .where("type", "==", "scheduled")
          .where("sent", "==", false)
          .where("scheduledTime", "<=", now)
          .get();

      for (const msgDoc of scheduledMessagesSnapshot.docs) {
        await msgDoc.ref.update({
          sent: true,
          timestamp: now,
          status: "sent",
        });
      }
    }
    return null;
  });
