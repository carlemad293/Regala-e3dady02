const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

// Cloud Function to send notifications from the notification queue
exports.sendNotifications = functions.firestore
    .document("notification_queue/{docId}")
    .onCreate(async (snap, context) => {
      const notification = snap.data();

      if (!notification.tokens || notification.tokens.length === 0) {
        console.log("No tokens provided for notification");
        await snap.ref.delete();
        return;
      }

      const message = {
        notification: {
          title: notification.title || "Regala e3dady",
          body: notification.body || "You have a new notification",
        },
        data: notification.data || {},
        tokens: notification.tokens,
        android: {
          priority: "high",
          notification: {
            channelId: "high_importance_channel",
            priority: "high",
            defaultSound: true,
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
            },
          },
        },
      };

      try {
        const response = await admin.messaging().sendMulticast(message);
        console.log(
          "Successfully sent messages:",
          response.successCount
        );
        console.log(
          "Failed messages:",
          response.failureCount
        );

        // Clean up the queue document
        await snap.ref.delete();

        // Update notification history
        await admin.firestore().collection("notification_history").add({
          title: notification.title,
          body: notification.body,
          data: notification.data,
          tokensCount: notification.tokens.length,
          successCount: response.successCount,
          failureCount: response.failureCount,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });
      } catch (error) {
        console.error("Error sending messages:", error);
      }
    });

// Cloud Function to send notification to specific users
exports.sendNotificationToUsers = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
        "unauthenticated", "User must be authenticated");
  }

  const {userEmails, title, body, data: notificationData} = data;

  if (!userEmails || !Array.isArray(userEmails) || userEmails.length === 0) {
    throw new functions.https.HttpsError(
        "invalid-argument", "userEmails must be a non-empty array");
  }

  if (!title || !body) {
    throw new functions.https.HttpsError(
        "invalid-argument", "title and body are required");
  }

  try {
    // Get tokens for the specified users
    const tokensSnapshot = await admin.firestore()
        .collection("user_tokens")
        .where("email", "in", userEmails)
        .get();

    const tokens = tokensSnapshot.docs
        .map((doc) => doc.data().token)
        .filter((token) => token && token.length > 0);

    if (tokens.length === 0) {
      return {
        success: false,
        message: "No valid tokens found for the specified users",
      };
    }

    // Send the notification
    const message = {
      notification: {
        title: title,
        body: body,
      },
      data: notificationData || {},
      tokens: tokens,
      android: {
        priority: "high",
        notification: {
          channelId: "high_importance_channel",
          priority: "high",
          defaultSound: true,
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    };

    const response = await admin.messaging().sendMulticast(message);

    // Log the notification
    await admin.firestore().collection("notification_history").add({
      title: title,
      body: body,
      data: notificationData,
      userEmails: userEmails,
      tokensCount: tokens.length,
      successCount: response.successCount,
      failureCount: response.failureCount,
      sentBy: context.auth.uid,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      message:
        `Notification sent to ${response.successCount} users`,
      successCount: response.successCount,
      failureCount: response.failureCount,
    };
  } catch (error) {
    console.error("Error sending notification:", error);
    throw new functions.https.HttpsError("internal", "Failed to send notification");
  }
});

// Cloud Function to send notification to all users
exports.sendNotificationToAllUsers = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
        "unauthenticated", "User must be authenticated");
  }

  const {title, body, data: notificationData} = data;

  if (!title || !body) {
    throw new functions.https.HttpsError(
        "invalid-argument", "title and body are required");
  }

  try {
    // Get all user tokens
    const tokensSnapshot = await admin.firestore()
        .collection("user_tokens")
        .get();

    const tokens = tokensSnapshot.docs
        .map((doc) => doc.data().token)
        .filter((token) => token && token.length > 0);

    if (tokens.length === 0) {
      return {
        success: false,
        message: "No users found with valid tokens",
      };
    }

    // Send the notification
    const message = {
      notification: {
        title: title,
        body: body,
      },
      data: notificationData || {},
      tokens: tokens,
      android: {
        priority: "high",
        notification: {
          channelId: "high_importance_channel",
          priority: "high",
          defaultSound: true,
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    };

    const response = await admin.messaging().sendMulticast(message);

    // Log the notification
    await admin.firestore().collection("notification_history").add({
      title: title,
      body: body,
      data: notificationData,
      userEmails: ["all_users"],
      tokensCount: tokens.length,
      successCount: response.successCount,
      failureCount: response.failureCount,
      sentBy: context.auth.uid,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      message:
        `Notification sent to ${response.successCount} users`,
      successCount: response.successCount,
      failureCount: response.failureCount,
    };
  } catch (error) {
    console.error("Error sending notification to all users:", error);
    throw new functions.https.HttpsError("internal", "Failed to send notification");
  }
}); 