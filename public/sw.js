/* eslint-disable no-restricted-globals, no-console */
/* globals clients */
self.addEventListener('push', event => {
  let notification = event.data && event.data.json();

  const tasks = [
    self.registration.showNotification(notification.title, {
      tag: notification.tag,
      data: {
        url: notification.url,
      },
    }),
  ];

  if (typeof notification.count === 'number' && self.navigator.setAppBadge) {
    tasks.push(self.navigator.setAppBadge(notification.count));
  }

  event.waitUntil(Promise.all(tasks));
});

self.addEventListener('notificationclick', event => {
  let notification = event.notification;

  if (self.navigator.clearAppBadge) {
    self.navigator.clearAppBadge();
  }

  event.waitUntil(
    clients.matchAll({ type: 'window' }).then(windowClients => {
      let matchingWindowClients = windowClients.filter(
        client => client.url === notification.data.url
      );

      if (matchingWindowClients.length) {
        let firstWindow = matchingWindowClients[0];
        if (firstWindow && 'focus' in firstWindow) {
          firstWindow.focus();
          return;
        }
      }
      if (clients.openWindow) {
        clients.openWindow(notification.data.url);
      }
    })
  );
});
