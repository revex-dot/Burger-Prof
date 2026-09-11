/**
 * Pawsitive Cat – backend (Cloud Functions for Firebase on Google Cloud).
 *
 * Responsibilities
 *  - Stripe: donations, subscriptions, merch orders, customer portal.
 *  - Charity routing: every payment is split into fee / net and credited to
 *    the beneficiary in a transparent ledger (`donations`, `charities`).
 *  - Push notifications: daily-reminder nudges, community replies, impact
 *    updates and weekly engagement tips via FCM.
 *
 * Secrets (never in code): STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET.
 */
import * as admin from "firebase-admin";
import { logger } from "firebase-functions";
import { defineSecret, defineString } from "firebase-functions/params";
import { HttpsError, onCall, onRequest } from "firebase-functions/v2/https";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import Stripe from "stripe";

admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();

const stripeSecret = defineSecret("STRIPE_SECRET_KEY");
const webhookSecret = defineSecret("STRIPE_WEBHOOK_SECRET");
const pricePlus = defineString("STRIPE_PRICE_PLUS");
const pricePro = defineString("STRIPE_PRICE_PRO");
const returnUrl = defineString("APP_RETURN_URL", {
  default: "https://pawsitivecat.app/account",
});

/** Donation processing fee in basis points. Must match the Flutter client. */
const DONATION_FEE_BPS = 500;
/** Share of subscription revenue forwarded to charities, per tier. */
const SUBSCRIPTION_CHARITY_BPS: Record<string, number> = { plus: 3000, pro: 5000 };
/** Default share of merch revenue forwarded to charities. */
const MERCH_CHARITY_BPS = 2000;

const stripe = () =>
  new Stripe(stripeSecret.value(), { apiVersion: "2025-02-24.acacia" });

type Tier = "plus" | "pro";

const bps = (cents: number, share: number) => Math.round((cents * share) / 10000);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

async function getOrCreateCustomer(uid: string): Promise<string> {
  const ref = db.collection("users").doc(uid);
  const snap = await ref.get();
  const existing = snap.get("stripeCustomerId") as string | undefined;
  if (existing) return existing;
  const customer = await stripe().customers.create({
    email: snap.get("email"),
    name: snap.get("displayName"),
    metadata: { uid },
  });
  await ref.set({ stripeCustomerId: customer.id }, { merge: true });
  return customer.id;
}

async function sheetPayload(customerId: string, clientSecret: string) {
  const ephemeralKey = await stripe().ephemeralKeys.create(
    { customer: customerId },
    { apiVersion: "2025-02-24.acacia" }
  );
  return { clientSecret, customerId, ephemeralKey: ephemeralKey.secret };
}

function requireAuth(uid: string | undefined): string {
  if (!uid) throw new HttpsError("unauthenticated", "Sign in first.");
  return uid;
}

async function pickDefaultCharity(): Promise<string | null> {
  // Round-robin-ish: the verified partner with the lowest total so far.
  const snap = await db
    .collection("charities")
    .where("verified", "==", true)
    .orderBy("totalReceivedCents", "asc")
    .limit(1)
    .get();
  return snap.empty ? null : snap.docs[0].id;
}

// ---------------------------------------------------------------------------
// Donations
// ---------------------------------------------------------------------------

export const createDonationIntent = onCall(
  { secrets: [stripeSecret] },
  async (req) => {
    const uid = requireAuth(req.auth?.uid);
    const { charityId, amountCents, currency = "usd", message } = req.data ?? {};
    if (typeof amountCents !== "number" || amountCents < 100 || amountCents > 1_000_000) {
      throw new HttpsError("invalid-argument", "Amount must be between 1 and 10,000.");
    }
    const charity = await db.collection("charities").doc(String(charityId)).get();
    if (!charity.exists || !charity.get("verified")) {
      throw new HttpsError("not-found", "Unknown or unverified charity.");
    }

    const feeCents = bps(amountCents, DONATION_FEE_BPS);
    const netCents = amountCents - feeCents;
    const customerId = await getOrCreateCustomer(uid);

    const donationRef = db.collection("donations").doc();
    const intent = await stripe().paymentIntents.create({
      amount: amountCents,
      currency,
      customer: customerId,
      automatic_payment_methods: { enabled: true },
      description: `Donation to ${charity.get("name")}`,
      metadata: { kind: "donation", uid, charityId, donationId: donationRef.id },
    });

    await donationRef.set({
      userId: uid,
      charityId,
      charityName: charity.get("name"),
      amountCents,
      feeCents,
      netCents,
      currency,
      status: "pending",
      source: "one_time",
      message: message ?? null,
      stripePaymentIntentId: intent.id,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return sheetPayload(customerId, intent.client_secret!);
  }
);

// ---------------------------------------------------------------------------
// Subscriptions
// ---------------------------------------------------------------------------

export const createSubscription = onCall(
  { secrets: [stripeSecret] },
  async (req) => {
    const uid = requireAuth(req.auth?.uid);
    const tier = String(req.data?.tier ?? "") as Tier;
    const price = tier === "plus" ? pricePlus.value() : tier === "pro" ? pricePro.value() : null;
    if (!price) throw new HttpsError("invalid-argument", "Unknown tier.");

    const customerId = await getOrCreateCustomer(uid);
    const sub = await stripe().subscriptions.create({
      customer: customerId,
      items: [{ price }],
      payment_behavior: "default_incomplete",
      payment_settings: { save_default_payment_method: "on_subscription" },
      expand: ["latest_invoice.payment_intent"],
      metadata: { uid, tier },
    });
    const invoice = sub.latest_invoice as Stripe.Invoice;
    const intent = invoice.payment_intent as Stripe.PaymentIntent;
    return sheetPayload(customerId, intent.client_secret!);
  }
);

export const createPortalLink = onCall({ secrets: [stripeSecret] }, async (req) => {
  const uid = requireAuth(req.auth?.uid);
  const customerId = await getOrCreateCustomer(uid);
  const session = await stripe().billingPortal.sessions.create({
    customer: customerId,
    return_url: returnUrl.value(),
  });
  return { url: session.url };
});

// ---------------------------------------------------------------------------
// Marketplace
// ---------------------------------------------------------------------------

export const createOrderIntent = onCall({ secrets: [stripeSecret] }, async (req) => {
  const uid = requireAuth(req.auth?.uid);
  const items = (req.data?.items ?? []) as { productId: string; quantity: number }[];
  const currency = String(req.data?.currency ?? "usd");
  if (!Array.isArray(items) || items.length === 0) {
    throw new HttpsError("invalid-argument", "Cart is empty.");
  }
  const charityId = (req.data?.charityId as string | undefined) ?? (await pickDefaultCharity());

  // Prices are always taken from Firestore, never trusted from the client.
  let totalCents = 0;
  let charityCents = 0;
  const lines: Record<string, unknown>[] = [];
  for (const item of items) {
    const qty = Math.max(1, Math.min(20, Number(item.quantity) || 1));
    const product = await db.collection("products").doc(String(item.productId)).get();
    if (!product.exists) throw new HttpsError("not-found", `Product ${item.productId}`);
    if ((product.get("stock") ?? 0) < qty) {
      throw new HttpsError("failed-precondition", `${product.get("name")} is out of stock.`);
    }
    const unit = product.get("priceCents") as number;
    const line = unit * qty;
    totalCents += line;
    charityCents += bps(line, product.get("charityShareBps") ?? MERCH_CHARITY_BPS);
    lines.push({ productId: product.id, name: product.get("name"), unitCents: unit, quantity: qty });
  }

  const customerId = await getOrCreateCustomer(uid);
  const orderRef = db.collection("orders").doc();
  const intent = await stripe().paymentIntents.create({
    amount: totalCents,
    currency,
    customer: customerId,
    automatic_payment_methods: { enabled: true },
    metadata: { kind: "order", uid, orderId: orderRef.id, charityId: charityId ?? "", charityCents },
  });
  await orderRef.set({
    userId: uid,
    items: lines,
    totalCents,
    charityCents,
    charityId,
    currency,
    status: "pending",
    stripePaymentIntentId: intent.id,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  return sheetPayload(customerId, intent.client_secret!);
});

// ---------------------------------------------------------------------------
// Stripe webhook – the single source of truth for payment state
// ---------------------------------------------------------------------------

export const stripeWebhook = onRequest(
  { secrets: [stripeSecret, webhookSecret] },
  async (req, res) => {
    let event: Stripe.Event;
    try {
      event = stripe().webhooks.constructEvent(
        req.rawBody,
        req.headers["stripe-signature"] as string,
        webhookSecret.value()
      );
    } catch (err) {
      logger.warn("Webhook signature verification failed", err);
      res.status(400).send("Invalid signature");
      return;
    }

    // Idempotency: Stripe retries; process each event once.
    const eventRef = db.collection("stripeEvents").doc(event.id);
    if ((await eventRef.get()).exists) {
      res.json({ received: true, duplicate: true });
      return;
    }
    await eventRef.set({ type: event.type, createdAt: admin.firestore.FieldValue.serverTimestamp() });

    try {
      switch (event.type) {
        case "payment_intent.succeeded":
          await onPaymentSucceeded(event.data.object as Stripe.PaymentIntent);
          break;
        case "payment_intent.payment_failed":
          await onPaymentFailed(event.data.object as Stripe.PaymentIntent);
          break;
        case "invoice.paid":
          await onInvoicePaid(event.data.object as Stripe.Invoice);
          break;
        case "customer.subscription.updated":
        case "customer.subscription.deleted":
          await onSubscriptionChanged(event.data.object as Stripe.Subscription);
          break;
        case "charge.refunded":
          await onRefund(event.data.object as Stripe.Charge);
          break;
        default:
          break;
      }
      res.json({ received: true });
    } catch (err) {
      logger.error("Webhook handler failed", err);
      res.status(500).send("Handler error");
    }
  }
);

async function creditCharity(
  charityId: string,
  netCents: number,
  userId: string,
  source: string,
  extra: Record<string, unknown> = {}
) {
  const charityRef = db.collection("charities").doc(charityId);
  await db.runTransaction(async (tx) => {
    const charity = await tx.get(charityRef);
    if (!charity.exists) return;
    tx.update(charityRef, {
      totalReceivedCents: admin.firestore.FieldValue.increment(netCents),
      donorCount: admin.firestore.FieldValue.increment(1),
    });
    tx.set(db.collection("users").doc(userId), {
      totalDonatedCents: admin.firestore.FieldValue.increment(netCents),
    }, { merge: true });
    if (source !== "one_time") {
      // Subscription / merch shares are recorded as donations too so users
      // see every cent in their history.
      tx.set(db.collection("donations").doc(), {
        userId,
        charityId,
        charityName: charity.get("name"),
        amountCents: netCents,
        feeCents: 0,
        netCents,
        currency: "usd",
        status: "succeeded",
        source,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        ...extra,
      });
    }
  });
}

async function onPaymentSucceeded(pi: Stripe.PaymentIntent) {
  const m = pi.metadata ?? {};
  if (m.kind === "donation") {
    const ref = db.collection("donations").doc(m.donationId);
    const snap = await ref.get();
    if (!snap.exists || snap.get("status") === "succeeded") return;
    await ref.update({ status: "succeeded", paidAt: admin.firestore.FieldValue.serverTimestamp() });
    await creditCharity(m.charityId, snap.get("netCents"), m.uid, "one_time");
    await notifyUser(m.uid, "Thank you! 💛", `Your donation to ${snap.get("charityName")} went through.`);
  } else if (m.kind === "order") {
    const ref = db.collection("orders").doc(m.orderId);
    const snap = await ref.get();
    if (!snap.exists || snap.get("status") === "paid") return;
    await ref.update({ status: "paid", paidAt: admin.firestore.FieldValue.serverTimestamp() });
    // Decrement stock.
    const batch = db.batch();
    for (const line of snap.get("items") as { productId: string; quantity: number }[]) {
      batch.update(db.collection("products").doc(line.productId), {
        stock: admin.firestore.FieldValue.increment(-line.quantity),
      });
    }
    await batch.commit();
    const charityId = m.charityId || (await pickDefaultCharity());
    const charityCents = Number(m.charityCents) || 0;
    if (charityId && charityCents > 0) {
      await creditCharity(charityId, charityCents, m.uid, "marketplace", { orderId: m.orderId });
    }
  }
}

async function onPaymentFailed(pi: Stripe.PaymentIntent) {
  const m = pi.metadata ?? {};
  if (m.kind === "donation") {
    await db.collection("donations").doc(m.donationId).set({ status: "failed" }, { merge: true });
  } else if (m.kind === "order") {
    await db.collection("orders").doc(m.orderId).set({ status: "failed" }, { merge: true });
  }
}

async function onInvoicePaid(invoice: Stripe.Invoice) {
  if (!invoice.subscription) return;
  const sub = await stripe().subscriptions.retrieve(String(invoice.subscription));
  const uid = sub.metadata?.uid;
  const tier = sub.metadata?.tier as Tier | undefined;
  if (!uid || !tier) return;
  await db.collection("users").doc(uid).set(
    { tier, subscriptionStatus: sub.status, subscriptionId: sub.id },
    { merge: true }
  );
  const share = SUBSCRIPTION_CHARITY_BPS[tier] ?? 0;
  const charityCents = bps(invoice.amount_paid, share);
  const charityId = await pickDefaultCharity();
  if (charityId && charityCents > 0) {
    await creditCharity(charityId, charityCents, uid, "subscription", { invoiceId: invoice.id });
  }
}

async function onSubscriptionChanged(sub: Stripe.Subscription) {
  const uid = sub.metadata?.uid;
  if (!uid) return;
  const active = sub.status === "active" || sub.status === "trialing";
  await db.collection("users").doc(uid).set(
    {
      tier: active ? (sub.metadata?.tier ?? "plus") : "free",
      subscriptionStatus: sub.status,
    },
    { merge: true }
  );
}

async function onRefund(charge: Stripe.Charge) {
  const piId = typeof charge.payment_intent === "string" ? charge.payment_intent : charge.payment_intent?.id;
  if (!piId) return;
  const snap = await db.collection("donations").where("stripePaymentIntentId", "==", piId).limit(1).get();
  if (snap.empty) return;
  const d = snap.docs[0];
  await d.ref.update({ status: "refunded" });
  await db.collection("charities").doc(d.get("charityId")).update({
    totalReceivedCents: admin.firestore.FieldValue.increment(-d.get("netCents")),
  });
}

// ---------------------------------------------------------------------------
// Push notifications (engagement)
// ---------------------------------------------------------------------------

async function notifyUser(uid: string, title: string, body: string, data: Record<string, string> = {}) {
  const user = await db.collection("users").doc(uid).get();
  const tokens = (user.get("fcmTokens") as string[] | undefined) ?? [];
  if (tokens.length === 0) return;
  const res = await messaging.sendEachForMulticast({
    tokens,
    notification: { title, body },
    data,
    android: { priority: "high" },
    apns: { payload: { aps: { sound: "default" } } },
  });
  // Prune dead tokens.
  const dead = tokens.filter((_, i) => {
    const code = res.responses[i].error?.code;
    return code === "messaging/registration-token-not-registered";
  });
  if (dead.length > 0) {
    await user.ref.update({ fcmTokens: admin.firestore.FieldValue.arrayRemove(...dead) });
  }
}

/** Reply notification for community comments. */
export const onCommentCreated = onDocumentCreated(
  "posts/{postId}/comments/{commentId}",
  async (event) => {
    const comment = event.data?.data();
    if (!comment) return;
    const post = await db.collection("posts").doc(event.params.postId).get();
    const authorId = post.get("authorId") as string | undefined;
    if (!authorId || authorId === comment.authorId) return;
    await notifyUser(
      authorId,
      `${comment.authorName} replied to "${post.get("title")}"`,
      String(comment.body).slice(0, 120),
      { route: `/community/post/${event.params.postId}` }
    );
  }
);

/** Expert replies inside a consultation thread. */
export const onConsultationMessage = onDocumentCreated(
  "consultations/{consultationId}/messages/{messageId}",
  async (event) => {
    const msg = event.data?.data();
    if (!msg) return;
    const consultation = await db.collection("consultations").doc(event.params.consultationId).get();
    const userId = consultation.get("userId") as string;
    if (msg.senderId === userId) return; // user's own message
    await notifyUser(
      userId,
      `${consultation.get("expertName")} replied`,
      String(msg.text).slice(0, 120),
      { route: `/consultations/${event.params.consultationId}` }
    );
  }
);

/** Transparency: when a partner posts an impact update, tell everyone who
 * opted into engagement pushes. */
export const onImpactUpdate = onDocumentCreated("impactUpdates/{id}", async (event) => {
  const u = event.data?.data();
  if (!u) return;
  await messaging.send({
    topic: "engagement",
    notification: { title: `${u.charityName}: ${u.title}`, body: String(u.body).slice(0, 140) },
    data: { route: "/give" },
  });
});

/** Weekly engagement tip, Mondays 10:00 UTC. */
export const weeklyTip = onSchedule("0 10 * * 1", async () => {
  const tips = [
    "Reward within two seconds – timing is what teaches your cat.",
    "Five minutes of training beats an hour. End while your cat wants more.",
    "Play like prey: move the toy away and let your cat catch it at the end.",
    "Check the Give tab – our partners posted new impact reports this week.",
  ];
  const tip = tips[Math.floor(Date.now() / 604_800_000) % tips.length];
  await messaging.send({
    topic: "engagement",
    notification: { title: "Weekly cat tip 🐾", body: tip },
    data: { route: "/home" },
  });
});

/** Re-engagement: nudge users who haven't logged a session in 3 days. */
export const inactivityNudge = onSchedule("0 17 * * *", async () => {
  const cutoff = admin.firestore.Timestamp.fromMillis(Date.now() - 3 * 86_400_000);
  const users = await db.collection("users").where("lastSessionAt", "<", cutoff).limit(500).get();
  await Promise.all(
    users.docs.map((u) =>
      notifyUser(u.id, "Your cat misses training 🐱", "A quick 5-minute session keeps the streak alive.", {
        route: "/train",
      })
    )
  );
});

/** Keep `lastSessionAt` on the user doc for the nudge above. */
export const onSessionLogged = onDocumentCreated("users/{uid}/sessions/{id}", async (event) => {
  await db.collection("users").doc(event.params.uid).set(
    { lastSessionAt: admin.firestore.FieldValue.serverTimestamp() },
    { merge: true }
  );
});
