import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart' show StripeException;
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/router/app_router.dart';
import '../../core/services/payment_service.dart';
import '../../core/services/repositories.dart';
import '../../core/utils/formatting.dart';
import '../../core/widgets/common.dart';

class CartController extends Notifier<List<CartItem>> {
  @override
  List<CartItem> build() => const [];

  void add(Product p) {
    final i = state.indexWhere((c) => c.product.id == p.id);
    if (i == -1) {
      state = [...state, CartItem(product: p, quantity: 1)];
    } else {
      state = [
        for (var j = 0; j < state.length; j++)
          j == i
              ? state[j].copyWith(quantity: state[j].quantity + 1)
              : state[j],
      ];
    }
  }

  void setQuantity(String productId, int qty) {
    state = [
      for (final c in state)
        if (c.product.id != productId)
          c
        else if (qty > 0)
          c.copyWith(quantity: qty),
    ];
  }

  void clear() => state = const [];

  int get totalCents => state.fold(0, (s, c) => s + c.totalCents);
}

final cartProvider =
    NotifierProvider<CartController, List<CartItem>>(CartController.new);

/// Brand merchandise; a share of every order funds partner shelters.
class MarketplaceScreen extends ConsumerWidget {
  const MarketplaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final products = ref.watch(productsProvider);
    final cart = ref.watch(cartProvider);
    final locale = Localizations.localeOf(context).toString();
    return Scaffold(
      appBar: AppBar(
        title: Text(l.marketplaceTitle),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: cart.isNotEmpty,
              label: Text('${cart.fold(0, (s, c) => s + c.quantity)}'),
              child: const Icon(Icons.shopping_cart_outlined),
            ),
            onPressed: () => context.push(Routes.cart),
          ),
        ],
      ),
      body: AsyncBody(
        value: products,
        builder: (items) => items.isEmpty
            ? EmptyState(icon: Icons.storefront_outlined, message: l.emptyCart)
            : GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.72,
                ),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final p = items[i];
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AspectRatio(
                          aspectRatio: 1,
                          child: p.imageUrl == null
                              ? Container(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                                  child: const Center(
                                    child: Text('🐾',
                                        style: TextStyle(fontSize: 40)),
                                  ),
                                )
                              : Image.network(p.imageUrl!, fit: BoxFit.cover),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)),
                                const Spacer(),
                                Text(formatMoney(p.priceCents, locale: locale)),
                                Text(
                                  l.supportsCharities(p.charityShareBps ~/ 100),
                                  style: Theme.of(context).textTheme.labelSmall,
                                  maxLines: 2,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                          child: FilledButton.tonal(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(38),
                            ),
                            onPressed: () {
                              ref.read(cartProvider.notifier).add(p);
                              showSnack(context, '${p.name} ✓');
                            },
                            child: Text(l.addToCart),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});
  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  bool _busy = false;
  String? _charityId;

  Future<void> _checkout() async {
    final l = context.l10n;
    final cart = ref.read(cartProvider);
    setState(() => _busy = true);
    try {
      await ref.read(paymentServiceProvider).checkoutCart(
        items: [
          for (final c in cart)
            {'productId': c.product.id, 'quantity': c.quantity},
        ],
        charityId: _charityId,
        currency: 'usd',
      );
      ref.read(cartProvider.notifier).clear();
      if (!mounted) return;
      showSnack(context, l.orderPlaced);
      context.pop();
    } on StripeException {
      if (mounted) showSnack(context, l.donationFailed);
    } catch (_) {
      if (mounted) showSnack(context, l.errorGeneric);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cart = ref.watch(cartProvider);
    final charities = ref.watch(charitiesProvider).valueOrNull ?? const [];
    final locale = Localizations.localeOf(context).toString();
    final total = cart.fold(0, (s, c) => s + c.totalCents);
    return Scaffold(
      appBar: AppBar(title: Text(l.cart)),
      body: cart.isEmpty
          ? EmptyState(icon: Icons.shopping_cart_outlined, message: l.emptyCart)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final c in cart)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(c.product.name),
                      subtitle: Text(formatMoney(c.totalCents, locale: locale)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () => ref
                                .read(cartProvider.notifier)
                                .setQuantity(c.product.id, c.quantity - 1),
                          ),
                          Text('${c.quantity}'),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () => ref
                                .read(cartProvider.notifier)
                                .setQuantity(c.product.id, c.quantity + 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (charities.isNotEmpty) ...[
                  SectionHeader(l.chooseBeneficiary),
                  DropdownButtonFormField<String>(
                    initialValue: _charityId,
                    items: [
                      for (final c in charities)
                        DropdownMenuItem(value: c.id, child: Text(c.name)),
                    ],
                    onChanged: (v) => setState(() => _charityId = v),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Text(l.total,
                        style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    Text(formatMoney(total, locale: locale),
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _busy ? null : _checkout,
                  icon: const Icon(Icons.lock_outline),
                  label: Text(l.checkout),
                ),
              ],
            ),
    );
  }
}
