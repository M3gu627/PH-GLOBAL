importScripts("https://www.gstatic.com/firebasejs/10.0.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.0.0/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyA2Pdu5WZZhEIawK_MG3bkPb5suzBuDur4",
  authDomain: "ph-global.firebaseapp.com",
  projectId: "ph-global",
  storageBucket: "ph-global.firebasestorage.app",
  messagingSenderId: "892347806970",
  appId: "1:892347806970:web:8e845d2c3f3c8ab64a4543",
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  self.registration.showNotification(payload.notification.title, {
    body: payload.notification.body,
  });
});