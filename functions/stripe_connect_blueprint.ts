import * as functions from "firebase-functions";
import Stripe from "stripe";

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, {
  apiVersion: "2025-06-30.basil",
});

export const createDriverExpressAccount = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Login required.");
  }

  const account = await stripe.accounts.create({
    type: "express",
    country: "CH",
    capabilities: {
      card_payments: { requested: true },
      transfers: { requested: true },
    },
  });

  const accountLink = await stripe.accountLinks.create({
    account: account.id,
    refresh_url: "https://goldtaxi.app/stripe/refresh",
    return_url: "https://goldtaxi.app/stripe/success",
    type: "account_onboarding",
  });

  return {
    accountId: account.id,
    onboardingUrl: accountLink.url,
  };
});

export const authorizeRidePayment = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Login required.");
  }

  const paymentIntent = await stripe.paymentIntents.create({
    amount: Math.round(data.estimatedAmount * 100),
    currency: data.currency ?? "chf",
    customer: data.stripeCustomerId,
    payment_method: data.paymentMethodId,
    confirm: true,
    capture_method: "manual",
    automatic_payment_methods: { enabled: true, allow_redirects: "never" },
    metadata: {
      ride_id: data.rideId,
      customer_id: context.auth.uid,
    },
  });

  return {
    paymentIntentId: paymentIntent.id,
    status: paymentIntent.status,
  };
});

export const captureRidePayment = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Login required.");
  }

  const finalAmount = Math.round(data.finalAmount * 100);
  const platformFee = Math.round(finalAmount * 0.20);

  const paymentIntent = await stripe.paymentIntents.capture(data.paymentIntentId, {
    amount_to_capture: finalAmount,
    application_fee_amount: platformFee,
    transfer_data: {
      destination: data.driverStripeAccountId,
    },
  });

  return {
    paymentIntentId: paymentIntent.id,
    status: paymentIntent.status,
  };
});
