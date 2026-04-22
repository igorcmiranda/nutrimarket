const { onDocumentCreated } = require('firebase-functions/v2/firestore')
const { onRequest } = require('firebase-functions/v2/https')
const admin = require('firebase-admin')
const serviceAccount = require('./serviceAccountKey.json')

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
})

exports.sendPushNotification = onRequest(
  { invoker: 'public' },
  async (req, res) => {
    res.set('Access-Control-Allow-Origin', '*')
    if (req.method === 'OPTIONS') {
      res.set('Access-Control-Allow-Methods', 'POST')
      res.set('Access-Control-Allow-Headers', 'Content-Type')
      res.status(204).send('')
      return
    }
    const { token, title, body, data } = req.body
    if (!token || !title || !body) {
      res.status(400).json({ error: 'campos obrigatórios faltando' })
      return
    }
    try {
      const result = await admin.messaging().send({
        token,
        notification: { title, body },
        data: data || {},
        apns: {
          headers: {
            'apns-priority': '10',
            'apns-push-type': 'alert'
          },
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
              'content-available': 1
            }
          }
        },
        android: { priority: 'high' }
      })
      res.status(200).json({ success: true, messageId: result })
    } catch (error) {
      console.error('❌ Erro send:', error.message)
      res.status(500).json({ error: error.message })
    }
  }
)

exports.onNotificationCreated = onDocumentCreated(
  'notifications/{userId}/items/{itemId}',
  async (event) => {
    const userId = event.params.userId
    const notification = event.data.data()

    const userDoc = await admin.firestore().collection('users').doc(userId).get()
    const fcmToken = userDoc.data()?.fcmToken
    if (!fcmToken) return null

    let title
    if (notification.type === 'new_follower') {
      title = notification.message?.includes('parou')
        ? '😢 Menos um seguidor'
        : '👤 Novo seguidor!'
    } else {
      const titles = {
        new_like: '❤️ Nova curtida',
        new_comment: '💬 Novo comentário',
        new_post: '📸 Nova publicação',
        challenge_received: '🏆 Novo desafio!',
        challenge_accepted: '✅ Desafio encerrado!',
        new_message: '💬 Nova mensagem'
      }
      title = titles[notification.type] || '🔔 Vyro'
    }

    const body = notification.message || 'Você tem uma nova notificação'

    try {
      const result = await admin.messaging().send({
        token: fcmToken,
        notification: { title, body },
        data: {
          type: notification.type || '',
          postID: notification.postID || '',
          challengeID: notification.challengeID || ''
        },
        apns: {
          headers: {
            'apns-priority': '10',
            'apns-push-type': 'alert'
          },
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
              'content-available': 1
            }
          }
        },
        android: { priority: 'high' }
      })
      console.log('✅ Push enviado:', result)
    } catch (error) {
      console.error('❌ Erro:', error.message)
    }

    return null
  }
)

exports.handleVerification = onRequest(
  { invoker: 'public' },
  async (req, res) => {
    const { uid, action } = req.query

    if (!uid || !action) {
      res.status(400).send('<h1>Link inválido</h1>')
      return
    }

    try {
      if (action === 'accept') {
        // Verifica o usuário
        await admin.firestore().collection('users').doc(uid).update({
          isVerified: true
        })

        await admin.firestore().collection('verificationRequests').doc(uid).update({
          status: 'approved',
          resolvedAt: admin.firestore.Timestamp.now()
        })

        // Notifica o usuário
        const userDoc = await admin.firestore().collection('users').doc(uid).get()
        const fcmToken = userDoc.data()?.fcmToken
        const userName = userDoc.data()?.name || 'Usuário'

        if (fcmToken) {
          await admin.messaging().send({
            token: fcmToken,
            notification: {
              title: '✦ Conta verificada!',
              body: 'Parabéns! Sua conta foi verificada no Vyro.'
            },
            apns: {
              headers: { 'apns-priority': '10' },
              payload: { aps: { sound: 'default', badge: 1 } }
            }
          })
        }

        res.status(200).send(`
          <!DOCTYPE html>
          <html>
          <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Vyro — Verificação</title>
            <style>
              body { font-family: -apple-system, sans-serif; display: flex; justify-content: center; align-items: center; min-height: 100vh; margin: 0; background: #f2f2f7; }
              .card { background: white; border-radius: 20px; padding: 40px; text-align: center; max-width: 400px; box-shadow: 0 4px 20px rgba(0,0,0,0.1); }
              .icon { font-size: 64px; margin-bottom: 16px; }
              h1 { color: #1c1c1e; margin-bottom: 8px; }
              p { color: #6c6c70; }
              .badge { color: #FFD700; font-size: 24px; }
            </style>
          </head>
          <body>
            <div class="card">
              <div class="icon">✅</div>
              <div class="badge">✦ Verificado</div>
              <h1>${userName} foi verificado!</h1>
              <p>O usuário receberá uma notificação e o selo dourado aparecerá no perfil dele.</p>
            </div>
          </body>
          </html>
        `)

      } else if (action === 'deny') {
        await admin.firestore().collection('verificationRequests').doc(uid).update({
          status: 'denied',
          resolvedAt: admin.firestore.Timestamp.now()
        })

        // Salva data da recusa para cooldown de 6 meses
        await admin.firestore().collection('users').doc(uid).update({
          verificationDeniedAt: admin.firestore.Timestamp.now()
        })

        res.status(200).send(`
          <!DOCTYPE html>
          <html>
          <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Vyro — Verificação</title>
            <style>
              body { font-family: -apple-system, sans-serif; display: flex; justify-content: center; align-items: center; min-height: 100vh; margin: 0; background: #f2f2f7; }
              .card { background: white; border-radius: 20px; padding: 40px; text-align: center; max-width: 400px; box-shadow: 0 4px 20px rgba(0,0,0,0.1); }
              .icon { font-size: 64px; margin-bottom: 16px; }
              h1 { color: #1c1c1e; margin-bottom: 8px; }
              p { color: #6c6c70; }
            </style>
          </head>
          <body>
            <div class="card">
              <div class="icon">❌</div>
              <h1>Solicitação recusada</h1>
              <p>O usuário poderá solicitar novamente em 6 meses.</p>
            </div>
          </body>
          </html>
        `)
      }
    } catch (error) {
      console.error('Erro na verificação:', error)
      res.status(500).send('<h1>Erro ao processar verificação</h1>')
    }
  }
)

exports.sendVerificationRequest = onRequest(
  { invoker: 'public' },
  async (req, res) => {
    res.set('Access-Control-Allow-Origin', '*')
    if (req.method === 'OPTIONS') {
      res.set('Access-Control-Allow-Methods', 'POST')
      res.set('Access-Control-Allow-Headers', 'Content-Type')
      res.status(204).send('')
      return
    }

    const { userName, username, userEmail, userId, customSubject, customHtml } = req.body

    const nodemailer = require('nodemailer')
    const transporter = nodemailer.createTransport({
      service: 'gmail',
      auth: {
        user: 'igorcmiranda3110@gmail.com',
        pass: 'fsoijnbvvlztplwa'
      }
    })

    const acceptURL = `https://us-central1-nutrimarket.cloudfunctions.net/handleVerification?uid=${userId}&action=accept`
    const denyURL = `https://us-central1-nutrimarket.cloudfunctions.net/handleVerification?uid=${userId}&action=deny`

    const subject = customSubject || `Pedido de verificação — ${userName}`
    const html = customHtml || `
      <h2>Pedido de verificação — Vyro</h2>
      <p><strong>Nome:</strong> ${userName}</p>
      <p><strong>@:</strong> ${username}</p>
      <p><strong>Email:</strong> ${userEmail}</p>
      <p><strong>UID:</strong> ${userId}</p>
      <br>
      <a href="${acceptURL}" style="background:#34C759;color:white;padding:12px 24px;border-radius:8px;text-decoration:none;margin-right:12px">✓ Verificar usuário</a>
      <a href="${denyURL}" style="background:#FF3B30;color:white;padding:12px 24px;border-radius:8px;text-decoration:none">✗ Recusar</a>
    `

    const mailOptions = {
      from: 'Vyro App <igorcmiranda3110@gmail.com>',
      to: 'igorcmiranda3110@gmail.com',
      subject,
      html
    }

    try {
      await transporter.sendMail(mailOptions)
      res.status(200).json({ success: true })
    } catch (error) {
      console.error('❌ Erro:', error.message)
      res.status(500).json({ error: error.message })
    }
  }
)