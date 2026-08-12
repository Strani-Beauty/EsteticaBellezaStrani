importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyD_EKsUz3JfvlrZMRp3AD_1JYzcDVHnKv8',
  authDomain: 'esteticaybellezastrani.firebaseapp.com',
  projectId: 'esteticaybellezastrani',
  storageBucket: 'esteticaybellezastrani.firebasestorage.app',
  messagingSenderId: '462789521668',
  appId: '1:462789521668:web:5ba9ff512a0fece57ca051',
  measurementId: 'G-6WKMVSSDFS',
});

const messaging = firebase.messaging();