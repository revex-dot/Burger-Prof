/**
 * Seeds reference data (charities, experts, products, plans, impact updates).
 * Run against the emulator:  FIRESTORE_EMULATOR_HOST=localhost:8080 npm run seed
 * Or against production with GOOGLE_APPLICATION_CREDENTIALS set.
 */
import * as admin from "firebase-admin";

admin.initializeApp();
const db = admin.firestore();

async function main() {
  const batch = db.batch();

  const charities = [
    {
      id: "whiskers-haven",
      name: "Whiskers Haven Shelter",
      type: "shelter",
      location: "Portland, OR",
      description: "No-kill shelter caring for 120 cats at a time, with a focus on seniors and special-needs cats.",
      verified: true,
      totalReceivedCents: 0,
      donorCount: 0,
      catsHelped: 0,
    },
    {
      id: "street-paws-rescue",
      name: "Street Paws Rescue",
      type: "rescue",
      location: "Lisbon, Portugal",
      description: "TNR (trap-neuter-return) and feeding programme for 40 feral colonies.",
      verified: true,
      totalReceivedCents: 0,
      donorCount: 0,
      catsHelped: 0,
    },
    {
      id: "riverside-vet-clinic",
      name: "Riverside Community Vet Clinic",
      type: "vetClinic",
      location: "Leeds, UK",
      description: "Low-cost veterinary care for cats of families in financial hardship.",
      verified: true,
      totalReceivedCents: 0,
      donorCount: 0,
      catsHelped: 0,
    },
  ];
  for (const c of charities) {
    const { id, ...data } = c;
    batch.set(db.collection("charities").doc(id), data, { merge: true });
  }

  const experts = [
    {
      id: "dr-amara-osei",
      name: "Dr. Amara Osei",
      credentials: "DVM, Diplomate ACVB (Veterinary Behaviorist)",
      bio: "15 years helping families with litter-box issues, aggression and anxiety. Evidence-based, punishment-free.",
      specialties: ["Litter box", "Aggression", "Multi-cat homes"],
      ratePerSessionCents: 8900,
      languages: ["en", "fr"],
      rating: 4.9,
      reviewCount: 212,
    },
    {
      id: "lena-hoffmann",
      name: "Lena Hoffmann",
      credentials: "Certified Cat Behavior Consultant (IAABC)",
      bio: "Clicker training specialist. Loves turning 'impossible' cats into trick stars.",
      specialties: ["Clicker training", "Carrier & handling", "Enrichment"],
      ratePerSessionCents: 5900,
      languages: ["en", "de"],
      rating: 4.8,
      reviewCount: 143,
    },
  ];
  for (const e of experts) {
    const { id, ...data } = e;
    batch.set(db.collection("experts").doc(id), data, { merge: true });
  }

  const products = [
    { id: "tee-pawsitive", name: "Pawsitive Cat T-shirt", description: "Organic cotton, unisex.", priceCents: 2800, category: "apparel", stock: 100, charityShareBps: 2000 },
    { id: "clicker-kit", name: "Clicker training starter kit", description: "Soft-click clicker, treat pouch and quick-start card.", priceCents: 1500, category: "training", stock: 250, charityShareBps: 2500 },
    { id: "mug-slowblink", name: "Slow Blink mug", description: "Ceramic, 350 ml.", priceCents: 1600, category: "home", stock: 80, charityShareBps: 2000 },
  ];
  for (const p of products) {
    const { id, ...data } = p;
    batch.set(db.collection("products").doc(id), data, { merge: true });
  }

  const plans = [
    { tier: "free", name: "Free", monthlyPriceCents: 0, charityShareBps: 0, features: ["Core behavior guides", "Progress tracker for 1 cat", "Community forum & feed", "Daily reminders"] },
    { tier: "plus", name: "Plus", monthlyPriceCents: 499, charityShareBps: 3000, features: ["All premium guides", "Unlimited cats & goals", "Video gallery (10 GB)", "30% goes to partner shelters"] },
    { tier: "pro", name: "Pro", monthlyPriceCents: 1299, charityShareBps: 5000, features: ["Everything in Plus", "Expert consultations", "Priority support", "50% goes to partner shelters"] },
  ];
  for (const p of plans) {
    batch.set(db.collection("plans").doc(p.tier), p, { merge: true });
  }

  batch.set(db.collection("impactUpdates").doc("welcome"), {
    charityId: "whiskers-haven",
    charityName: "Whiskers Haven Shelter",
    title: "New quarantine room opened",
    body: "Thanks to app donations we built a 6-cage quarantine room so incoming cats get treated before joining the colony.",
    amountSpentCents: 320000,
    catsHelped: 48,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await batch.commit();
  console.log("Seed complete.");
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
