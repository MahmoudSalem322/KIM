import 'package:flutter/material.dart';

typedef AppDestination = ({String key, String path, IconData icon});
const destinations = <AppDestination>[
  (key: 'dashboard', path: '/', icon: Icons.grid_view_rounded),
  (
    key: 'wallets',
    path: '/wallets',
    icon: Icons.account_balance_wallet_outlined,
  ),
  (key: 'transactions', path: '/transactions', icon: Icons.swap_horiz_rounded),
  (key: 'budgets', path: '/budgets', icon: Icons.donut_large_rounded),
  (key: 'reports', path: '/reports', icon: Icons.bar_chart_rounded),
  (key: 'settings', path: '/settings', icon: Icons.tune_rounded),
];
