const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const logger = require('firebase-functions/logger');

initializeApp();

const db = getFirestore();

exports.sendNotificationPush = onDocumentCreated(
  'notifications/{notificationId}',
  async (event) => {
    const notification = event.data?.data();
    if (!notification || typeof notification.userId !== 'string') {
      logger.warn('Notification has no valid userId', {
        notificationId: event.params.notificationId,
      });
      return;
    }

    const userSnapshot = await db.collection('users').doc(notification.userId).get();
    const tokens = userSnapshot.get('fcmTokens');
    if (!Array.isArray(tokens) || tokens.length === 0) {
      logger.info('No registered devices for notification recipient', {
        userId: notification.userId,
      });
      return;
    }

    const uniqueTokens = [...new Set(tokens.filter((token) => typeof token === 'string'))];
    if (uniqueTokens.length === 0) return;

    const response = await getMessaging().sendEachForMulticast({
      tokens: uniqueTokens,
      notification: {
        title: String(notification.title ?? 'JC Sports Hub'),
        body: String(notification.message ?? ''),
      },
      data: {
        notificationId: event.params.notificationId,
        type: String(notification.type ?? 'general'),
        referenceId: String(notification.referenceId ?? ''),
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'jc_sports_hub_updates',
        },
      },
    });

    const invalidTokens = [];
    response.responses.forEach((result, index) => {
      if (!result.success &&
          ['messaging/registration-token-not-registered',
           'messaging/invalid-registration-token'].includes(result.error?.code)) {
        invalidTokens.push(uniqueTokens[index]);
      }
    });

    if (invalidTokens.length > 0) {
      await db.collection('users').doc(notification.userId).update({
        fcmTokens: FieldValue.arrayRemove(...invalidTokens),
      });
    }

    logger.info('Notification push completed', {
      notificationId: event.params.notificationId,
      successCount: response.successCount,
      failureCount: response.failureCount,
    });
  },
);
