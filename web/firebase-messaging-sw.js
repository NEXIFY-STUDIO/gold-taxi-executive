importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyAK4G7fy6EVObmwI4bYe7l6UCpqAGeY7l4',
  authDomain: 'goldtaxi-202ff.firebaseapp.com',
  projectId: 'goldtaxi-202ff',
  storageBucket: 'goldtaxi-202ff.firebasestorage.app',
  messagingSenderId: '1007297424308',
  appId: '1:1007297424308:web:a2c533be04584179eca0e1',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const title = payload.notification?.title || 'GoldTaxi';
  const body = payload.notification?.body || 'New notification';
  const shellIndex = payload.data?.shellIndex || '0';

  self.registration.showNotification(title, {
    body,
    icon: '/favicon.png',
    badge: '/favicon.png',
    data: {
      shellIndex,
      route: payload.data?.route || '/app',
    },
  });
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const shellIndex = event.notification.data?.shellIndex || '0';
  const route = event.notification.data?.route || '/app';
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        if ('focus' in client) {
          client.focus();
          client.postMessage({ type: 'goldtaxi-notification', shellIndex, route });
          return;
        }
      }
      return clients.openWindow(route);
    }),
  );
});
