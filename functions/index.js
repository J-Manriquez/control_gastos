const functions = require('firebase-functions');
const admin = require('firebase-admin');
const cors = require('cors')({origin: true});
const crypto = require('crypto');
const mercadopago = require('mercadopago');

// Inicializar Firebase Admin
admin.initializeApp();

// Configurar Mercado Pago
mercadopago.configure({
  access_token: process.env.MERCADO_PAGO_ACCESS_TOKEN
});

// 🔥 FUNCIÓN 1: Crear Preferencia de Pago
exports.createPaymentPreference = functions.https.onCall(async (data, context) => {
  try {
    console.log('🎯 Creando preferencia de pago:', data);
    
    // Validar autenticación
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Usuario no autenticado');
    }
    
    const { title, price, userEmail, userId, planType } = data;
    
    // Crear preferencia
    const preference = {
      items: [{
        title: title,
        quantity: 1,
        unit_price: parseFloat(price),
        currency_id: 'COP' // Cambiar según tu país
      }],
      payer: {
        email: userEmail
      },
      external_reference: userId,
      notification_url: `https://us-central1-${process.env.GCLOUD_PROJECT}.cloudfunctions.net/mercadoPagoWebhook`,
      back_urls: {
        success: 'https://tu-app.com/success',
        failure: 'https://tu-app.com/failure',
        pending: 'https://tu-app.com/pending'
      },
      auto_return: 'approved',
      metadata: {
        plan_type: planType,
        user_id: userId
      }
    };
    
    const response = await mercadopago.preferences.create(preference);
    
    console.log('✅ Preferencia creada:', response.body.id);
    
    return {
      id: response.body.id,
      init_point: response.body.init_point,
      sandbox_init_point: response.body.sandbox_init_point
    };
    
  } catch (error) {
    console.error('❌ Error creando preferencia:', error);
    throw new functions.https.HttpsError('internal', 'Error creando preferencia de pago');
  }
});

// 🔥 FUNCIÓN 2: Webhook de Mercado Pago
exports.mercadoPagoWebhook = functions.https.onRequest(async (req, res) => {
  return cors(req, res, async () => {
    try {
      console.log('🔔 Webhook recibido:', req.body);
      
      // Validar signature (opcional pero recomendado)
      const signature = req.headers['x-signature'];
      if (signature) {
        const isValid = validateSignature(req.body, signature);
        if (!isValid) {
          console.log('❌ Signature inválida');
          return res.status(401).send('Unauthorized');
        }
      }
      
      const { type, data } = req.body;
      
      if (type === 'payment') {
        const paymentId = data.id;
        
        // Obtener detalles del pago
        const payment = await mercadopago.payment.findById(paymentId);
        const paymentData = payment.body;
        
        console.log('💰 Estado del pago:', paymentData.status);
        
        if (paymentData.status === 'approved') {
          // Actualizar usuario en Firestore
          await updateUserSubscription(paymentData);
        }
      }
      
      res.status(200).send('OK');
      
    } catch (error) {
      console.error('❌ Error en webhook:', error);
      res.status(500).send('Error');
    }
  });
});

// 🔥 FUNCIÓN 3: Verificar Estado de Pago
exports.checkPaymentStatus = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Usuario no autenticado');
    }
    
    const { paymentId } = data;
    const payment = await mercadopago.payment.findById(paymentId);
    
    return {
      status: payment.body.status,
      status_detail: payment.body.status_detail
    };
    
  } catch (error) {
    console.error('❌ Error verificando pago:', error);
    throw new functions.https.HttpsError('internal', 'Error verificando estado del pago');
  }
});

// 🛠️ Función auxiliar: Actualizar suscripción del usuario
async function updateUserSubscription(paymentData) {
  try {
    const userId = paymentData.external_reference;
    const planType = paymentData.metadata.plan_type;
    
    console.log(`✅ Actualizando usuario ${userId} a plan ${planType}`);
    
    await admin.firestore().collection('usuarios').doc(userId).update({
      userType: 'pro',
      subscriptionType: planType,
      subscriptionDate: admin.firestore.FieldValue.serverTimestamp(),
      lastPaymentDate: admin.firestore.FieldValue.serverTimestamp(),
      paymentId: paymentData.id,
      paymentAmount: paymentData.transaction_amount
    });
    
    console.log('🎉 Usuario actualizado exitosamente');
    
  } catch (error) {
    console.error('❌ Error actualizando usuario:', error);
  }
}

// 🛠️ Función auxiliar: Validar signature
function validateSignature(body, signature) {
  try {
    const secret = process.env.MERCADO_PAGO_WEBHOOK_SECRET;
    const hash = crypto.createHmac('sha256', secret)
                      .update(JSON.stringify(body))
                      .digest('hex');
    return hash === signature;
  } catch (error) {
    console.error('Error validando signature:', error);
    return false;
  }
}
